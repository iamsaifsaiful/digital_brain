# Step I.1–2: the members' labelled samples → training rows.
#   python3 tool/nlu/retrain/labels.py samples.jsonl  → tool/nlu/out/data/real.jsonl
#
# Which reading is right, in this order (the brief's priority):
#   1. the admin's label (review in the admin app),
#   2. the member's own correction (what they did after an edit / "না" / undo),
#   3. the cloud's reading,
#   4. the phone's reading when it was sure (≥ 0.9) and drew no error signal
#      and the member's final action agreed.
# Otherwise the sample is skipped. The names the phone took out ("<নাম১>")
# are filled with made-up names, so the model learns names in general. These
# rows teach the intent only (no fact labels: the samples carry none).
import json, os, random, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'data'))
import lexicon as L  # noqa: E402

OUT = os.path.abspath(os.path.join(HERE, '..', 'out', 'data', 'real.jsonl'))
SPEC = json.load(open(os.path.join(HERE, '..', 'spec', 'intents.json')))
INTENTS = {x['id'] for x in SPEC}
FIX = {'edited', 'said_no', 'undo', 'repeated', 'thumbs_down'}


def intents_of(j):
    try:
        d = json.loads(j) if isinstance(j, str) else j
    except Exception:
        return []
    pieces = d.get('pieces', d) if isinstance(d, dict) else d
    out = []
    for p in pieces or []:
        i = p.get('intent') if isinstance(p, dict) else None
        if i in INTENTS and i not in out:
            out.append(i)
    return out


def choose(s):
    """→ (intents, source) or None."""
    if s.get('admin_label'):
        lab = json.loads(s['admin_label'])
        got = [i for i in lab.get('intents', []) if i in INTENTS]
        if got:
            return got, 'admin'
    sig = s.get('signal_kind') or s.get('signal') or ''
    final = intents_of(s.get('final_json'))
    local = intents_of(s.get('local_json'))
    if sig in FIX and final and final != local:
        return final, 'user'
    cloud = intents_of(s.get('cloud_json'))
    if cloud:
        return cloud, 'cloud'
    if local and float(s.get('local_conf') or 0) >= 0.9 and sig in ('', 'thumbs_up') and (not final or final == local):
        return local, 'phone'
    return None


def fill_names(text, rnd):
    names = {}

    def one(m):
        if m.group(0) not in names:
            names[m.group(0)] = rnd.choice(L.NAMES)
        return names[m.group(0)]
    return re.sub(r'<নাম[০-৯0-9]+>', one, text)


def main():
    rnd = random.Random(5)
    src = sys.argv[1]
    rows, why = [], {}
    for line in open(src):
        if not line.strip():
            continue
        s = json.loads(line)
        got = choose(s)
        if not got:
            why['skipped'] = why.get('skipped', 0) + 1
            continue
        intents, source = got
        if len(intents) > 1:
            # Several requests in one message: the sample has no word positions to split them by.
            why['several'] = why.get('several', 0) + 1
            continue
        why[source] = why.get(source, 0) + 1
        text = fill_names(s['text_delex'], rnd)
        toks = text.split()
        state = s.get('state') or 'idle'
        rows.append(dict(family=f"real:{s['id']}", kind='real', state=state, shown=[], asked=None, tokens=toks, tags=['O'] * len(toks), text=text,
                         intent=intents, segs=[dict(intent=intents[0], start=0, end=len(toks), slots={})], slots={}, pair=None, noise=[],
                         intent_only=True, source=f'real:{source}', sample_id=s['id']))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')
    print(json.dumps({'rows': len(rows), **why}, ensure_ascii=False))


if __name__ == '__main__':
    main()
