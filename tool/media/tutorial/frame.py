import json, math, functools
from PIL import Image, ImageDraw
from draw import *
from scenes import CH


@functools.lru_cache(None)
def steps_of(ci):
    c = CH[ci]
    js = json.load(open(f"{SHOTS}{c['flow']}.json"))
    out = []
    for i in range(len(c['steps'])):
        n = c.get('shot', list(range(len(c['steps']))))[i]
        s = js[n]
        rect = None
        if i in c.get('rect', {}):
            rect = c['rect'][i]
        elif 'tap' in s:
            rect = ('tap', s['tap'])
        elif 'look' in s:
            rect = ('look', s['look'])
        if rect:
            rect = (rect[0], tuple(rect[1]))
        out.append((n, rect))
    return out


def ease(x):
    x = min(max(x, 0), 1)
    return x * x * (3 - 2 * x)


def timing(D, kind):
    """When, inside a step of D seconds, the card comes, the hand lands and presses."""
    if D < 1.4:
        return dict(card=0.12, land=max(0.35, D - 0.55), press=max(0.45, D - 0.42))
    return dict(card=0.4, land=min(1.25, D - 0.75), press=max(1.3, D - 0.6) if D < 3 else min(D - 0.6, 1.9))


def step_layer(ci, i, t, D, bare=False):
    """Phone screen, dim, card and hand for step i, t seconds into it."""
    c = CH[ci]
    n, rect = steps_of(ci)[i]
    scr = screen(c['flow'], n)
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    lay.paste(scr, (SC[0], SC[1]), screen_mask())
    if not rect or bare:
        return lay
    tm = timing(D, rect[0])
    a = ease((t - tm['card']) / 0.28)
    if a <= 0:
        return lay
    dim = Image.new('RGBA', (SC[2] - SC[0], SC[3] - SC[1]), (12, 20, 18, int(115 * a)))
    m = screen_mask()
    lay.alpha_composite(Image.composite(dim, Image.new('RGBA', dim.size, (0, 0, 0, 0)), m), (SC[0], SC[1]))
    card, (tx, ty) = callout(c['flow'], n, rect)
    s = 0.94 + 0.06 * a
    cw, chh = round(card.width * s), round(card.height * s)
    cimg = card.resize((cw, chh), Image.BILINEAR)
    if a < 1:
        al = cimg.getchannel('A').point(lambda v: int(v * a))
        cimg.putalpha(al)
    px, py = callout_pos(rect, card)
    ox, oy = px + (card.width - cw) / 2, py + (card.height - chh) / 2
    lay.alpha_composite(cimg, (round(ox), round(oy)))
    if rect[0] != 'tap':
        return lay
    # the hand comes from below right, lands, presses; a ring spreads
    gx, gy = ox + tx * s, oy + ty * s
    hi, (fx, fy) = hand()
    ha = ease((t - tm['card'] - 0.1) / 0.25)
    if ha <= 0:
        return lay
    m_ = ease((t - tm['card']) / max(0.2, tm['land'] - tm['card']))
    hx = gx + (1 - m_) * 150
    hy = gy + (1 - m_) * 190
    pr = t - tm['press']
    sc = 1.0
    if 0 <= pr < 0.3:
        sc = 1 - 0.12 * math.sin(pr / 0.3 * math.pi)
    if pr >= 0:
        rp = min(pr / 0.5, 1)
        R = 18 + 46 * rp
        ring = Image.new('RGBA', (160, 160), (0, 0, 0, 0))
        dd = ImageDraw.Draw(ring)
        al = int(230 * (1 - rp))
        dd.ellipse((80 - R, 80 - R, 80 + R, 80 + R), outline=ORANGE + (al,), width=6)
        dd.ellipse((80 - R * 0.45, 80 - R * 0.45, 80 + R * 0.45, 80 + R * 0.45), fill=ORANGE + (int(al * 0.45),))
        lay.alpha_composite(ring, (round(gx - 80), round(gy - 80)))
    hw = round(hi.width * sc)
    him = hi.resize((hw, hw), Image.BILINEAR)
    if ha < 1:
        him.putalpha(him.getchannel('A').point(lambda v: int(v * ha)))
    lay.alpha_composite(him, (round(hx - fx * hw), round(hy - fy * hw)))
    return lay


def frame(ci, T):
    """The scene of chapter ci at video time T."""
    c = CH[ci]
    ts = c['t'] + [c['end']]
    i = max(k for k in range(len(c['t'])) if ts[k] <= T + 1e-6) if T >= ts[0] else 0
    t = T - ts[i]
    D = ts[i + 1] - ts[i]
    im = base().copy()
    cur = step_layer(ci, i, t, D)
    if i > 0 and t < 0.3:
        prev = step_layer(ci, i - 1, ts[i] - ts[i - 1] + t, ts[i] - ts[i - 1], bare=True)
        a = ease(t / 0.3)
        im.alpha_composite(prev)
        cur.putalpha(cur.getchannel('A').point(lambda v: int(v * a)))
    im.alpha_composite(cur)
    if i == 0 and t < 0.22:  # the first screen comes up from white
        wa = 1 - ease(t / 0.22)
        wh = Image.new('RGBA', (SC[2] - SC[0], SC[3] - SC[1]), (255, 255, 255, int(255 * wa)))
        im.alpha_composite(Image.composite(wh, Image.new('RGBA', wh.size, (0, 0, 0, 0)), screen_mask()), (SC[0], SC[1]))
    p = panel(ci, i)
    if i > 0 and t < 0.15:
        pp = panel(ci, i - 1)
        a = ease(t / 0.15)
        mix = Image.blend(pp, p, a)
        im.alpha_composite(mix, (900, 0))
    else:
        im.alpha_composite(p, (900, 0))
    span = c['end'] - c['t'][0]
    bar(im, (ci + (T - c['t'][0]) / span) / len(CH))
    return im.convert('RGB')
