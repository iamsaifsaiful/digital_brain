# Step E.2 — the main model: a small joint transformer (intent + facts +
# where a request ends), trained from scratch on the step-D data, then
# converted to TFLite with int8 weights.
#
# Input per word: the word's id and its letters (so unseen spellings and
# names still get a vector). Two context words go first: <s:state> <l:shown>.
# Outputs: intent of the whole input (softmax), slot BIO per word, boundary
# B/I/O per word.
#
# Runs where TensorFlow is installed (GitHub Actions: .github/workflows/nlu_train.yml):
#   python3 tool/nlu/train/tiny.py → tool/nlu/out/models/tiny/{model.tflite, vocab.json, config.json, report.json}
#                                    tool/nlu/out/pred_tiny.jsonl (gold, read with the .tflite itself)
import json, math, os, sys, time
from collections import Counter

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

MAXW = 40          # words per input (context words included)
MAXC = 12          # letters per word
D = 128
LAYERS = 2
HEADS = 4
OUT = os.path.join(C.ROOT, 'out', 'models', 'tiny')
DELETE = {'task_delete', 'reminder_delete', 'item_delete'}
MONEY = {'ledger_add', 'ledger_set', 'cash_add', 'menu_accounts', 'menu_savings', 'menu_shop', 'menu_cash', 'menu_project', 'menu_installment'}
LOOKUPS = {'task_query', 'reminder_query', 'ledger_query', 'cash_query', 'note_query', 'contact_query', 'special_query', 'calendar_query',
           'open_page', 'briefing', 'doc_query', 'profile_query', 'smalltalk', 'out_of_scope', 'complain_help'}


class Vocab:
    def __init__(self, seqs):
        wc = Counter(w for _, ws, *_ in seqs for w in ws)
        cc = Counter(ch for _, ws, *_ in seqs for w in ws for ch in w)
        self.words = ['<pad>', '<unk>'] + sorted({c for ctx, *_ in seqs for c in ctx}) + sorted(w for w, n in wc.items() if n >= 2 and not w.startswith('<'))
        self.chars = ['<pad>', '<unk>'] + sorted(ch for ch, n in cc.items() if n >= 3)
        self.wi = {w: i for i, w in enumerate(self.words)}
        self.ci = {c: i for i, c in enumerate(self.chars)}

    def encode(self, ctx, ws):
        toks = (ctx + ws)[:MAXW]
        w = np.zeros(MAXW, np.int32)
        c = np.zeros((MAXW, MAXC), np.int32)
        for i, t in enumerate(toks):
            w[i] = self.wi.get(t, 1)
            if not t.startswith('<'):
                for j, ch in enumerate(t[:MAXC]):
                    c[i, j] = self.ci.get(ch, 1)
        return w, c

    def dump(self):
        return dict(words=self.words, chars=self.chars, maxw=MAXW, maxc=MAXC)


def build_arrays(vocab, segs, seqs, intents, slot_tags):
    """Pieces teach intent (+ their tags); whole multi-request lines teach
    tags and boundaries only (their intent loss is weighted 0)."""
    ii = {x: i for i, x in enumerate(intents)}
    si = {x: i for i, x in enumerate(slot_tags)}
    bi = {'O': 0, 'B': 1, 'I': 2}
    W, Ch, Y, S, B, wy, wt = [], [], [], [], [], [], []
    for ctx, ws, intent, tags in segs:
        w, c = vocab.encode(ctx, ws)
        s = np.zeros(MAXW, np.int32)
        b = np.zeros(MAXW, np.int32)
        m = np.zeros(MAXW, np.float32)
        for k, t in enumerate(tags[:MAXW - len(ctx)]):
            s[len(ctx) + k] = si.get(t, 0)
            b[len(ctx) + k] = 1 if k == 0 else 2
            m[len(ctx) + k] = 1
        W.append(w); Ch.append(c); Y.append(ii[intent]); S.append(s); B.append(b); wy.append(1.0); wt.append(m)
    for ctx, ws, tags, bound, n in seqs:
        if n < 2:
            continue
        w, c = vocab.encode(ctx, ws)
        s = np.zeros(MAXW, np.int32)
        b = np.zeros(MAXW, np.int32)
        m = np.zeros(MAXW, np.float32)
        for k, (t, bb) in enumerate(list(zip(tags, bound))[:MAXW - len(ctx)]):
            s[len(ctx) + k] = si.get(t, 0)
            b[len(ctx) + k] = bi[bb]
            m[len(ctx) + k] = 1
        W.append(w); Ch.append(c); Y.append(0); S.append(s); B.append(b); wy.append(0.0); wt.append(m)
    return (np.array(W), np.array(Ch)), (np.array(Y), np.array(S), np.array(B)), (np.array(wy, np.float32), np.array(wt))


