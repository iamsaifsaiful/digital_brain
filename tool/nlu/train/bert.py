# Step E.2 (pretrained) — BanglaBERT-small (ELECTRA-small, pretrained on
# Bengali text by BUET CSE NLP) fine-tuned jointly for intent, facts (slot BIO
# on each word's first piece) and request boundaries; then TFLite, int8 weights.
#
# Input: "<context words> [SEP] <message words>" — the context is the app's
# state and the kind of list on screen, written as plain Bengali words so the
# pretrained vocabulary knows them.
#
#   python tool/nlu/train/bert.py   (GitHub Actions: needs tensorflow, transformers, torch for the weights)
import json, os, sys, time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from tiny import DELETE, MONEY, LOOKUPS  # noqa: E402

NAME = os.environ.get('BERT_NAME', 'csebuetnlp/banglabert_small')
MAXT = 48
EPOCHS = int(os.environ.get('BERT_EPOCHS', '3'))
OUT = os.path.join(C.ROOT, 'out', 'models', 'bert')
STATE_WORDS = {
    'idle': 'সাধারণ', 'await_time': 'সময় জানতে চাওয়া', 'await_ampm': 'সকাল না সন্ধ্যা', 'await_new_value': 'নতুন মান জানতে চাওয়া',
    'await_person': 'কার সাথে', 'await_kind': 'দিলেন না নিলেন', 'confirm_delete': 'মুছব কিনা', 'confirm_save': 'রাখব কিনা',
    'confirm_batch': 'একসাথে রাখব কিনা', 'pick_one': 'কোনটা', 'clarify': 'দুই বিকল্প', 'dictating_list': 'তালিকা লেখা চলছে',
}
KIND_WORDS = {'none': 'তালিকা নেই', 'tasks': 'কাজের তালিকা', 'reminders': 'রিমাইন্ডারের তালিকা'}


def ctx_text(ctx):
    state = ctx[0][3:-1]
    kind = ctx[1][3:-1]
    return f'{STATE_WORDS[state]} {KIND_WORDS[kind]}'


class Enc:
    def __init__(self, tok):
        self.tok = tok

    def encode(self, ctx, ws):
        """→ ids, mask, types, first-piece position of each word (or -1 if cut)."""
        ids = [self.tok.cls_token_id] + self.tok.encode(ctx_text(ctx), add_special_tokens=False) + [self.tok.sep_token_id]
        types = [0] * len(ids)
        first = []
        for w in ws:
            p = self.tok.encode(w, add_special_tokens=False) or [self.tok.unk_token_id]
            if len(ids) + len(p) >= MAXT:
                first.append(-1)
                continue
            first.append(len(ids))
            ids += p
            types += [1] * len(p)
        ids.append(self.tok.sep_token_id)
        types.append(1)
        mask = [1] * len(ids)
        pad = MAXT - len(ids)
        return np.array(ids + [0] * pad, np.int32), np.array(mask + [0] * pad, np.int32), np.array(types + [0] * pad, np.int32), first


def arrays(enc, segs, seqs, intents, slot_tags):
    ii = {x: i for i, x in enumerate(intents)}
    si = {x: i for i, x in enumerate(slot_tags)}
    bi = {'O': 0, 'B': 1, 'I': 2}
    I, M, T, Y, S, B, wy, wt = [], [], [], [], [], [], [], []

    def add(ctx, ws, tags, bound, intent, weight):
        ids, mask, types, first = enc.encode(ctx, ws)
        s = np.zeros(MAXT, np.int32)
        b = np.zeros(MAXT, np.int32)
        m = np.zeros(MAXT, np.float32)
        for k, pos in enumerate(first):
            if pos < 0:
                continue
            s[pos] = si.get(tags[k], 0) if tags is not None else 0
            b[pos] = bi[bound[k]]
            m[pos] = 1
        I.append(ids); M.append(mask); T.append(types); Y.append(ii.get(intent, 0)); S.append(s); B.append(b); wy.append(weight); wt.append(m)

    for ctx, ws, intent, tags in segs:
        add(ctx, ws, tags, ['B'] + ['I'] * (len(ws) - 1), intent, 1.0)
        if tags is None:
            wt[-1] = np.zeros(MAXT, np.float32)  # intent only: no word labels learned
    for ctx, ws, tags, bound, n in seqs:
        if n >= 2:
            add(ctx, ws, tags, bound, None, 0.0)
    return [np.array(I), np.array(M), np.array(T)], [np.array(Y), np.array(S), np.array(B)], [np.array(wy, np.float32), np.array(wt)]


