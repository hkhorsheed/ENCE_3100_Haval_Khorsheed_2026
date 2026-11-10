"""
UART protocol between the PC and the FPGA (DESIGN_NOTES.md, sections 5 and 6).
Shared by the GUI, board_test.py and export.py. The Verilog side is in
verilog/rx_parser.v, weight_loader.v and tx_packet.v.

PC -> FPGA
    frame:    28 x ( 0x80|row, 28 pixels 0..127 )
    upload:   0xF0, model ID, length (3 LE), payload, Fletcher-16 (2 LE)
    identify: 0xF1

FPGA -> PC (packets)
    0xA5, type, len, payload, ck_a, ck_b      (Fletcher-16 over type, len, payload)
    type 1 result   : flags, digit, 10 x int16 LE      (flags bit 0 rows_ok, bit 1 empty; digit 15 = none)
    type 2 ack      : status, Fletcher-16 of the received weights (LE)
    type 3 identify : model ID, weight_bytes (3 LE), weights_valid, baud code
"""

import struct

CMD_PROGRAM = 0xF0
CMD_IDENTIFY = 0xF1
ROW_HEADER = 0x80
PACKET_SYNC = 0xA5

PKT_RESULT, PKT_ACK, PKT_IDENTIFY = 1, 2, 3
ACK_STATUS = {0: "OK", 1: "wrong model ID", 2: "wrong length", 3: "wrong checksum", 4: "timeout"}
BAUD_CODES = {0: 115200, 1: 230400, 2: 460800, 3: 921600}
DIGIT_NONE = 15

# Empty canvas: pixel sum below this value. Must be the same as the parameter
# EMPTY_THRESHOLD in verilog/de10lite_top.v. Real MNIST digits: sum >= about 4,900.
EMPTY_THRESHOLD = 1270


def fletcher16(data):
    """
    Fletcher-16 checksum: two running sums, each modulo 255.
        sum1 = sum of the bytes
        sum2 = sum of all intermediate sum1 values (so the byte order has an effect)
    Returns (sum2 << 8) | sum1. Hardware: two 8-bit adders, each with a
    "subtract 255 if >= 255" step.
    """
    s1 = s2 = 0
    for b in data:
        s1 = (s1 + b) % 255
        s2 = (s2 + s1) % 255
    return (s2 << 8) | s1


# ---------------------------------------------------------------------------
# PC -> FPGA
# ---------------------------------------------------------------------------
def frame_bytes(image):
    """image: 28x28 values 0..127 (any nested sequence or NumPy array). Returns 812 bytes."""
    out = bytearray()
    for r in range(28):
        out.append(ROW_HEADER | r)
        row = [int(v) for v in image[r]]
        if min(row) < 0 or max(row) > 127:
            raise ValueError("pixels must be 0..127")
        out.extend(row)
    return bytes(out)


def upload_bytes(model_id, blob):
    n = len(blob)
    return (bytes([CMD_PROGRAM, model_id, n & 0xFF, (n >> 8) & 0xFF, (n >> 16) & 0xFF])
            + bytes(blob) + struct.pack("<H", fletcher16(blob)))


def identify_bytes():
    return bytes([CMD_IDENTIFY])


# ---------------------------------------------------------------------------
# FPGA -> PC
# ---------------------------------------------------------------------------
def decode_payload(ptype, payload):
    """Return a dict for a packet payload."""
    if ptype == PKT_RESULT and len(payload) == 22:
        return {"type": "result", "rows_ok": bool(payload[0] & 1), "empty": bool(payload[0] & 2),
                "digit": None if payload[1] == DIGIT_NONE else payload[1],
                "scores": list(struct.unpack("<10h", payload[2:22]))}
    if ptype == PKT_ACK and len(payload) == 3:
        return {"type": "ack", "status": payload[0], "status_text": ACK_STATUS.get(payload[0], "?"),
                "checksum": payload[1] | payload[2] << 8}
    if ptype == PKT_IDENTIFY and len(payload) == 6:
        return {"type": "identify", "model_id": payload[0],
                "weight_bytes": payload[1] | payload[2] << 8 | payload[3] << 16,
                "weights_valid": bool(payload[4]), "baud": BAUD_CODES.get(payload[5])}
    return {"type": "unknown", "ptype": ptype, "payload": bytes(payload)}


class PacketReader:
    """
    Collects bytes from the FPGA and returns complete packets.
    Bytes before a sync byte, and packets with a wrong checksum, are dropped
    (the counters show how many).
    """

    def __init__(self):
        self.buf = bytearray()
        self.bad_checksum = 0
        self.skipped_bytes = 0

    def feed(self, data):
        """Add received bytes. Returns a list of decoded packets."""
        self.buf.extend(data)
        packets = []
        while True:
            i = self.buf.find(PACKET_SYNC)
            if i < 0:
                self.skipped_bytes += len(self.buf)
                self.buf.clear()
                break
            if i > 0:
                self.skipped_bytes += i
                del self.buf[:i]
            if len(self.buf) < 3:
                break
            plen = self.buf[2]
            total = 3 + plen + 2
            if len(self.buf) < total:
                break
            body = bytes(self.buf[1:3 + plen])                 # type, len, payload
            ck = self.buf[3 + plen] | self.buf[4 + plen] << 8
            if ck == fletcher16(body):
                packets.append(decode_payload(body[0], body[2:]))
                del self.buf[:total]
            else:
                self.bad_checksum += 1
                del self.buf[:1]                               # look for the next sync byte
        return packets
