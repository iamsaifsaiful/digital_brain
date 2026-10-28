import 'package:digital_brain/logic/cash.dart' show monthSums, mainCopyOf;
import 'package:digital_brain/logic/money_more.dart' show accountBalance, ZakatSaved;
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/zakat.dart';
import 'package:digital_brain/logic/server_notices.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  test('the admin moves the weekly round-up to Sunday 11:00; the phone follows (owner, 28 Oct)', () {
    final now = DateTime(2026, 10, 27, 6); // Tuesday
    final d = AppData(tasks: [Task(title: 'বাজার করা')]);
    final plain = assistantNotices(d, now, const AssistantPrefs()).where((n) => n.reminderId == nudgeWeek).toList();
    expect(plain.single.at.weekday, DateTime.saturday);
    expect(plain.single.at.hour, 10);
    const rules = NoticeRules(kinds: {'nudge:week': NoticeRule(wd: DateTime.sunday, at: '11:00')});
    final moved = assistantNotices(d, now, const AssistantPrefs(rules: rules)).where((n) => n.reminderId == nudgeWeek).toList();
    expect(moved.single.at.weekday, DateTime.sunday);
    expect((moved.single.at.hour, moved.single.at.minute), (11, 0));
    expect(moved.single.at.isAfter(plain.single.at), isTrue, reason: 'the next Sunday after the app’s own Saturday');
    // Read from what the site sends, and kept on the phone.
    final r = NoticeRules.fromJson({'kinds': {'nudge:week': {'wd': 7, 'at': '11:00'}}});
    expect(NoticeRules.fromJson(r.toJson()).forTag('nudge:week')?.wd, 7);
    expect(NoticeRules.fromJson({'kinds': {'nudge:week': {'wd': 12}}}).forTag('nudge:week')?.wd, 7, reason: 'out of range is clamped');
  });

  test('a হিসাব kept apart from the main money stays out of zakat and the accounts; one let in still counts (owner, 28 Oct)', () {
    final now = DateTime(2026, 10, 28, 10);
    final bank = MoneyAccount(id: 'b1', name: 'ব্যাংক', kind: AccountKind.bank, opening: 100000);
    final apart = Project(id: 'shop', name: 'বন্ধুর দোকান', inMain: false, mainAsked: true);
    final mine = Project(id: 'home', name: 'বাড়ির কাজ', inMain: true, mainAsked: true);
    final d = AppData(
      accounts: [bank],
      projects: [apart, mine],
      cash: [
        CashEntry(kind: CashKind.income, amount: 50000, category: 'বিক্রি', date: now, projectId: 'shop', accountId: 'b1'),
        CashEntry(kind: CashKind.expense, amount: 3000, category: 'রড', date: now, projectId: 'home', accountId: 'b1'),
      ],
      ledger: [
        LedgerEntry(person: 'করিম', kind: LedgerKind.lent, amount: 7000, date: now, projectId: 'shop'),
        LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 2000, date: now, projectId: 'home'),
      ],
    );
    expect(accountBalance(d, bank), 100000, reason: 'a হিসাব’s own entries are not the account’s money');
    final lines = zakatLines(d, now, const ZakatSaved());
    expect(lines.any((l) => l.label.contains('করিম')), isFalse, reason: 'বকেয়া of a হিসাব kept apart');
    expect(lines.any((l) => l.label.contains('রহিম')), isTrue, reason: 'বকেয়া of a হিসাব let into the main money');
    expect(lines.firstWhere((l) => l.key == 'account:b1').amount, 100000);
  });

  testWidgets('a হিসাব let into the main money: its আয় shows in the main আয়, its খরচ in the main ব্যয়; one kept apart in neither (owner, 28 Oct)', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    b.data.projects.addAll([Project(id: 'in', name: 'দোকান', inMain: true, mainAsked: true), Project(id: 'out', name: 'বন্ধুর ব্যবসা', inMain: false, mainAsked: true)]);
    final inc = CashEntry(kind: CashKind.income, amount: 5000, category: 'বিক্রি', date: now, projectId: 'in');
    final exp = CashEntry(kind: CashKind.expense, amount: 1200, category: 'মাল কেনা', date: now, projectId: 'in');
    final apartInc = CashEntry(kind: CashKind.income, amount: 9000, category: 'বিক্রি', date: now, projectId: 'out');
    for (final e in [inc, exp, apartInc]) {
      await b.saveCash(e);
    }
    expect(mainCopyOf(b.data, inc.id)?.kind, CashKind.income);
    expect(mainCopyOf(b.data, exp.id)?.kind, CashKind.expense);
    expect(mainCopyOf(b.data, apartInc.id), isNull);
    final m = monthSums(b.data.cash, now);
    expect(m.income, 5000, reason: 'only the হিসাব let in, in আয়');
    expect(m.expense, 1200, reason: 'in ব্যয়');
  });
}
