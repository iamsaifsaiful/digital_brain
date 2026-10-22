# Step I.1: the labelled samples from the server, with the retraining key.
#   MA_NLU_CI_KEY=… python3 tool/nlu/retrain/fetch.py [--site https://getmyassistant.app] → tool/nlu/out/real_samples.jsonl
import argparse, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', 'out', 'real_samples.jsonl'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--site', default='https://getmyassistant.app')
    a = ap.parse_args()
    key = os.environ.get('MA_NLU_CI_KEY', '')
    if not key:
        sys.exit('MA_NLU_CI_KEY is not set')
    since, rows = 0, []
    while True:
        req = urllib.request.Request(f'{a.site}/wp-json/my-assistant/v1/nlu/ci/export?since_id={since}', headers={'x-ma-ci-key': key, 'user-agent': 'my-assistant-retrain'})
        got = json.loads(urllib.request.urlopen(req, timeout=60).read())['samples']
        if not got:
            break
        rows += got
        since = max(int(x['id']) for x in got)
        if len(got) < 2000:
            break
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')
    print(json.dumps({'samples': len(rows)}))


if __name__ == '__main__':
    main()
