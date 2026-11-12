/// The app's language: Bangla (default) or English, chosen in সেটিংস › ভাষা.
///
/// Screens wrap their words in [tr] (plain text) or [trf] (text with
/// values: `trf('{0}টা কাজ', [n])`). The Bangla text is the key; the English
/// comes from strings_en.dart. Anything without an English entry shows in
/// Bangla, so a missing translation never breaks a screen.
library;

import 'strings_en.dart';

/// True while the app shows English.
bool isEn = false;

String tr(String bn) => isEn ? (enStrings[bn] ?? bn) : bn;

/// A menu or tile name (owner, 28 Oct): in English the name a menu would
/// have ("Notes", "Passwords"), not the word's plain meaning.
String trm(String bn) => isEn ? (_menuEn[bn] ?? tr(bn)) : bn;

const _menuEn = {
  'নোট': 'Notes',
  'পাসওয়ার্ড': 'Passwords',
  'ব্লাড ডোনেশন': 'Blood',
  'ডকুমেন্ট': 'Documents',
  'অ্যালার্ম': 'Alarms',
  'ওষুধ': 'Medicines',
  'রিমাইন্ডার': 'Reminders',
  'হিসাব': 'Money',
  'গ্রাহক': 'Customers',
  'বিক্রি': 'Sales',
  'স্টক': 'Inventory',
};

String trf(String bn, List<Object?> args) {
  var s = isEn ? (enStrings[bn] ?? bn) : bn;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    // In English a value that is one of the app's own words (a category,
    // a unit, a kind) shows in English too; anything else as it is.
    s = s.replaceAll('{$i}', isEn && a is String ? (enStrings[a] ?? a) : '$a');
  }
  // A clock time put before "-এ"/"-এর": "৫টা" + "-এ" is said "৫টায়", and
  // "৫টা" + "-এর" is "৫টার" (a time with minutes keeps "৫:৩০-এ").
  if (!isEn) s = s.replaceAll(_taE, 'টায়').replaceAll(_taEr, 'টার');
  // "1 products" → "1 product": counts read naturally in English.
  if (isEn) s = s.replaceAllMapped(_onePlural, (m) => '${m[1]}1 ${_singular[m[2]!] ?? m[2]!.substring(0, m[2]!.length - 1)}');
  return s;
}

const _singular = {'people': 'person', 'entries': 'entry', 'categories': 'category', 'times': 'time', 'pcs': 'pc'};
final _onePlural = RegExp(r'(^|[^\d.,])1 (products|items|receipts|customers|suppliers|days|tasks|reminders|notes|entries|transactions|people|hours|minutes|months|years|weeks|installments|deposits|members|numbers|photos|files|documents|lines|categories|accounts|projects|goals|habits|passwords|cards|sales|requests|alarms|readings|medicines|folders|contacts|messages|digits|sections|dealers|units|orders|purchases|payments|debts|loans|records|rows|pages|steps)\b');

final _taE = RegExp(r'টা-এ(?![র\u0980-\u09FF])');
final _taEr = RegExp(r'টা-এর(?![\u0980-\u09FF])');

/// One of two words, by language.
String bnEn(String bn, String en) => isEn ? en : bn;
