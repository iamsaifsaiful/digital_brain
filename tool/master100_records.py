#!/usr/bin/env python3
"""Builds docs/master100-records.md from a run of test/master100_test.dart.

Usage: flutter test --no-pub test/master100_test.dart > run.log
       python3 tool/master100_records.py run.log <commit>
Each record: case, fixture, clock, the turns as run, the stored-state
checks (the test's expect lines), the result, and the first-run result.
"""
import re, sys, collections

log, commit = sys.argv[1], sys.argv[2]
src = open('test/master100_test.dart', encoding='utf-8').read()
text = open(log, encoding='utf-8').read()

# Test blocks in the source: id, title, fixture, expects.
blocks = {}
for m in re.finditer(r"(?:testWidgets|test)\('((C\d\d|R\d|H\d)[^']*?)'", src):
    start = m.end()
    nxt = re.search(r"\n  (?:testWidgets|test|group|final heldOut|for \(final e)", src[start:])
    body = src[start:start + (nxt.start() if nxt else 4000)]
    fx = [f for f, k in (('T', 'fixtureT('), ('R', 'fixtureR('), ('P', 'fixtureP('), ('L', 'fixtureL(')) if k in body] or ['own']
    exp = [re.sub(r'\s+', ' ', e.strip())[:140] for e in re.findall(r'expect\((.*?)\);', body)]
    blocks[m.group(2)] = (m.group(1), '+'.join(fx), exp)
# Held-out cases live in a map: their keys are the titles.
for m in re.finditer(r"'(H\d)([^']*)': \(\) async \{(.*?)\n    \},", src, re.S):
    exp = [re.sub(r'\s+', ' ', e.strip())[:140] for e in re.findall(r'expect\((.*?)\);', m.group(3))]
    blocks[m.group(1)] = (m.group(1) + m.group(2), 'own', exp)

# Turns and results per test, from the log.
turns = collections.defaultdict(list)
result = {}
cur = None
for line in text.split('\n'):
    h = re.match(r'^\d\d:\d\d \+\d+(?: -\d+)?: (?:AI on )?((C\d\d|R\d|H\d)\S*)', line)
    if h:
        cur = h.group(2)
        if line.rstrip().endswith('[E]'):
            result[cur] = 'fail'
        continue
    if cur and line.startswith('» '):
        turns[cur].append(['user', line[2:].strip()])
    elif cur and line.startswith('  ') and turns[cur] and turns[cur][-1][0] == 'user' and re.search(r'\[\w+\]\s*$', line):
        turns[cur].append(['app', line.strip()])
final = re.search(r'\+(\d+)(?: -(\d+))?: (All tests passed|Some tests failed)', text)

first_fail = set('C19 C20 C21 C24 C25 C29 C38 C41 C44 C46 C47 C48 C49 C54 C55 C58 C61 C64 C65 C68 C70 C71 C78 C79 C90 C96 C97 C99 C09 C62 C72 C73 C95'.split())
test_wrong = {'C19': 'test expected a duplicate of T7; the app rightly said it was already there', 'C96': 'test expected "AB+", the app says "এবি পজিটিভ"', 'C99': 'test expected the word নভেম্বর; the app said "আগামী মাসে কোনো সরকারি ছুটি নেই"'}

def bn(s):
    return s.replace('|', '\\|')

out = ['# ১০০-case — প্রতি case-এর রেকর্ড', '',
       f'commit `{commit}` · ঘড়ি ১৯ অক্টোবর ২০২৬ ১১:০০ Asia/Dhaka · input: লেখা (chat-এর একই পথ, ভয়েস নয়) · scheduler: FakeNotifier · AI: বন্ধ (R1, R4, C09-এ FakeAi)',
       f'চালানো (পুরো suite ১০৭১ পাসের অংশ): `flutter test --no-pub test/master100_test.dart` → {final.group(1) if final else "?"} পাস, {final.group(2) or 0 if final else "?"} ব্যর্থ', '',
       'প্রথম চালানো = নিয়ম ঠিক করার আগে এই test প্রথমবার চালানোর ফল।', '']
def key(k):
    return (k[0], int(k[1:]))
for cid in sorted(blocks, key=key):
    title, fx, exp = blocks[cid]
    res = result.get(cid, 'pass')
    first = 'fail' if cid in first_fail else 'pass'
    out.append(f'### {cid} — {bn(title[len(cid):].strip())}')
    out.append('')
    out.append(f'- fixture: {fx} · ফল: **{res}** · প্রথম চালানো: {first}' + (f' (test-এর ভুল: {test_wrong[cid]})' if cid in test_wrong else ''))
    if turns.get(cid):
        out.append('- কথোপকথন:')
        for who, t in turns[cid][:12]:
            out.append(f'  - {"ব্যবহারকারী" if who == "user" else "অ্যাপ"}: {bn(t[:300])}')
    if exp:
        out.append('- যা যাচাই হলো (DB/উত্তর):')
        for e in exp[:8]:
            out.append(f'  - `{e}`')
    out.append('')
open('docs/master100-records.md', 'w', encoding='utf-8').write('\n'.join(out))
print(len(blocks), 'records;', sum(1 for k in blocks if result.get(k) == 'fail'), 'failing')
