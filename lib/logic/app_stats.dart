import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/extras.dart' show dayKey;

/// কোম্পানির পরিসংখ্যান (owner, 24 Nov): which parts of the app were
/// opened on a day and how long the app took to open — only names of parts
/// ("money", "notes"…), never what was written or how much. On unless the
/// user turns off Settings › "ব্যবহারের হিসাব পাঠান" (pref `stats_off`).
/// Kept on the phone until sent with the account refresh (Brain).
class AppStats {
  AppStats._();

  /// The parts counted, as the server knows them (stats.php MA_ST_PARTS).
  static const parts = {
    'tasks', 'reminders', 'money', 'diary', 'files', 'calendar', 'prayer', 'health', 'notes', 'contacts', 'passwords', 'zakat', 'family', 'business', 'voice',
  };

  /// False when the user turned it off: nothing is kept or sent.
  static bool on = true;

  /// The clock (tests set it).
  static DateTime Function() now = DateTime.now;

  /// Called when something new was kept (Brain saves it, later).
  static void Function()? changed;

  /// Day (yyyy-mm-dd) => parts opened that day.
  static final Map<String, Set<String>> opens = {};

  /// Day => milliseconds the app took to open (the first open of that day).
  static final Map<String, int> starts = {};

  /// A part of the app was opened (cheap: safe to call from build()).
  static void open(String part) {
    if (!on || !parts.contains(part)) return;
    final set = opens.putIfAbsent(dayKey(now()), () => <String>{});
    if (set.add(part)) changed?.call();
  }

  /// The first screen was up [ms] after the app started.
  static void started(int ms) {
    if (!on || ms <= 0 || ms >= 60000) return;
    final k = dayKey(now());
    if (starts.containsKey(k)) return;
    starts[k] = ms;
    changed?.call();
  }

  static bool get isEmpty => opens.isEmpty && starts.isEmpty;

  /// The days, newest last, at most [keep] of them.
  static List<Map<String, Object?>> days({int keep = 14}) {
    final all = {...opens.keys, ...starts.keys}.toList()..sort();
    return [
      for (final d in all.skip(all.length > keep ? all.length - keep : 0))
        {'d': d, 'o': [...(opens[d] ?? const <String>{})]..sort(), if (starts[d] != null) 'st': starts[d]},
    ];
  }

  /// As saved on the phone.
  static String save() => jsonEncode(days());

  /// What was saved, added to what this run already kept (the opening time
  /// comes before the saved days are read).
  static void restore(String? saved) {
    if (saved == null || saved.isEmpty) return;
    try {
      for (final x in jsonDecode(saved) as List) {
        final m = x as Map;
        final d = '${m['d']}';
        opens.putIfAbsent(d, () => <String>{}).addAll([for (final p in (m['o'] as List? ?? const [])) if (parts.contains('$p')) '$p']);
        final st = m['st'];
        if (st is num) starts.putIfAbsent(d, () => st.toInt());
      }
    } catch (_) {}
  }

  /// After a send: the days before today are done (today keeps growing).
  static void sent() {
    final today = dayKey(now());
    opens.removeWhere((d, _) => d != today);
    starts.removeWhere((d, _) => d != today);
  }

  static void clear() {
    opens.clear();
    starts.clear();
  }

  /// The phone's maker and Android version, from the app's Android side.
  static Future<({String brand, int android})> device() async {
    try {
      final m = await const MethodChannel('my_assistant/location').invokeMapMethod<String, Object?>('device') ?? const {};
      return (brand: '${m['brand'] ?? ''}', android: (m['sdk'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return (brand: '', android: 0);
    }
  }
}
