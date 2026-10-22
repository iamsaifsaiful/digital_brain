# Step E.1 — the yardstick: a light linear model.
#   intent of a piece of text: logistic regression on character 1–4-grams and
#     word 1–2-grams, with the context marker (app state, shown list kind);
#   where one request ends and the next begins inside a line, and which words
#     carry which fact: per-word linear classifiers on the word, its affixes
#     and its neighbours (a CRF is the usual choice; python-crfsuite cannot be
#     installed here, so a per-word classifier with BIO repair stands in).
# Lines and numbered items are split by rule first (common.split_lines).
#
#   python3 tool/nlu/train/baseline.py      → out/models/baseline.pkl,
#                                             out/pred_baseline.jsonl (gold), dev report
import os, pickle, sys, time
from collections import Counter

import numpy as np
from scipy.sparse import hstack
from sklearn.feature_extraction import DictVectorizer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression, SGDClassifier

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

OUT = os.path.join(C.ROOT, 'out')


def word_grams(s):
    w = s.split()
    return w + [a + '_' + b for a, b in zip(w, w[1:])]


def seg_text(ctx, ws):
    return ' '.join(ctx + ws)


def word_feats(ctx, ws, i):
    w = ws[i]
    f = {'w=' + w: 1, 'p2=' + w[:2]: 1, 'p3=' + w[:3]: 1, 's2=' + w[-2:]: 1, 's3=' + w[-3:]: 1, 'ctx=' + ctx[0]: 1,
         'dig': int(any(c in '০১২৩৪৫৬৭৮৯' for c in w)), 'first': int(i == 0), 'last': int(i == len(ws) - 1)}
    for d in (-2, -1, 1, 2):
        j = i + d
        v = ws[j] if 0 <= j < len(ws) else ('<b>' if j < 0 else '<e>')
        f[f'w{d}=' + v] = 1
        if d in (-1, 1):
            f[f's{d}=' + v[-2:]] = 1
    f['w-1w=' + (ws[i - 1] if i else '<b>') + '|' + w] = 1
    return f


def bio_repair(tags):
    out = []
    for i, t in enumerate(tags):
        if t.startswith('I-') and (i == 0 or out[-1] == 'O' or out[-1][2:] != t[2:]):
            t = 'B-' + t[2:]
        out.append(t)
    return out


class Baseline:
    def fit(self, rows):
        segs, seqs = C.examples(rows)
        t0 = time.time()
        X = [seg_text(c, w) for c, w, _, _ in segs]
        y = [i for _, _, i, _ in segs]
        self.vc = TfidfVectorizer(analyzer='char_wb', ngram_range=(1, 4), min_df=2, sublinear_tf=True, max_features=200000)
        self.vw = TfidfVectorizer(analyzer=word_grams, min_df=2, sublinear_tf=True)
        Xv = hstack([self.vc.fit_transform(X), self.vw.fit_transform(X)]).tocsr()
        self.clf = LogisticRegression(C=20, max_iter=400)
        self.clf.fit(Xv, y)
        print(f'intent model: {len(X)} pieces, {Xv.shape[1]} features, {time.time() - t0:.0f}s', flush=True)
        t0 = time.time()
        F, S, B = [], [], []
        for ctx, ws, tags, bound, _ in seqs:
            for i in range(len(ws)):
                F.append(word_feats(ctx, ws, i))
                S.append(tags[i])
                B.append(bound[i])
        self.dv = DictVectorizer()
        XF = self.dv.fit_transform(F)
        XF.indices = XF.indices.astype(np.int32)
        XF.indptr = XF.indptr.astype(np.int32)
        self.slot = SGDClassifier(loss='log_loss', alpha=2e-6, max_iter=20, tol=None, random_state=0).fit(XF, S)
        self.bound = SGDClassifier(loss='log_loss', alpha=2e-6, max_iter=20, tol=None, random_state=0).fit(XF, B)
        print(f'word models: {XF.shape[0]} words, {XF.shape[1]} features, {time.time() - t0:.0f}s', flush=True)
        return self

    def intent(self, ctx, ws):
        x = seg_text(ctx, ws)
        Xv = hstack([self.vc.transform([x]), self.vw.transform([x])]).tocsr()
        p = self.clf.predict_proba(Xv)[0]
        k = int(np.argmax(p))
        return self.clf.classes_[k], float(p[k]), p

    def tag(self, ctx, ws):
        XF = self.dv.transform([word_feats(ctx, ws, i) for i in range(len(ws))])
        return bio_repair(list(self.slot.predict(XF))), list(self.bound.predict(XF))

    def read(self, text, state, kind):
        return C.read(text, state, kind, self.tag, lambda c, w: self.intent(c, w)[:2])


def predict_gold(model, name):
    preds = []
    t0 = time.time()
    for g in C.gold_rows():
        segs = model.read(g['text'], g['state'], C.shown_kind(g['state'], g.get('before')))
        preds.append(C.gold_prediction(g, name, segs))
    return preds, (time.time() - t0) / max(1, len(preds)) * 1000


def dev_report(model, dev):
    segs, seqs = C.examples(dev)
    ok = sum(model.intent(c, w)[0] == i for c, w, i, _ in segs)
    tok = tot = 0
    for ctx, ws, tags, _, _ in seqs[:3000]:
        pt, _ = model.tag(ctx, ws)
        tok += sum(a == b for a, b in zip(pt, tags))
        tot += len(tags)
    return dict(dev_pieces=len(segs), dev_intent_acc=round(ok / len(segs), 4), dev_word_tag_acc=round(tok / tot, 4))


def main():
    train = C.load_jsonl(os.path.join(C.DATA, 'train.jsonl'))
    dev = C.load_jsonl(os.path.join(C.DATA, 'dev.jsonl'))
    m = Baseline().fit(train)
    os.makedirs(os.path.join(OUT, 'models'), exist_ok=True)
    path = os.path.join(OUT, 'models', 'baseline.pkl')
    pickle.dump(m, open(path, 'wb'))
    rep = dev_report(m, dev)
    preds, ms = predict_gold(m, 'base')
    with open(os.path.join(OUT, 'pred_baseline.jsonl'), 'w') as f:
        for p in preds:
            f.write(__import__('json').dumps(p, ensure_ascii=False) + '\n')
    rep.update(size_mb=round(os.path.getsize(path) / 1e6, 1), ms_per_message_server_cpu=round(ms, 1))
    print(rep)
    __import__('json').dump(rep, open(os.path.join(OUT, 'baseline_dev.json'), 'w'))


if __name__ == '__main__':
    main()
