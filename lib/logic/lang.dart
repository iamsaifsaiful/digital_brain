/// The app's language: Bangla (default) or English, chosen in সেটিংস › ভাষা.
///
/// Screens wrap their words in [tr] (plain text) or [trf] (text with
/// values: `trf('{0}টা কাজ', [n])`). The Bangla text is the key; the English
/// comes from strings_en.dart. Anything without an English entry shows in
/// Bangla, so a missing translation never breaks a screen.
library;

import 'region.dart';
import 'strings_en.dart';

/// True while the app shows English.
bool isEn = false;

String tr(String bn) {
  var s = isEn ? (enStrings[bn] ?? bn) : bn;
  // The English of the country in use (global version).
  if (isEn) s = localEnglish(s);
  return takaMoney ? s : inCurrency(s, english: isEn);
}

/// [tr] without the currency change: for a text whose ৳ is really taka
/// (the Bangladesh price of Premium).
String trTaka(String bn) => isEn ? localEnglish(enStrings[bn] ?? bn) : bn;

/// A menu or tile name (owner, 28 Oct): in English the name a menu would
/// have ("Notes", "Passwords"), not the word's plain meaning.
String trm(String bn) => isEn ? (_menuEn[bn] != null ? localEnglish(_menuEn[bn]!) : tr(bn)) : bn;

const _menuEn = {
  'নোট': 'Notes',
  'পাসওয়ার্ড': 'Passwords',
  'ব্লাড ডোনেশন': 'Blood',
  'ডকুমেন্ট': 'Documents',
  'অ্যালার্ম': 'Alarms',
  'ওষুধ': 'Medicines',
  'রিমাইন্ডার': 'Reminders',
  'হিসাব': 'Money',
};

String trf(String bn, List<Object?> args) {
  var s = isEn ? (enStrings[bn] ?? bn) : bn;
  if (isEn) s = localEnglish(s);
  // Amounts in the member's currency (global version; taka: unchanged).
  if (!takaMoney) s = inCurrency(s, english: isEn);
  for (var i = 0; i < args.length; i++) {
    var a = '${args[i]}';
    // An app word put in (a period like "এই মাসে", a kind like "রিমাইন্ডার",
    // a repeat like "প্রতি মাসে"): in English too (global version).
    if (isEn) {
      final en = enStrings[a];
      if (en != null) a = localEnglish(en);
    }
    s = s.replaceAll('{$i}', a);
  }
  // A clock time put before "-এ"/"-এর": "৫টা" + "-এ" is said "৫টায়", and
  // "৫টা" + "-এর" is "৫টার" (a time with minutes keeps "৫:৩০-এ").
  if (!isEn) s = s.replaceAll(_taE, 'টায়').replaceAll(_taEr, 'টার');
  return s;
}

final _taE = RegExp(r'টা-এ(?![র\u0980-\u09FF])');
final _taEr = RegExp(r'টা-এর(?![\u0980-\u09FF])');

/// One of two words, by language.
String bnEn(String bn, String en) => isEn ? en : bn;
