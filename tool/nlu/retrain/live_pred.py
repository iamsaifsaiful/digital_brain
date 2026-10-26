# Today's gold read by the model members have now (owner, 26 Oct), so the gate
# compares like with like: the gold has grown (crowd, persona) since
# tool/nlu/train/pred_live.jsonl was made, and a new model was being judged on
# 7,117 rows against an old one judged on 1,593.
#   python3 tool/nlu/retrain/live_pred.py <live model .tflite>
# Writes tool/nlu/out/pred_live_now.jsonl.
import json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
live = open(os.path.join(HERE, 'LIVE')).read().strip()
cfg_path = os.path.join(ROOT, 'models', live, 'config.json')
cfg = json.load(open(cfg_path))
# The live model reads this many word pieces; set before bert.py reads it.
os.environ['BERT_MAXT'] = str(cfg['maxt'])
sys.path.insert(0, os.path.join(ROOT, 'train'))
import bert  # noqa: E402

d = os.path.join(ROOT, 'out', 'live')
os.makedirs(d, exist_ok=True)
shutil.copy(sys.argv[1], os.path.join(d, 'model.tflite'))
shutil.copy(cfg_path, os.path.join(d, 'config.json'))
from transformers import AutoTokenizer  # noqa: E402

AutoTokenizer.from_pretrained(cfg['base']).save_pretrained(d)
bert.OUT = d
rep = bert.predict_gold('bert')
os.replace(os.path.join(ROOT, 'out', 'pred_bert.jsonl'), os.path.join(ROOT, 'out', 'pred_live_now.jsonl'))
print(json.dumps(dict(live=live, maxt=cfg['maxt'], **rep)))
