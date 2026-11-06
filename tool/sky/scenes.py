"""Step 2: the scenes. Six seasons on the river (day and night), then the
regions. python3 tool/sky/prep.py && python3 tool/sky/scenes.py"""
import sys
import numpy as np, cv2
from common import *

D0 = cv2.cvtColor(cv2.imread(os.path.join(SRC, 'day_clean.png')), cv2.COLOR_BGR2RGB).astype(np.float32) / 255
N0 = cv2.cvtColor(cv2.imread(os.path.join(SRC, 'night_clean.png')), cv2.COLOR_BGR2RGB).astype(np.float32) / 255
PALMS = palms_mask(D0)
PALMS_N = PALMS.copy()
GRASS = grass_mask(D0) * (1 - PALMS)
BANKY = bank_line(D0)
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)
SKY = (YY < HORIZON).astype(np.float32)
SKY = soft(SKY, 41)
WATER = ((YY >= BANK_FAR) & (YY < BANKY[None, :])).astype(np.float32) * (1 - PALMS)


def keep_palms(img, base):
    a = soft(PALMS, 3)[..., None]
    return img * (1 - a) + base * a


def shade(col, night):
    c = np.asarray(col, np.float32)
    c = c / 255 if c.max() > 1 else c
    if not night:
        return c
    lum = float(c.mean())
    return np.array([0.16, 0.18, 0.32], np.float32) * (0.35 + lum * 0.9)


# ── ground textures ──
def recolor_ground(img, top, bottom, night, mask=None, keep=0.25, seed=0):
    m = GRASS if mask is None else mask
    t = np.clip((YY - 890) / 166, 0, 1)[..., None]
    target = shade(top, night) * (1 - t) + shade(bottom, night) * t
    lum = img.mean(2, keepdims=True)
    n = fbm(H, W, 5, 6, seed)[..., None]
    tex = target * (0.78 + 0.5 * (lum / max(1e-3, float(lum[m > 0.5].mean())) - 1) * keep + (n - 0.5) * 0.25)
    return img * (1 - m[..., None]) + tex * m[..., None]


def blades(img, n, color, ylo, yhi, hlo, hhi, night, width=1, lean=4, seed=0, alpha=0.8, heads=None):
    r = np.random.default_rng(seed)
    c = shade(color, night)
    layer = img.copy()
    for _ in range(n):
        x = r.uniform(0, W)
        y = r.uniform(ylo, yhi)
        if y < BANKY[int(min(W - 1, x))] + 2:
            continue
        hgt = r.uniform(hlo, hhi) * (0.6 + 0.4 * (y - 880) / 176)
        dx = r.uniform(-lean, lean)
        pts = [(x, y), (x + dx * 0.4, y - hgt * 0.5), (x + dx, y - hgt)]
        cc = c * r.uniform(0.75, 1.15)
        cv2.polylines(layer, [np.int32(pts)], False, tuple(float(v) for v in np.clip(cc, 0, 1)), width, cv2.LINE_AA)
        if heads is not None:
            hc = tuple(float(v) for v in np.clip(shade(heads, night) * r.uniform(0.85, 1.1), 0, 1))
            cv2.ellipse(layer, (int(x + dx), int(y - hgt)), (2, 4), r.uniform(-30, 30), 0, 360, hc, -1, cv2.LINE_AA)
    m = GRASS[..., None] * alpha
    return img * (1 - m) + layer * m


# ── trees and plants (painted blobs) ──
def tree_trunk(img, x, ybase, ytop, wbase, color, night, bend=0.0, seed=0):
    r = np.random.default_rng(seed)
    pts = []
    for i in range(12):
        t = i / 11
        pts.append((x + bend * t * t + r.uniform(-1.5, 1.5), ybase - (ybase - ytop) * t))
    for i in range(len(pts) - 1):
        w = wbase * (1 - 0.6 * i / 11)
        img = stroke(img, [pts[i], pts[i + 1]], w, shade(color, night), 1.0, 1)
    return img, pts


