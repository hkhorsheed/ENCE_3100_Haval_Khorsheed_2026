"""
gui.py - draw a digit; PyTorch, the integer model, and the FPGA recognize it live.

    conda activate nn_fpga
    python gui.py                       # model mlp_784_32_10

Left:   the drawing canvas (left mouse button draws, right button erases).
Middle: the 28x28 image that the GUI sends (after preprocessing).
Right:  three results:
          PyTorch float   the trained float model (on the PC)
          Integer model   the bit-exact integer model (on the PC) = what the FPGA must give
          FPGA            the result packet from the board; a check mark when it equals
                          the integer model exactly (digit and all 10 scores)
        and the probability of each digit (softmax of the float scores).

There is no "send" button: a timer sends the current image at a fixed rate.
    frame = 28 x (1 header + 28 pixels) = 812 bytes; 10 bits for each byte on the wire
    921600 baud -> at most 113 frames/s; the default 30 Hz uses 26% of the link
    115200 baud -> at most 14 frames/s; use 10 Hz

"Center" makes the image MNIST-like (size 20 pixels, centre of mass in the middle).
Switch it off to see how much the MLP depends on size and position.
"""

import argparse
import sys
from pathlib import Path

import numpy as np
import torch
from PySide6.QtCore import QPoint, Qt, QTimer, Signal
from PySide6.QtGui import QColor, QFont, QImage, QPainter, QPalette, QPen
from PySide6.QtWidgets import (QApplication, QCheckBox, QComboBox, QGridLayout, QGroupBox,
                               QHBoxLayout, QLabel, QMainWindow, QPushButton, QSlider, QSpinBox,
                               QVBoxLayout, QWidget)
from serial.tools import list_ports

import protocol
from fpga_link import FpgaLink
from models import get_model
from preprocess import CANVAS, preprocess

ROOT = Path(__file__).resolve().parent
BAUDS = [921600, 460800, 230400, 115200]


