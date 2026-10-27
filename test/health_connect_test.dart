import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/logic/health.dart';
import 'package:digital_brain/logic/health_connect.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/models/models.dart';

void main() {
  final bed = DateTime(2026, 10, 26, 23, 0);
  final wake = DateTime(2026, 10, 27, 6, 30);

  tearDown(() => LiveSteps.today = null);

  group('sleep hours', () {
    test('a session without stages counts whole', () {
      expect(sleepHours(HcSession(id: 's', start: bed, end: wake)), 7.5);
    });

    test('awake, out of bed and awake-in-bed stages are left out', () {
      final s = HcSession(id: 's', start: bed, end: wake, stages: [
        HcStage(4, bed, bed.add(const Duration(hours: 3))), // light, 3 h
        HcStage(1, bed.add(const Duration(hours: 3)), bed.add(const Duration(hours: 3, minutes: 30))), // awake
        HcStage(5, bed.add(const Duration(hours: 3, minutes: 30)), bed.add(const Duration(hours: 5))), // deep, 1.5 h
        HcStage(3, bed.add(const Duration(hours: 5)), bed.add(const Duration(hours: 5, minutes: 15))), // out of bed
        HcStage(6, bed.add(const Duration(hours: 5, minutes: 15)), bed.add(const Duration(hours: 7))), // REM, 1.75 h
        HcStage(7, bed.add(const Duration(hours: 7)), wake), // awake in bed
      ]);
      expect(sleepHours(s), 6.3); // 375 minutes → 6.25 h → 6.3 to a tenth
    });
  });

  group('records become readings', () {
    test('sleep: hours, at waking, for "আমি", tagged hc, id from the record', () {
      final h = sleepLog(HcSession(id: 'abc-1', start: bed, end: wake))!;
      expect(h.id, 'hc:sleep:abc-1');
      expect(h.kind, HealthKind.sleep);
      expect(h.member, FamilyMember.meId);
      expect(h.at, wake);
      expect(h.a, 7.5);
      expect(h.tag, hcTag);
    });

    test('exercise: minutes, at its start', () {
      final st = DateTime(2026, 10, 27, 7);
      final h = exerciseLog(HcSession(id: 'run9', start: st, end: st.add(const Duration(minutes: 42)), type: 56))!;
      expect(h.id, 'hc:exercise:run9');
      expect(h.kind, HealthKind.exercise);
      expect(h.a, 42);
      expect(h.at, st);
      expect(h.tag, hcTag);
    });

    test('nonsense sessions are dropped', () {
      expect(sleepLog(HcSession(id: 'x', start: bed, end: bed.add(const Duration(hours: 30)))), isNull);
      expect(HcSession.fromJson({'id': 'x', 'start': 5, 'end': 5}), isNull);
      expect(HcSession.fromJson({'start': 1, 'end': 9}), isNull);
    });

    test('read from the channel shape', () {
      final s = HcSession.fromJson({
        'id': 'k',
        'start': bed.millisecondsSinceEpoch,
        'end': wake.millisecondsSinceEpoch,
        'stages': [
          {'stage': 5, 'start': bed.millisecondsSinceEpoch, 'end': wake.millisecondsSinceEpoch},
        ],
      })!;
      expect(s.stages.single.stage, 5);
      expect(sleepHours(s), 7.5);
    });
  });

  group('no doubles', () {
    final night = sleepLog(HcSession(id: 'n1', start: bed, end: wake))!;
    final hand = HealthLog(id: 'mine', kind: HealthKind.sleep, at: wake, a: 7);

    test('reading the same record twice adds it once', () {
      final (a, n1) = mergeHcLogs([hand], [night]);
      final (b, n2) = mergeHcLogs(a, [night]);
      expect(n1, 1);
      expect(n2, 0);
      expect(b.length, 2);
      expect(b.where((h) => h.id == 'hc:sleep:n1').length, 1);
    });

    test('an edited session replaces the old reading; hand-written ones stay', () {
      final edited = sleepLog(HcSession(id: 'n1', start: bed, end: wake.add(const Duration(hours: 1))))!;
      final (out, n) = mergeHcLogs([hand, night], [edited]);
      expect(n, 0);
      expect(out.length, 2);
      expect(out.firstWhere((h) => h.id == 'hc:sleep:n1').a, 8.5);
      expect(out.firstWhere((h) => h.id == 'mine').a, 7);
    });

    test('the same id given twice in one read counts once', () {
      final (out, n) = mergeHcLogs([], [night, night]);
      expect(n, 1);
      expect(out.length, 1);
    });
  });

  group('voice', () {
    final now = DateTime(2026, 10, 27, 9);
    final p = Parser(ledger: const [], now: now);

    test('questions are understood', () {
      expect((p.parse('আজ কত হাঁটলাম?') as HealthQuery).what, 'steps');
      expect((p.parse('গত রাতে কত ঘুমিয়েছি?') as HealthQuery).what, 'sleep');
      expect((p.parse('আজ কত মিনিট ব্যায়াম করলাম?') as HealthQuery).what, 'exercise');
      // Telling, not asking, still writes it down.
      expect(p.parse('আজ ৩০ মিনিট হাঁটলাম'), isA<HealthAdd>());
    });

    test('answers carry the real numbers', () {
      final d = AppData(health: [sleepLog(HcSession(id: 'n1', start: bed, end: wake))!]);
      expect(healthAnswer(d, 'sleep', now), contains('৭.৫ ঘণ্টা'));
      expect(healthAnswer(d, 'sleep', now), contains('Health Connect'));
      LiveSteps.today = (day: DateTime(2026, 10, 27), steps: 4321, at: now, hc: true);
      expect(healthAnswer(d, 'steps', now), contains('৪৩২১'));
      expect(healthAnswer(AppData(), 'exercise', now), contains('কোনো হিসাব নেই'));
    });

    test('no steps read today: says so, no made-up number', () {
      LiveSteps.today = (day: DateTime(2026, 10, 26), steps: 900, at: DateTime(2026, 10, 26, 20), hc: true);
      final a = healthAnswer(AppData(), 'steps', now);
      expect(a, contains('এখনো পাইনি'));
      expect(a.contains('৯০০'), isFalse);
    });
  });
}