def make_model(nw, nc, n_int, n_slot):
    import tensorflow as tf
    L = tf.keras.layers
    w_in = L.Input((MAXW,), dtype='int32', name='words')
    c_in = L.Input((MAXW, MAXC), dtype='int32', name='chars')
    we = L.Embedding(nw, D, name='wemb')(w_in)
    ce = L.Embedding(nc, 32, name='cemb')(c_in)                       # B,W,C,32
    ce = L.Conv2D(96, (1, 3), padding='same', activation='relu', name='cconv')(ce)
    ce = L.Lambda(lambda t: tf.reduce_max(t, axis=2), name='cpool')(ce)
    x = L.Dense(D, name='proj')(L.Concatenate()([we, ce]))
    pos = L.Embedding(MAXW, D, name='pos')(tf.range(MAXW)[None, :] * tf.ones_like(w_in[:, :1]))
    x = x + pos
    mask = tf.cast(tf.not_equal(w_in, 0), tf.float32)                 # B,W
    bias = (1.0 - mask)[:, None, None, :] * -1e9                     # B,1,1,W
    hd = D // HEADS
    for l in range(LAYERS):
        h = L.LayerNormalization(epsilon=1e-6, name=f'ln1_{l}')(x)
        q = L.Dense(D, name=f'q{l}')(h)
        k = L.Dense(D, name=f'k{l}')(h)
        v = L.Dense(D, name=f'v{l}')(h)
        def heads(t):
            return tf.transpose(tf.reshape(t, (-1, MAXW, HEADS, hd)), (0, 2, 1, 3))
        a = tf.matmul(heads(q), heads(k), transpose_b=True) / math.sqrt(hd) + bias
        a = tf.nn.softmax(a, axis=-1)
        o = tf.reshape(tf.transpose(tf.matmul(a, heads(v)), (0, 2, 1, 3)), (-1, MAXW, D))
        x = x + L.Dropout(0.1)(L.Dense(D, name=f'o{l}')(o))
        h = L.LayerNormalization(epsilon=1e-6, name=f'ln2_{l}')(x)
        h = L.Dense(D * 2, activation='gelu', name=f'f1_{l}')(h)
        x = x + L.Dropout(0.1)(L.Dense(D, name=f'f2_{l}')(h))
    x = L.LayerNormalization(epsilon=1e-6, name='lnf')(x)
    pooled = tf.reduce_sum(x * mask[:, :, None], 1) / tf.maximum(tf.reduce_sum(mask, 1, keepdims=True), 1.0)
    hcls = L.Concatenate()([pooled, x[:, 0, :], x[:, 1, :]])
    intent = L.Dense(n_int, name='intent')(L.Dropout(0.1)(hcls))
    slots = L.Dense(n_slot, name='slots')(x)
    bound = L.Dense(3, name='bound')(x)
    return tf.keras.Model([w_in, c_in], [intent, slots, bound])


