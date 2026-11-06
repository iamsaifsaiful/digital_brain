"""Shared helpers for the home pictures (owner, 4 Nov: seasons, regions).

All scenes start from the owner's river painting (assets/sky/day.jpg and
night.jpg) so they keep its painted look; elements are added with soft,
noisy brush shapes rather than flat vector shapes.
"""
import os
import numpy as np
import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(HERE, 'src')        # the owner's originals, kept unchanged
OUT = os.path.join(ROOT, 'assets', 'sky')
W, H = 1170, 1056
HORIZON = 718   # sky ends, far trees start
BANK_FAR = 800  # far bank meets the water
BANK = 890      # near bank (water ends, grass starts), roughly

rng = np.random.default_rng(7)


def load(name):
    im = cv2.imread(os.path.join(SRC, name), cv2.IMREAD_COLOR)
    return cv2.cvtColor(im, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0


def save(img, name, q=82):
    os.makedirs(OUT, exist_ok=True)
    rgb = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    cv2.imwrite(os.path.join(OUT, name), cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_WEBP_QUALITY, q])


def fbm(h, w, octaves=5, base=4, seed=0):
    """Smooth value noise 0..1 (sum of blurred random grids)."""
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        gh, gw = max(2, base * 2 ** o * h // w + 1), base * 2 ** o + 1
        g = r.random((gh, gw)).astype(np.float32)
        out += amp * cv2.resize(g, (w, h), interpolation=cv2.INTER_CUBIC)
        tot += amp
        amp *= 0.5
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def grain(img, amount=0.025, seed=1):
    r = np.random.default_rng(seed)
    return img + (r.random(img.shape[:2]).astype(np.float32)[..., None] - 0.5) * amount


def blend(img, color, alpha):
    """alpha: HxW 0..1; color: rgb tuple or HxWx3."""
    a = np.clip(alpha, 0, 1)[..., None]
    c = np.asarray(color, np.float32)
    if c.ndim == 1:
        c = c / 255.0 if c.max() > 1 else c
    return img * (1 - a) + c * a


def soft(mask, k):
    k = int(k) | 1
    return cv2.GaussianBlur(mask.astype(np.float32), (k, k), 0)


def grass_mask(img):
    """Near-bank ground (green, below the water), without the palm trunks/crowns."""
    h = np.zeros(img.shape[:2], np.float32)
    g = img[..., 1] - img[..., 2]
    for x in range(img.shape[1]):
        col = g[860:, x]
        idx = np.argmax(col > 0.12)
        y0 = 860 + idx if col[idx] > 0.12 else BANK
        h[y0:, x] = 1
    dark = img.mean(2) < 0.17
    h[dark] = 0
    return soft(h, 5)


def bank_line(img):
    g = img[..., 1] - img[..., 2]
    ys = []
    for x in range(img.shape[1]):
        col = g[860:, x]
        idx = np.argmax(col > 0.12)
        ys.append(860 + idx if col[idx] > 0.12 else BANK)
    ys = np.array(ys, np.float32)
    return cv2.GaussianBlur(ys.reshape(1, -1), (1, 61), 0).ravel()


def palms_mask(day):
    """The dark palm silhouettes (left and right), to keep in front of everything."""
    m = (day.mean(2) < 0.16).astype(np.float32)
    m[:600] = 0
    m[:, 130:900] = 0
    return m


def brush_blob(canvas, cx, cy, rx, ry, color, alpha=1.0, seed=0, rough=0.35):
    """A painted, ragged ellipse."""
    h, w = canvas.shape[:2]
    x0, x1 = max(0, int(cx - rx * 1.6)), min(w, int(cx + rx * 1.6))
    y0, y1 = max(0, int(cy - ry * 1.6)), min(h, int(cy + ry * 1.6))
    if x1 <= x0 or y1 <= y0:
        return canvas
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    n = fbm(y1 - y0, x1 - x0, 3, 3, seed)
    a = np.clip((1 + rough * (n - 0.5) * 2 - d) * 3, 0, 1) * alpha
    c = np.asarray(color, np.float32)
    c = c / 255.0 if c.max() > 1 else c
    canvas[y0:y1, x0:x1] = canvas[y0:y1, x0:x1] * (1 - a[..., None]) + c * a[..., None]
    return canvas


def stroke(canvas, pts, width, color, alpha=1.0, blur=1):
    m = np.zeros(canvas.shape[:2], np.uint8)
    cv2.polylines(m, [np.int32(pts)], False, 255, int(max(1, width)), cv2.LINE_AA)
    a = soft(m / 255.0, blur * 2 + 1) * alpha
    return blend(canvas, color, a)


def night_of(day_layer_rgb, strength=1.0):
    """A day colour as it would sit in the night painting: dark and blue."""
    lum = day_layer_rgb.mean(-1, keepdims=True)
    blue = np.array([0.20, 0.23, 0.42], np.float32)
    return (lum * 0.35 * blue / blue.mean() * 0.9 + day_layer_rgb * 0.08) * strength
