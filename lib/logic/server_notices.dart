/// Notifications written on our website's admin page and shown on the
/// phone (see the plugin's notices.php). The list comes down when the app
/// opens; each one is planned here like the assistant's own nudges, so it
/// keeps to the user's quiet hours, daily limit and switch.
library;

import '../models/models.dart';
import '../services/notifications.dart';

class ServerNotice {
  const ServerNotice({
    required this.id,
    required this.title,
    this.body = '',
    this.kind = 'daily',
    this.time = '21:00',
    this.weekday = 5,
    this.date,
    this.from,
    this.until,
    this.cond = '',
    this.mic = false,
  });

  final int id;
  final String title;
  final String body;

  /// 'once', 'daily' or 'weekly'.
  final String kind;

  /// "HH:MM", phone time.
  final String time;

  /// For weekly: 1 = Monday … 7 = Sunday.
  final int weekday;
  final DateTime? date;
  final DateTime? from;
  final DateTime? until;

  /// '' (always), 'no_tasks', 'no_spending', 'not_opened' — checked on the phone.
  final String cond;

  /// A tap opens the mic.
  final bool mic;

  static DateTime? _day(Object? v) => v == null ? null : DateTime.tryParse('$v');

  static ServerNotice? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = (j['id'] as num?)?.toInt();
    final title = '${j['title'] ?? ''}'.trim();
    if (id == null || title.isEmpty) return null;
    return ServerNotice(
      id: id,
      title: title.length > 120 ? title.substring(0, 120) : title,
      body: '${j['body'] ?? ''}'.trim(),
      kind: '${j['kind'] ?? 'daily'}',
      time: RegExp(r'^\d\d:\d\d$').hasMatch('${j['time']}') ? '${j['time']}' : '21:00',
      weekday: ((j['weekday'] as num?)?.toInt() ?? 5).clamp(1, 7),
      date: _day(j['date']),
      from: _day(j['from']),
      until: _day(j['until']),
      cond: '${j['cond'] ?? ''}',
      mic: j['mic'] == true,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'kind': kind,
        'time': time,
        'weekday': weekday,
        'date': date?.toIso8601String(),
        'from': from?.toIso8601String(),
        'until': until?.toIso8601String(),
        'cond': cond,
        'mic': mic,
      };
}

/// Tag of a server notification ("nudge:plan:" ones open the mic when tapped).
String serverTag(ServerNotice n) => n.mic ? 'nudge:plan:srv${n.id}' : 'nudge:srv:${n.id}';

/// The next three days of server notifications that still apply.
List<PlannedNotice> serverNotices(List<ServerNotice> list, AppData d, DateTime now, {DateTime? lastOpen}) {
  final out = <PlannedNotice>[];
  final today = DateTime(now.year, now.month, now.day);
  for (final n in list) {
    final hm = n.time.split(':');
    final minutes = int.parse(hm[0]) * 60 + int.parse(hm[1]);
    for (var i = 0; i < 3; i++) {
      final day = today.add(Duration(days: i));
      final ok = switch (n.kind) {
        'once' => n.date != null && dayKey(n.date!) == dayKey(day),
        'weekly' => day.weekday == n.weekday,
        _ => true,
      };
      if (!ok) continue;
      if (n.from != null && day.isBefore(DateTime(n.from!.year, n.from!.month, n.from!.day))) continue;
      if (n.until != null && day.isAfter(DateTime(n.until!.year, n.until!.month, n.until!.day))) continue;
      final at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
      if (!at.isAfter(now)) continue;
      if (!_condition(n.cond, d, day, lastOpen)) continue;
      final tag = serverTag(n);
      out.add(PlannedNotice(id: stableId('$tag:${dayKey(day)}'), at: at, title: n.title, body: n.body, reminderId: tag, gentle: true));
    }
  }
  return out;
}

bool _condition(String cond, AppData d, DateTime day, DateTime? lastOpen) {
  bool sameDay(DateTime? a) => a != null && a.year == day.year && a.month == day.month && a.day == day.day;
  return switch (cond) {
    'no_tasks' => !d.tasks.any((t) => sameDay(t.due) || (t.due == null && sameDay(t.createdAt))),
    'no_spending' => !d.cash.any((e) => e.kind == CashKind.expense && sameDay(e.date)),
    'not_opened' => !sameDay(lastOpen),
    '' => true,
    _ => false, // a condition this version does not know: better silent than wrong
  };
}
