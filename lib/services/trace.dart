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

  static void clear() {
    _events.clear();
    sentUpTo = null;
  }

  /// The newest event already sent to our server (আরও › সমস্যা খোঁজার লগ ›
  /// সার্ভারে পাঠান); only newer ones go next time.
  static DateTime? sentUpTo;

  /// Words of what never leaves the phone (passwords, the vault, PIN/OTP,
  /// health, medicines, other apps' messages): a conversation with any of
  /// them is left out whole — its speech, what it was understood as and
  /// what it found.
  static final private = RegExp(
      r'পাসওয়ার্ড|পাসওয়ার্ড|পাসওয়ার্ড|password|ভল্ট|vault|পিন|\bpin\b|otp|ওটিপি|কোড|\bcode\b|গোপন|কার্ড|card|'
      r'স্বাস্থ্য|health|ওষুধ|ঔষধ|ওষুদ|medicine|\bmed|ট্যাবলেট|ক্যাপসুল|সিরাপ|ইনসুলিন|ডাক্তার|doctor|হাসপাতাল|প্রেসার|রক্ত|ডায়াবেটিস|সুগার|'
      r'ওজন|weight|bmi|পিরিয়ড|মাসিক|গর্ভ|টিকা|vaccine|অসুখ|অসুস্থ|জ্বর|ব্যথা|ব্যাথা|রোগ|ঘুম|sleep|step|হাঁট|'
      r'নোটিফিকেশন|notification|মেসেজ|message|sms|এসএমএস|বিকাশ|bkash|নগদ মেসেজ|ওছিয়ত|অসিয়ত|will_',
      caseSensitive: false);

  /// What may go to our server: the events after [sentUpTo], without any
  /// conversation that touched a private subject. Returns the lines and how
  /// many conversations were left out.
  static ({List<String> lines, int left, DateTime? upTo}) forServer({bool all = false}) {
    final fresh = [for (final e in _events) if (all || sentUpTo == null || e.at.isAfter(sentUpTo!)) e];
    final touched = <String>{};
    for (final e in _events) {
      if (private.hasMatch(e.toString())) touched.add(e.conversation.isEmpty ? '#${e.at.microsecondsSinceEpoch}' : e.conversation);
    }
    String key(TraceEvent e) => e.conversation.isEmpty ? '#${e.at.microsecondsSinceEpoch}' : e.conversation;
    final left = {for (final e in fresh) if (touched.contains(key(e))) key(e)};
    final keep = [for (final e in fresh) if (!touched.contains(key(e))) e];
    return (lines: [for (final e in keep) mask(e.toString())], left: left.length, upTo: fresh.isEmpty ? null : fresh.last.at);
  }

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
