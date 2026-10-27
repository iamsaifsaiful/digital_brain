/// Health Connect (Android's shared health store), read only — step one
/// (owner, 27 Oct): steps, sleep and exercise for "আমি" only. Records read
/// from the phone become the app's own [HealthLog]s here, so everything
/// else (the health page, voice answers, the doctor's summary) works the
/// same; the hand-written way stays as it was. Nothing read leaves the phone.
library;

import '../models/models.dart';

/// One sleep stage inside a session (Health Connect's stage numbers).
class HcStage {
  const HcStage(this.stage, this.start, this.end);
  final int stage;
  final DateTime start;
  final DateTime end;

  /// Health Connect: 0 unknown, 1 awake, 2 sleeping, 3 out of bed, 4 light, 5 deep, 6 REM, 7 awake in bed.
  bool get asleep => stage != 1 && stage != 3 && stage != 7;
}

/// A sleep or exercise session as Health Connect keeps it.
class HcSession {
  const HcSession({required this.id, required this.start, required this.end, this.stages = const [], this.type = 0});
  final String id;
  final DateTime start;
  final DateTime end;
  final List<HcStage> stages;

  /// Exercise type (Health Connect's number), 0 for sleep.
  final int type;

  static HcSession? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = '${j['id'] ?? ''}';
    final s = _ms(j['start']), e = _ms(j['end']);
    if (id.isEmpty || s == null || e == null || !e.isAfter(s)) return null;
    return HcSession(
      id: id,
      start: s,
      end: e,
      type: (j['type'] as num?)?.toInt() ?? 0,
      stages: [
        for (final x in (j['stages'] as List?) ?? const [])
          if (x is Map && _ms(x['start']) != null && _ms(x['end']) != null) HcStage((x['stage'] as num?)?.toInt() ?? 0, _ms(x['start'])!, _ms(x['end'])!),
      ],
    );
  }

  static DateTime? _ms(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
}

/// The tag every reading from Health Connect carries (its source).
const hcTag = 'hc';

/// Hours asleep in a session: the stages that are sleep, when the session has
/// stages; else the whole session. Rounded to a tenth of an hour.
double sleepHours(HcSession s) {
  final minutes = s.stages.isEmpty
      ? s.end.difference(s.start).inMinutes
      : s.stages.where((x) => x.asleep).fold<int>(0, (a, x) => a + x.end.difference(x.start).inMinutes);
  return (minutes / 6).round() / 10;
}

/// Minutes of exercise in a session.
int exerciseMinutes(HcSession s) => s.end.difference(s.start).inMinutes;

/// The id of a reading made from a Health Connect record: the same record
/// always gives the same id, so reading it again never adds it twice.
String hcLogId(String kind, String recordId) => 'hc:$kind:$recordId';

/// A night's sleep (at the time of waking) for "আমি".
HealthLog? sleepLog(HcSession s) {
  final h = sleepHours(s);
  if (h <= 0 || h > 24) return null;
  return HealthLog(id: hcLogId('sleep', s.id), member: FamilyMember.meId, kind: HealthKind.sleep, at: s.end, a: h, tag: hcTag);
}

/// An exercise session (at its start) for "আমি".
HealthLog? exerciseLog(HcSession s) {
  final m = exerciseMinutes(s);
  if (m <= 0 || m > 24 * 60) return null;
  return HealthLog(id: hcLogId('exercise', s.id), member: FamilyMember.meId, kind: HealthKind.exercise, at: s.start, a: m.toDouble(), tag: hcTag);
}

/// [logs] with [incoming] put in: one with the same id replaces the old one
/// (a session edited in Health Connect), a new one is added. Hand-written
/// readings are never touched. Returns the new list and how many were new.
(List<HealthLog>, int) mergeHcLogs(List<HealthLog> logs, Iterable<HealthLog> incoming) {
  final byId = {for (final h in incoming) h.id: h};
  var added = byId.length;
  final out = <HealthLog>[];
  for (final h in logs) {
    final n = byId.remove(h.id);
    if (n != null) added--;
    out.add(n ?? h);
  }
  out.addAll(byId.values);
  return (out, added);
}

/// Today's steps from Health Connect (or the phone's own counter), kept for
/// the voice answer "আজ কত হাঁটলাম?" — set by the app, read by [healthAnswer].
class LiveSteps {
  LiveSteps._();
  static ({DateTime day, int steps, DateTime at, bool hc})? today;
}
