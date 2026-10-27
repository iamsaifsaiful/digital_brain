import 'package:flutter/services.dart';

import '../logic/health_connect.dart';

/// Whether this phone can give Health Connect data.
enum HcStatus {
  /// Android 8 or older (Health Connect needs Android 9): the feature is hidden.
  unsupported,

  /// Android 9–13 without the Health Connect app (or it needs an update): offer Play Store.
  notInstalled,

  /// Ready; permissions may or may not be given yet.
  available,
}

/// Android's Health Connect, read only (HealthConnect.kt). Steps, sleep and
/// exercise; nothing is written.
abstract class HealthConnectSource {
  Future<HcStatus> status();

  /// All three read permissions given.
  Future<bool> granted();

  /// Asks for them (Health Connect's own screen); true when all were given.
  Future<bool> request();

  /// Total steps between the two moments, or null.
  Future<int?> steps(DateTime from, DateTime to);
  Future<List<HcSession>> sleep(DateTime from, DateTime to);
  Future<List<HcSession>> exercise(DateTime from, DateTime to);

  /// Health Connect in the Play Store.
  Future<void> install();
}

class DeviceHealthConnect implements HealthConnectSource {
  static const _ch = MethodChannel('my_assistant/health');

  @override
  Future<HcStatus> status() async {
    try {
      final s = await _ch.invokeMethod<String>('status');
      return switch (s) {
        'available' => HcStatus.available,
        'not_installed' => HcStatus.notInstalled,
        _ => HcStatus.unsupported,
      };
    } catch (_) {
      return HcStatus.unsupported;
    }
  }

  @override
  Future<bool> granted() async {
    try {
      return await _ch.invokeMethod<bool>('granted') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> request() async {
    try {
      return await _ch.invokeMethod<bool>('request') ?? false;
    } catch (_) {
      return false;
    }
  }

  Map<String, int> _range(DateTime from, DateTime to) => {'from': from.millisecondsSinceEpoch, 'to': to.millisecondsSinceEpoch};

  @override
  Future<int?> steps(DateTime from, DateTime to) async {
    try {
      return (await _ch.invokeMethod<num>('steps', _range(from, to)))?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<List<HcSession>> _sessions(String method, DateTime from, DateTime to) async {
    try {
      final l = await _ch.invokeListMethod<Object?>(method, _range(from, to)) ?? const [];
      return l.map(HcSession.fromJson).whereType<HcSession>().toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<HcSession>> sleep(DateTime from, DateTime to) => _sessions('sleep', from, to);

  @override
  Future<List<HcSession>> exercise(DateTime from, DateTime to) => _sessions('exercise', from, to);

  @override
  Future<void> install() async {
    try {
      await _ch.invokeMethod<void>('install');
    } catch (_) {}
  }
}

/// For tests (and phones without the Android side): set what it answers.
class FakeHealthConnect implements HealthConnectSource {
  HcStatus state = HcStatus.unsupported;
  bool allowed = false;
  bool allowOnAsk = true;
  int askedTimes = 0;
  int installs = 0;
  int? stepCount;
  List<HcSession> sleeps = [];
  List<HcSession> workouts = [];

  @override
  Future<HcStatus> status() async => state;

  @override
  Future<bool> granted() async => state == HcStatus.available && allowed;

  @override
  Future<bool> request() async {
    askedTimes++;
    if (state == HcStatus.available && allowOnAsk) allowed = true;
    return allowed;
  }

  @override
  Future<int?> steps(DateTime from, DateTime to) async => allowed ? stepCount : null;

  @override
  Future<List<HcSession>> sleep(DateTime from, DateTime to) async => allowed ? [for (final s in sleeps) if (s.end.isAfter(from) && !s.end.isAfter(to)) s] : const [];

  @override
  Future<List<HcSession>> exercise(DateTime from, DateTime to) async => allowed ? [for (final s in workouts) if (s.start.isAfter(from) && !s.start.isAfter(to)) s] : const [];

  @override
  Future<void> install() async => installs++;
}
