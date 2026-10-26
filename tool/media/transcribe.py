# The owner's voice-over, written down with word times (to fit the promo's
# scenes to it). faster-whisper large-v3 on CPU.
import json, os
from faster_whisper import WhisperModel

m = WhisperModel('large-v3', device='cpu', compute_type='int8')
segs, info = m.transcribe('tool/media/in/vo.mp3', language='bn', word_timestamps=True, vad_filter=False, beam_size=5)
out = []
for s in segs:
    out.append(dict(start=s.start, end=s.end, text=s.text, words=[dict(w=w.word, s=w.start, e=w.end) for w in (s.words or [])]))
os.makedirs('out', exist_ok=True)
json.dump(out, open('out/vo_words.json', 'w'), ensure_ascii=False, indent=1)
print('\n'.join(f"{s['start']:.2f}-{s['end']:.2f} {s['text']}" for s in out))
