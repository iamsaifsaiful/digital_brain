"""Step 1: the base plates. The boat comes out of both paintings (it moves in
the app now) and the moon out of the night one (the app draws the real
phase). Writes src/day_clean.png, src/night_clean.png and the boat sprites."""
import numpy as np, cv2
from common import *

day, night = load('day.jpg'), load('night.jpg')
u8 = lambda a: (np.clip(a, 0, 1) * 255).astype(np.uint8)

# The boat: dark pixels in its box (hull, roof, boatman, oar).
box = (560, 765, 750, 885)  # x0, y0, x1, y1
def boat_mask(img, thr, thr_top):
    """Hull, roof, boatman and oar — not the dark far bank behind them.
    Below the bank line: dark pixels; above it only the boatman's narrow
    column, near-black and grey; then only what touches the hull."""
    m = np.zeros(img.shape[:2], np.uint8)
    x0, y0, x1, y1 = box
    sub = img[y0:y1, x0:x1]
    mean, sat = sub.mean(2), sub.max(2) - sub.min(2)
    yy = np.arange(y0, y1)[:, None]
    xx = np.arange(x0, x1)[None, :]
    low = (yy >= 812) & (mean < thr) & ~((yy < 832) & (xx > 668) & (xx < 688))  # bank reflection between roof and boatman
    top = (yy < 812) & (xx >= 683) & (xx <= 712) & (mean < thr_top) & (sat < 0.08)
    raw = (low | top).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(raw, 8)
    keep = np.zeros_like(raw)
    for i in range(1, n):
        bottom = st[i, cv2.CC_STAT_TOP] + st[i, cv2.CC_STAT_HEIGHT] + y0
        if (bottom > 835 and st[i, cv2.CC_STAT_AREA] > 30) or (bottom > 826 and st[i, cv2.CC_STAT_AREA] > 400):  # the hull, or the roof
            keep[lab == i] = 255
    m[y0:y1, x0:x1] = cv2.morphologyEx(keep, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    return m


def cut(img, m, name):
    x0, y0, x1, y1 = box
    rgba = np.dstack([img[y0:y1, x0:x1], cv2.GaussianBlur(m[y0:y1, x0:x1], (3, 3), 0) / 255.0])
    cv2.imwrite(os.path.join(OUT, name), cv2.cvtColor(u8(rgba), cv2.COLOR_RGBA2BGRA))

os.makedirs(OUT, exist_ok=True)
md = boat_mask(day, 0.22, 0.13)
mn = boat_mask(night, 0.075, 0.05)
cut(day, md, 'boat_day.png')
cut(night, mn, 'boat_night.png')
dil = lambda m: cv2.dilate(m, np.ones((7, 7), np.uint8))
dc = cv2.inpaint(u8(day), dil(md), 9, cv2.INPAINT_TELEA)
nc = cv2.inpaint(u8(night), dil(mn), 9, cv2.INPAINT_TELEA)

# The moon and its halo (centre ~ (915, 450)): fill from the sky around, then stars again.
mm = np.zeros(night.shape[:2], np.uint8)
cv2.circle(mm, (915, 452), 42, 255, -1)
nc = cv2.inpaint(nc, mm, 15, cv2.INPAINT_TELEA)
f = nc.astype(np.float32) / 255
yy, xx = np.mgrid[0:H, 0:W]
d = np.sqrt((xx - 915) ** 2 + (yy - 452) ** 2)
halo = np.exp(-(d / 120.0) ** 2)
sky = cv2.GaussianBlur(f, (0, 0), 60)
f = f - halo[..., None] * np.clip(f - np.array([0.20, 0.22, 0.40]) * 0.0 - sky * 0.0, 0, 1) * 0.0  # keep texture
# take the halo's extra light away: compare with a ring further out
ring = (d > 150) & (d < 190)
base = f[ring].mean(0)
inner = halo > 0.02
lift = np.clip(sky - base, 0, 1)
f = np.where(inner[..., None], f - lift * np.clip(halo * 1.4, 0, 1)[..., None], f)
r = np.random.default_rng(3)
for _ in range(14):
    x, y = r.integers(800, 1030), r.integers(340, 560)
    if (x - 915) ** 2 + (y - 452) ** 2 < 130 ** 2:
        cv2.circle(f, (int(x), int(y)), 1, (0.9, 0.9, 1.0), -1, cv2.LINE_AA)
cv2.imwrite(os.path.join(SRC, 'day_clean.png'), cv2.cvtColor(dc, cv2.COLOR_RGB2BGR))
cv2.imwrite(os.path.join(SRC, 'night_clean.png'), cv2.cvtColor(u8(f), cv2.COLOR_RGB2BGR))
print('ok', md.sum() // 255, mn.sum() // 255)
