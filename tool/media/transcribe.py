# The owner's voice-over, written down with word times (to fit the promo's
# scenes to it). faster-whisper large-v3 on CPU; second pass on the parts the
# first pass skipped, each cut out and read alone.
import json, os, subprocess
from faster_whisper import WhisperModel

m = WhisperModel('large-v3', device='cpu', compute_type='int8')
prompt = 'রিমাইন্ডার, হিসাব, ধার-দেনা, ডকুমেন্ট, পাসওয়ার্ড, ফ্যামিলি, ওষুধ, যাকাত, অটো ব্যাকআপ, My Assistant।'
os.makedirs('out', exist_ok=True)
res = {}
for a, b in [(20, 50), (52, 66), (67, 86)]:
    f = f'tool/media/in/cut_{a}.wav'  # cut beforehand (no ffmpeg on the runner)
    segs, _ = m.transcribe(f, language='bn', word_timestamps=True, vad_filter=True, beam_size=5, condition_on_previous_text=False, initial_prompt=prompt)
    rows = []
    for s in segs:
        rows.append(dict(start=a + s.start, end=a + s.end, text=s.text, words=[dict(w=w.word, s=a + w.start, e=a + w.end) for w in (s.words or [])]))
    res[f'{a}-{b}'] = rows
    print(f'== {a}-{b}')
    print('\n'.join(f"{r['start']:.2f}-{r['end']:.2f} {r['text']}" for r in rows))
json.dump(res, open('out/vo_words2.json', 'w'), ensure_ascii=False, indent=1)