def branch(img, p0, ang, length, width, color, night, depth, seed, ends):
    r = np.random.default_rng(seed)
    if depth == 0 or length < 6:
        ends.append(p0)
        return img
    p1 = (p0[0] + np.cos(ang) * length, p0[1] - np.sin(ang) * length)
    img = stroke(img, [p0, p1], max(1, width), shade(color, night), 1.0, 1)
    for k in range(2):
        a2 = ang + r.uniform(0.25, 0.7) * (1 if k else -1)
        img = branch(img, p1, a2, length * r.uniform(0.62, 0.8), width * 0.68, color, night, depth - 1, seed * 3 + k + 1, ends)
    return img


def crown(img, cx, cy, rx, ry, dark, light, night, n=26, seed=0):
    """A leafy crown: many small leaf clusters, dark underneath, lit on top-right."""
    r = np.random.default_rng(seed)
    d, l = shade(dark, night), shade(light, night)
    img = brush_blob(img, cx, cy + ry * 0.05, rx * 0.92, ry * 0.88, d * 0.8, 1, seed, 0.5)
    pts = []
    for i in range(int(n * 5)):
        a = r.uniform(0, 2 * np.pi)
        k = np.sqrt(r.uniform(0, 1))
        pts.append((cx + np.cos(a) * rx * k, cy + np.sin(a) * ry * k))
    pts.sort(key=lambda p: -p[1] + r.uniform(-20, 20))
    pts = pts[::-1]
    for i, (bx, by) in enumerate(pts):
        lit = np.clip(0.55 - (by - cy) / ry * 0.55 + (bx - cx) / rx * 0.25 + r.uniform(-0.18, 0.18), 0, 1)
        col = d + (l - d) * lit
        s = r.uniform(0.09, 0.17)
        img = brush_blob(img, bx, by, rx * s, ry * s * 0.85, col, 0.95, seed * 97 + i, 0.6)
    return img


def dots(img, cx, cy, rx, ry, n, color, size, night, seed=0, alpha=1.0, glow=False):
    r = np.random.default_rng(seed)
    c = tuple(float(v) for v in np.clip(shade(color, night), 0, 1))
    layer = img.copy()
    for _ in range(n):
        a = r.uniform(0, 2 * np.pi)
        d = np.sqrt(r.uniform(0, 1))
        x, y = cx + np.cos(a) * rx * d, cy + np.sin(a) * ry * d
        s = max(1, int(size * r.uniform(0.6, 1.3)))
        cv2.circle(layer, (int(x), int(y)), s, c, -1, cv2.LINE_AA)
    return img * (1 - alpha) + layer * alpha


def kash_field(img, y0, y1, night, seed=0):
    """শরৎ: kash — thin stems, each topped by a soft white plume that arcs
    over down-wind, many of them, small at the back, big in front."""
    r = np.random.default_rng(seed)
    white = np.array([0.98, 0.98, 0.96], np.float32) if not night else np.array([0.46, 0.49, 0.64], np.float32)
    grey = np.array([0.78, 0.79, 0.78], np.float32) if not night else np.array([0.28, 0.31, 0.45], np.float32)
    stemc = tuple(float(v) for v in shade((120, 128, 88), night))
    order = sorted([(r.uniform(y0, y1 + 40), r.uniform(-20, W + 20)) for _ in range(420)])
    out = img.copy()
    for y, x in order:
        xi = int(min(W - 1, max(0, x)))
        if y < BANKY[xi] + 2:
            continue
        depth = np.clip((y - y0) / (y1 + 40 - y0), 0, 1)
        s = 0.45 + 1.1 * depth ** 1.5
        h = r.uniform(40, 70) * s
        lean = r.uniform(4, 10) * s
        top = (x + lean, y - h)
        cv2.polylines(out, [np.int32([(x, y), (x + lean * 0.5, y - h * 0.55), top])], False, stemc, max(1, int(1.3 * s)), cv2.LINE_AA)
        # the plume: an arc over to the right, thick at the root, thin at the tip
        L = r.uniform(26, 44) * s
        bend = r.uniform(0.5, 1.0)
        pts = []
        for t in np.linspace(0, 1, 9):
            ang = np.deg2rad(80 - 120 * bend * t)
            pts.append((top[0] + np.sin(np.deg2rad(10 + 100 * bend * t)) * L * t * 0.9, top[1] - np.cos(np.deg2rad(10 + 100 * bend * t)) * L * t * 0.55))
        layer = np.zeros((H, W), np.float32)
        for i in range(len(pts) - 1):
            w = max(1, int((7.5 - 6 * i / 8) * s))
            cv2.line(layer, (int(pts[i][0]), int(pts[i][1])), (int(pts[i + 1][0]), int(pts[i + 1][1])), 1.0, w, cv2.LINE_AA)
        x0, y0b = int(max(0, min(p[0] for p in pts) - 12)), int(max(0, min(p[1] for p in pts) - 12))
        x1, y1b = int(min(W, max(p[0] for p in pts) + 12)), int(min(H, max(p[1] for p in pts) + 12))
        if x1 <= x0 or y1b <= y0b:
            continue
        sub = cv2.GaussianBlur(layer[y0b:y1b, x0:x1], (5, 5), 0)
        nz = fbm(y1b - y0b, x1 - x0, 2, 6, int(r.integers(1e6)))
        a = np.clip(sub * (0.75 + 0.4 * nz), 0, 0.95)[..., None]
        col = white * (0.92 + 0.08 * nz[..., None]) if r.random() < 0.8 else grey
        out[y0b:y1b, x0:x1] = out[y0b:y1b, x0:x1] * (1 - a) + col * a
    return out


