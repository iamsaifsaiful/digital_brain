import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/ai.dart';
import 'services/crypto.dart';
import 'services/data_store.dart';
import 'services/files.dart';
import 'services/launcher.dart';
import 'services/lock.dart';
import 'services/notifications.dart';
import 'services/voice.dart';
import 'state/brain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final keys = SecureKeyVault();
  final services = Services(
    store: DataStore(keys: keys, blob: FileBlobStore()),
    lock: LockService(keys: keys, biometrics: DeviceBiometrics()),
    voice: DeviceVoice(),
    notifier: NotificationService(),
    files: DeviceFiles(),
    ai: ClaudeAi(),
    launcher: DeviceLauncher(),
  );
  await services.notifier.init();
  final brain = Brain(services);
  runApp(DigitalBrainApp(brain: brain));
  await brain.load();
}
