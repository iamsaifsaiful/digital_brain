/// The sentences the app shows and speaks.
library;

import '../models/models.dart';
import 'bn.dart';

const _vowelEnd = 'ািীুূৃেৈোৌঅআইঈউঊঋএঐওঔ';

bool _latin(String s) => RegExp(r'[A-Za-z0-9]$').hasMatch(s);

/// সজীব → সজীবের, রনি → রনির, Rahim → Rahim-এর.
String possessive(String name) {
  final n = name.trim();
  if (n.isEmpty) return n;
  if (_latin(n)) return '$n-এর';
  return _vowelEnd.contains(n[n.length - 1]) ? '$nর' : '$nের';
}

/// সজীব → সজীবকে, Rahim → Rahim-কে.
String toPerson(String name) {
  final n = name.trim();
  return _latin(n) ? '$n-কে' : '$nকে';
}

String _amt(int a) => '${bnNumber(a)} টাকা';

/// "আপনি সজীবকে ৫০০ টাকা ধার দিয়েছেন"
String describe(LedgerKind kind, String person, int amount) => switch (kind) {
      LedgerKind.lent => 'আপনি ${toPerson(person)} ${_amt(amount)} ধার দিয়েছেন',
      LedgerKind.borrowed => 'আপনি ${possessive(person)} কাছ থেকে ${_amt(amount)} ধার নিয়েছেন',
      LedgerKind.received => '$person আপনাকে ${_amt(amount)} ফেরত দিয়েছেন',
      LedgerKind.repaid => 'আপনি ${toPerson(person)} ${_amt(amount)} শোধ করেছেন',
    };

/// Asked before saving.
String confirmQuestion(LedgerKind kind, String person, int amount) => '${describe(kind, person, amount)}। সেভ করব?';

/// "এখন সজীবের কাছে আপনার ২০০ টাকা পাওনা।"
String balanceSentence(String person, int balance) {
  if (balance > 0) return 'এখন ${possessive(person)} কাছে আপনার ${_amt(balance)} পাওনা।';
  if (balance < 0) return 'এখন ${toPerson(person)} আপনার ${_amt(-balance)} দিতে হবে।';
  return 'এখন ${possessive(person)} সাথে হিসাব শূন্য।';
}

/// Spoken after saving.
String savedSentence(LedgerKind kind, String person, int amount, int newBalance) =>
    '${describe(kind, person, amount)}। ${balanceSentence(person, newBalance)}';

/// "সজীবের কাছে আপনি পাবেন" / "সজীবকে আপনি দেবেন" heading for a balance card.
String balanceHeading(String person, int balance) {
  if (balance < 0) return '${toPerson(person)} আপনি দেবেন';
  if (balance > 0) return '${possessive(person)} কাছে আপনি পাবেন';
  return '${possessive(person)} সাথে হিসাব';
}
