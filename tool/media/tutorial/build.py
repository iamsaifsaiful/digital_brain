# Old video in, new video out: the intro, chapter cards, ending and the voice
# stay; every scene (phone + steps) is drawn again from today's app.
import json, subprocess, sys, numpy as np
from multiprocessing import Pool
from scenes import CH
S = '/tmp/claude-0/-home-claude/4fd9a382-e0f3-5053-ab35-3e2ac049be70/scratchpad/'
SRC, OUT = sys.argv[1], sys.argv[2]
fr = json.load(open(S + 'vid/frames.json'))
FPS = 30
W, H = 1920, 1080

def kind(r):
    bg, pill, mid = r[1], r[2], r[3]
    if bg[0] < 40: return 'G'
    if bg[0] > 238 and pill[0] < 60 and pill[1] > 80:
        if abs(mid[0] - 11) + abs(mid[1] - 105) + abs(mid[2] - 83) < 15: return 'W'  # the green circle coming in
        return 'S'
    return 'L' if bg[0] > 238 else 'T'

job = {}
for ci, c in enumerate(CH):
    lo, hi = round((c['t'][0] - 0.2) * FPS), round(c['end'] * FPS) + 3
    idx = [r[0] for r in fr[lo:hi] if kind(r) == 'S']
    for i in idx:
        job[i] = (ci, i / FPS)
print('scene frames', len(job), 'of', len(fr), file=sys.stderr)

def render(i):
    from frame import frame
    ci, T = job[i]
    return i, frame(ci, T).tobytes()

if __name__ == '__main__':
    order = sorted(job)
    dec = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', SRC, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    enc = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                            '-i', SRC, '-map', '0:v', '-map', '1:a', '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p',
                            '-c:a', 'copy', '-movflags', '+faststart', '-shortest', OUT], stdin=subprocess.PIPE)
    with Pool(int(sys.argv[3]) if len(sys.argv) > 3 else 4) as pool:
        it = pool.imap(render, order, chunksize=4)
        nxt = next(it, None)
        n = 0
        while True:
            b = dec.stdout.read(W * H * 3)
            if len(b) < W * H * 3: break
            if nxt and nxt[0] == n:
                b = nxt[1]
                nxt = next(it, None)
            enc.stdin.write(b)
            n += 1
            if n % 600 == 0: print(n, file=sys.stderr, flush=True)
    enc.stdin.close(); enc.wait()
    print('done', n, file=sys.stderr)