def build(n_int, n_slot):
    import tensorflow as tf
    from transformers import TFAutoModel
    enc = TFAutoModel.from_pretrained(NAME, from_pt=True)
    L = tf.keras.layers
    ids = L.Input((MAXT,), dtype='int32', name='input_ids')
    mask = L.Input((MAXT,), dtype='int32', name='attention_mask')
    types = L.Input((MAXT,), dtype='int32', name='token_type_ids')
    h = enc(input_ids=ids, attention_mask=mask, token_type_ids=types).last_hidden_state
    h = L.Dropout(0.1)(h)
    intent = L.Dense(n_int, name='intent')(h[:, 0, :])
    slots = L.Dense(n_slot, name='slots')(h)
    bound = L.Dense(3, name='bound')(h)
    return tf.keras.Model([ids, mask, types], [intent, slots, bound])


def train():
    import tensorflow as tf
    from transformers import AutoTokenizer
    tf.random.set_seed(7)
    np.random.seed(7)
    tok = AutoTokenizer.from_pretrained(NAME)
    enc = Enc(tok)
    tr_segs, tr_seqs = C.examples(C.load_jsonl(os.path.join(C.DATA, 'train.jsonl')))
    dv_segs, dv_seqs = C.examples(C.load_jsonl(os.path.join(C.DATA, 'dev.jsonl')))
    intents = [x['id'] for x in json.load(open(os.path.join(C.ROOT, 'spec', 'intents.json')))]
    slot_tags = C.spec_slot_tags()
    Xtr, Ytr, Wtr = arrays(enc, tr_segs, tr_seqs, intents, slot_tags)
    Xdv, Ydv, Wdv = arrays(enc, dv_segs, dv_seqs, intents, slot_tags)
    print('train', len(Ytr[0]), 'dev', len(Ydv[0]), flush=True)
    model = build(len(intents), len(slot_tags))
    sce = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    steps = EPOCHS * (len(Ytr[0]) // 32 + 1)
    lr = tf.keras.optimizers.schedules.PolynomialDecay(1e-4, steps, 1e-6)
    model.compile(optimizer=tf.keras.optimizers.Adam(lr), loss=[sce, sce, sce], loss_weights=[1.0, 0.7, 0.5])
    best, best_w = -1, None
    for epoch in range(EPOCHS):
        t0 = time.time()
        perm = np.random.permutation(len(Ytr[0]))
        model.fit([x[perm] for x in Xtr], [y[perm] for y in Ytr], sample_weight=[Wtr[0][perm], Wtr[1][perm], Wtr[1][perm]],
                  batch_size=32, epochs=1, verbose=2)
        li, ls, _ = model.predict(Xdv, batch_size=128, verbose=0)
        acc = float(np.sum((li.argmax(-1) == Ydv[0]) * Wdv[0]) / np.sum(Wdv[0]))
        tacc = float(np.sum((ls.argmax(-1) == Ydv[1]) * Wdv[1]) / np.sum(Wdv[1]))
        print(f'epoch {epoch + 1}: dev intent {acc:.4f} tags {tacc:.4f} ({time.time() - t0:.0f}s)', flush=True)
        if acc > best:
            best, best_w = acc, model.get_weights()
    model.set_weights(best_w)

    li, _, _ = model.predict(Xdv, batch_size=128, verbose=0)
    keep = Wdv[0] > 0
    logits, gold = li[keep], Ydv[0][keep]

    def probs(t):
        z = logits / t
        z = z - z.max(1, keepdims=True)
        return np.exp(z) / np.exp(z).sum(1, keepdims=True)
    temp = min([0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0], key=lambda t: -np.mean(np.log(probs(t)[np.arange(len(gold)), gold] + 1e-12)))
    p = probs(temp)
    pred, conf = p.argmax(1), p.max(1)
    thresholds = {}
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
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    tfl = conv.convert()
    open(os.path.join(OUT, 'model.tflite'), 'wb').write(tfl)
    tok.save_pretrained(OUT)
    # Test vectors for the Dart word-piece split (lib/nlu/wordpiece.dart).
    with open(os.path.join(OUT, 'wordpiece_vectors.jsonl'), 'w') as f:
        for line in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'vectors.jsonl')):
            n = json.loads(line)['norm']
            f.write(json.dumps(dict(norm=n, ids=tok.encode(n, add_special_tokens=False)), ensure_ascii=False) + '\n')
    cfg = dict(version=1, base=NAME, intents=intents, slot_tags=slot_tags, temperature=temp, thresholds=thresholds, maxt=MAXT,
               state_words=STATE_WORDS, kind_words=KIND_WORDS)
    json.dump(cfg, open(os.path.join(OUT, 'config.json'), 'w'), ensure_ascii=False, indent=1)
    return dict(dev_intent_acc=round(best, 4), temperature=temp, params=int(model.count_params()), tflite_mb=round(len(tfl) / 1e6, 2))


