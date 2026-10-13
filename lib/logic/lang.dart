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

String trf(String bn, List<Object?> args) {
  var s = isEn ? (enStrings[bn] ?? bn) : bn;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// One of two words, by language.
String bnEn(String bn, String en) => isEn ? en : bn;
