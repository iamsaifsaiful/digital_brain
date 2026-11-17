import json, math, functools
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from txt import font, width, draw as tdraw
from scenes import CH

SHOTS = '/home/claude/digital_brain/test/ui/shots/tutorial/'
W, H = 1920, 1080
BG = (243, 245, 245)
CIRCLE = (226, 240, 236)
GREEN = (14, 103, 78)
DARK = (13, 58, 46)
ORANGE = (238, 127, 14)
YELLOW = (242, 184, 56)
DONE = (92, 108, 103)
TODO = (170, 178, 175)
INK = (16, 35, 29)
WD = 87

PH = (340, 52, 790, 1028)      # phone body
SC = (354, 66, 776, 1014)      # screen
SCALE = (SC[3] - SC[1]) / 844  # logical px -> video px (fills the height)
SX0 = SC[0] - (390 * SCALE - (SC[2] - SC[0])) / 2


def bn(n):
    return str(n).translate(str.maketrans('0123456789', '০১২৩৪৫৬৭৮৯'))


def ss(img, k=3):
    return img.resize((img.width // k, img.height // k), Image.LANCZOS)


@functools.lru_cache(None)
def base():
    k = 3
    im = Image.new('RGBA', (W * k, H * k), BG + (255,))
    d = ImageDraw.Draw(im)
    cx, cy, r = 587, 583, 487
    d.ellipse(((cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k), fill=CIRCLE)
    im = ss(im, k)
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((PH[0] + 6, PH[1] + 26, PH[2] - 6, PH[3] + 22), 64, fill=(10, 40, 32, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(26))
    im.alpha_composite(sh)
    ph = Image.new('RGBA', (W * k, H * k), (0, 0, 0, 0))
    ImageDraw.Draw(ph).rounded_rectangle([v * k for v in PH], 64 * k, fill=(16, 22, 22, 255))
    im.alpha_composite(ss(ph, k))
    return im


@functools.lru_cache(None)
def screen_mask():
    k = 3
    m = Image.new('L', ((SC[2] - SC[0]) * k, (SC[3] - SC[1]) * k), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, m.width - 1, m.height - 1), 50 * k, fill=255)
    return ss(m, k)


@functools.lru_cache(None)
def screen(flow, n):
    im = Image.open(f'{SHOTS}{flow}-{n}.png').convert('RGBA')
    w = round(390 * SCALE)
    im = im.resize((w, SC[3] - SC[1]), Image.LANCZOS)
    off = round(SC[0] - SX0)
    return im.crop((off, 0, off + SC[2] - SC[0], im.height))


def to_video(r):
    x, y, w, h = r
    return (SX0 + x * SCALE, SC[1] + y * SCALE, w * SCALE, h * SCALE)


CW = 552  # callout width
TIP = (0.476, 0.115)


@functools.lru_cache(None)
def callout(flow, n, rect):
    """The spot to look at or press, larger, in a card above the phone."""
    kind, (x, y, w, h) = rect
    pad = 10
    y0, y1 = max(0, y - pad), min(844, y + h + pad)
    if y1 - y0 < 34:
        c = (y0 + y1) / 2
        y0, y1 = max(0, c - 17), min(844, c + 17)
    src = Image.open(f'{SHOTS}{flow}-{n}.png').convert('RGBA')
    mag = (CW - 12) / 390
    crop = src.crop((0, round(y0 * 3), 1170, round(y1 * 3))).resize((CW - 12, round((y1 - y0) * mag)), Image.LANCZOS)
    k = 3
    cw, ch = CW, crop.height + 12
    card = Image.new('RGBA', (cw * k, ch * k), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle((0, 0, cw * k - 1, ch * k - 1), 16 * k, fill=GREEN + (255,))
    card = ss(card, k)
    m = Image.new('L', ((cw - 12) * k, crop.height * k), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, m.width - 1, m.height - 1), 11 * k, fill=255)
    card.paste(crop, (6, 6), ss(m, k))
    # where the press lands, inside the card
    tx = 6 + (x + w / 2) * mag
    ty = 6 + (y + h / 2 - y0) * mag
    shadow = Image.new('RGBA', (cw + 80, ch + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((40, 52, cw + 40, ch + 46), 16, fill=(8, 40, 30, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    shadow.alpha_composite(card, (40, 40))
    return shadow, (tx + 40, ty + 40)


def callout_pos(rect, img):
    _, r = rect
    vx, vy, vw, vh = to_video(r)
    cy = vy + vh / 2
    h = img.height - 80
    top = min(max(cy - h / 2, 20), H - 20 - h)
    left = (PH[0] + PH[2]) / 2 - CW / 2
    return round(left - 40), round(top - 40)


@functools.lru_cache(None)
def hand():
    """A pointing hand: white with a dark edge (Material 'touch_app')."""
    f = ImageFont.truetype('/opt/fl/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf', 300)
    g = chr(0xf0544)
    k = 3
    im = Image.new('RGBA', (110 * k, 110 * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    bb = d.textbbox((0, 0), g, font=f)
    ox, oy = (im.width - (bb[2] - bb[0])) / 2 - bb[0], (im.height - (bb[3] - bb[1])) / 2 - bb[1]
    for dx in range(-9, 10, 3):
        for dy in range(-9, 10, 3):
            if dx * dx + dy * dy <= 81:
                d.text((ox + dx, oy + dy), g, font=f, fill=(255, 255, 255, 255))
    d.text((ox, oy), g, font=f, fill=(20, 26, 26, 255))
    im = ss(im, k)
    # tip of the finger, as a fraction of the box
    return im, TIP


def wrap(s, wd, wg, size, maxw):
    ws = s.split(' ')
    lines, cur = [], ''
    for w_ in ws:
        t = (cur + ' ' + w_).strip()
        if cur and width(t, wd, wg, size) > maxw:
            lines.append(cur)
            cur = w_
        else:
            cur = t
    lines.append(cur)
    return lines


@functools.lru_cache(None)
def panel(ci, active):
    """Right side: chapter pill, title, the steps (done ✓ / now / later), footer."""
    c = CH[ci]
    n = len(c['steps'])
    k = 2
    im = Image.new('RGBA', (1020 * k, H * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    X = 0  # panel x=0 is video x=900
    # pill
    label = f'অধ্যায় · {bn(ci + 1)}/{bn(len(CH))}'
    lw = width(label, WD, 700, 31)
    pw = 8 + 54 + 12 + lw + 22
    d.rounded_rectangle((X * k, 120 * k, (X + pw) * k, 192 * k), 36 * k, fill=GREEN)
    d.ellipse(((X + 10) * k, 130 * k, (X + 62) * k, 182 * k), fill=YELLOW)
    num = bn(ci + 1)
    f = font('bengali', WD, 800, 30 * k)
    d.text(((X + 36) * k, 157 * k), num, font=f, fill=DARK, anchor='mm')
    tdraw(d, ((X + 74) * k, 168 * k), label, WD, 700, 31 * k, (255, 255, 255))
    # title
    tsize = 96
    while width(c['title'], WD, 800, tsize) > 960:
        tsize -= 4
    tdraw(d, (X * k, 280 * k), c['title'], WD, 800, tsize * k, DARK)
    big = n <= 6
    gap = 87 if big else 68
    cd = 56 if big else 46
    fs = 40 if big else 33
    fa = 46 if big else 38
    y = 374 if big else 366
    tx = X + 76 if big else X + 64
    for i, s in enumerate(c['steps']):
        state = 'done' if i < active else ('now' if i == active else 'todo')
        size = fa if state == 'now' else fs
        wg = 800 if state == 'now' else 500
        lines = wrap(s, WD, wg, size, 880 - tx)
        lh = size * 1.32
        extra = (len(lines) - 1) * lh
        cyc = y + extra / 2
        cx = X + cd / 2
        if state == 'done':
            d.ellipse(((cx - cd / 2) * k, (cyc - cd / 2) * k, (cx + cd / 2) * k, (cyc + cd / 2) * k), fill=GREEN)
            fc = font('latin', WD, 800, int(cd * 0.62 * k))
            d.text((cx * k, cyc * k), '✓', font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', int(cd * 0.55 * k)), fill=(255, 255, 255), anchor='mm')
            col = DONE
        elif state == 'now':
            d.ellipse(((cx - cd / 2) * k, (cyc - cd / 2) * k, (cx + cd / 2) * k, (cyc + cd / 2) * k), fill=ORANGE)
            d.text((cx * k, (cyc + 1) * k), bn(i + 1), font=font('bengali', WD, 800, int(cd * 0.5 * k)), fill=(255, 255, 255), anchor='mm')
            col = INK
        else:
            r = cd * 0.36
            d.ellipse(((cx - r) * k, (cyc - r) * k, (cx + r) * k, (cyc + r) * k), outline=(214, 220, 218), width=2 * k)
            d.text((cx * k, (cyc + 1) * k), bn(i + 1), font=font('bengali', WD, 600, int(cd * 0.36 * k)), fill=TODO, anchor='mm')
            col = TODO
        for j, ln in enumerate(lines):
            base_y = y + j * lh + size * 0.36
            tdraw(d, (tx * k, base_y * k), ln, WD, wg, size * k, col)
        y += gap + extra + (6 if state == 'now' else 0)
    # footer
    tdraw(d, (X * k, 975 * k), f"{c['title']} · ধাপ {bn(active + 1)}/{bn(n)}", WD, 500, 26 * k, (110, 122, 118))
    return ss(im, k)


def bar(im, frac):
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((900, 999, 1800, 1009), 5, fill=(219, 226, 224))
    if frac > 0:
        d.rounded_rectangle((900, 999, 900 + max(10, 900 * frac), 1009), 5, fill=GREEN)
