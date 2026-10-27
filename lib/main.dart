import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'services/health_connect.dart';
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
import 'services/error_log.dart';
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
    health: DeviceHealthConnect(),
  );
  await services.notifier.init();
  // সমস্যার লগ: every error the app runs into, cleaned, for our server —
  // kept in a small file until sent, and sent a few seconds after.
  ErrorLog.version = appVersion;
  try {
    await ErrorLog.open(await getApplicationSupportDirectory());
  } catch (_) {}
  final shown = FlutterError.onError;
  FlutterError.onError = (d) {
    ErrorLog.record(d.exception, d.stack, version: appVersion);
    shown?.call(d);
  };
  PlatformDispatcher.instance.onError = (e, s) {
    ErrorLog.record(e, s, version: appVersion);
    return false;
  };
  final brain = Brain(services);
  ErrorLog.connect(services.server, () => brain.services.ai.session);
  nluAppVersion = appVersion;
  runApp(DigitalBrainApp(brain: brain));
  await brain.load();
}
