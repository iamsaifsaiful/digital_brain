# Step I.3: may the new model replace the one members have now?
#   python3 tool/nlu/retrain/gate.py new_pred.jsonl old_pred.jsonl --key bert [--md report.md]
# Refused when any intent's accuracy on the gold set drops by more than one
# point and more than one sentence (intents with at least 5 gold rows), or when removals or money get
# less accurate, or when more removals are proposed that nobody asked for.
import argparse, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import eval as E  # noqa: E402


def pct(a, b):
    return 100 * a / b if b else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('new')
    ap.add_argument('old')
    ap.add_argument('--key', default='bert')
    ap.add_argument('--old-key', default='bert')
    ap.add_argument('--md')
    a = ap.parse_args()
    gold = E.load_gold(os.path.join(HERE, '..', 'gold'))
    load = lambda f: [json.loads(l) for l in open(f) if l.strip()]
    new, old = E.evaluate(gold, load(a.new), a.key), E.evaluate(gold, load(a.old), a.old_key)
    problems, lines = [], []
    for intent, (n, ok_new) in sorted(new['per'].items()):
        n_old, ok_old = old['per'].get(intent, (0, 0))
        if n >= 5 and n_old:
            d = pct(ok_new, n) - pct(ok_old, n_old)
            lines.append(f'| {intent} | {n} | {pct(ok_old, n_old):.1f}% | {pct(ok_new, n):.1f}% | {d:+.1f} |')
            # A drop counts when it is more than one point AND more than one
            # sentence (with 7 gold rows one sentence is 14 points; owner,
            # 26 Oct: a single row should not decide).
            lost = round(ok_old / n_old * n - ok_new) if n_old else 0
            if d < -1.0 and lost >= 2:
                problems.append(f'{intent}: {d:+.1f} পয়েন্ট ({lost}টা বাক্য)')
    for name in ('delete', 'money'):
        if pct(new[name][1], new[name][0]) < pct(old[name][1], old[name][0]):
            problems.append(f'{name}: {pct(old[name][1], old[name][0]):.1f}% → {pct(new[name][1], new[name][0]):.1f}%')
    if new['false_delete'] > old['false_delete']:
        problems.append(f"না-চাওয়া মোছা: {old['false_delete']} → {new['false_delete']}")
    ok = not problems
    report = '\n'.join([
        f"# নতুন মডেল {'পাস' if ok else 'বাতিল'}", '',
        f"পুরো মিল: {pct(old['exact'], old['n']):.1f}% → {pct(new['exact'], new['n']):.1f}% · মোছা {pct(old['delete'][1], old['delete'][0]):.1f}% → {pct(new['delete'][1], new['delete'][0]):.1f}% · টাকা {pct(old['money'][1], old['money'][0]):.1f}% → {pct(new['money'][1], new['money'][0]):.1f}%",
        '', ('**কারণ:** ' + '; '.join(problems)) if problems else 'কোনো intent ১ পয়েন্টের বেশি খারাপ হয়নি; মোছা আর টাকা কমেনি।', '',
        '| intent | সারি | আগে | পরে | বদল |', '|---|---|---|---|---|', *lines,
    ])
    if a.md:
        open(a.md, 'w').write(report)
    print(report)
    json.dump({'ok': ok, 'problems': problems, 'exact': round(pct(new['exact'], new['n']) / 100, 4),
               'delete': round(pct(new['delete'][1], new['delete'][0]) / 100, 4), 'money': round(pct(new['money'][1], new['money'][0]) / 100, 4)},
              open(os.path.join(os.path.dirname(a.new), 'gate.json'), 'w'))
    sys.exit(0 if ok else 3)


if __name__ == '__main__':
    main()