def train():
    import tensorflow as tf
    tf.random.set_seed(7)
    np.random.seed(7)
    train_rows = C.load_jsonl(os.path.join(C.DATA, 'train.jsonl'))
    dev_rows = C.load_jsonl(os.path.join(C.DATA, 'dev.jsonl'))
    tr_segs, tr_seqs = C.examples(train_rows)
    dv_segs, dv_seqs = C.examples(dev_rows)
    vocab = Vocab(tr_seqs)
    spec = [x['id'] for x in json.load(open(os.path.join(C.ROOT, 'spec', 'intents.json')))]
    intents = spec
    slot_tags = ['O'] + sorted({t for *_, tags, _b, _n in tr_seqs for t in tags if t != 'O'})
    Xtr, Ytr, Wtr = build_arrays(vocab, tr_segs, tr_seqs, intents, slot_tags)
    Xdv, Ydv, Wdv = build_arrays(vocab, dv_segs, dv_seqs, intents, slot_tags)
    print('train', len(Ytr[0]), 'dev', len(Ydv[0]), 'words', len(vocab.words), 'chars', len(vocab.chars), 'slot tags', len(slot_tags), flush=True)
    model = make_model(len(vocab.words), len(vocab.chars), len(intents), len(slot_tags))
    sce = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)

    # Word dropout: replace 8% of words with <unk> so unseen words are handled.
    def augment(w):
        drop = (np.random.rand(*w.shape) < 0.08) & (w > 1)
        drop[:, :2] = False
        return np.where(drop, 1, w)

    opt = tf.keras.optimizers.Adam(2e-3)
    model.compile(optimizer=opt, loss=[sce, sce, sce], loss_weights=[1.0, 0.7, 0.5])
    best, best_w, patience = -1, None, 0
    n = len(Ytr[0])
    for epoch in range(30):
        perm = np.random.permutation(n)
        w = augment(Xtr[0][perm])
        model.fit([w, Xtr[1][perm]], [Ytr[0][perm], Ytr[1][perm], Ytr[2][perm]],
                  sample_weight=[Wtr[0][perm], Wtr[1][perm], Wtr[1][perm]], batch_size=64, epochs=1, verbose=2)
        li, ls, lb = model.predict(list(Xdv), batch_size=256, verbose=0)
        acc = float(np.sum((li.argmax(-1) == Ydv[0]) * Wdv[0]) / np.sum(Wdv[0]))
        tacc = float(np.sum((ls.argmax(-1) == Ydv[1]) * Wdv[1]) / np.sum(Wdv[1]))
        print(f'epoch {epoch + 1}: dev intent {acc:.4f} tags {tacc:.4f}', flush=True)
        if acc > best + 1e-4:
            best, best_w, patience = acc, model.get_weights(), 0
        else:
            patience += 1
            if patience >= 4:
                break
        if epoch == 7:
            opt.learning_rate.assign(7e-4)
        if epoch == 14:
            opt.learning_rate.assign(2e-4)
    model.set_weights(best_w)

    # Temperature scaling on dev (intent).
    li, _, _ = model.predict(list(Xdv), batch_size=256, verbose=0)
    keep = Wdv[0] > 0
    logits, gold = li[keep], Ydv[0][keep]

    def nll(t):
        z = logits / t
        z = z - z.max(1, keepdims=True)
        p = np.exp(z) / np.exp(z).sum(1, keepdims=True)
        return -np.mean(np.log(p[np.arange(len(gold)), gold] + 1e-12))
    temp = min([0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0], key=nll)
    z = logits / temp
    z = z - z.max(1, keepdims=True)
    p = np.exp(z) / np.exp(z).sum(1, keepdims=True)
    # Per-intent threshold: lowest confidence at which dev precision of that
    # predicted intent reaches its target (removals/money 0.99, lookups 0.90, rest 0.97).
    thresholds = {}
    pred, conf = p.argmax(1), p.max(1)
    for k, name in enumerate(intents):
        target = 0.99 if name in DELETE | MONEY else 0.90 if name in LOOKUPS else 0.97
        sel = np.where(pred == k)[0]
        thr = 0.99
        for t in [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95, 0.98, 0.99]:
            s = sel[conf[sel] >= t]
            if len(s) >= 5 and np.mean(gold[s] == k) >= target:
                thr = t
                break
        thresholds[name] = thr

    os.makedirs(OUT, exist_ok=True)
    conv = tf.lite.TFLiteConverter.from_keras_model(model)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]          # int8 weights
    tfl = conv.convert()
    open(os.path.join(OUT, 'model.tflite'), 'wb').write(tfl)
    json.dump(vocab.dump(), open(os.path.join(OUT, 'vocab.json'), 'w'), ensure_ascii=False)
    cfg = dict(version=1, intents=intents, slot_tags=slot_tags, temperature=temp, thresholds=thresholds, maxw=MAXW, maxc=MAXC,
               inputs=['words', 'chars'], outputs=['intent', 'slots', 'bound'])
    json.dump(cfg, open(os.path.join(OUT, 'config.json'), 'w'), ensure_ascii=False, indent=1)
    return dict(dev_intent_acc=round(best, 4), temperature=temp, params=int(model.count_params()), tflite_mb=round(len(tfl) / 1e6, 2))


