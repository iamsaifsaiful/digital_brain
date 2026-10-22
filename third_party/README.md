# Vendored packages

`tflite_flutter/` — TensorFlow Lite for Flutter (Apache 2.0, LICENSE inside), copied from
https://github.com/tensorflow/flutter-tflite (0.12.1) because pub.dev cannot be reached from the
build environment. Desktop platforms, examples and dev dependencies were removed; the GPU delegate
Android library was dropped (the on-phone NLU model runs on the CPU), which keeps the APK smaller.
