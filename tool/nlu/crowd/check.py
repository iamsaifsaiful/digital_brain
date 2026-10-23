# Checks the app's answers to the crowd (crowd.py) against what each user
# meant, and says who it fails: by district's speech, schooling, trade,
# temper, regard, home, age, and by the kind of request.
#   python3 tool/nlu/crowd/check.py test/persona/out/crowd_test.jsonl [--half test] [--md out.md]
import argparse, json, os
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'out', 'crowd')

RULE_OK = {
    'cash_add': {'CashAdd'}, 'ledger_add': {'LedgerAdd'}, 'cash_query': {'CashQuery', 'Menu:cash'}, 'ledger_query': {'LedgerQuery'},
    'task_add': {'TaskAdd'}, 'reminder_add': {'ReminderAdd'}, 'task_query': {'TaskQuery', 'Briefing'}, 'reminder_query': {'ReminderQuery'},
    'health_add': {'HealthAdd', 'Menu:health'}, 'contact_add': {'ContactAdd'}, 'call': {'CallPerson'}, 'open_page': {'OpenPlace'},
    'special_add': {'SpecialAdd'},
}


def rule_verdict(want_intent, want, cmds):
    """'ok', 'asks' (right kind, a detail left to ask) or a short reason."""
    if len(cmds) != 1:
        return f'{len(cmds)} commands' if cmds else 'nothing'
    c = cmds[0]
    t = c['t'] if c['t'] != 'Menu' else f"Menu:{c['domain']}"
    if t not in RULE_OK[want_intent]:
        return f'as {t}'
    if 'amount' in want and c.get('amount') != want['amount']:
        return 'amount' if c.get('amount') else 'asks amount'
    if 'cash_kind' in want and c.get('kind') != want['cash_kind']:
        return 'in/out'
    if 'ledger_kind' in want and c.get('kind') != want['ledger_kind']:
        return 'asks kind' if c.get('kind') is None else 'lent/borrowed'
    if 'hour' in want and c.get('hour') != want['hour']:
        return 'asks time' if c.get('hour') is None else 'hour'
    if want.get('repeat') and c.get('repeat') != want['repeat']:
        return 'repeat'
    return 'ok'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pred')
    ap.add_argument('--half', default='test')
    ap.add_argument('--md')
    a = ap.parse_args()
    users = {u['id']: u for u in map(json.loads, open(os.path.join(OUT, 'users.jsonl')))}
    rows = {r['id']: r for r in map(json.loads, open(os.path.join(OUT, f'{a.half}.jsonl')))}
    preds = [json.loads(l) for l in open(a.pred)]
    by = defaultdict(lambda: defaultdict(lambda: [0, 0, 0]))  # attr → value → [n, rules ok, model ok]
    why = Counter()
    fails = defaultdict(list)
    n = rok = mok = msure = mright = 0
    for p in preds:
        g = rows[p['id']]
        u = users[g['user']]
        v = rule_verdict(g['intent'], g['want'], p['rules'])
        ok = v == 'ok'
        m = p.get('model')
        mk = m is not None and m == [g['intent']]
        n += 1
        rok += ok
        mok += mk
        if m is not None and p.get('model_conf', 0) >= 0.8:
            msure += 1
            mright += mk
        if not ok:
            why[(g['intent'], v)] += 1
            fails[(g['intent'], v)].append(g['text'])
        for attr in ('dialect', 'school', 'trade', 'temper', 'regard', 'home', 'age', 'mic'):
            b = by[attr][str(u[attr])]
            b[0] += 1
            b[1] += ok
            b[2] += mk
        b = by['intent'][g['intent']]
        b[0] += 1
        b[1] += ok
        b[2] += mk
    pc = lambda x, y: f'{100 * x / y:.1f}%' if y else '—'
    L = [f'# ২০০০ জনের পরীক্ষা — {a.half}', '', f'বাক্য: {n} · নিয়ম ঠিক: {pc(rok, n)}' + (f' · মডেল ঠিক intent: {pc(mok, n)} · মডেল নিশ্চিত (≥০.৮): {msure}, তার মধ্যে ঠিক {pc(mright, msure)}' if any('model' in p for p in preds) else ''), '']
    names = {'dialect': 'এলাকার ভাষা', 'school': 'পড়াশোনা', 'trade': 'পেশা', 'temper': 'মেজাজ', 'regard': 'মানুষকে যেভাবে বলে', 'home': 'থাকেন', 'age': 'বয়স', 'mic': 'মাইকে বলেন', 'intent': 'অনুরোধের ধরন'}
    for attr, vals in by.items():
        L += [f'## {names[attr]}', '', '| | বাক্য | নিয়ম ঠিক | মডেল ঠিক |', '|---|---|---|---|']
        for k, (c, r_, m_) in sorted(vals.items(), key=lambda kv: kv[1][1] / kv[1][0]):
            L.append(f'| {k} | {c} | {pc(r_, c)} | {pc(m_, c)} |')
        L.append('')
    L += ['## নিয়মের ভুল, ধরন অনুযায়ী', '', '| অনুরোধ | কী হলো | কয়টা | যেমন |', '|---|---|---|---|']
    for (i, v), c in why.most_common(40):
        L.append(f'| {i} | {v} | {c} | {fails[(i, v)][0]} |')
    s = '\n'.join(L)
    if a.md:
        open(a.md, 'w').write(s)
    print(s)


if __name__ == '__main__':
    main()
