/// The sentences the app shows and speaks.
library;

import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';

const _vowelEnd = 'ািীুূৃেৈোৌঅআইঈউঊঋএঐওঔ';

bool _latin(String s) => RegExp(r'[A-Za-z0-9]$').hasMatch(s);

/// সজীব → সজীবের, রনি → রনির, Rahim → Rahim-এর.
String possessive(String name) {
  final n = name.trim();
  if (n.isEmpty) return n;
  if (_latin(n)) return trf('{0}-এর', [n]);
  return _vowelEnd.contains(n[n.length - 1]) ? trf('{0}র', [n]) : trf('{0}ের', [n]);
}

/// সজীব → সজীবকে, Rahim → Rahim-কে.
String toPerson(String name) {
  final n = name.trim();
  return _latin(n) ? trf('{0}-কে', [n]) : trf('{0}কে', [n]);
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
  if (balance > 0) return trf('{0} কাছে আপনার {1} পাওনা আছে', [possessive(person), _amt(balance)]);
  if (balance < 0) return trf('{0} আপনার {1} দিতে হবে', [toPerson(person), _amt(-balance)]);
  return trf('{0} সাথে হিসাব একদম মিটে গেছে', [possessive(person)]);
}

/// "এখন সজীবের কাছে আপনার ২০০ টাকা পাওনা আছে।"
String balanceSentence(String person, int balance) => 'এখন ${owesText(person, balance)}।';

/// Spoken after saving.
String savedSentence(LedgerKind kind, String person, int amount, int newBalance) =>
    'ঠিক আছে, লিখে রাখলাম। ${balanceSentence(person, newBalance)}';

/// "সজীবের কাছে আপনি পাবেন" / "সজীবকে আপনি দেবেন" heading for a balance card.
String balanceHeading(String person, int balance) {
  if (balance < 0) return trf('{0} আপনি দেবেন', [toPerson(person)]);
  if (balance > 0) return trf('{0} কাছে আপনি পাবেন', [possessive(person)]);
  return trf('{0} সাথে হিসাব', [possessive(person)]);
}
