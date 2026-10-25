# Bangla voice-over for the explainer video: one mp3 per scene, two voices.
import asyncio, json, os, edge_tts
lines = json.load(open(os.path.join(os.path.dirname(__file__), 'lines.json')))
async def main():
    os.makedirs('out', exist_ok=True)
    for voice in ['bn-BD-NabanitaNeural', 'bn-BD-PradeepNeural']:
        tag = voice.split('-')[2].replace('Neural', '').lower()
        for sid, text in lines:
            await edge_tts.Communicate(text, voice, rate='-4%').save(f'out/{tag}-{sid}.mp3')
asyncio.run(main())
