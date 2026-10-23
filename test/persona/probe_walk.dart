import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

String d(Command c) => switch (c) {
      LedgerAdd x => 'LedgerAdd(${x.person}, ${x.amount}, ${x.kind}, opts=${x.options})',
      CashAdd x => 'CashAdd(${x.kind}, ${x.amount}, ${x.category}, proj=${x.project})',
      ReminderAdd x => 'ReminderAdd(${x.title} @ ${x.at} ${x.repeat})',
      TaskAdd x => 'TaskAdd(${x.title})',
      NoteAdd x => 'NoteAdd(${x.text})',
      MenuAction x => 'Menu(${x.domain}.${x.op} "${x.target}" ${x.amount})',
      LedgerSet x => 'LedgerSet(${x.person}, ${x.balance})',
      CashQuery x => 'CashQuery(proj=${x.project})',
      LedgerQuery x => 'LedgerQuery(${x.ask}, ${x.person})',
      ProfileSet x => 'ProfileSet(${x.field}=${x.value})',
      OpenPlace x => 'Open(${x.place})',
      _ => '${c.runtimeType}',
    };

void main() {
  final now = DateTime(2026, 10, 9, 15, 53);
  const lines = String.fromEnvironment('LINES');
  test('probe', () {
    for (final s in lines.split('|')) {
      final cs = parseAll(s, const [], now: now, data: AppData(projects: [Project(name: 'রহিম ভবন'), Project(name: 'বোরো ধান'), Project(name: 'দোকান')]));
      // ignore: avoid_print
      print('$s\n   → ${cs.map(d).join(' ; ')}');
    }
  });
}
