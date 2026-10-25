# Draft Bangla voice-over with Meta's MMS-TTS (facebook/mms-tts-ben, CC-BY-NC 4.0: preview only).
import json, os
import torch, soundfile as sf
from transformers import VitsModel, AutoTokenizer
name = 'facebook/mms-tts-ben'
model = VitsModel.from_pretrained(name)
tok = AutoTokenizer.from_pretrained(name)
lines = json.load(open(os.path.join(os.path.dirname(__file__), 'lines.json')))
os.makedirs('out', exist_ok=True)
model.speaking_rate = 1.0
for sid, text in lines:
    torch.manual_seed(3)
    with torch.no_grad():
        wav = model(**tok(text, return_tensors='pt')).waveform
    sf.write(f'out/mms-{sid}.wav', wav.squeeze().numpy(), model.config.sampling_rate)
    print(sid, flush=True)
