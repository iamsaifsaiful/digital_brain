// The text clean-up every on-phone model reading starts with. It must give
// exactly what tool/nlu/train/common.py gives (test: test/nlu_normalize_test.dart
// against tool/nlu/train/vectors.jsonl) — the model was trained on that.

const _bnDigits = '০১২৩৪৫৬৭৮৯';

/// Unicode NFC for the Bengali letters that differ (Dart has no NFC):
/// য়/ড়/ঢ় are kept split (letter + nukta) as NFC does; ে+া → ো, ে+ৗ → ৌ.
String _nfcBengali(String s) => s
    .replaceAll('য়', 'য়')
    .replaceAll('ড়', 'ড়')
    .replaceAll('ঢ়', 'ঢ়')
    .replaceAll('ো', 'ো')
    .replaceAll('ৌ', 'ৌ');

final _zeroWidth = RegExp('[​‌‍﻿]');
final _punct = RegExp('[?!,।;:"“”‘’\'()\\[\\]{}…|]+');
final _dotDash = RegExp(r'(?<![০-৯])[.\-]|[.\-](?![০-৯])');
final _space = RegExp(r'\s+');

/// Lower-case, Bengali digits, punctuation to spaces ("/=" and "." or "-"
/// inside numbers stay), one space between words.
String nluNormalize(String text) {
  var t = _nfcBengali(text).replaceAll(_zeroWidth, '').toLowerCase();
  t = t.replaceAllMapped(RegExp('[0-9]'), (m) => _bnDigits[m[0]!.codeUnitAt(0) - 48]);
  t = t.replaceAll(_punct, ' ').replaceAll(_dotDash, ' ');
  return t.replaceAll(_space, ' ').trim();
}

List<String> nluWords(String text) {
  final n = nluNormalize(text);
  return n.isEmpty ? const [] : n.split(' ');
}

final _listMark = RegExp(r'(?:^|\s)([০-৯0-9]{1,2})\s*[.)।]\s+');

/// Rule split of a message: new lines, and numbered items ("১. … ২) …") when
/// a line has two or more; text before the first item is a heading.
/// Each part is (kind, text) with kind 'head', 'item' or 'line'.
List<(String, String)> nluSplitLines(String text) {
  final parts = <(String, String)>[];
  for (var line in text.trim().split(RegExp(r'\n+'))) {
    line = line.trim();
    if (line.isEmpty) continue;
    final marks = _listMark.allMatches(line).toList();
    if (marks.length >= 2) {
      final head = line.substring(0, marks.first.start).trim();
      if (head.isNotEmpty) parts.add(('head', head));
      for (var i = 0; i < marks.length; i++) {
        final end = i + 1 < marks.length ? marks[i + 1].start : line.length;
        parts.add(('item', line.substring(marks[i].end, end).trim()));
      }
    } else {
      parts.add(('line', line));
    }
  }
  return parts;
}