# ---------------------------------------------------------------------------
# Widgets
# ---------------------------------------------------------------------------
class Canvas(QWidget):
    """280x280 8-bit image, shown 2x larger. White ink on black, as in MNIST."""
    changed = Signal()
    ZOOM = 2

    def __init__(self):
        super().__init__()
        self.image = QImage(CANVAS, CANVAS, QImage.Format_Grayscale8)
        self.image.fill(0)
        self.pen_width = 22
        self.last = None
        self.erase = False
        self.setFixedSize(CANVAS * self.ZOOM, CANVAS * self.ZOOM)
        self.setCursor(Qt.CrossCursor)

    def clear(self):
        self.image.fill(0)
        self.update()
        self.changed.emit()

    def array(self):
        """Canvas as a NumPy array, 280x280 uint8."""
        ptr = self.image.constBits()
        bpl = self.image.bytesPerLine()
        return np.frombuffer(ptr, np.uint8, bpl * CANVAS).reshape(CANVAS, bpl)[:, :CANVAS].copy()

    def _pos(self, event):
        p = event.position()
        return QPoint(int(p.x() / self.ZOOM), int(p.y() / self.ZOOM))

    def mousePressEvent(self, event):
        self.erase = event.button() == Qt.RightButton
        self.last = self._pos(event)
        self._line(self.last, self.last)

    def mouseMoveEvent(self, event):
        if self.last is not None:
            p = self._pos(event)
            self._line(self.last, p)
            self.last = p

    def mouseReleaseEvent(self, event):
        self.last = None

    def _line(self, a, b):
        painter = QPainter(self.image)
        painter.setRenderHint(QPainter.Antialiasing)
        width = self.pen_width * (2 if self.erase else 1)
        painter.setPen(QPen(QColor(0, 0, 0) if self.erase else QColor(255, 255, 255),
                            width, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
        painter.drawLine(a, b)
        painter.end()
        self.update()
        self.changed.emit()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.drawImage(self.rect(), self.image)
        painter.setPen(QColor(60, 60, 60))
        painter.drawRect(self.rect().adjusted(0, 0, -1, -1))


class PixelView(QWidget):
    """The 28x28 image that is sent, 8x larger, with a grid."""
    SCALE = 8

    def __init__(self):
        super().__init__()
        self.pixels = np.zeros((28, 28), np.uint8)
        self.setFixedSize(28 * self.SCALE, 28 * self.SCALE)

    def set_pixels(self, x_q):
        self.pixels = x_q
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        s = self.SCALE
        for r in range(28):
            for c in range(28):
                v = int(self.pixels[r, c]) * 2
                painter.fillRect(c * s, r * s, s, s, QColor(v, v, v))
        painter.setPen(QColor(40, 40, 40))
        for i in range(29):
            painter.drawLine(i * s, 0, i * s, 28 * s)
            painter.drawLine(0, i * s, 28 * s, i * s)


class Bars(QWidget):
    """Probability of each digit."""

    def __init__(self):
        super().__init__()
        self.values = np.zeros(10)
        self.best = None
        self.setFixedHeight(140)
        self.setMinimumWidth(300)

    def set_values(self, values, best):
        self.values, self.best = values, best
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        w = self.width() / 10
        h = self.height() - 20
        for d in range(10):
            bh = int(h * float(self.values[d]))
            color = QColor(40, 140, 220) if d == self.best else QColor(150, 150, 150)
            painter.fillRect(int(d * w + 4), h - bh, int(w - 8), bh, color)
            painter.setPen(self.palette().color(QPalette.WindowText))
            painter.drawText(int(d * w), h, int(w), 20, Qt.AlignCenter, str(d))


def result_label():
    lab = QLabel("-")
    f = QFont()
    f.setPointSize(26)
    f.setBold(True)
    lab.setFont(f)
    lab.setMinimumWidth(170)
    return lab


# ---------------------------------------------------------------------------
# Main window
# ---------------------------------------------------------------------------
class MainWindow(QMainWindow):
    def __init__(self, model_name):
        super().__init__()
        self.spec = get_model(model_name)
        self.torch_model = self.spec.build_torch()
        self.torch_model.load_state_dict(torch.load(ROOT / "checkpoints" / f"{self.spec.NAME}.pt"))
        self.torch_model.eval()
        self.blob = (ROOT.parent / "generated" / self.spec.NAME / "weights.bin").read_bytes()
        self.params = self.spec.unpack(self.blob)
        self.link = None
        self.setWindowTitle(f"NN Number Recognition - {self.spec.NAME}")

        # ---- left: canvas ----
        self.canvas = Canvas()
        clear = QPushButton("Clear")
        clear.clicked.connect(self.canvas.clear)
        self.center = QCheckBox("Center (MNIST style)")
        self.center.setChecked(True)
        pen = QSlider(Qt.Horizontal)
        pen.setRange(8, 40)
        pen.setValue(self.canvas.pen_width)
        pen.valueChanged.connect(lambda v: setattr(self.canvas, "pen_width", v))
        left = QVBoxLayout()
        left.addWidget(self.canvas)
        row = QHBoxLayout()
        row.addWidget(clear)
        row.addWidget(self.center)
        row.addWidget(QLabel("Pen"))
        row.addWidget(pen)
        left.addLayout(row)
        left.addWidget(QLabel("Left button: draw.  Right button: erase."))

        # ---- middle: what is sent ----
        self.pixel_view = PixelView()
        self.sum_label = QLabel()
        mid = QVBoxLayout()
        mid.addWidget(QLabel("28 x 28 image sent to the FPGA"))
        mid.addWidget(self.pixel_view)
        mid.addWidget(self.sum_label)
        mid.addStretch()

        # ---- right: results ----
        self.lab_float = result_label()
        self.lab_int = result_label()
        self.lab_fpga = result_label()
        res = QGridLayout()
        for i, (name, lab) in enumerate([("PyTorch float", self.lab_float),
                                         ("Integer model", self.lab_int),
                                         ("FPGA", self.lab_fpga)]):
            res.addWidget(QLabel(name), i, 0)
            res.addWidget(lab, i, 1)
        self.bars = Bars()
        results = QGroupBox("Results")
        rl = QVBoxLayout(results)
        rl.addLayout(res)
        rl.addWidget(QLabel("Probability of each digit (PyTorch float)"))
        rl.addWidget(self.bars)

        # ---- right: connection ----
        self.port = QComboBox()
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(self.refresh_ports)
        self.baud = QComboBox()
        self.baud.addItems([str(b) for b in BAUDS])
        self.rate = QSpinBox()
        self.rate.setRange(1, 100)
        self.rate.setValue(30)
        self.rate.setSuffix(" Hz")
        self.rate.valueChanged.connect(self.set_rate)
        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.toggle_connection)
        self.upload_btn = QPushButton("Upload weights again")
        self.upload_btn.clicked.connect(lambda: self.link and self.link.ready and self.link.upload())
        self.status = QLabel("Not connected")
        self.status.setWordWrap(True)
        self.stats = QLabel()
        self.stats.setWordWrap(True)
        conn = QGroupBox("FPGA")
        cl = QGridLayout(conn)
        cl.addWidget(QLabel("Port"), 0, 0)
        cl.addWidget(self.port, 0, 1)
        cl.addWidget(refresh, 0, 2)
        cl.addWidget(QLabel("Baud"), 1, 0)
        cl.addWidget(self.baud, 1, 1)
        cl.addWidget(QLabel("Frame rate"), 2, 0)
        cl.addWidget(self.rate, 2, 1)
        cl.addWidget(self.connect_btn, 3, 0, 1, 2)
        cl.addWidget(self.upload_btn, 3, 2)
        cl.addWidget(self.status, 4, 0, 1, 3)
        cl.addWidget(self.stats, 5, 0, 1, 3)

        right = QVBoxLayout()
        right.addWidget(results)
        right.addWidget(conn)
        right.addStretch()
        right_panel = QWidget()
        right_panel.setLayout(right)
        right_panel.setFixedWidth(440)

        main = QHBoxLayout()
        main.addLayout(left)
        main.addLayout(mid)
        main.addWidget(right_panel)
        w = QWidget()
        w.setLayout(main)
        self.setCentralWidget(w)

        # ---- timers ----
        self.frame_timer = QTimer(self)
        self.frame_timer.timeout.connect(self.on_frame)
        self.set_rate(self.rate.value())
        self.poll_timer = QTimer(self)
        self.poll_timer.timeout.connect(self.on_poll)
        self.poll_timer.start(5)
        self.refresh_ports()
        self.on_frame()

    # ------------------------------------------------------------------
    def refresh_ports(self):
        self.port.clear()
        for p in list_ports.comports():
            self.port.addItem(f"{p.device}  {p.description}", p.device)

    def set_rate(self, hz):
        self.frame_timer.start(int(1000 / hz))

    def toggle_connection(self):
        if self.link:
            self.link.close()
            self.link = None
            self.connect_btn.setText("Connect")
            self.status.setText("Not connected")
            self.lab_fpga.setText("-")
            return
        port = self.port.currentData()
        if not port:
            self.status.setText("No serial port selected.")
            return
        self.link = FpgaLink(port, int(self.baud.currentText()), self.spec.MODEL_ID, self.blob)
        try:
            self.link.open()
        except Exception as e:                      # port in use, missing, ...
            self.status.setText(f"Cannot open {port}: {e}")
            self.link = None
            return
        self.connect_btn.setText("Disconnect")

    # ------------------------------------------------------------------
    def on_frame(self):
        """Timer tick: preprocess, run both PC models, send the frame."""
        x_q = preprocess(self.canvas.array(), self.center.isChecked())
        self.pixel_view.set_pixels(x_q)
        pixel_sum = int(x_q.sum())
        empty = pixel_sum < protocol.EMPTY_THRESHOLD
        self.sum_label.setText(f"Pixel sum {pixel_sum}" + ("  (empty)" if empty else ""))

        with torch.no_grad():
            scores = self.torch_model(torch.tensor(x_q[None], dtype=torch.float32) / 128)[0]
        prob = torch.softmax(scores, dim=0).numpy()
        float_digit = int(prob.argmax())
        ref = self.spec.int_forward(self.params, x_q[None])
        int_digit = int(ref["digit"][0])
        int_scores = [int(s) for s in ref["scores"][0]]

        if empty:
            self.lab_float.setText("-")
            self.lab_int.setText("-")
            self.bars.set_values(np.zeros(10), None)
        else:
            self.lab_float.setText(f"{float_digit}  ({100 * prob[float_digit]:.0f}%)")
            self.lab_int.setText(str(int_digit))
            self.bars.set_values(prob, float_digit)

        if self.link:
            self.link.send_frame(x_q, (None if empty else int_digit, int_scores))

    def on_poll(self):
        if not self.link:
            return
        for ev in self.link.poll():
            if ev["type"] == "result":
                text = "-" if ev["digit"] is None else str(ev["digit"])
                if ev["match"] is True:
                    text += "  ✓"
                elif ev["match"] is False:
                    text += "  ✗"
                self.lab_fpga.setText(text)
        self.status.setText(self.link.message)
        s = self.link.stats
        self.stats.setText(f"Frames sent {s['frames']}, results {s['results']}, "
                           f"match {s['match']}, mismatch {s['mismatch']}, dropped {s['dropped']}")
        if self.link.state == "error":
            self.lab_fpga.setText("-")


def main():
    ap = argparse.ArgumentParser(description="Draw a digit; PC and FPGA recognize it.")
    ap.add_argument("--model", default="mlp_784_32_10")
    args = ap.parse_args()
    app = QApplication(sys.argv)
    win = MainWindow(args.model)
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
