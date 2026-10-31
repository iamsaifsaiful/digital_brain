"""The site's phone pictures from the app's own screens.

    SHOTS=1 flutter test --no-pub test/ui/site_shots_test.dart --update-goldens
    python3 website/shots.py && python3 website/build_elementor.py
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'test', 'ui', 'shots', 'site')
for n in ['home', 'report', 'chat']:
    for look in ['light', 'dark']:
        im = Image.open(os.path.join(SRC, f'{n}_{look}.png')).convert('RGB')
        im.resize((585, 1266), Image.LANCZOS).save(os.path.join(HERE, 'img', f'{n}_{look}.png'), optimize=True)
        print(n, look)
