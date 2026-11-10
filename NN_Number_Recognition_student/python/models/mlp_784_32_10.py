"""
Model ID 1: MLP 784-32-10

    28x28 image --> 784 inputs --> 32 hidden neurons (ReLU) --> 10 outputs (one for each digit)

    input layer     hidden layer          output layer
    x0 ... x783 --> h0 ... h31  (ReLU) --> s0 ... s9   --> digit = index of the largest score

Each hidden neuron is a perceptron with 784 inputs: h = ReLU(sum(w * x) + b).
Each output neuron is a perceptron with 32 inputs:  s = sum(w * h) + b.
The hardware does the same calculation with one shared MAC (DESIGN_NOTES.md, 8.3).

Parameters: 784*32 + 32 (W1, b1) + 32*10 + 10 (W2, b2) = 25,450.

This file is the plug-in for this model (DESIGN_NOTES.md, section 10.1):
    build_torch()      float PyTorch model (training)
    quantize()         float weights -> integer parameters
    int_forward()      bit-exact integer model: the reference for the Verilog
    pack(), unpack()   integer parameters <-> weight blob (the bytes sent to the FPGA)
    extreme_params()   parameter sets with extreme values, for the Verilog tests

----------------------------------------------------------------------------------
Integer calculation (all values are integers; "scale 2^-k" means the integer
2^k stands for 1.0):

    x    uint7   0..127        scale 2^-7          (the pixels from the GUI)
    W1   int8    -128..127     scale 2^-k1
    b1   int16                 scale 2^-(7+k1)     (the scale of x*W1)
    acc1 = sum(x * W1) + b1    int32, scale 2^-(7+k1)
    h    = sat_0_255( round_shift( max(acc1, 0), s1 ) )      s1 = 7 + k1 - kh
         uint8   0..255        scale 2^-kh
    W2   int8                  scale 2^-k2
    b2   int16                 scale 2^-(kh+k2)
    acc2 = sum(h * W2) + b2    int32, scale 2^-(kh+k2)
    digit  = first index of the largest acc2 (a tie goes to the lower digit)
    scores = sat_int16( round_shift(acc2, s2) )               s2 = kh + k2 - 8
             -> scores are in Q8.8: 256 means 1.0

The argmax uses acc2 (32 bits), not the scores, so score saturation never changes
the digit. The scores are for display only.
----------------------------------------------------------------------------------
"""

import numpy as np
import torch
from torch import nn

from fixed_point import check_width, round_shift, saturate, to_fixed

MODEL_ID = 1
NAME = "mlp_784_32_10"
HIDDEN = 32
N_IN = 28 * 28
N_OUT = 10
X_FRAC = 7                     # pixel scale 2^-7
SCORE_FRAC = 8                 # scores in Q8.8
BLOB_BYTES = 4 + N_IN * HIDDEN + 2 * HIDDEN + HIDDEN * N_OUT + 2 * N_OUT   # 25,496


# ---------------------------------------------------------------------------
# Float model (training)
# ---------------------------------------------------------------------------
class MLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.hidden = nn.Linear(N_IN, HIDDEN)      # W1: 32 x 784, b1: 32
        self.output = nn.Linear(HIDDEN, N_OUT)     # W2: 10 x 32,  b2: 10

    def forward(self, x):
        """x: a batch of images, shape [batch, 28, 28]. Returns 10 scores for each image."""
        x = x.flatten(start_dim=1)                 # [batch, 28, 28] -> [batch, 784], row by row
        h = torch.relu(self.hidden(x))             # ReLU(x) = max(0, x)
        return self.output(h)                      # raw scores; no softmax (argmax gives the digit)


def build_torch():
    """Return a new float model with random start weights."""
    return MLP()


# ---------------------------------------------------------------------------
# Integer model (hardware reference)
# ---------------------------------------------------------------------------
def _matmul_exact(a, b):
    """
    Integer matrix product. float64 holds every integer below 2^53 exactly, and here
    every product and partial sum is below 2^25, so the float64 product is exact and
    much faster than an int64 product in NumPy. The result is converted back to int64.
    """
    return np.rint(a.astype(np.float64) @ b.astype(np.float64)).astype(np.int64)