def fog(img, y0, y1, amount, night, seed=0):
    n = fbm(H, W, 4, 3, seed)
    band = np.clip(1 - np.abs((YY - (y0 + y1) / 2) / ((y1 - y0) / 2)), 0, 1) ** 0.8
    a = band * (0.55 + 0.45 * n) * amount
    col = np.array([0.93, 0.94, 0.95], np.float32) if not night else np.array([0.30, 0.33, 0.48], np.float32)
    return blend(img, col, a)


def clouds(img, amount, color, night, seed=0, cover=0.5, ylim=HORIZON):
    n = fbm(H, W, 6, 3, seed)
    a = np.clip((n - (1 - cover)) / 0.25, 0, 1) * amount * np.clip((ylim - YY) / 120, 0, 1)
    under = np.clip((fbm(H, W, 3, 2, seed + 1) - 0.5) * 2, 0, 1) * np.clip((YY - 200) / 400, 0, 1)
    c = shade(color, night)
    col = c[None, None, :] * (1 - 0.12 * under[..., None])
    return img * (1 - a[..., None]) + col * a[..., None]


def adjust_sky(img, mul, add=(0, 0, 0)):
    k = SKY[..., None]
    return img * (1 - k) + np.clip(img * np.asarray(mul, np.float32) + np.asarray(add, np.float32), 0, 1) * k


def raise_water(img, rise, night):
    """বর্ষা: the river comes up over the near bank."""
    out = img.copy()
    for x in range(W):
        b = int(BANKY[x])
        for y in range(b, min(H, b + rise)):
            out[y, x] = img[b - 1 - (y - b) % 30, x] * (0.95 + 0.05 * np.sin(y * 0.7 + x * 0.05))
    m = np.zeros((H, W), np.float32)
    for x in range(W):
        b = int(BANKY[x]); m[b:min(H, b + rise), x] = 1
    m = soft(m * (1 - PALMS), 7)[..., None]
    return img * (1 - m) + out * m


def hyacinth(img, n, night, seed=0):
    r = np.random.default_rng(seed)
    for i in range(n):
        x = r.uniform(80, 1100); y = r.uniform(840, 900)
        img = brush_blob(img, x, y, r.uniform(16, 34), r.uniform(5, 8), shade((52, 102, 52), night), 0.95, seed + i)
        img = dots(img, x, y - 4, 10, 3, 4, (190, 160, 230), 1.6, night, seed + i, 0.9)
    return img


def pot(img, x, y, night):
    img = brush_blob(img, x, y, 9, 11, shade((150, 82, 46), night), 1, 5, 0.1)
    img = brush_blob(img, x, y - 9, 6, 2.5, shade((96, 52, 30), night), 1, 6, 0.1)
    return stroke(img, [(x - 4, y - 12), (x + 6, y - 26)], 2, shade((90, 70, 50), night))


