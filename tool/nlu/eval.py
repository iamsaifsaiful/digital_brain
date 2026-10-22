# Measures a reading of the gold set (tool/nlu/gold/*.jsonl).
#   python3 tool/nlu/eval.py tool/nlu/out/baseline_old.jsonl [--system chat|parse|<key>] [--md out.md]
#
# A prediction file has one JSON object per gold row: {"id": …, "<system>": [intents…]}
# and, for a model, "<system>_conf": 0..1 and "<system>_slots": {…}.
#
# Reports: how much is settled on the phone at each confidence threshold and
# how much of that is right; accuracy per intent and the confusions; the
# accuracy of removals and of money; slots where both sides have them; all by
# source, and apart for rows the old rules were tuned on.
import argparse, glob, json, os
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
DELETE = {'task_delete', 'reminder_delete', 'item_delete'}
MONEY = {'ledger_add', 'ledger_set', 'ledger_query', 'cash_add', 'cash_query', 'menu_accounts', 'menu_savings', 'menu_shop', 'menu_cash', 'menu_project', 'menu_installment'}
UNDECIDED_PREFIX = ('none', 'reply', 'wait:', 'pending:', 'query:', 'other', 'bulk_', 'item_edit')


def load_gold(gold_dir):
    rows = {}
    for f in sorted(glob.glob(os.path.join(gold_dir, '*.jsonl'))):
        for line in open(f):
            if line.strip():
                r = json.loads(line)
                rows[r['id']] = r
    return rows


def decided(pred):
    return bool(pred) and not any(p.startswith(UNDECIDED_PREFIX) for p in pred)


def pct(a, b):
    return f'{100 * a / b:.1f}%' if b else '—'


CLOSED = json.load(open(os.path.join(HERE, 'gold', 'closed.json')))


def is_closed(g):
    words = [w for w in g['text'].replace('?', ' ').replace(',', ' ').replace('।', ' ').split() if w]
    return set(g['intent']) <= set(CLOSED['intents']) and len(words) <= CLOSED['max_words']


def evaluate(gold, preds, system):
    allrows = [(gold[p['id']], p) for p in preds if p['id'] in gold and system in p]
    rows = [(g, p) for g, p in allrows if not is_closed(g)]
    closed = [(g, p) for g, p in allrows if is_closed(g)]
    out = {}
    # Coverage and accuracy at confidence thresholds (rules: decided = 1.0).
    th = [0.0, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95]
    cov = []
    for t in th:
        n = ok = 0
        for g, p in rows:
            conf = p.get(f'{system}_conf', 1.0 if decided(p[system]) else 0.0)
            if conf >= t and decided(p[system]):
                n += 1
                ok += set(p[system]) == set(g['intent'])
        cov.append((t, n, ok))
    out['coverage'] = cov
    exact = sum(set(p[system]) == set(g['intent']) for g, p in rows)
    primary = sum(g['intent'][0] in p[system] for g, p in rows)
    out['n'], out['exact'], out['primary'] = len(rows), exact, primary
    # The same sentence appears many times in some sources (one screen, many
    # contexts); count each distinct (text, state) once as well.
    seen = {}
    for g, p in rows:
        seen.setdefault((g['text'], g['state']), set(p[system]) == set(g['intent']))
    out['distinct'] = (len(seen), sum(seen.values()))
    # Per intent (gold primary).
    per = defaultdict(lambda: [0, 0])
    conf = Counter()
    for g, p in rows:
        gi = g['intent'][0]
        per[gi][0] += 1
        per[gi][1] += gi in p[system]
        if gi not in p[system]:
            conf[(gi, (p[system] or ['∅'])[0])] += 1
    out['per'] = per
    out['confusions'] = conf
    # Removals and money.
    for name, s in (('delete', DELETE), ('money', MONEY)):
        sub = [(g, p) for g, p in rows if set(g['intent']) & s]
        out[name] = (len(sub), sum(set(p[system]) == set(g['intent']) for g, p in sub))
        # Wrong removals: something removed when the user did not ask to remove.
        if name == 'delete':
            out['false_delete'] = sum(1 for g, p in rows if (set(p[system]) & DELETE) and not (set(g['intent']) & DELETE))
    # Slots, where both have them.
    sl = [(g, p) for g, p in rows if g.get('slots') and p.get(f'{system}_slots') is not None]
    def slot_ok(ps, k, v):
        if k == 'title_has':
            return v in (ps.get('title') or '')
        return ps.get(k) == v
    out['slots'] = (len(sl), sum(all(slot_ok(p[f'{system}_slots'], k, v) for k, v in g['slots'].items()) for g, p in sl))
    # By source and tuned.
    src = defaultdict(lambda: [0, 0])
    for g, p in rows:
        k = f"{g['source']}{'' if g.get('tuned', True) else ' (untuned)'}"
        src[k][0] += 1
        src[k][1] += set(p[system]) == set(g['intent'])
    out['by_source'] = src
    out['by_state'] = defaultdict(lambda: [0, 0])
    for g, p in rows:
        out['by_state'][g['state']][0] += 1
        out['by_state'][g['state']][1] += set(p[system]) == set(g['intent'])
    out['closed'] = (len(closed), sum(set(p[system]) == set(g['intent']) for g, p in closed))
    return out


