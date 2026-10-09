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

/// "সজীবকে ৫০০ টাকা ধার দিলেন" — said the way people talk, not formally.
String describe(LedgerKind kind, String person, int amount) => switch (kind) {
      LedgerKind.lent => '${toPerson(person)} ${_amt(amount)} ধার দিলেন',
      LedgerKind.borrowed => '${possessive(person)} কাছ থেকে ${_amt(amount)} ধার নিলেন',
      LedgerKind.received => '$person আপনাকে ${_amt(amount)} ফেরত দিলেন',
      LedgerKind.repaid => '${toPerson(person)} ${_amt(amount)} শোধ করলেন',
    };

/// Asked before saving: "আচ্ছা, সজীবকে ৫০০ টাকা ধার দিলেন, তাই তো? লিখে রাখি?"
String confirmQuestion(LedgerKind kind, String person, int amount) => 'আচ্ছা, ${describe(kind, person, amount)}, তাই তো? লিখে রাখি?';

/// "সজীবের কাছে আপনার ২০০ টাকা পাওনা আছে" (no full stop).
String owesText(String person, int balance) {
  if (balance > 0) return '${possessive(person)} কাছে আপনার ${_amt(balance)} পাওনা আছে';
  if (balance < 0) return '${toPerson(person)} আপনার ${_amt(-balance)} দিতে হবে';
  return '${possessive(person)} সাথে হিসাব একদম মিটে গেছে';
}

/// "এখন সজীবের কাছে আপনার ২০০ টাকা পাওনা আছে।"
String balanceSentence(String person, int balance) => 'এখন ${owesText(person, balance)}।';

/// Spoken after saving.
String savedSentence(LedgerKind kind, String person, int amount, int newBalance) =>
    'ঠিক আছে, লিখে রাখলাম। ${balanceSentence(person, newBalance)}';

/// "সজীবের কাছে আপনি পাবেন" / "সজীবকে আপনি দেবেন" heading for a balance card.
String balanceHeading(String person, int balance) {
  if (balance < 0) return '${toPerson(person)} আপনি দেবেন';
  if (balance > 0) return '${possessive(person)} কাছে আপনি পাবেন';
  return '${possessive(person)} সাথে হিসাব';
}
