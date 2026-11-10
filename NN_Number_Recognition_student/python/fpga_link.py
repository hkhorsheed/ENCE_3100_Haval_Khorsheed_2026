"""
fpga_link.py - the GUI's connection to the FPGA (model-independent).

    link = FpgaLink(port, baud, model_id, blob)
    link.open()            # sends identify; then the upload starts by itself
    every few ms: events = link.poll()
    every frame:  link.send_frame(x_q, expected)   # only when link.ready

States:
    closed -> identifying -> uploading -> ready
                    \-------------\--------> error (message in link.message)

- Identify: the FPGA must report the same model ID and weight size as the blob.
- Upload: written in small pieces from poll(), so the GUI does not freeze.
  The link is ready only after an ack with status OK and the correct checksum.
- Frames: one frame is sent only if the previous bytes are out, so frames never
  queue up (a late frame is dropped, the next one is newer anyway).
- Results: the FPGA answers each frame in order. The link keeps the expected
  integer-model result of each frame sent, and compares it with the FPGA result.
"""

import time
from collections import deque

import serial

import protocol


class FpgaLink:
    def __init__(self, port, baud, model_id, blob):
        self.port, self.baud = port, baud
        self.model_id, self.blob = model_id, bytes(blob)
        self.blob_checksum = protocol.fletcher16(self.blob)
        self.ser = None
        self.state = "closed"
        self.message = ""
        self.reader = protocol.PacketReader()
        self.tx = bytearray()                     # bytes not yet written
        self.expected = deque()                   # integer-model results of frames in flight
        self.deadline = 0.0
        self.bytes_per_poll = max(64, baud // 10 // 100)   # about 10 ms of line time
        self.stats = {"frames": 0, "dropped": 0, "results": 0, "match": 0, "mismatch": 0,
                      "missing_rows": 0}

    @property
    def ready(self):
        return self.state == "ready"

    # ------------------------------------------------------------------
    def open(self):
        self.ser = serial.serial_for_url(self.port, baudrate=self.baud, timeout=0, write_timeout=1)
        self.ser.reset_input_buffer()
        self.tx = bytearray(protocol.identify_bytes())
        self.state, self.message = "identifying", "Identify..."
        self.deadline = time.monotonic() + 1.0

    def close(self):
        if self.ser:
            self.ser.close()
        self.ser = None
        self.state, self.message = "closed", "Not connected"

    def upload(self):
        """Send the weight blob again (for example after fine-tuning)."""
        self.tx = bytearray(protocol.upload_bytes(self.model_id, self.blob))
        self.expected.clear()
        self.state, self.message = "uploading", "Upload..."
        self.deadline = time.monotonic() + 3.0 + 12 * len(self.tx) / self.baud

    def send_frame(self, x_q, expected):
        """Send one 28x28 frame. expected = (digit or None, list of 10 scores)."""
        if not self.ready:
            return False
        if self.tx:                                # last frame not out yet: drop this one
            self.stats["dropped"] += 1
            return False
        self.tx = bytearray(protocol.frame_bytes(x_q))
        self.expected.append(expected)
        if len(self.expected) > 8:                 # lost results: start the comparison again
            self.expected.clear()
        self.stats["frames"] += 1
        return True

    # ------------------------------------------------------------------
    def poll(self):
        """Write pending bytes, read packets. Returns a list of events (dicts)."""
        events = []
        if self.ser is None:
            return events
        try:
            if self.tx:
                n = self.ser.write(self.tx[:self.bytes_per_poll]) or 0
                del self.tx[:n]
            data = self.ser.read(self.ser.in_waiting or 1)
        except serial.SerialException as e:
            self._error(f"Serial port error: {e}")
            return events
        for pkt in self.reader.feed(data):
            events.extend(self._handle(pkt))
        if self.state in ("identifying", "uploading") and time.monotonic() > self.deadline:
            what = "identify" if self.state == "identifying" else "ack"
            self._error(f"No {what} from the FPGA. Check the port, baud rate, bitstream, and push KEY[0].")
        return events

    def _error(self, text):
        self.state, self.message = "error", text
        self.tx.clear()

    def _handle(self, pkt):
        t = pkt["type"]
        if t == "identify" and self.state == "identifying":
            if pkt["model_id"] != self.model_id or pkt["weight_bytes"] != len(self.blob):
                self._error(f"The FPGA has model {pkt['model_id']} ({pkt['weight_bytes']} bytes); "
                            f"the GUI has model {self.model_id} ({len(self.blob)} bytes).")
            else:
                self.upload()
            return [pkt]
        if t == "ack" and self.state == "uploading":
            if pkt["status"] == 0 and pkt["checksum"] == self.blob_checksum:
                self.state = "ready"
                self.message = f"Ready. Weights checksum {pkt['checksum']:04x}"
            else:
                self._error(f"Upload failed: {pkt['status_text']}, checksum {pkt['checksum']:04x}")
            return [pkt]
        if t == "result" and self.ready:
            self.stats["results"] += 1
            if not pkt["rows_ok"]:
                self.stats["missing_rows"] += 1
            if self.expected:
                exp_digit, exp_scores = self.expected.popleft()
                pkt["match"] = (pkt["digit"] == exp_digit and pkt["scores"] == exp_scores)
                self.stats["match" if pkt["match"] else "mismatch"] += 1
            else:
                pkt["match"] = None
            return [pkt]
        return []
