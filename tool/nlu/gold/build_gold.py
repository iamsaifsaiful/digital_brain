# Builds the gold (যাচাই) set: tool/nlu/gold/*.jsonl, one row per user turn.
#   python3 tool/nlu/gold/build_gold.py
#
# A row: id, source, tuned (the rules were fixed while looking at this source,
# so the old rules' score on it is optimistic), fixture (seed data the Dart
# harness loads), now, before (user turns said first, to set the context),
# state (the dialog state the turn is said in, worked out here), text, intent
# (a list: one message may ask several things), slots (what is known), expect
# (the data check of the whole scenario, on its last turn only).
#
# Sources: the conversations of test/screens_*_test.dart and
# regression_b85_test.dart, docs/master100-records.md, test/intent500_test.dart,
# test/intent_holdout_test.dart, test/angles_test.dart, test/angles_holdout_test.dart.
# real.jsonl is for the owner's own recorded sentences (empty until then).
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)
from labels_master100 import L as M100  # noqa: E402
from labels_screens import L as SCR  # noqa: E402

INTENTS = {i['id'] for i in json.load(open(os.path.join(ROOT, 'tool/nlu/spec/intents.json')))}


def dart_str(s):
    return s.replace("\\'", "'").replace('\\n', '\n').replace('\\$', '$')


def lst(x):
    return x if isinstance(x, list) else [x]


# The dialog state a turn is said in, from the intents of the turns before it
# (what the app would be waiting for after them).
WAITS = {
    'task_delete': 'confirm_delete', 'reminder_delete': 'confirm_delete', 'item_delete': 'confirm_delete',
    'cash_add': 'confirm_save', 'ledger_add': 'confirm_save', 'ledger_set': 'confirm_save', 'note_add': 'confirm_save', 'special_add': 'confirm_save',
    'task_remind': 'await_time', 'reminder_add': 'await_time', 'reminder_edit': 'await_new_value', 'dictate_start': 'dictating_list',
}


def state_after(prev):
    if not prev:
        return 'idle'
    last = lst(prev[-1])
    if 'dictate_start' in last or ('task_add' in last and 'dictating_list' in state_after(prev[:-1])):
        return 'dictating_list'
    for i in last:
        if i in WAITS:
            return WAITS[i]
    return 'idle'


def rows_from_conversation(source, key, fixture, now, turns, labels, tuned=True, expect=None):
    out, prev = [], []
    for j, text in enumerate(turns):
        lab = labels.get((key, j))
        if lab is None:
            prev.append('?')
            continue
        intents = lst(lab)
        for x in intents:
            assert x in INTENTS, (source, key, j, x)
        r = dict(id=f'{source}-{key}-{j}', source=source, tuned=tuned, fixture=fixture, now=now, before=turns[:j],
                 state=state_after([p for p in prev if p != '?']), text=text, intent=intents, slots={})
        if expect and j == len(turns) - 1:
            r['expect'] = expect
        out.append(r)
        prev.append(intents)
    return out


def master100():
    cases = re.split(r'\n### ', open(os.path.join(ROOT, 'docs/master100-records.md')).read())[1:]
    rows = []
    for c in cases:
        cid = c.split(' ', 1)[0]
        fx = re.search(r'fixture: (\S+)', c)
        fx = fx.group(1) if fx else 'own'
        turns = [t.replace('\\|', '|') for t in re.findall(r'  - ব্যবহারকারী: (.*)', c)]
        if not turns:
            continue
        fixture = {'T': 'm100_T', 'R': 'm100_R', 'P': 'm100_P', 'L': 'm100_L', 'T+R': 'm100_TR'}.get(fx, 'empty')
        rows += rows_from_conversation('master100', cid, fixture, '2026-10-19T11:00', turns, M100)
    return rows


def screens():
    files = sorted(glob.glob(os.path.join(ROOT, 'test/screens_*_test.dart'))) + [os.path.join(ROOT, 'test/regression_b85_test.dart')]
    tests = []
    for f in files:
        s = open(f).read()
        for p in re.split(r"\n\s*(?:testWidgets|test)\(\s*'", s)[1:]:
            name = p.split("'", 1)[0]
            turns = []
            for m in re.finditer(r"(?:say|hear|type|ask)\(\s*'((?:[^'\\]|\\.)*)'|talk\(t,\s*\[(.*?)\]\)", p, re.S):
                if m.group(1) is not None:
                    turns.append(dart_str(m.group(1)))
                else:
                    turns += [dart_str(x) for x in re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(2))]
            if turns:
                tests.append((os.path.basename(f), name, turns))
    rows = []
    for i, (f, name, turns) in enumerate(tests):
        rows += rows_from_conversation('screens', i, 'empty', '2026-10-09T15:53', turns, SCR)
    return rows


def parse_cases(path, multi):
    s = open(os.path.join(ROOT, path)).read()
    body = s[s.index('[\n') + 2:s.index('\n];')]
    out = []
    if multi:
        for m in re.finditer(r"\(\[(.*?)\], '(\w+)', '((?:[^'\\]|\\.)*)'\),", body):
            out.append(([dart_str(x) for x in re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(1))], m.group(2), dart_str(m.group(3))))
    else:
        for m in re.finditer(r"\('((?:[^'\\]|\\.)*)', '(\w+)', '((?:[^'\\]|\\.)*)'\),", body):
            out.append((dart_str(m.group(1)), m.group(2), dart_str(m.group(3))))
    return out


