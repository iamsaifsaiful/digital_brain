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
    this.pushed = false,
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

  /// Our server pushes this one itself at its time (owner, 27 Oct: notices
  /// did not come when the app had not been opened since they were
  /// written), so the phone does not plan it again.
  final bool pushed;

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
      pushed: j['pushed'] == true,
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
        'pushed': pushed,
      };
}

/// Tag of a server notification ("nudge:plan:" ones open the mic when tapped).
String serverTag(ServerNotice n) => n.mic ? 'nudge:plan:srv${n.id}' : 'nudge:srv:${n.id}';

/// The next three days of server notifications that still apply.
List<PlannedNotice> serverNotices(List<ServerNotice> list, AppData d, DateTime now, {DateTime? lastOpen}) {
  final out = <PlannedNotice>[];
  final today = DateTime(now.year, now.month, now.day);
  for (final n in list) {
    if (n.pushed) continue;
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

/// How the admin wants one kind of the app's own notifications (owner, 27
/// Oct: controlled from the site or the admin app). Empty fields keep the
/// app's own way.
class NoticeRule {
  const NoticeRule({this.on = true, this.at = '', this.title = '', this.body = '', this.who = 'all', this.wd = 0});
  final bool on;

  /// Another weekday for a one-weekday kind (1 = Monday … 7 = Sunday), 0 = the app's own.
  final int wd;

  /// 'HH:MM' or '' (the app's own time).
  final String at;

  /// Templates: {title} and {body} = what the app would say, {name} = the member's name.
  final String title;
  final String body;

  /// 'all', 'new', 'old', 'regular', 'occasional', 'free', 'pro' — decided on this phone.
  final String who;

  static NoticeRule fromJson(Map j) =>
      NoticeRule(on: j['on'] != false, at: '${j['at'] ?? ''}', title: '${j['title'] ?? ''}', body: '${j['body'] ?? ''}', who: '${j['who'] ?? 'all'}', wd: ((j['wd'] as num?)?.toInt() ?? 0).clamp(0, 7));
  Map<String, Object?> toJson() => {'on': on, 'at': at, 'title': title, 'body': body, 'who': who, if (wd > 0) 'wd': wd};

  /// Minutes after midnight, or null.
  int? get minutes {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(at);
    if (m == null) return null;
    final h = int.parse(m[1]!), mi = int.parse(m[2]!);
    return h < 24 && mi < 60 ? h * 60 + mi : null;
  }
}

class NoticeRules {
  const NoticeRules({this.kinds = const {}, this.cap});
  final Map<String, NoticeRule> kinds;

  /// At most this many nudges a day (the member's own limit may be lower).
  final int? cap;

  static const none = NoticeRules();

  static NoticeRules fromJson(Object? j) {
    if (j is! Map) return none;
    final k = j['kinds'];
    return NoticeRules(
      kinds: {if (k is Map) for (final e in k.entries) if (e.value is Map) '${e.key}': NoticeRule.fromJson(e.value as Map)},
      cap: (j['cap'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => {'kinds': {for (final e in kinds.entries) e.key: e.value.toJson()}, 'cap': cap};

  /// The rule for a notification's tag ('nudge:prayer:fajr' → 'nudge:prayer'), if any.
  NoticeRule? forTag(String tag) {
    for (final e in kinds.entries) {
      if (tag == e.key || tag.startsWith('${e.key}:')) return e.value;
    }
    return null;
  }
}

/// Which groups this phone's member is in, from how the app is used here
/// (nothing of it is sent anywhere): new/old by the first day, regular or
/// occasional by the days it was opened in the last 14, free or pro.
Set<String> memberGroups({required DateTime now, DateTime? firstUse, required Iterable<DateTime> openDays, required bool pro}) {
  final today = DateTime(now.year, now.month, now.day);
  final first = firstUse == null ? today : DateTime(firstUse.year, firstUse.month, firstUse.day);
  final days = {for (final d in openDays) DateTime(d.year, d.month, d.day)}.where((d) => !d.isBefore(today.subtract(const Duration(days: 13))) && !d.isAfter(today)).length;
  return {
    'all',
    today.difference(first).inDays < 7 ? 'new' : 'old',
    days >= 5 ? 'regular' : 'occasional',
    pro ? 'pro' : 'free',
  };
}

/// "{title}", "{body}", "{name}" filled in.
String fillNotice(String template, {required String title, required String body, required String name}) =>
    template.replaceAll('{title}', title).replaceAll('{body}', body).replaceAll('{name}', name).trim();
