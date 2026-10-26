# The owner's tutorial voice-over, written down with word times (to fit the
# tutorial's steps to it). faster-whisper large-v3 on CPU, 56 s cuts made
# beforehand (no ffmpeg on the runner), each read alone.
import json, os
from faster_whisper import WhisperModel

m = WhisperModel('large-v3', device='cpu', compute_type='int8')
prompt = 'Google, PIN, রিমাইন্ডার, হিসাব, ধার-দেনা, ডকুমেন্টস, পাসওয়ার্ড, ফ্যামিলি, ওষুধ, যাকাত, ব্যাকআপ, জরুরি কার্ড, My Assistant।'
os.makedirs('out', exist_ok=True)
res = {}
for a in [0, 50, 100, 150, 200, 250]:
    segs, _ = m.transcribe(f'tool/media/in/tut_{a}.wav', language='bn', word_timestamps=True, vad_filter=False, beam_size=5, condition_on_previous_text=False, initial_prompt=prompt)
    rows = [dict(start=a + s.start, end=a + s.end, text=s.text, words=[dict(w=w.word, s=a + w.start, e=a + w.end) for w in (s.words or [])]) for s in segs]
    res[str(a)] = rows
    print(f'== {a}', flush=True)
    print('\n'.join(f"{r['start']:.2f}-{r['end']:.2f} {r['text']}" for r in rows), flush=True)
    json.dump(res, open('out/tut_words.json', 'w'), ensure_ascii=False, indent=1)
