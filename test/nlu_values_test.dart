import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/nlu/values.dart';

void main() {
  final now = DateTime(2026, 10, 22, 9, 30); // Thursday

  group('when', () {
    final table = <(String?, String?, DateTime, bool)>[
      ('কাল', 'সকাল ৯টায়', DateTime(2026, 10, 23, 9), false),
      ('আজ', 'রাত ১২টা', DateTime(2026, 10, 23, 0), false), // রাত ১২টা = next day's 00:00
      (null, 'রাত ১২টায়', DateTime(2026, 10, 23, 0), false),
      ('১৫ জুন', null, DateTime(2027, 6, 15, 9), false), // no year: the next 15 June
      ('১৫ ডিসেম্বর', null, DateTime(2026, 12, 15, 9), false),
      ('১৫ ডিসেম্বর ২০২৮', null, DateTime(2028, 12, 15, 9), false),
      ('পরশু', 'সন্ধ্যা সাড়ে ৭টায়', DateTime(2026, 10, 24, 19, 30), false),
      ('কাল', 'বিকাল ৪.৪৫-এ', DateTime(2026, 10, 23, 16, 45), false),
    ];
    for (final (d, t, at, ask) in table) {
      test('$d $t', () {
        final w = whenOf(d, t, now)!;
        expect(w.at, at);
        expect(w.askAmPm, ask);
      });
    }
    test('only an hour: ask সকাল না সন্ধ্যা', () {
      expect(whenOf('কাল', '৭টায়', now)!.askAmPm, isTrue);
      expect(whenOf('কাল', 'সকাল ৭টায়', now)!.askAmPm, isFalse);
    });
  });

  test('amounts', () {
    const table = {
      '১৫০০০/=': 15000, '2k': 2000, 'দেড় হাজার': 1500, 'আড়াইশো': 250, 'পাঁচশো টাকা': 500, '১ লাখ': 100000,
      '15,000 টাকা': 15000, 'সাড়ে তিন হাজার': 3500, '৩০০ tk': 300, '৫০k': 50000,
    };
    table.forEach((s, v) => expect(amountOf(s), v, reason: s));
  });

  test('quantity and price stay apart: "৩ কেজি ৩০০ টাকা"', () {
    expect(quantityOf('৩ কেজি'), (3, 'কেজি'));
    expect(amountOf('৩০০ টাকা'), 300);
    expect(quantityOf('আধা কেজি'), (0.5, 'কেজি'));
    expect(quantityOf('২ ডজন'), (2, 'ডজন'));
  });
}
