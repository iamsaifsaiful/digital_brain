#!/usr/bin/env python3
"""Lists Bangla tr()/trf() texts in lib/ that have no English entry yet in
lib/logic/strings_en.dart. Add each missing one to the enStrings map there
(Bangla key → English), then run this again until it prints "0 missing".

Usage: python3 tool/i18n_missing.py   (from the repo root)
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def unesc(t):
    return re.sub(r"\\(.)", lambda g: {'n': '\n'}.get(g.group(1), g.group(1)), t)


have = set()
src = open(os.path.join(ROOT, 'lib/logic/strings_en.dart'), encoding='utf-8').read()
for k in re.findall(r"^\s*'((?:[^'\\]|\\.)*)'\s*:", src, flags=re.M):
    have.add(unesc(k))

keep = os.path.join(ROOT, 'tool/i18n_keep_bn.txt')
for line in open(keep, encoding='utf-8'):
    line = line.rstrip('\n')
    if line and not line.startswith('#'):
        have.add(line)

miss = []
for f in glob.glob(os.path.join(ROOT, 'lib/**/*.dart'), recursive=True):
    if f.endswith('strings_en.dart'):
        continue
    for k in re.findall(r"\btrf?\('((?:[^'\\]|\\.)*)'", open(f, encoding='utf-8').read()):
        k = unesc(k)
        if re.search('[ঀ-৿]', k) and k not in have and k not in miss:
            miss.append(k)
for k in miss:
    print(repr(k))
print(len(miss), 'missing')
