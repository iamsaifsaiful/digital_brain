import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/plan_screens.dart' show nextRingLabel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('দিনলিপি › নিয়মিত: a repeating reminder shows how often, and the date and time it rings next (owner, 28 Oct)', () {
    final now = DateTime(2026, 10, 28, 11);
    final monthly = Reminder(title: 'বাসা ভাড়া', date: DateTime(2026, 10, 5), hour: 10, repeat: Repeat.monthly);
    final l = nextRingLabel(monthly, now);
    expect(l, contains('নভে'));
    expect(l, contains('৫'));
    expect(l, contains('১০'));
    final daily = Reminder(title: 'ওষুধ', date: DateTime(2026, 10, 1), hour: 21, repeat: Repeat.daily);
    final d = nextRingLabel(daily, now);
    expect(d, contains('আজ'));
    expect(d, contains('২৮'), reason: 'the date too, not only "আজ"');
  });
}
