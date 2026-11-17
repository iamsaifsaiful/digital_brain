# "কীভাবে ব্যবহার করবেন" video — new screens

Re-draws every chapter scene of the how-to video from today's app, keeping
the intro, chapter cards, ending and the owner's voice from the old video.

1. `SHOTS=1 flutter test --no-pub test/ui/tutorial_shots_test.dart --update-goldens`
2. Fonts: Anek Bangla (npm `@fontsource-variable/anek-bangla`, instanced to
   wdth 87 with fontTools); paths are set in `txt.py`.
3. Frame list of the old video (`frames.json`: per frame, pixels at
   (20,20), (1000,156), (565,540)), then `python3 build.py old.mp4 new.mp4 2`.
4. Step times and texts: `scenes.py` (times measured from the old video).
