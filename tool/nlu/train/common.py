# Shared by every model: the same text normalisation, word split, context
# marker and rule-based split of lines/numbered lists. The Dart side
# (lib/nlu/normalize.dart, segment.dart) must give exactly the same output —
# test vectors: tool/nlu/train/vectors.jsonl.
import json, os, re, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
DATA = os.path.join(ROOT, 'out', 'data')
GOLD = os.path.join(ROOT, 'gold')

ASCII2BN = str.maketrans('0123456789', '০১২৩৪৫৬৭৮৯')
PUNCT = re.compile(r'[?!,।;:"“”‘’\'()\[\]{}…|]+')
ZW = re.compile('[​‌‍﻿]')


def normalize(text):
    """Lower-case, NFC, no zero-width marks, Bengali digits, punctuation to
    spaces (but "/=", "." inside numbers and "-" stay), one space."""
    t = unicodedata.normalize('NFC', text)
    t = ZW.sub('', t).lower().translate(ASCII2BN)
    t = PUNCT.sub(' ', t)
    t = re.sub(r'(?<![০-৯])[.\-]|[.\-](?![০-৯])', ' ', t)
    return re.sub(r'\s+', ' ', t).strip()


def words(text):
    return normalize(text).split()


LIST_MARK = re.compile(r'(?:^|\s)([০-৯0-9]{1,2})\s*[.)।]\s+')


def split_lines(text):
    """Rule split: new lines and numbered items ("১. … ২) …"). A heading
    ending in ':' before the first item is returned apart."""
    parts = []
    for line in re.split(r'\n+', text.strip()):
        line = line.strip()
        if not line:
            continue
        marks = list(LIST_MARK.finditer(line))
        if len(marks) >= 2:
            head = line[:marks[0].start()].strip()
            if head:
                parts.append(('head', head))
            for i, m in enumerate(marks):
                end = marks[i + 1].start() if i + 1 < len(marks) else len(line)
                parts.append(('item', line[m.end():end].strip()))
        else:
            parts.append(('line', line))
    return parts


def shown_kind(state, before, shown=None):
    if state in ('idle', 'await_time', 'await_ampm', 'await_new_value', 'await_person', 'await_kind', 'confirm_save'):
        return 'none'
    if shown is not None:
        if not shown:
            return 'none'
    text = ' '.join(before or []) + ' ' + ' '.join(shown or [])
    return 'reminders' if 'রিমাইন্ডার' in text else 'tasks'


def ctx_tokens(state, kind):
    return [f'<s:{state}>', f'<l:{kind}>']


def load_jsonl(path):
    return [json.loads(l) for l in open(path) if l.strip()]


def gold_rows():
    rows = []
    for f in sorted(os.listdir(GOLD)):
        if f.endswith('.jsonl'):
            rows += load_jsonl(os.path.join(GOLD, f))
    return rows


def train_kind(r):
    """Shown-list kind for a generated row (state + what was shown)."""
    if r['state'] == 'idle' or not r.get('shown'):
        return 'none'
    asked = r.get('asked') or ''
    return 'reminders' if 'রিমাইন্ডার' in asked else 'tasks'


def spans(ws, tags):
    """First span of each slot → its words."""
    slots, cur, buf = {}, None, []
    for w, t in list(zip(ws, tags)) + [('', 'O')]:
        if cur and not (t.startswith('I-') and t[2:] == cur):
            slots.setdefault(cur, ' '.join(buf))
            cur, buf = None, []
        if t.startswith('B-'):
            cur, buf = t[2:], [w]
        elif t.startswith('I-') and cur:
            buf.append(w)
    return slots


def read(text, state, kind, tag_fn, intent_fn):
    """The reading every model shares: rule split of lines and numbered items
    (a first line ending in ':' is a heading), then the model's boundary tags
    split a line, then each piece gets an intent.
    tag_fn(ctx, words) → (slot tags, boundary tags); intent_fn(ctx, words) → (intent, conf).
    Returns [{intent, conf, words, slots}]."""
    ctx = ctx_tokens(state, kind)
    parts = split_lines(text)
    if len(parts) > 1:
        parts = [('head', p) if (k == 'line' and i == 0 and p.rstrip().endswith((':', '-', 'ঃ'))) else (k, p) for i, (k, p) in enumerate(parts)]
    out = []
    for kind_, p in parts:
        ws = words(p)
        if not ws or kind_ == 'head':
            continue
        tags, bound = tag_fn(ctx, ws)
        cuts = [0] + [i for i in range(1, len(ws)) if bound[i] == 'B' and i >= 2 and len(ws) - i >= 2] + [len(ws)]
        for a, b in zip(cuts, cuts[1:]):
            intent, conf = intent_fn(ctx, ws[a:b])
            out.append(dict(intent=intent, conf=conf, words=ws[a:b], slots=spans(ws[a:b], tags[a:b])))
    return out


def gold_prediction(g, name, segs):
    intents = []
    for s in segs:
        if s['intent'] not in intents:
            intents.append(s['intent'])
    return {'id': g['id'], name: intents, f'{name}_conf': min((s['conf'] for s in segs), default=0.0),
            f'{name}_slots': segs[0]['slots'] if segs else {}}


def norm_tokens(tokens, tags):
    """Training rows are split on spaces with punctuation attached; split each
    word the way the app will (normalize) and carry its label."""
    out_t, out_g, idx = [], [], []
    for i, (t, g) in enumerate(zip(tokens, tags)):
        for k, p in enumerate(normalize(t).split()):
            out_t.append(p)
            out_g.append(g if k == 0 or g == 'O' else 'I-' + g[2:])
            idx.append(i)
    return out_t, out_g, idx


def examples(rows):
    """→ pieces (ctx, words, intent) and sequences (ctx, words, slot tags, boundary tags, n_segments)."""
    segs, seqs = [], []
    for r in rows:
        ctx = ctx_tokens(r['state'], train_kind(r))
        toks, tags, idx = norm_tokens(r['tokens'], r['tags'])
        if not toks:
            continue
        bound = ['O'] * len(toks)
        n = 0
        for s in r['segs']:
            ws = [j for j, i in enumerate(idx) if s['start'] <= i < s['end']]
            if not ws:
                continue
            n += 1
            bound[ws[0]] = 'B'
            for j in ws[1:]:
                bound[j] = 'I'
            segs.append((ctx, [toks[j] for j in ws], s['intent'], [tags[j] for j in ws]))
        seqs.append((ctx, toks, tags, bound, n))
    return segs, seqs
