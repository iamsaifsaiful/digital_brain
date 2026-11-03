# Step I.1–2: the members' labelled samples → training rows.
#   python3 tool/nlu/retrain/labels.py [samples.jsonl]  → tool/nlu/out/data/real.jsonl
#
# Which reading is right, in this order (the brief's priority):
#   1. the admin's label (review in the admin app),
#   1b. the owner's review kept in the repo (review_labels.json — rows the
#      owner went through with Claude; used even when the server sends none),
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
REVIEW = os.path.join(HERE, 'review_labels.json')


def reviewed():
    """sample id → the owner's reviewed row (review_labels.json)."""
    if not os.path.exists(REVIEW):
        return {}
    out = {}
    for r in json.load(open(REVIEW))['labels']:
        bad = [i for i in r['intents'] if i not in INTENTS]
        if bad:
            raise SystemExit(f'review_labels.json: id {r["id"]}: not in the spec: {bad}')
        out[int(r['id'])] = r
    return out


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


def choose(s, review=None):
    """→ (intents, source) or None."""
    if s.get('admin_label'):
        lab = json.loads(s['admin_label'])
        got = [i for i in lab.get('intents', []) if i in INTENTS]
        if got:
            return got, 'admin'
    r = (review or {}).get(int(s.get('id') or 0))
    if r:
        return list(r['intents']), 'review'
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


def row(s, intents, source, rnd):
    text = fill_names(s['text_delex'], rnd)
    toks = text.split()
    state = s.get('state') or 'idle'
    r = dict(family=f"real:{s['id']}", kind='real', state=state, shown=[], asked=None, tokens=toks, tags=['O'] * len(toks), text=text,
             intent=intents, segs=[dict(intent=intents[0], start=0, end=len(toks), slots={})], slots={}, pair=None, noise=[],
             intent_only=True, source=f'real:{source}', sample_id=s['id'])
    if source in ('admin', 'review'):
        # Checked by a person: taught, never held back for the dev score.
        r['force_train'] = True
    return r


def main():
    rnd = random.Random(5)
    src = sys.argv[1] if len(sys.argv) > 1 else ''
    review = reviewed()
    rows, why, seen = [], {}, set()
    for line in (open(src) if src and os.path.exists(src) else []):
        if not line.strip():
            continue
        s = json.loads(line)
        seen.add(int(s['id']))
        got = choose(s, review)
        if not got:
            why['skipped'] = why.get('skipped', 0) + 1
            continue
        intents, source = got
        if len(intents) > 1:
            # Several requests in one message: the sample has no word positions to split them by.
            why['several'] = why.get('several', 0) + 1
            continue
        why[source] = why.get(source, 0) + 1
        rows.append(row(s, intents, source, rnd))
    # Reviewed rows the server did not send (no key, or the samples were deleted).
    for i, r in sorted(review.items()):
        if i in seen:
            continue
        why['review'] = why.get('review', 0) + 1
        rows.append(row({'id': i, 'text_delex': r['text'], 'state': r.get('state', 'idle')}, list(r['intents']), 'review', rnd))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')
    print(json.dumps({'rows': len(rows), **why}, ensure_ascii=False))


if __name__ == '__main__':
    main()
