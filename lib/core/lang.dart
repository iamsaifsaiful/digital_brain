import 'en_words.dart';
import 'format.dart';

/// One-tap English: every text the app shows goes through [tr]. Whole
/// phrases are looked up first, then known words inside longer texts;
/// anything not in the list (customer names, notes) stays as typed.
/// Messages that go out on WhatsApp are not touched.
String tr(String s) {
  if (!appEnglish || s.isEmpty) return s;
  final hit = _cache[s];
  if (hit != null) return hit;
  var out = enWords[s.trim()];
  if (out == null) {
    // Digits first, so "১০টা" is "10টা" and "টা" stands as its own word.
    final latin = _latin(s);
    out = latin.replaceAllMapped(_words, (m) => _norm[m[0]]!);
  }
  out = out.replaceAll('৳', 'Tk ');
  out = out.replaceAll(RegExp(r' {2,}'), ' ').replaceAll(' ,', ',').replaceAll('( ', '(');
  if (_cache.length > 4000) _cache.clear();
  return _cache[s] = out;
}

final _cache = <String, String>{};

String _latin(String s) => s.replaceAllMapped(RegExp('[০-৯]'), (m) => '${'০১২৩৪৫৬৭৮৯'.indexOf(m[0]!)}');

/// The word list with Latin digits in the keys, to match text after its
/// digits were turned Latin.
final Map<String, String> _norm = {for (final e in enWords.entries) _latin(e.key): e.value};

final RegExp _words = () {
  final keys = _norm.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  return RegExp('(?<![ঀ-৿])(?:${keys.map(RegExp.escape).join('|')})(?![ঀ-৿])');
}();