class TFLiteReader:
    def __init__(self, folder=OUT):
        try:
            from ai_edge_litert.interpreter import Interpreter
        except ImportError:
            from tensorflow.lite.python.interpreter import Interpreter
        self.it = Interpreter(model_path=os.path.join(folder, 'model.tflite'), num_threads=1)
        self.it.allocate_tensors()
        self.inp = {d['name']: d['index'] for d in self.it.get_input_details()}
        self.out = self.it.get_output_details()
        v = json.load(open(os.path.join(folder, 'vocab.json')))
        self.cfg = json.load(open(os.path.join(folder, 'config.json')))
        self.vocab = Vocab.__new__(Vocab)
        self.vocab.words, self.vocab.chars = v['words'], v['chars']
        self.vocab.wi = {w: i for i, w in enumerate(v['words'])}
        self.vocab.ci = {c: i for i, c in enumerate(v['chars'])}
        self.times = []

    def run(self, ctx, ws):
        w, c = self.vocab.encode(ctx, ws)
        for name, idx in self.inp.items():
            self.it.set_tensor(idx, (w if 'word' in name else c)[None])
        t0 = time.perf_counter()
        self.it.invoke()
        self.times.append(time.perf_counter() - t0)
        res = {}
        for d in self.out:
            a = self.it.get_tensor(d['index'])[0]
            n = a.shape[-1]
            key = 'intent' if a.ndim == 1 else ('bound' if n == 3 else 'slots')
            res[key] = a
        return res

    def tag(self, ctx, ws):
        r = self.run(ctx, ws)
        st = self.cfg['slot_tags']
        tags = [st[i] for i in r['slots'].argmax(-1)[len(ctx):len(ctx) + len(ws)]]
        bound = [['O', 'B', 'I'][i] for i in r['bound'].argmax(-1)[len(ctx):len(ctx) + len(ws)]]
        fixed = []
        for i, t in enumerate(tags):
            if t.startswith('I-') and (i == 0 or fixed[-1] == 'O' or fixed[-1][2:] != t[2:]):
                t = 'B-' + t[2:]
            fixed.append(t)
        return fixed, bound

    def intent(self, ctx, ws):
        z = self.run(ctx, ws)['intent'] / self.cfg['temperature']
        z = np.exp(z - z.max())
        p = z / z.sum()
        k = int(p.argmax())
        return self.cfg['intents'][k], float(p[k])


def predict_gold(name='tiny'):
    r = TFLiteReader()
    preds = []
    for g in C.gold_rows():
        segs = C.read(g['text'], g['state'], C.shown_kind(g['state'], g.get('before')), r.tag, r.intent)
        p = C.gold_prediction(g, name, segs)
        # Phone-settled only if every piece clears its intent's threshold.
        p[f'{name}_conf'] = min((1.0 if s['conf'] >= r.cfg['thresholds'][s['intent']] else s['conf'] * 0.5 for s in segs), default=0.0)
        p[f'{name}_raw_conf'] = min((s['conf'] for s in segs), default=0.0)
        preds.append(p)
    with open(os.path.join(C.ROOT, 'out', f'pred_{name}.jsonl'), 'w') as f:
        for p in preds:
            f.write(json.dumps(p, ensure_ascii=False) + '\n')
    t = sorted(r.times)
    return dict(invokes=len(t), ms_median=round(1000 * t[len(t) // 2], 2), ms_p95=round(1000 * t[int(len(t) * 0.95)], 2))


if __name__ == '__main__':
    rep = train()
    rep.update(predict_gold())
    print(rep)
    json.dump(rep, open(os.path.join(OUT, 'report.json'), 'w'), indent=1)