def int_forward(params, x_q):
    """
    Bit-exact integer model.
    x_q: pixels 0..127, shape [N, 28, 28] or [N, 784].
    Returns a dict: digit [N], scores [N, 10] (int16, Q8.8), and the trace values
    acc1 [N, 32], hidden [N, 32], acc2 [N, 10] for debugging the Verilog.
    """
    x = np.asarray(x_q, dtype=np.int64).reshape(-1, N_IN)
    if x.min() < 0 or x.max() > 127:
        raise ValueError("pixels must be 0..127")

    acc1 = _matmul_exact(x, params["W1"].T) + params["b1"]
    check_width(acc1, 32, "acc1")
    hidden = saturate(round_shift(np.maximum(acc1, 0), params["s1"]), 0, 255)

    acc2 = _matmul_exact(hidden, params["W2"].T) + params["b2"]
    check_width(acc2, 32, "acc2")

    digit = np.argmax(acc2, axis=1)                # NumPy returns the first index of a tie
    scores = saturate(round_shift(acc2, params["s2"]), -32768, 32767)
    return {"digit": digit, "scores": scores, "acc1": acc1, "hidden": hidden, "acc2": acc2}


def make_params(W1, b1, W2, b2, k1, k2, kh):
    """Float weights + formats -> integer parameters. Returns None if a shift is negative."""
    s1 = X_FRAC + k1 - kh
    s2 = kh + k2 - SCORE_FRAC
    if s1 < 0 or s2 < 0:
        return None
    W1_q, n_w1 = to_fixed(W1, k1, -128, 127)
    b1_q, n_b1 = to_fixed(b1, X_FRAC + k1, -32768, 32767)
    W2_q, n_w2 = to_fixed(W2, k2, -128, 127)
    b2_q, n_b2 = to_fixed(b2, kh + k2, -32768, 32767)
    return {"W1": W1_q, "b1": b1_q, "W2": W2_q, "b2": b2_q, "s1": s1, "s2": s2,
            "formats": {"k1": k1, "k2": k2, "kh": kh},
            "saturated": {"W1": n_w1, "b1": n_b1, "W2": n_w2, "b2": n_b2}}


def quantize(torch_model, calib_x_q, calib_labels):
    """
    Select the formats k1, k2, kh and return the best integer parameters.

    kh (hidden scale): the float hidden values on the calibration images give the
    largest kh with 255 * 2^-kh >= max(h). This kh never saturates h. kh+1 and kh+2
    give more resolution, with some saturation. The search also tries k1, k2 = 5..7.
    Each candidate runs the integer model on the calibration images (training data,
    not test data), and the most accurate one wins.

    Returns (params, table), where table lists the accuracy of each candidate.
    """
    W1 = torch_model.hidden.weight.detach().numpy().astype(np.float64)
    b1 = torch_model.hidden.bias.detach().numpy().astype(np.float64)
    W2 = torch_model.output.weight.detach().numpy().astype(np.float64)
    b2 = torch_model.output.bias.detach().numpy().astype(np.float64)

    x = np.asarray(calib_x_q, dtype=np.float64).reshape(-1, N_IN) / 2 ** X_FRAC
    h_float = np.maximum(x @ W1.T + b1, 0)
    h_max = float(h_float.max())
    kh_fit = int(np.floor(np.log2(255 / h_max)))

    table, best, best_acc = [], None, -1.0
    for kh in (kh_fit, kh_fit + 1, kh_fit + 2):
        for k1 in (5, 6, 7):
            for k2 in (5, 6, 7):
                p = make_params(W1, b1, W2, b2, k1, k2, kh)
                if p is None:
                    continue
                acc = float(np.mean(int_forward(p, calib_x_q)["digit"] == calib_labels))
                table.append({"k1": k1, "k2": k2, "kh": kh, "s1": p["s1"], "s2": p["s2"],
                              "accuracy": acc, "saturated": p["saturated"]})
                if acc > best_acc:
                    best, best_acc = p, acc
    best["h_max_float"] = h_max
    return best, table


