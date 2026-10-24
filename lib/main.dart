import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/google_account.dart';
import 'services/push.dart';

import 'app.dart';
import 'services/ai.dart';
import 'services/crypto.dart';
import 'services/data_store.dart';
import 'services/files.dart';
import 'services/launcher.dart';
import 'services/lock.dart';
import 'services/notifications.dart';
import 'services/ocr.dart';
import 'services/weather.dart';
import 'services/compass.dart';
import 'services/phonebook.dart';
import 'services/voice.dart';
import 'state/brain.dart';
import 'nlu/samples.dart' show nluAppVersion;
import 'screens/more_screen.dart' show appVersion;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final keys = SecureKeyVault();
  final services = Services(
    store: DataStore(keys: keys, blob: FileBlobStore(), docFiles: FileDocFiles()),
    lock: LockService(keys: keys, biometrics: DeviceBiometrics()),
    voice: DeviceVoice(),
    notifier: NotificationService(),
    files: DeviceFiles(),
    ai: ClaudeAi(),
    launcher: DeviceLauncher(),
    phonebook: DevicePhonebook(),
    google: DeviceGoogle(),
    drive: HttpDrive(),
    server: AccountServer(),
    push: DevicePush(),
    ocr: DeviceTextReader(),
    weather: OpenMeteo(),
    compass: DeviceCompass(),
  );
  await services.notifier.init();
  final brain = Brain(services);
  nluAppVersion = appVersion;
  runApp(DigitalBrainApp(brain: brain));
  await brain.load();
}
