// BERT word-piece split for the BanglaBERT model (do_lower_case false, no
// Chinese-character split). Input is already cleaned by nluNormalize. Must
// match the Python tokenizer: test/nlu_wordpiece_test.dart against the
// vectors the training run writes (tool/nlu/train/wordpiece_vectors.jsonl).

bool _isPunct(int c) {
  if ((c >= 33 && c <= 47) || (c >= 58 && c <= 64) || (c >= 91 && c <= 96) || (c >= 123 && c <= 126)) return true;
  // Unicode punctuation that can survive the clean-up.
  const p = {0x0964, 0x0965, 0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x00AB, 0x00BB, 0x00A1, 0x00BF, 0x00B7};
  return p.contains(c);
}

class WordPiece {
  WordPiece(List<String> vocab, {this.unk = '[UNK]', this.maxChars = 100}) : _ids = {for (var i = 0; i < vocab.length; i++) vocab[i]: i};

  final Map<String, int> _ids;
  final String unk;
  final int maxChars;

  int idOf(String token) => _ids[token] ?? _ids[unk]!;

  /// Whitespace, then punctuation as tokens of their own, then word pieces.
  List<String> pieces(String text) {
    final out = <String>[];
    for (final w in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      final runes = w.runes.toList();
      var buf = StringBuffer();
      for (final r in runes) {
        if (_isPunct(r)) {
          if (buf.isNotEmpty) out.addAll(_word(buf.toString()));
          buf = StringBuffer();
          out.addAll(_word(String.fromCharCode(r)));
        } else {
          buf.writeCharCode(r);
        }
      }
      if (buf.isNotEmpty) out.addAll(_word(buf.toString()));
    }
    return out;
  }

  List<int> ids(String text) => [for (final p in pieces(text)) idOf(p)];

  List<String> _word(String w) {
    final cs = w.runes.toList();
    if (cs.length > maxChars) return [unk];
    final out = <String>[];
    var start = 0;
    while (start < cs.length) {
      var end = cs.length;
      String? cur;
      while (start < end) {
        var sub = String.fromCharCodes(cs.sublist(start, end));
        if (start > 0) sub = '##$sub';
        if (_ids.containsKey(sub)) {
          cur = sub;
          break;
        }
        end--;
      }
      if (cur == null) return [unk];
      out.add(cur);
      start = end;
    }
    return out;
  }
}