def season(name, night):
    base = N0 if night else D0
    img = base.copy()
    if name == 'grishma':  # গ্রীষ্ম: dry earth, hazy hot sky, a mango tree
        img = adjust_sky(img, (1.04, 1.0, 0.92), (0.03, 0.02, 0.0)) if not night else img
        img = recolor_ground(img, (196, 178, 104), (150, 122, 62), night, seed=11)
        img = blades(img, 2200, (170, 150, 80), 895, 1056, 6, 16, night, seed=12, alpha=0.7)
        r = np.random.default_rng(4)
        for i in range(26):  # cracked patches
            x, y = r.uniform(150, 1000), r.uniform(960, 1050)
            pts = [(x, y)]
            for k in range(5):
                pts.append((pts[-1][0] + r.uniform(-14, 14), pts[-1][1] + r.uniform(-4, 4)))
            img = stroke(img, pts, 1, shade((110, 84, 46), night), 0.6)
        img, _ = tree_trunk(img, 215, 965, 740, 24, (70, 54, 42), night, bend=-6, seed=3)
        img = crown(img, 215, 700, 140, 100, (22, 52, 24), (96, 146, 64), night, 34, 21)
        img = dots(img, 215, 730, 105, 62, 30, (196, 196, 64), 3, night, 22)
    elif name == 'borsha':  # বর্ষা: dark rain clouds, the river up, kadam, hyacinth
        if not night:
            img = adjust_sky(img, (0.72, 0.75, 0.80), (0.05, 0.05, 0.06))
            img = clouds(img, 0.85, (92, 98, 110), night, 31, 0.62)
            img = clouds(img, 0.6, (140, 146, 156), night, 32, 0.45)
        else:
            img = clouds(img, 0.75, (50, 52, 70), night, 31, 0.6)
        img = raise_water(img, 40, night)
        img = recolor_ground(img, (64, 128, 52), (32, 84, 30), night, seed=33)
        img = blades(img, 2600, (40, 104, 36), 900, 1056, 10, 22, night, seed=34, alpha=0.7)
        img = hyacinth(img, 7, night, 35)
        img, _ = tree_trunk(img, 230, 950, 760, 15, (64, 52, 42), night, bend=4, seed=36)
        img = crown(img, 232, 705, 120, 98, (26, 72, 34), (76, 140, 70), night, 32, 37)
        img = dots(img, 232, 700, 100, 76, 34, (236, 206, 92), 5, night, 38)
        img = dots(img, 232, 700, 100, 76, 34, (250, 246, 220), 2, night, 39)
    elif name == 'shorot':  # শরৎ: blue sky, cotton clouds, kash along the river
        if not night:
            img = adjust_sky(img, (0.92, 0.97, 1.05))
            img = clouds(img, 0.9, (250, 250, 252), night, 41, 0.38, ylim=600)
        img = recolor_ground(img, (126, 168, 74), (70, 112, 44), night, seed=42)
        img = blades(img, 2600, (96, 150, 60), 900, 1056, 8, 20, night, seed=45, alpha=0.7)
        img = kash_field(img, 900, 1000, night, 43)
    elif name == 'hemonto':  # হেমন্ত: golden paddy
        if not night:
            img = adjust_sky(img, (1.02, 1.0, 0.96), (0.02, 0.01, 0))
        img = recolor_ground(img, (214, 170, 62), (160, 112, 34), night, seed=51)
        img = blades(img, 5200, (196, 150, 50), 895, 1056, 10, 26, night, seed=52, lean=6, alpha=0.85, heads=(226, 182, 74))
        img = blades(img, 1200, (130, 92, 30), 930, 1056, 14, 30, night, seed=53, lean=8, alpha=0.6)
    elif name == 'sheet':  # শীত: mist, mustard fields, a pot on the date palm
        img = recolor_ground(img, (150, 162, 70), (96, 112, 44), night, seed=61)
        r = np.random.default_rng(62)
        layer = img.copy()
        c = tuple(float(v) for v in np.clip(shade((246, 214, 42), night), 0, 1))
        for _ in range(9000):
            x, y = r.uniform(0, W), r.uniform(900, 1056)
            if y < BANKY[int(min(W - 1, x))] + 4:
                continue
            s = 1 + int((y - 900) / 60)
            cv2.circle(layer, (int(x), int(y)), s, c, -1, cv2.LINE_AA)
        img = img * (1 - GRASS[..., None] * 0.9) + layer * GRASS[..., None] * 0.9
        img = fog(img, 690, 900, 0.75 if not night else 0.55, night, 63)
        img = fog(img, 880, 1000, 0.35 if not night else 0.25, night, 64)
        if not night:
            img = adjust_sky(img, (0.95, 0.97, 1.0), (0.04, 0.04, 0.04))
        img = keep_palms(img, base)
        img = pot(img, 46, 868, night)
        return img
    elif name == 'boshonto':  # বসন্ত: shimul in red bloom, fresh green
        img = recolor_ground(img, (150, 196, 84), (84, 138, 52), night, seed=71)
        img = blades(img, 2400, (110, 170, 60), 900, 1056, 8, 18, night, seed=72, alpha=0.7)
        img, tp = tree_trunk(img, 250, 985, 640, 28, (88, 72, 62), night, bend=-10, seed=73)
        ends = []
        for k, (ang, ln) in enumerate([(1.2, 150), (1.95, 140), (0.7, 120), (2.45, 115), (1.55, 170), (0.95, 110)]):
            img = branch(img, tp[7 + k % 3], ang, ln * 0.62, 12, (84, 68, 58), night, 5, 74 + k, ends)
        r = np.random.default_rng(75)
        for (ex, ey) in ends:
            seedv = int(r.integers(1e6))
            img = dots(img, ex, ey, 18, 12, 10, (150, 22, 20), 4.2, night, seedv)
            img = dots(img, ex, ey - 2, 15, 10, 9, (222, 48, 32), 3.4, night, seedv + 1)
            img = dots(img, ex + 2, ey - 3, 10, 7, 4, (255, 128, 64), 2, night, seedv + 2)
        img = dots(img, 600, 760, 420, 20, 70, (200, 54, 38), 2, night, 76, 0.8)  # palash far away
    return keep_palms(img, base)


