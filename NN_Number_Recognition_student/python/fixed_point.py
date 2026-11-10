"""
Fixed-point helpers, shared by all models. Integer operations only (NumPy int64),
so that each function matches one piece of Verilog exactly.

Project rules (CLAUDE.md, design decisions):
    - Scales are powers of 2, so a scale change is a shift.
    - Shifts round to nearest (half rounds up). Truncation adds a steady drift.
    - Results saturate. An overflow could flip a sign.
"""

import numpy as np


def round_shift(a, s):
    """
    Arithmetic shift right by s bits, rounded to nearest (half rounds up).

    Verilog:  (a + (1 << (s-1))) >>> s     (a signed, s > 0)
    NumPy >> on signed integers is a floor shift, the same as Verilog >>> on signed values.
    """
    a = np.asarray(a, dtype=np.int64)
    if s == 0:
        return a
    return (a + (1 << (s - 1))) >> s


def saturate(a, lo, hi):
    """Limit a to [lo, hi]. Verilog: two compares and a multiplexer."""
    return np.clip(np.asarray(a, dtype=np.int64), lo, hi)


def to_fixed(x, frac_bits, lo, hi):
    """
    Float -> integer with 2^frac_bits as 1.0, rounded, then saturated.
    Python uses this function only. The hardware never sees floats.
    Returns (integers, number of values that saturated).
    """
    q = np.round(np.asarray(x, dtype=np.float64) * (2.0 ** frac_bits)).astype(np.int64)
    n_sat = int(np.sum((q < lo) | (q > hi)))
    return np.clip(q, lo, hi), n_sat


def check_width(a, bits, name):
    """Stop if a value does not fit in a signed register of the given width."""
    lim = 1 << (bits - 1)
    a = np.asarray(a)
    if a.size and (a.min() < -lim or a.max() >= lim):
        raise AssertionError(f"{name}: value {a.min()}..{a.max()} does not fit in {bits} signed bits")
