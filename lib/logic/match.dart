/// Matching words that are written differently but mean the same thing:
/// "ফেসবুক" ↔ "Facebook", "এবিসি" ↔ "ABC", "জিমেইলের" ↔ "Gmail".
/// Speech recognition writes English names in Bengali letters, while people
/// usually save them in English, so plain text search misses them.
library;

import 'dart:math';

import 'parser.dart' show fold, stem;

/// Common services, Bengali spelling → English name.
const _brandsRaw = {
  'ফেসবুক': 'facebook', 'ফেইসবুক': 'facebook', 'জিমেইল': 'gmail', 'জি মেইল': 'gmail', 'গুগল': 'google',
  'হোয়াটসঅ্যাপ': 'whatsapp', 'হোয়াটসআপ': 'whatsapp', 'হোয়াটস অ্যাপ': 'whatsapp', 'ইউটিউব': 'youtube',
  'ইনস্টাগ্রাম': 'instagram', 'ইন্সটাগ্রাম': 'instagram', 'ইনস্টা': 'instagram', 'বিকাশ': 'bkash', 'নগদ': 'nagad',
  'রকেট': 'rocket', 'উপায়': 'upay', 'টুইটার': 'twitter', 'টিকটক': 'tiktok', 'ইমো': 'imo', 'মেসেঞ্জার': 'messenger',
  'নেটফ্লিক্স': 'netflix', 'দারাজ': 'daraz', 'পাঠাও': 'pathao', 'উবার': 'uber', 'অ্যামাজন': 'amazon', 'আমাজন': 'amazon',
  'মাইক্রোসফট': 'microsoft', 'আউটলুক': 'outlook', 'ইয়াহু': 'yahoo', 'হটমেইল': 'hotmail', 'অ্যাপল': 'apple',
  'আইক্লাউড': 'icloud', 'গিটহাব': 'github', 'পেওনিয়ার': 'payoneer', 'পেপ্যাল': 'paypal', 'পেপাল': 'paypal',
  'আপওয়ার্ক': 'upwork', 'ফাইভার': 'fiverr', 'ফাইবার': 'fiverr', 'বাইন্যান্স': 'binance', 'লিংকডইন': 'linkedin',
  'লিঙ্কডইন': 'linkedin', 'ওয়ার্ডপ্রেস': 'wordpress', 'সিপ্যানেল': 'cpanel', 'জুম': 'zoom', 'স্কাইপ': 'skype',
  'টেলিগ্রাম': 'telegram', 'ক্যানভা': 'canva', 'চ্যাটজিপিটি': 'chatgpt', 'ড্রপবক্স': 'dropbox', 'ওয়াইফাই': 'wifi',
  'ওয়াই-ফাই': 'wifi', 'রাউটার': 'router', 'ডোমেইন': 'domain', 'ডোমেন': 'domain', 'হোস্টিং': 'hosting', 'ইমেইল': 'email',
  'ইমেল': 'email', 'মেইল': 'mail', 'ব্যাংক': 'bank', 'নেট': 'net', 'ইন্টারনেট': 'internet', 'ওয়েবসাইট': 'website',
  'সাইট': 'site', 'অ্যাডমিন': 'admin', 'এডমিন': 'admin', 'প্যানেল': 'panel', 'হোম': 'home', 'অফিস': 'office',
};

final Map<String, String> _brands = {for (final e in _brandsRaw.entries) fold(e.key): e.value};

/// English letters as people say them in Bengali.
const _lettersRaw = {
  'এ': 'a', 'বি': 'b', 'সি': 'c', 'ডি': 'd', 'ই': 'e', 'এফ': 'f', 'জি': 'g', 'এইচ': 'h', 'আই': 'i', 'জে': 'j',
  'কে': 'k', 'এল': 'l', 'এম': 'm', 'এন': 'n', 'ও': 'o', 'পি': 'p', 'কিউ': 'q', 'আর': 'r', 'এস': 's', 'টি': 't',
  'ইউ': 'u', 'ভি': 'v', 'ডাব্লিউ': 'w', 'ডব্লিউ': 'w', 'ডাবলিউ': 'w', 'এক্স': 'x', 'ওয়াই': 'y', 'জেড': 'z', 'জেট': 'z',
};