# ---------------------------------------------------------------------------
# Weight blob (DESIGN_NOTES.md, section 9.1)
# ---------------------------------------------------------------------------
def pack(params):
    """
    Offset      Content                                     Bytes
    0           s1, s2, 0, 0                                4
    4           W1 int8, neuron 0 weights 0..783, neuron 1 ...   25,088
    25,092      b1 int16 little endian                      64
    25,156      W2 int8, output 0 weights 0..31, output 1 ...    320
    25,476      b2 int16 little endian                      20
    total                                                   25,496

    The hardware uses 5 bits of s1 and s2, so both must be 0..31.
    """
    if not (0 <= params["s1"] <= 31 and 0 <= params["s2"] <= 31):
        raise ValueError("s1 and s2 must be 0..31 (5-bit shifter in the hardware)")
    blob = bytes([params["s1"], params["s2"], 0, 0])
    blob += params["W1"].astype("<i1").tobytes()     # row-major = one neuron after the other
    blob += params["b1"].astype("<i2").tobytes()
    blob += params["W2"].astype("<i1").tobytes()
    blob += params["b2"].astype("<i2").tobytes()
    assert len(blob) == BLOB_BYTES
    return blob


def unpack(blob):
    if len(blob) != BLOB_BYTES:
        raise ValueError(f"blob must be {BLOB_BYTES} bytes, not {len(blob)}")
    o = 4
    W1 = np.frombuffer(blob, "<i1", N_IN * HIDDEN, o).reshape(HIDDEN, N_IN); o += N_IN * HIDDEN
    b1 = np.frombuffer(blob, "<i2", HIDDEN, o); o += 2 * HIDDEN
    W2 = np.frombuffer(blob, "<i1", HIDDEN * N_OUT, o).reshape(N_OUT, HIDDEN); o += HIDDEN * N_OUT
    b2 = np.frombuffer(blob, "<i2", N_OUT, o)
    return {"W1": W1.astype(np.int64), "b1": b1.astype(np.int64),
            "W2": W2.astype(np.int64), "b2": b2.astype(np.int64),
            "s1": blob[0], "s2": blob[1]}


# ---------------------------------------------------------------------------
# Extreme parameter sets for the Verilog tests
# ---------------------------------------------------------------------------
def extreme_params(seed=0):
    """
    Parameter sets that drive every register to its limits:
      max_pos   all W1 = +127, b1 = +32767, s1 = 0: acc1 near its largest value,
                every h saturates at 255. W2 rows 0..4 = +127 (equal scores: the tie
                must go to digit 0), rows 5..9 = -128. s2 = 0: scores saturate.
      max_neg   all W1 = -128, b1 = -32768: acc1 at its most negative, ReLU gives 0.
                Thus acc2 = b2, and the digit comes from b2 only.
      random    random full-range W and b, s1 = 13, s2 = 9 (large shifts).
    """
    rng = np.random.default_rng(seed)
    full = lambda shape, lo, hi: rng.integers(lo, hi + 1, size=shape, dtype=np.int64)

    max_pos = {"W1": np.full((HIDDEN, N_IN), 127, np.int64), "b1": np.full(HIDDEN, 32767, np.int64),
               "W2": np.vstack([np.full((5, HIDDEN), 127), np.full((5, HIDDEN), -128)]).astype(np.int64),
               "b2": np.array([32767] * 5 + [-32768] * 5, np.int64), "s1": 0, "s2": 0}
    max_neg = {"W1": np.full((HIDDEN, N_IN), -128, np.int64), "b1": np.full(HIDDEN, -32768, np.int64),
               "W2": full((N_OUT, HIDDEN), -128, 127),
               "b2": np.array([-32768, 100, -5, 32767, 0, -1, 7, 32767, -200, 3], np.int64),
               "s1": 3, "s2": 2}
    random = {"W1": full((HIDDEN, N_IN), -128, 127), "b1": full(HIDDEN, -32768, 32767),
              "W2": full((N_OUT, HIDDEN), -128, 127), "b2": full(N_OUT, -32768, 32767),
              "s1": 13, "s2": 9}
    return {"max_pos": max_pos, "max_neg": max_neg, "random": random}
