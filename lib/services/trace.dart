import 'package:flutter/foundation.dart';

/// A diagnostic trace of one conversation: recogniser sessions, partial and
/// final results, the assembled speech, what it was understood as, where the
/// answer was looked up and which records it used.
///
/// Off by default in the released app (turned on from আরও › সমস্যা খোঁজার
/// লগ). Kept only in memory on this phone and cleared when the app closes;
/// never written to the system log in a release build. Phone numbers and
/// long digit runs are masked; passwords are never passed in.
class Trace {
  static bool enabled = kDebugMode;
  static const _max = 600;
  static final List<TraceEvent> _events = [];
  static String conversation = '';

  static List<TraceEvent> get events => List.unmodifiable(_events);

  static void log(String area, String what, [Map<String, Object?> data = const {}]) {
    if (!enabled) return;
    final e = TraceEvent(DateTime.now(), conversation, area, what, {for (final x in data.entries) x.key: mask('${x.value}')});
    _events.add(e);
    if (_events.length > _max) _events.removeRange(0, _events.length - _max);
    // Printed only in a development build run with --dart-define=TRACE_PRINT=true.
    if (kDebugMode && const bool.fromEnvironment('TRACE_PRINT')) debugPrint('[trace] $e');
  }

  static void clear() => _events.clear();

  /// Six or more digits in a row (phone numbers, account numbers) are hidden.
  static String mask(String s) => s.replaceAllMapped(RegExp(r'[+]?[0-9০-৯][0-9০-৯ \-]{5,}[0-9০-৯]'), (m) => '•' * 6);

  static String dump() => _events.map((e) => e.toString()).join('\n');
}

class TraceEvent {
  const TraceEvent(this.at, this.conversation, this.area, this.what, this.data);
  final DateTime at;
  final String conversation;
  final String area;
  final String what;
  final Map<String, String> data;

  @override
  String toString() {
    final t = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}.${(at.millisecond ~/ 10).toString().padLeft(2, '0')}';
    final d = data.entries.map((x) => '${x.key}=“${x.value}”').join(' ');
    return '$t [$conversation] $area · $what${d.isEmpty ? '' : ' · $d'}';
  }
}
