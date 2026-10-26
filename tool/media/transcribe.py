# The owner's tutorial voice-over, one spoken piece at a time (cut at the
# pauses beforehand; no ffmpeg on the runner). Long cuts made whisper skip
# parts, so each piece is read alone and only its text is used: the times
# come from where the piece was cut.
import json, os
from faster_whisper import WhisperModel

m = WhisperModel('large-v3', device='cpu', compute_type='int8')
prompt = 'Google, PIN, রিমাইন্ডার, হিসাব, ধার-দেনা, ডকুমেন্টস, পাসওয়ার্ড, ফ্যামিলি, ওষুধ, যাকাত, ব্যাকআপ, জরুরি কার্ড, My Assistant।'
os.makedirs('out', exist_ok=True)
D = 'tool/media/in/tutclips'
segs = json.load(open(f'{D}/clips.json'))
res = []
for i, (a, b) in enumerate(segs):
    s, _ = m.transcribe(f'{D}/{i:03d}.wav', language='bn', vad_filter=False, beam_size=5, condition_on_previous_text=False, initial_prompt=prompt)
    text = ' '.join(x.text.strip() for x in s)
    res.append(dict(i=i, s=a, e=b, text=text))
    print(f'{i:03d} {a:7.2f}-{b:7.2f} {text}', flush=True)
    json.dump(res, open('out/tut_clips.json', 'w'), ensure_ascii=False, indent=1)
