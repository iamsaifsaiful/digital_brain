import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// The app's own folders. Problem log, 19 Nov: on some phones
/// path_provider's JNI call threw (JThrowable) at start, and the app said
/// the member's data could not be opened — the data was fine, only the
/// folder's name was not given. So: path_provider, then the app's own
/// channel (Context.filesDir / cacheDir — the same folders), then a few
/// more tries before giving up.
const _paths = MethodChannel('my_assistant/paths');

Future<Directory> _dir(Future<Directory> Function() provider, String which) async {
  Object? last;
  for (var i = 0; i < 3; i++) {
    try {
      return await provider();
    } catch (e) {
      last = e;
    }
    try {
      final p = await _paths.invokeMethod<String>(which);
      if (p != null && p.isNotEmpty) return Directory(p);
    } catch (_) {}
    await Future<void>.delayed(Duration(milliseconds: 150 * (i + 1)));
  }
  throw AppDirUnavailable('$last');
}

Future<Directory> appSupportDir() => _dir(getApplicationSupportDirectory, 'support');
Future<Directory> appTempDir() => _dir(getTemporaryDirectory, 'cache');

/// The phone did not give the app its folder: nothing is wrong with the data.
class AppDirUnavailable implements Exception {
  AppDirUnavailable(this.why);
  final String why;
  @override
  String toString() => 'AppDirUnavailable';
}