SEASONS = ['grishma', 'borsha', 'shorot', 'hemonto', 'sheet', 'boshonto']

if __name__ == '__main__' and not (len(sys.argv) > 1 and sys.argv[1] in ('regions', 'river')):
    which = sys.argv[1:] or SEASONS
    for s in which:
        for night in (False, True):
            save(grain(season(s, night), 0.018, 5), f'{s}_{"night" if night else "day"}.webp')
        print(s)


# ── Regions (owner, 4 Nov: "এটা আমার এলাকা") ──

def ridge(seed, base, amp, smooth=60):
    r = np.random.default_rng(seed)
    v = r.random(W // 130 + 4).astype(np.float32)
    v = cv2.resize(v.reshape(1, -1), (W + 80, 1), interpolation=cv2.INTER_CUBIC).ravel()[40:40 + W]
    v = cv2.GaussianBlur(v.reshape(1, -1), (1, smooth | 1), 0).ravel()
    v = (v - v.min()) / (v.max() - v.min() + 1e-6)
    return base - v * amp


def hills(img, layers, night, bottom=800):
    """Layered hills, far ones pale with haze, near ones deeper."""
    for i, (seed, base, amp, col) in enumerate(layers):
        ry = ridge(seed, base, amp)
        m = (YY >= ry[None, :]) & (YY < bottom)
        m = soft(m.astype(np.float32), 5)
        n = fbm(H, W, 5, 8, seed + 100)[..., None]
        c = shade(col, night)
        tex = c * (0.88 + 0.24 * n)
        # a lit edge on top of each ridge
        edge = np.clip(1 - (YY - ry[None, :]) / 30, 0, 1) * m
        tex = tex + edge[..., None] * (0.05 if not night else 0.01)
        img = img * (1 - m[..., None]) + tex * m[..., None]
    return img


def tea_rows(img, night, seed=0):
    """Sylhet: rounded rows of tea bushes over the near ground, shade trees between."""
    r = np.random.default_rng(seed)
    dark, light = shade((32, 84, 40), night), shade((112, 166, 74), night)
    y = 905.0
    gap = 9.0
    rows = []
    while y < H + 20:
        rows.append(y)
        y += gap
        gap *= 1.18
    for y in rows:
        s = (y - 880) / 170
        for x0 in np.arange(-40, W + 40, 8):
            yy = y + 14 * np.sin(x0 / 210 + y * 0.03) * s
            img = brush_blob(img, x0 + r.uniform(-3, 3), yy, 10 + 10 * s, 4 + 7 * s, dark + (light - dark) * r.uniform(0.15, 0.5), 0.95, int(r.integers(1e6)), 0.4) if r.random() < 0.9 else img
        for x0 in np.arange(-40, W + 40, 14):
            img = brush_blob(img, x0 + r.uniform(-4, 4), y - 3 - 5 * s, 8 + 7 * s, 2 + 3 * s, light * r.uniform(0.9, 1.1), 0.8, int(r.integers(1e6)), 0.5)
    for x in (380, 640, 860):  # tall shade trees
        img, tp = tree_trunk(img, x, 930, 790, 6, (70, 60, 50), night, bend=3, seed=x)
        img = crown(img, x + 3, 780, 46, 16, (30, 66, 36), (90, 140, 70), night, 10, x + 1)
    return img


def sea(img, night, seed=0):
    """Cox's Bazar: open sea to the horizon, waves on a long sand beach."""
    hz = 742
    sky_bottom = img[HORIZON - 30:HORIZON - 10].mean(axis=0)  # per column
    out = img.copy()
    for y in range(HORIZON - 10, hz):
        out[y] = sky_bottom
    t = np.clip((YY - hz) / (905 - hz), 0, 1)[..., None]
    far = shade((150, 184, 204), night) if not night else np.array([0.12, 0.15, 0.28], np.float32)
    near = shade((40, 120, 140), night) if not night else np.array([0.06, 0.09, 0.20], np.float32)
    water = far * (1 - t) + near * t
    n = fbm(H, W, 5, 10, seed)
    streak = cv2.resize(fbm(H // 6, W, 3, 30, seed + 1), (W, H))
    water = water * (0.9 + 0.2 * streak[..., None])
    sm = ((YY >= hz) & (YY < 905)).astype(np.float32)
    out = out * (1 - sm[..., None]) + water * sm[..., None]
    # sun or moon path on the water
    path = np.exp(-((XX - 915) / 70) ** 2) * sm * (0.45 + 0.55 * streak)
    out = blend(out, (1, 1, 0.95) if not night else (0.6, 0.62, 0.75), path * (0.55 if not night else 0.45))
    # wave lines
    r = np.random.default_rng(seed + 2)
    for k in range(40):
        y = r.uniform(hz + 8, 900); x = r.uniform(-100, W); L = r.uniform(40, 220) * (0.4 + (y - hz) / 160)
        out = stroke(out, [(x, y), (x + L, y + r.uniform(-1, 1))], 1 + int((y - hz) / 60), (0.92, 0.95, 0.96) if not night else (0.3, 0.33, 0.45), 0.45)
    for k, y in enumerate([872, 890, 903]):  # surf
        pts = [(x, y + 4 * np.sin(x / 60 + k)) for x in range(-10, W + 20, 20)]
        out = stroke(out, pts, 4 - k, (0.98, 0.98, 0.98) if not night else (0.36, 0.38, 0.5), 0.8, 2)
    # sand
    sand = shade((214, 196, 156), night) if not night else np.array([0.13, 0.14, 0.22], np.float32)
    tex = sand * (0.9 + 0.18 * n[..., None]) * (1 - np.clip((YY - 905) / 400, 0, 0.25))[..., None]
    gm = np.clip((YY - 905) / 6, 0, 1) * (1 - PALMS)
    wet = np.clip(1 - (YY - 905) / 30, 0, 1) * gm * 0.5
    out = out * (1 - gm[..., None]) + tex * gm[..., None]
    out = blend(out, shade((150, 140, 116), night), wet)
    return out


def mangroves(img, night, seed=0):
    """Sundarbans: dark, dense mangrove forest; a mud bank with breathing roots and golpata."""
    out = img.copy()
    r = np.random.default_rng(seed)
    dark, mid = shade((24, 56, 34), night), shade((60, 100, 58), night)
    for i in range(160):  # tall keora/sundari crowns along the far bank
        x = r.uniform(-20, W + 20); top = r.uniform(640, 720)
        out = brush_blob(out, x, top + 40, r.uniform(16, 34), r.uniform(30, 60), dark + (mid - dark) * r.uniform(0, 0.5), 0.95, i, 0.5)
    out = brush_blob(out, 585, 790, 640, 22, dark * 0.8, 0.9, seed + 1, 0.3)
    # mud bank
    mud = shade((104, 92, 70), night) if not night else np.array([0.09, 0.10, 0.17], np.float32)
    n = fbm(H, W, 5, 9, seed + 2)
    gm = GRASS.copy()
    out = out * (1 - gm[..., None]) + (mud * (0.85 + 0.3 * n[..., None])) * gm[..., None]
    out = blades(out, 900, (90, 110, 70), 900, 1056, 6, 14, night, seed=seed + 3, alpha=0.5)
    for i in range(700):  # breathing roots
        x = r.uniform(0, W); y = r.uniform(BANK + 5, 1050)
        if y < BANKY[int(min(W - 1, x))] + 3:
            continue
        hh = r.uniform(4, 10) * (0.6 + (y - 890) / 120)
        out = stroke(out, [(x, y), (x + r.uniform(-1, 1), y - hh)], 1, shade((60, 52, 40), night), 0.8, 0)
    for i, x in enumerate((140, 330, 470, 760, 840)):  # golpata clumps
        for k in range(14):
            ang = np.deg2rad(r.uniform(30, 150)); L = r.uniform(90, 170)
            pts = [(x, 960), (x + np.cos(ang) * L * 0.6, 960 - np.sin(ang) * L * 0.8), (x + np.cos(ang) * L, 960 - np.sin(ang) * L * 0.55)]
            out = stroke(out, pts, 6, shade((52, 104, 46), night) * r.uniform(0.8, 1.2), 0.95, 1)
            for q in range(8):
                f = 0.3 + q * 0.08; px, py = pts[1][0] * (1 - f) + pts[2][0] * f, pts[1][1] * (1 - f) + pts[2][1] * f
                out = stroke(out, [(px, py), (px + r.uniform(-14, 14), py + r.uniform(8, 18))], 2, shade((70, 128, 56), night), 0.9)
    return out


def char_lands(img, night, seed=0):
    """Rajshahi: the wide Padma with sand chars, mango orchards on the far bank."""
    out = img.copy()
    r = np.random.default_rng(seed)
    # the near ground becomes wide river: the far water's colour, calmer and paler towards us
    wc = out[830:880].reshape(-1, 3).mean(0)
    t = np.clip((YY - 890) / 166, 0, 1)[..., None]
    streak = cv2.resize(fbm(H // 8, W, 3, 30, seed + 5), (W, H))[..., None]
    water = wc * (1.05 + 0.1 * t) * (0.92 + 0.16 * streak)
    gm = soft((YY >= BANKY[None, :] - 2).astype(np.float32) * (1 - PALMS), 9)[..., None]
    out = out * (1 - gm) + water * gm
    for k in range(60):
        y = r.uniform(895, 1050); x = r.uniform(-50, W); L = r.uniform(30, 160)
        out = stroke(out, [(x, y), (x + L, y)], 1, (0.9, 0.92, 0.92) if not night else (0.25, 0.27, 0.4), 0.35)
    sandc = shade((222, 204, 160), night) if not night else np.array([0.13, 0.14, 0.22], np.float32)
    for (cx, cy, rx, ry) in [(300, 930, 330, 12), (860, 968, 380, 18), (420, 1028, 300, 16)]:
        out = brush_blob(out, cx, cy + ry * 0.6, rx * 1.02, ry * 0.5, (out[int(cy), int(cx)] * 0.8), 0.6, int(cx) + 1, 0.3)  # its reflection/shadow
        out = brush_blob(out, cx, cy, rx, ry, sandc, 1, int(cx), 0.18)
        out = brush_blob(out, cx - rx * 0.1, cy - ry * 0.2, rx * 0.8, ry * 0.45, sandc * 1.05, 0.7, int(cx) + 2, 0.3)
        for k in range(int(rx / 12)):  # kash/grass tufts on the char
            gx = cx + r.uniform(-rx * 0.6, rx * 0.6); gy = cy - ry * r.uniform(0.2, 0.6)
            out = brush_blob(out, gx, gy, r.uniform(8, 20), r.uniform(3, 6), shade((130, 156, 84), night), 0.8, int(gx * 7 + gy), 0.5)
    for i in range(14):  # mango trees on the far bank
        x = 60 + i * 80 + r.uniform(-20, 20)
        out = crown(out, x, 760, r.uniform(34, 48), r.uniform(26, 34), (26, 60, 28), (80, 130, 60), night, 6, 900 + i)
    return out


def skyline(img, night, seed=0):
    """Dhaka: the city's towers behind the trees, lights on at night."""
    out = img.copy()
    r = np.random.default_rng(seed)
    x = 40.0
    blds = []
    while x < W - 40:
        w = r.uniform(26, 70); h = r.uniform(50, 230) * (0.7 + 0.5 * np.exp(-((x - 600) / 380) ** 2))
        blds.append((x, w, h)); x += w + r.uniform(-6, 10)
    for i, (x, w, h) in enumerate(sorted(blds, key=lambda b: b[2])):
        top = 780 - h
        tone = r.uniform(0.85, 1.1)
        c = (shade((150, 160, 176), night) * tone) if not night else np.array([0.07, 0.08, 0.15], np.float32) * tone
        x0, x1, y0, y1 = int(x), int(x + w), int(top), 790
        out[y0:y1, x0:x1] = out[y0:y1, x0:x1] * 0.1 + c * 0.9
        out[y0:y1, x0:x0 + 2] *= 0.85  # a shaded side
        for wy in range(y0 + 6, 770, 9):
            for wx in range(x0 + 4, x1 - 4, 8):
                if night:
                    if r.random() < 0.28:
                        out[wy:wy + 4, wx:wx + 4] = (0.95, 0.80, 0.45)
                else:
                    out[wy:wy + 4, wx:wx + 4] *= 0.92
    # the trees in front again (from the base), so the city sits behind them
    base = img
    trees = np.clip((YY - 735) / 25, 0, 1)
    tm = (base.mean(2) < (0.55 if not night else 0.12)) * trees
    tm = soft(tm.astype(np.float32), 3)
    out = out * (1 - tm[..., None]) + base * tm[..., None]
    if not night:
        out = adjust_sky(out, (0.96, 0.96, 0.95), (0.03, 0.03, 0.02))
    return out


def region(name, night):
    base = N0 if night else D0
    img = base.copy()
    if name == 'sylhet':
        img = hills(img, [(1, 700, 150, (150, 178, 170)), (2, 742, 110, (98, 140, 112)), (3, 780, 70, (56, 104, 66))], night)
        img = tea_rows(img, night, 4)
    elif name == 'cox':
        img = sea(img, night, 11)
    elif name == 'sundarbans':
        img = mangroves(img, night, 21)
    elif name == 'chattogram':
        img = hills(img, [(31, 640, 210, (140, 166, 176)), (32, 700, 160, (92, 124, 120)), (33, 760, 90, (52, 92, 62))], night)
    elif name == 'rajshahi':
        img = char_lands(img, night, 41)
    elif name == 'dhaka':
        img = skyline(img, night, 51)
    return keep_palms(img, base)


REGIONS = ['sylhet', 'cox', 'sundarbans', 'chattogram', 'rajshahi', 'dhaka']

if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'regions':
    for s in sys.argv[2:] or REGIONS:
        for night in (False, True):
            save(grain(region(s, night), 0.018, 6), f'{s}_{"night" if night else "day"}.webp')
        print(s)

if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'river':
    save(grain(D0, 0.0, 1), 'river_day.webp'); save(grain(N0, 0.0, 1), 'river_night.webp'); print('river')
