// Owner, 26 Oct: "হিসাবে ভেতরে মাসিক হিসেবের পাশাপাশি দৈনিক দেখা যাবে।
// ফিল্টার অপশন থাকা দরকার।"
import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  test('periods: a week starts on Saturday; months and years roll over', () {
    final fri = DateTime(2026, 10, 9, 15);
    expect(spanStart(CashSpan.week, fri), DateTime(2026, 10, 3));
    expect(spanStart(CashSpan.week, DateTime(2026, 10, 3, 8)), DateTime(2026, 10, 3));
    expect(spanStart(CashSpan.day, fri), DateTime(2026, 10, 9));
    expect(spanShift(CashSpan.month, DateTime(2026, 12), 1), DateTime(2027, 1));
    expect(spanShift(CashSpan.day, DateTime(2026, 10, 1), -1), DateTime(2026, 9, 30));
    expect(spanShift(CashSpan.year, DateTime(2026), -1), DateTime(2025));
  });

  testWidgets('হিসাব: দৈনিক, সাপ্তাহিক, মাসিক, বাৎসরিক and filters by kind and খাত', (t) async {
    // The rig's day: Friday 9 Oct 2026.
    final rig = await start(t,
        data: AppData(cash: [
          CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: DateTime(2026, 10, 9, 10)),
          CashEntry(kind: CashKind.expense, amount: 200, category: 'যাতায়াত', date: DateTime(2026, 10, 9, 12)),
          CashEntry(kind: CashKind.expense, amount: 300, category: 'বাজার', date: DateTime(2026, 10, 8, 18)),
          CashEntry(kind: CashKind.income, amount: 30000, category: 'বেতন', date: DateTime(2026, 10, 1, 9)),
          CashEntry(kind: CashKind.expense, amount: 8000, category: 'বাসা ভাড়া', date: DateTime(2026, 9, 28, 9)),
        ]));
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    String total() => (t.widget<Text>(find.byKey(const Key('cash-filter-total'))).data ?? '');

    // Opens on দৈনিক.
    expect(find.text('আজকের ব্যালেন্স'), findsOneWidget);
    // A swipe on the period moves দৈনিক → সাপ্তাহিক → মাসিক (the আয়-ব্যয় tab stays).
    await t.fling(find.byKey(const Key('cash-swipe')), const Offset(-300, 0), 1200);
    await settle(t);
    expect(find.text('এই সপ্তাহের ব্যালেন্স'), findsOneWidget);
    await t.fling(find.byKey(const Key('cash-swipe')), const Offset(-300, 0), 1200);
    await settle(t);
    // Monthly: October only, day by day.
    expect(find.text('এই মাসের ব্যালেন্স'), findsOneWidget);
    expect(find.text('আমি পাব'), findsNothing, reason: 'still on আয়-ব্যয়, not ধার-দেনা');
    expect(find.text('৳২৯,০০০'), findsWidgets);
    expect(find.textContaining('· আজ'), findsOneWidget);
    expect(find.textContaining('· গতকাল'), findsOneWidget);

    // Daily: today only.
    await t.tap(find.text('দৈনিক'));
    await settle(t);
    expect(find.text('আজকের ব্যালেন্স'), findsOneWidget);
    expect(find.text('৳৭০০'), findsWidgets);
    expect(find.text('বেতন'), findsNothing);
    // The day before.
    await t.tap(find.byKey(const Key('cash-prev')));
    await settle(t);
    expect(find.text('দিনের ব্যালেন্স'), findsOneWidget);
    expect(find.text('৳৩০০'), findsWidgets);
    await t.tap(find.byKey(const Key('cash-next')));
    await settle(t);
    expect(find.text('আজকের ব্যালেন্স'), findsOneWidget);

    // Weekly (Sat 3 – Fri 9 Oct): not the salary on the 1st.
    await t.tap(find.text('সাপ্তাহিক'));
    await settle(t);
    expect(find.text('এই সপ্তাহের ব্যালেন্স'), findsOneWidget);
    expect(find.text('৳১,০০০'), findsWidgets);

    // Yearly, then the filters.
    await t.tap(find.text('বাৎসরিক'));
    await settle(t);
    expect(find.text('এই বছরের ব্যালেন্স'), findsOneWidget);
    Future<void> show(Finder f) async {
      await Scrollable.ensureVisible(t.element(f), alignment: 0.3);
      await settle(t);
    }

    await show(find.byKey(const Key('cash-kind-expense')));
    await t.tap(find.byKey(const Key('cash-kind-expense')));
    await settle(t);
    expect(total(), contains('খরচ ৳৯,০০০'));
    expect(total(), contains('৪টা লেনদেন'));
    expect(find.text('বেতন'), findsNothing);
    await show(find.byKey(const Key('cash-cat')));
    await t.tap(find.byKey(const Key('cash-cat')));
    await settle(t);
    await t.tap(find.byKey(const Key('cash-cat-বাজার')));
    await settle(t);
    expect(total(), contains('খরচ ৳৮০০'));
    expect(total(), contains('২টা লেনদেন'));
    // Clear the খাত, then only income.
    await show(find.byKey(const Key('cash-cat-on')));
    await t.tap(find.descendant(of: find.byKey(const Key('cash-cat-on')), matching: find.byIcon(Icons.clear)));
    await settle(t);
    await show(find.byKey(const Key('cash-kind-income')));
    await t.tap(find.byKey(const Key('cash-kind-income')));
    await settle(t);
    expect(total(), contains('আয় ৳৩০,০০০'));
    expect(find.text('খাত অনুযায়ী আয়'), findsOneWidget);
    expect(rig.brain.data.cash.length, 5, reason: 'filters only look');
    // Past বাৎসরিক, a swipe moves on to ধার-দেনা.
    await show(find.byKey(const Key('cash-swipe')));
    await t.fling(find.byKey(const Key('cash-swipe')), const Offset(-300, 0), 1200);
    await settle(t, 20);
    expect(find.text('আমি পাব'), findsOneWidget);
  });
}
