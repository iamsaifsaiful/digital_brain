/// নোটিফিকেশন: what the phone is set to show in the coming days, and what
/// it already showed, for the নোটিফিকেশন page. The same list, stripped to
/// kind and time (never the user's own words), goes to our server so the
/// admin can see what each member is getting and when.
library;

import '../services/notifications.dart';

/// One notification: coming up, or already gone by.
class NoticeEvent {
  const NoticeEvent({required this.at, required this.title, this.body = '', required this.tag, required this.kind});

  final DateTime at;
  final String title;
  final String body;

  /// The notification's reminder id or assistant tag.
  final String tag;

  /// 'reminder', 'reminder_early', 'server' or the assistant's kind
  /// ('brief:morning', 'nudge:streak' …); see [noticeKind].
  final String kind;

  bool get isReminder => kind == 'reminder' || kind == 'reminder_early';

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 't': title, if (body.isNotEmpty) 'b': body, 'g': tag, 'k': kind};

  static NoticeEvent? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['at']}');
    if (at == null) return null;
    return NoticeEvent(at: at, title: '${j['t'] ?? ''}', body: '${j['b'] ?? ''}', tag: '${j['g'] ?? ''}', kind: '${j['k'] ?? ''}');
  }

  String get key => '$tag@${at.millisecondsSinceEpoch}';
}

/// What sort of notification [n] is. A reminder is only ever "reminder":
/// its words (a medicine, a person, a bill) stay on the phone.
String noticeKind(PlannedNotice n) {
  if (!n.gentle) return n.early ? 'reminder_early' : 'reminder';
  final tag = n.reminderId;
  if (tag.startsWith('nudge:srv:') || tag.startsWith('nudge:plan:srv')) return 'server';
  final parts = tag.split(':');
  final head = parts.length >= 2 ? '${parts[0]}:${parts[1]}' : parts.first;
  // Only letters, digits, _ and : — never something the user wrote.
  return RegExp(r'^[a-z0-9_:]{1,40}$').hasMatch(head) ? head : 'assistant';
}

/// Every time a planned notification will show from [now] for [days] days,
/// soonest first (a repeating one once per time it rings).
List<NoticeEvent> expandPlan(Iterable<PlannedNotice> plan, DateTime now, {int days = 7, int max = 400}) {
  final end = now.add(Duration(days: days));
  final out = <NoticeEvent>[];
  NoticeEvent ev(PlannedNotice n, DateTime at) => NoticeEvent(at: at, title: n.title, body: n.body, tag: n.reminderId, kind: noticeKind(n));
  for (final n in plan) {
    if (n.every != null && n.every! > Duration.zero) {
      var at = n.at;
      if (at.isBefore(now)) {
        final steps = now.difference(at).inMicroseconds ~/ n.every!.inMicroseconds + 1;
        at = at.add(n.every! * steps);
      }
      for (var i = 0; i < 48 && !at.isAfter(end); i++, at = at.add(n.every!)) {
        out.add(ev(n, at));
      }
      continue;
    }
    if (n.repeat == NoticeRepeat.none) {
      if (n.at.isAfter(now) && !n.at.isAfter(end)) out.add(ev(n, n.at));
      continue;
    }
    var at = nextAhead(n, now);
    for (var i = 0; i < 60 && !at.isAfter(end); i++) {
      out.add(ev(n, at));
      at = nextAhead(n, at);
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > max ? out.sublist(0, max) : out;
}

/// The history after a new look at the plan: everything from the last plan
/// whose time came between [since] and [now] has been shown; the newest
/// [keep] are kept, newest first, none older than [days].
List<NoticeEvent> addPassed(List<NoticeEvent> history, List<NoticeEvent> lastPlan, DateTime? since, DateTime now, {int keep = 150, int days = 30}) {
  final seen = {for (final e in history) e.key};
  final passed = [
    for (final e in lastPlan)
      if (!e.at.isAfter(now) && (since == null || e.at.isAfter(since)) && !seen.contains(e.key)) e,
  ];
  final cut = now.subtract(Duration(days: days));
  final all = [...passed, ...history].where((e) => e.at.isAfter(cut)).toList()..sort((a, b) => b.at.compareTo(a.at));
  return all.length > keep ? all.sublist(0, keep) : all;
}

/// What goes to our server: kind and time only; a title only for the
/// server's own notifications (it wrote them).
List<Map<String, Object?>> planForServer(List<NoticeEvent> plan) => [
      for (final e in plan.take(300))
        {
          'kind': e.kind,
          'at': e.at.toUtc().toIso8601String(),
          if (e.kind == 'server') 'title': e.title.length > 120 ? e.title.substring(0, 120) : e.title,
        },
    ];

/// A push our server sent this member (from its log).
class PushRecord {
  const PushRecord({required this.at, required this.title, required this.kind, required this.status});
  final DateTime at;
  final String title;
  final String kind;

  /// 'sent', 'no_device' or 'failed'.
  final String status;

  static PushRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = DateTime.tryParse('${j['at']}');
    if (at == null) return null;
    return PushRecord(at: at.toLocal(), title: '${j['title'] ?? ''}', kind: '${j['kind'] ?? ''}', status: '${j['status'] ?? ''}');
  }
}