def report(name, r):
    L = [f'## {name}', '', f"সারি: {r['n']} · পুরো মিল (সব intent): {pct(r['exact'], r['n'])} · প্রধান intent ধরা: {pct(r['primary'], r['n'])} · আলাদা বাক্য ধরে: {r['distinct'][1]}/{r['distinct'][0]} ({pct(r['distinct'][1], r['distinct'][0])})", '',
         '**আত্মবিশ্বাসের সীমা অনুযায়ী ফোনে সমাধান** (নিয়মে আত্মবিশ্বাস নেই — সিদ্ধান্ত নিলে ১.০)', '', '| সীমা | ফোনে সমাধান | তার মধ্যে ঠিক |', '|---|---|---|']
    for t, n, ok in r['coverage']:
        L.append(f"| {t:.2f} | {n} ({pct(n, r['n'])}) | {ok} ({pct(ok, n)}) |")
    d, m = r['delete'], r['money']
    L += ['', f"মোছা: {d[1]}/{d[0]} ঠিক ({pct(d[1], d[0])}); না-চাওয়া মোছার প্রস্তাব: {r['false_delete']} · টাকা: {m[1]}/{m[0]} ঠিক ({pct(m[1], m[0])})",
          f"ছোট সাধারণ উত্তর (শেখানোয় আছে, মূল হিসাবের বাইরে): {r['closed'][1]}/{r['closed'][0]}",
          f"তথ্য (slot) হুবহু: " + (f"{r['slots'][1]}/{r['slots'][0]}" if r['slots'][0] else 'এই পদ্ধতি তথ্য দেয় না — মাপা হয়নি'), '',
          '**উৎস অনুযায়ী**', '', '| উৎস | সারি | পুরো মিল |', '|---|---|---|']
    for k, (n, ok) in sorted(r['by_source'].items()):
        L.append(f'| {k} | {n} | {pct(ok, n)} |')
    L += ['', '**অবস্থা অনুযায়ী**', '', '| অবস্থা | সারি | পুরো মিল |', '|---|---|---|']
    for k, (n, ok) in sorted(r['by_state'].items()):
        L.append(f'| {k} | {n} | {pct(ok, n)} |')
    L += ['', '**intent-ওয়ারি (প্রধান intent ধরা)**', '', '| intent | সারি | ধরা |', '|---|---|---|']
    for k, (n, ok) in sorted(r['per'].items(), key=lambda x: (-x[1][0], x[0])):
        L.append(f'| {k} | {n} | {pct(ok, n)} |')
    L += ['', '**সবচেয়ে বেশি গুলিয়ে যাওয়া (ঠিক → যা পড়া হলো)**', '', '| ঠিক | পড়া হলো | বার |', '|---|---|---|']
    for (a, b), n in r['confusions'].most_common(25):
        L.append(f'| {a} | {b} | {n} |')
    return '\n'.join(L)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pred')
    ap.add_argument('--gold', default=os.path.join(HERE, 'gold'))
    ap.add_argument('--system', action='append')
    ap.add_argument('--md')
    a = ap.parse_args()
    gold = load_gold(a.gold)
    preds = [json.loads(l) for l in open(a.pred) if l.strip()]
    systems = a.system or [k for k in ('chat', 'parse', 'local', 'cloud') if any(k in p for p in preds)]
    parts = [f'# যাচাই-সেটে মাপ — {os.path.basename(a.pred)}', '', f'যাচাই-সেট: {len(gold)} সারি · ভবিষ্যদ্বাণী: {len(preds)}', '']
    for s in systems:
        parts.append(report({'chat': 'পুরো চ্যাট (এখনকার নিয়ম, প্রসঙ্গসহ)', 'parse': 'শুধু parseAll() (প্রসঙ্গ ছাড়া)'}.get(s, s), evaluate(gold, preds, s)))
        parts.append('')
    text = '\n'.join(parts)
    if a.md:
        open(a.md, 'w').write(text)
    print(text)


if __name__ == '__main__':
    main()
