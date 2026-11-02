# Turns tool/en.tsv (Bangla<TAB>English) into lib/core/en_words.dart.
# Run from the project root: python3 tool/gen_en.py
rows, seen = [], set()
for line in open('tool/en.tsv', encoding='utf8'):
    line = line.rstrip('\n')
    if '\t' not in line:
        continue
    bn, en = line.split('\t', 1)
    if bn not in seen:
        seen.add(bn)
        rows.append((bn, en))
q = lambda s: "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"
out = ['// Generated from tool/en.tsv by tool/gen_en.py. Do not edit by hand.', '', 'const enWords = <String, String>{']
out += [f'  {q(b)}: {q(e)},' for b, e in rows]
out.append('};')
open('lib/core/en_words.dart', 'w', encoding='utf8').write('\n'.join(out) + '\n')
print(len(rows))
