# Step I.4: a model that passed the gate becomes a draft on the server.
# The .tflite is published as a GitHub release asset (public, so phones can
# download it); its SHA-256 and the model's config go with the draft. An
# admin then makes it live for a share of members in the admin app.
#   GH_TOKEN=… MA_NLU_CI_KEY=… python3 tool/nlu/retrain/publish.py VERSION [--site …] [--repo owner/name]
import argparse, hashlib, json, os, subprocess, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.abspath(os.path.join(HERE, '..', 'out', 'models', 'bert'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('version')
    ap.add_argument('--site', default='https://getmyassistant.app')
    ap.add_argument('--repo', default=os.environ.get('GITHUB_REPOSITORY', 'iamsaifsaiful/digital_brain'))
    a = ap.parse_args()
    key = os.environ.get('MA_NLU_CI_KEY', '')
    if not key:
        sys.exit('MA_NLU_CI_KEY is not set')
    path = os.path.join(MODEL, 'model.tflite')
    data = open(path, 'rb').read()
    sha = hashlib.sha256(data).hexdigest()
    tag = f'nlu-model-{a.version}'
    name = f'nlu-{a.version}.tflite'
    named = os.path.join(MODEL, name)
    open(named, 'wb').write(data)
    subprocess.run(['gh', 'release', 'create', tag, named, '--repo', a.repo, '--prerelease', '--title', f'NLU model {a.version}',
                    '--notes', 'ফোনের বোঝার মডেল (draft) — এডমিন অ্যাপ থেকে চালু করতে হয়।'], check=True)
    url = f'https://github.com/{a.repo}/releases/download/{tag}/{name}'
    cfg = json.load(open(os.path.join(MODEL, 'config.json')))
    gate = os.path.join(HERE, '..', 'out', 'gate.json')
    ev = json.load(open(gate)) if os.path.exists(gate) else {}
    body = json.dumps({'version': a.version, 'url': url, 'sha256': sha, 'size': len(data), 'thresholds': cfg,
                       'eval': {k: ev[k] for k in ('exact', 'delete', 'money') if k in ev}}).encode()
    req = urllib.request.Request(f'{a.site}/wp-json/my-assistant/v1/nlu/ci/model', data=body, method='POST',
                                 headers={'x-ma-ci-key': key, 'content-type': 'application/json', 'user-agent': 'my-assistant-retrain'})
    print(urllib.request.urlopen(req, timeout=60).read().decode())


if __name__ == '__main__':
    main()