I500 = {'list': 'task_query', 'listday': 'task_query', 'add': 'task_add', 'done': 'task_done', 'delete': 'task_delete', 'move': 'task_edit',
        'remtask': 'task_remind', 'remind': 'reminder_add', 'remq': 'reminder_query', 'alarmq': 'reminder_query'}
DELETE_WORDS = re.compile(r'(মুছ|ডিলিট|বাদ|ফেলে)')


def none_intent(text):
    t = re.sub(r'^(ভাই|একটু|আচ্ছা|শোনো,|প্লিজ|আপু|জি,)\s+|\s+(প্লিজ|তো|একটু|ভাই)$', '', text.strip().rstrip('?।'))
    if 'ধন্যবাদ' in t:
        return 'smalltalk'
    if t in ('ঠিক আছে', 'হুম', 'আচ্ছা', 'হ্যাঁ'):
        return 'confirm_yes'
    if t == 'না':
        return 'confirm_no'
    return 'complain_help'


def intent500(path, source, fixture):
    rows = []
    for n, (text, label, arg) in enumerate(parse_cases(path, False)):
        if label == 'remoff':
            intent = 'reminder_delete' if DELETE_WORDS.search(text) else 'reminder_stop'
        elif label == 'none':
            intent = none_intent(text)
        else:
            intent = I500[label]
        slots = {}
        if label == 'add':
            slots['title_has'] = arg
        rows.append(dict(id=f'{source}-{n:04d}', source=source, tuned=True, fixture=fixture, now='2026-10-19T11:00', before=[], state='idle',
                         text=text, intent=[intent], slots=slots, expect=dict(check=label, arg=arg)))
    return rows


def angle_turn_intent(turns, j, check):
    t = turns[j]
    if j == 0 and len(turns) > 1 and t in ('আমার কাজের তালিকা দাও',):
        return 'task_query'
    if j == 0 and len(turns) > 1 and t in ('আমার সব রিমাইন্ডার দাও',):
        return 'reminder_query'
    if j == 0 and len(turns) > 1 and t in ('সব রিমাইন্ডার মুছে দাও', 'সব রিমাইন্ডার বাদ দাও'):
        return 'reminder_delete'
    if j == 0 and len(turns) > 1 and t == 'সব কাজ মুছে দাও':
        return 'task_delete'
    first = {'rename': 'rename', 'deltasks': 'task_delete', 'done': 'task_done', 'move': 'task_edit', 'remtime': 'reminder_edit',
             'delrems': 'reminder_delete', 'remtask': 'task_remind', 'remoff': 'reminder_stop', 'none': 'complain_help'}
    if j == 0 or (j == 1 and turns[0] in ('আমার কাজের তালিকা দাও', 'আমার সব রিমাইন্ডার দাও') and check not in ('remtask',)):
        if check == 'delrems' and not DELETE_WORDS.search(t):
            return 'reminder_stop'
        if check == 'remoff' and DELETE_WORDS.search(t):
            return 'reminder_delete'
        return first[check]
    # Later turns: an answer to what the app asked.
    if t == 'ওটাই সরাও':
        return 'select'
    if re.match(r'^(না[,!]?\s+)?(না\s+)?(শুধু|শুধুমাত্র|কেবল)', t) or re.match(r'^না,?\s+(কেবল|শুধু)', t):
        return 'select'
    if check == 'remtime':
        return 'inform'
    return 'confirm_yes'


def angles(path, source, tuned=True):
    rows = []
    for n, (turns, check, arg) in enumerate(parse_cases(path, True)):
        prev = []
        for j, t in enumerate(turns):
            intent = angle_turn_intent(turns, j, check)
            r = dict(id=f'{source}-{n:04d}-{j}', source=source, tuned=tuned, fixture='angles', now='2026-10-19T20:30', before=turns[:j],
                     state=state_after(prev), text=t, intent=[intent], slots={})
            if j == len(turns) - 1:
                r['expect'] = dict(check=check, arg=arg)
            rows.append(r)
            prev.append([intent])
    return rows


def main():
    sets = {
        'screens': screens(),
        'master100': master100(),
        'intent500': intent500('test/intent500_test.dart', 'intent500', 'intent500'),
        'intent_holdout': intent500('test/intent_holdout_test.dart', 'intent_holdout', 'intent500'),
        'angles': angles('test/angles_test.dart', 'angles'),
        'angles_holdout': angles('test/angles_holdout_test.dart', 'angles_holdout'),
    }
    total = 0
    for name, rows in sets.items():
        with open(os.path.join(HERE, f'{name}.jsonl'), 'w') as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + '\n')
        total += len(rows)
        print(f'{name}: {len(rows)}')
    real = os.path.join(HERE, 'real.jsonl')
    if not os.path.exists(real):
        open(real, 'w').close()
    print('total', total)


if __name__ == '__main__':
    main()