class Reader:
    def __init__(self):
        from transformers import AutoTokenizer
        try:
            from ai_edge_litert.interpreter import Interpreter
        except ImportError:
            from tensorflow.lite.python.interpreter import Interpreter
        self.it = Interpreter(model_path=os.path.join(OUT, 'model.tflite'), num_threads=1)
        self.it.allocate_tensors()
        self.inp = {d['name']: d['index'] for d in self.it.get_input_details()}
        self.out = self.it.get_output_details()
        self.cfg = json.load(open(os.path.join(OUT, 'config.json')))
        self.enc = Enc(AutoTokenizer.from_pretrained(OUT))
        self.times = []

    def run(self, ctx, ws):
        ids, mask, types, first = self.enc.encode(ctx, ws)
        for name, idx in self.inp.items():
            arr = types if 'type' in name else mask if 'mask' in name else ids
            self.it.set_tensor(idx, arr[None])
        t0 = time.perf_counter()
        self.it.invoke()
        self.times.append(time.perf_counter() - t0)
        res = {}
        for d in self.out:
            a = self.it.get_tensor(d['index'])[0]
            res['intent' if a.ndim == 1 else ('bound' if a.shape[-1] == 3 else 'slots')] = a
        return res, first

    def tag(self, ctx, ws):
        r, first = self.run(ctx, ws)
        st = self.cfg['slot_tags']
        tags, bound = [], []
        for pos in first:
            tags.append('O' if pos < 0 else st[int(r['slots'][pos].argmax())])
            bound.append('I' if pos < 0 else ['O', 'B', 'I'][int(r['bound'][pos].argmax())])
        fixed = []
        for i, t in enumerate(tags):
            if t.startswith('I-') and (i == 0 or fixed[-1] == 'O' or fixed[-1][2:] != t[2:]):
                t = 'B-' + t[2:]
            fixed.append(t)
        return fixed, bound

    def intent(self, ctx, ws):
        r, _ = self.run(ctx, ws)
        z = r['intent'] / self.cfg['temperature']
        z = np.exp(z - z.max())
        p = z / z.sum()
        k = int(p.argmax())
        return self.cfg['intents'][k], float(p[k])


def predict_gold(name='bert'):
    r = Reader()
    preds = []
    for g in C.gold_rows():
        segs = C.read(g['text'], g['state'], C.shown_kind(g['state'], g.get('before')), r.tag, r.intent)
        p = C.gold_prediction(g, name, segs)
        p[f'{name}_raw_conf'] = p[f'{name}_conf']
        p[f'{name}_conf'] = min((1.0 if s['conf'] >= r.cfg['thresholds'][s['intent']] else s['conf'] * 0.5 for s in segs), default=0.0)
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
