# Bangla voice-over with AI4Bharat's Indic Parler-TTS (Apache-2.0): one wav per scene.
import json, os, sys
import torch, soundfile as sf
from parler_tts import ParlerTTSForConditionalGeneration
from transformers import AutoTokenizer

name = 'ai4bharat/indic-parler-tts'
model = ParlerTTSForConditionalGeneration.from_pretrained(name).to('cpu')
tok = AutoTokenizer.from_pretrained(name)
dtok = AutoTokenizer.from_pretrained(model.config.text_encoder._name_or_path)
lines = json.load(open(os.path.join(os.path.dirname(__file__), 'lines.json')))
voices = {
    'aditi': "Aditi speaks with a warm, friendly and expressive voice at a moderate pace. The recording is very clear with no background noise.",
    'arjun': "Arjun speaks with a calm, confident and friendly voice at a moderate pace. The recording is very clear with no background noise.",
}
os.makedirs('out', exist_ok=True)
for tag, desc in voices.items():
    d = dtok(desc, return_tensors='pt')
    for sid, text in lines:
        torch.manual_seed(1)
        p = tok(text, return_tensors='pt')
        audio = model.generate(input_ids=d.input_ids, attention_mask=d.attention_mask, prompt_input_ids=p.input_ids, prompt_attention_mask=p.attention_mask)
        sf.write(f'out/{tag}-{sid}.wav', audio.cpu().numpy().squeeze(), model.config.sampling_rate)
        print(tag, sid, flush=True)
