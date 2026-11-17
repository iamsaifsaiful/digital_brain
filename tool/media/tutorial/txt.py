from PIL import ImageFont, ImageDraw
import re, functools
FD='/tmp/claude-0/-home-claude/4fd9a382-e0f3-5053-ab35-3e2ac049be70/scratchpad/fonts/'
@functools.lru_cache(None)
def font(sc,wd,wg,size): return ImageFont.truetype(f'{FD}anek-{sc}-{wd}-{wg}.ttf',size)
def runs(s):
    # latin run = ASCII letters/digits and following spaces; everything else bengali font (has punctuation, dashes, quotes?)
    # Bengali letters (and the spaces between them) in the Bengali font; Latin, digits and punctuation in the Latin one.
    out=[]
    for m in re.finditer(r'[\u0980-\u09FF\u200c\u200d](?:[\u0980-\u09FF\u200c\u200d ]*[\u0980-\u09FF\u200c\u200d])?|[^\u0980-\u09FF\u200c\u200d]+',s):
        t=m.group(0); out.append(('bengali' if re.match(r'[\u0980-\u09FF]',t) else 'latin',t))
    return out
def width(s,wd,wg,size):
    return sum(font(sc,wd,wg,size).getlength(t) for sc,t in runs(s))
def draw(d,xy,s,wd,wg,size,fill,anchor_baseline=None):
    x,y=xy
    for sc,t in runs(s):
        f=font(sc,wd,wg,size)
        d.text((x,y),t,font=f,fill=fill,anchor='ls')
        x+=f.getlength(t)
    return x
