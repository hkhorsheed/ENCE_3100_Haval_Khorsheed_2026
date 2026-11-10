"""
Canvas -> 28x28 image with 7-bit pixels (0..127), the bytes that the GUI sends.
Model-independent (DESIGN_NOTES.md, section 10.2).

The canvas is 280 x 280 pixels, 8 bits (0 = black, 255 = white ink), the same
colours as MNIST (white digit on a black background).

Two modes:

  center = False   plain downsample: each 10 x 10 block of the canvas becomes one pixel
                   (the average). The digit stays where you drew it, at the size you
                   drew it.

  center = True    MNIST-style (the way the MNIST images were made):
                   1. crop the bounding box of the ink
                   2. scale it so that its larger side is 20 pixels (keep the aspect ratio)
                   3. put it in a 28 x 28 image with its centre of mass at (14, 14)
                   Measured on MNIST: centre of mass 14.00 +- 0.29, box height <= 20.

Then both modes convert 0..1 to 7 bits: x_q = min(round(x * 128), 127),
the same as mnist_data.py, so the network sees what it saw in training.
"""

import numpy as np
from PIL import Image

CANVAS = 280
SIZE = 28
BOX = 20
COM_TARGET = 14.0


def to_uint7(x01):
    """0..1 -> 0..127 (as in training)."""
    return np.minimum(np.round(np.asarray(x01) * 128), 127).astype(np.uint8)


def downsample(canvas):
    """280x280 uint8 -> 28x28 float 0..1, the average of each 10x10 block."""
    f = CANVAS // SIZE
    return canvas.reshape(SIZE, f, SIZE, f).mean(axis=(1, 3)) / 255.0


def _shift(img, dy, dx):
    """Move the image by whole pixels, with black fill (no wrap-around)."""
    out = np.zeros_like(img)
    h, w = img.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = img[ys, xs]
    return out


def center_mnist(canvas):
    """280x280 uint8 -> 28x28 float 0..1, MNIST-style size and position."""
    ys, xs = np.nonzero(canvas)
    if len(ys) == 0:
        return np.zeros((SIZE, SIZE))

    # 1. Bounding box
    crop = canvas[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

    # 2. Larger side -> 20 pixels. BOX = area average, so thin lines become grey, as in MNIST.
    h, w = crop.shape
    scale = BOX / max(h, w)
    nh, nw = max(1, round(h * scale)), max(1, round(w * scale))
    small = np.asarray(Image.fromarray(crop).resize((nw, nh), Image.BOX), dtype=np.float64) / 255.0

    # 3. Put the box in the middle, then move the centre of mass to (14, 14)
    img = np.zeros((SIZE, SIZE))
    top, left = (SIZE - nh) // 2, (SIZE - nw) // 2
    img[top:top + nh, left:left + nw] = small
    total = img.sum()
    if total > 0:
        yy, xx = np.mgrid[0:SIZE, 0:SIZE]
        cy, cx = (img * yy).sum() / total, (img * xx).sum() / total
        dy, dx = int(round(COM_TARGET - cy)), int(round(COM_TARGET - cx))
        # never move ink out of the image
        dy = max(-top, min(SIZE - top - nh, dy))
        dx = max(-left, min(SIZE - left - nw, dx))
        img = _shift(img, dy, dx)
    return img


def preprocess(canvas, center):
    """280x280 uint8 canvas -> 28x28 uint8 pixels 0..127."""
    canvas = np.asarray(canvas, dtype=np.uint8)
    if canvas.shape != (CANVAS, CANVAS):
        raise ValueError(f"canvas must be {CANVAS}x{CANVAS}")
    return to_uint7(center_mnist(canvas) if center else downsample(canvas))