final List<MapEntry<String, String>> _letters = [for (final e in _lettersRaw.entries) MapEntry(fold(e.key), e.value)]
  ..sort((a, b) => b.key.length.compareTo(a.key.length));

/// "এবিসি" → "abc"; null when the word is not spelled-out letters.
String? spelledLetters(String word) {
  if (word.isEmpty || word.length > 24) return null;
  final out = StringBuffer();
  var i = 0;
  while (i < word.length) {
    MapEntry<String, String>? hit;
    for (final e in _letters) {
      if (word.startsWith(e.key, i)) {
        hit = e;
        break;
      }
    }
    if (hit == null) return null;
    out.write(hit.value);
    i += hit.key.length;
  }
  return out.length >= 2 ? out.toString() : null;
}

/// One comparable form: the English brand name, spelled-out letters, or
/// the word itself.
String canon(String word) {
  final w = fold(word.toLowerCase());
  return _brands[w] ?? _brands[stem(w)] ?? spelledLetters(w) ?? spelledLetters(stem(w)) ?? w;
}

const _bnMap = {
  'ক': 'k', 'খ': 'k', 'গ': 'g', 'ঘ': 'g', 'ঙ': 'n', 'চ': 'c', 'ছ': 'c', 'জ': 'j', 'ঝ': 'j', 'ঞ': 'n',
  'ট': 't', 'ঠ': 't', 'ড': 'd', 'ঢ': 'd', 'ণ': 'n', 'ত': 't', 'থ': 't', 'দ': 'd', 'ধ': 'd', 'ন': 'n',
  'প': 'p', 'ফ': 'f', 'ব': 'b', 'ভ': 'b', 'ম': 'm', 'য': 'j', 'র': 'r', 'ল': 'l', 'শ': 's', 'ষ': 's',
  'স': 's', 'হ': 'h', 'ং': 'n', 'ৎ': 't',
};

/// Consonant outline used to compare a Bengali spelling with an English
/// one: "ফেসবুক" and "facebook" both give "fsbk".
String skeleton(String word) {
  final w = fold(word.toLowerCase());
  final b = StringBuffer();
  if (RegExp(r'[ঀ-৿]').hasMatch(w)) {
    for (var i = 0; i < w.length; i++) {
      final c = w[i];
      final next = i + 1 < w.length ? w[i + 1] : '';
      final prev = i > 0 ? w[i - 1] : '';
      if (c == 'য' && (next == '়' || prev == '্')) continue; // য় and য-ফলা are vowels here
      if ((c == 'ড' || c == 'ঢ') && next == '়') {
        b.write('r');
        continue;
      }
      final m = _bnMap[c];
      if (m != null) b.write(m);
    }
  } else {
    var s = w.replaceAll(RegExp(r'[^a-z]'), '');
    for (final (a, r) in const [('ph', 'f'), ('ck', 'k'), ('sh', 's'), ('ch', 'c'), ('th', 't'), ('kh', 'k'), ('gh', 'g'), ('bh', 'b'), ('dh', 'd'), ('qu', 'k')]) {
      s = s.replaceAll(a, r);
    }
    s = s.replaceAllMapped(RegExp(r'c(?=[eiy])'), (_) => 's').replaceAll('c', 'k');
    s = s.replaceAll('q', 'k').replaceAll('x', 'ks').replaceAll('v', 'b').replaceAll('z', 'j').replaceAll(RegExp('[aeiouwy]'), '');
    b.write(s);
  }
  // Collapse doubled letters ("pp" → "p").
  return b.toString().replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
}

int _lev(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Does search word [term] match the stored word [word]?
bool wordsMatch(String term, String word) {
  final t = fold(term.toLowerCase());
  final w = fold(word.toLowerCase());
  if (t.length < 2 || w.isEmpty) return false;
  if (w.contains(t)) return true;
  final ct = canon(t);
  final cw = canon(w);
  if (ct == cw || (ct.length >= 3 && cw.contains(ct)) || (cw.length >= 3 && ct.contains(cw) && cw.length >= ct.length - 1)) return true;
  final st = skeleton(ct);
  final sw = skeleton(cw);
  if (st.length < 2 || sw.length < 2) return false;
  if (st == sw) return true;
  return st.length >= 4 && sw.length >= 4 && _lev(st, sw) <= 1;
}
