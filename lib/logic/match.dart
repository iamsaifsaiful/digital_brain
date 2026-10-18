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
/// one: "ফেসবুক" and "facebook" both give "fsbk"; "মিটিং" and "meeting" "mtn".
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
      if (m != null) {
        b.write(m);
      } else if (RegExp(r'[অ-ঔা-ৌ]').hasMatch(c)) {
        // A vowel keeps two same sounds apart: "শরীর" is s-r-r, not s-r.
        b.write('.');
      }
    }
  } else {
    var s = w.replaceAll(RegExp(r'[^a-z]'), '');
    for (final (a, r) in const [('ng', 'n'), ('ph', 'f'), ('ck', 'k'), ('sh', 's'), ('ch', 'c'), ('th', 't'), ('kh', 'k'), ('gh', 'g'), ('bh', 'b'), ('dh', 'd'), ('qu', 'k')]) {
      s = s.replaceAll(a, r);
    }
    s = s.replaceAllMapped(RegExp(r'c(?=[eiy])'), (_) => 's').replaceAll('c', 'k');
    s = s.replaceAll('q', 'k').replaceAll('x', 'ks').replaceAll('v', 'b').replaceAll('z', 'j');
    // Doubled letters next to each other are one sound ("pp", "oo").
    s = s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!).replaceAll(RegExp('[aeiouwy]+'), '.');
    b.write(s);
  }
  // Collapse doubled consonants written together ("pp", "ক্ক"); a vowel
  // between them keeps both ("shoshur" is s-s-r, never "শরীর").
  return b.toString().replaceAllMapped(RegExp(r'([^.])\1+'), (m) => m[1]!).replaceAll('.', '');
}

const _bnVowelSigns = {'া': 'a', 'ি': 'i', 'ী': 'i', 'ু': 'u', 'ূ': 'u', 'ে': 'e', 'ৈ': 'oi', 'ো': 'o', 'ৌ': 'ou', 'ৃ': 'ri'};
const _bnVowels = {'অ': 'o', 'আ': 'a', 'ই': 'i', 'ঈ': 'i', 'উ': 'u', 'ঊ': 'u', 'এ': 'e', 'ঐ': 'oi', 'ও': 'o', 'ঔ': 'ou', 'ঋ': 'ri'};

/// A rough Latin spelling with the vowels ("রবিন" → "robin"), to tell
/// "Robin" from "Rabbani" when both have the same consonants.
String roman(String word) {
  final w = fold(word.toLowerCase());
  if (!RegExp(r'[ঀ-৿]').hasMatch(w)) {
    return w.replaceAll(RegExp(r'[^a-z]'), '').replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!).replaceAll('ph', 'f').replaceAll('sh', 's').replaceAll('w', 'o').replaceAll('y', 'i').replaceAll('ee', 'i').replaceAll('oo', 'u');
  }
  final b = StringBuffer();
  for (var i = 0; i < w.length; i++) {
    final c = w[i];
    final next = i + 1 < w.length ? w[i + 1] : '';
    if (c == 'য' && next == '়') {
      b.write('y');
      i++;
      continue;
    }
    final v = _bnVowels[c] ?? _bnVowelSigns[c];
    if (v != null) {
      b.write(v);
      continue;
    }
    final m = _bnMap[c];
    if (m == null) continue;
    b.write(m == 's' && (c == 'শ' || c == 'ষ') ? 's' : m);
    // The vowel a consonant carries when nothing else is written, except at
    // the end of the word or before a joined letter.
    final carries = next.isNotEmpty && !_bnVowelSigns.containsKey(next) && next != '্' && next != '়' && next != 'ং' && i + 1 < w.length - 1;
    if (carries) b.write('o');
  }
  return b.toString().replaceAll('y', 'i').replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
}

/// How far apart two spellings of a name sound (0 = the same).
int soundDistance(String a, String b) => _lev(roman(a), roman(b));

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

final _bengali = RegExp(r'[ঀ-৿]');

/// Does search word [term] match the stored word [word]?
bool wordsMatch(String term, String word) {
  final t = fold(term.toLowerCase());
  final w = fold(word.toLowerCase());
  if (t.length < 2 || w.isEmpty) return false;
  if (w.contains(t)) return true;
  final ct = canon(t);
  final cw = canon(w);
  if (ct == cw || (ct.length >= 3 && cw.contains(ct)) || (cw.length >= 3 && ct.contains(cw) && cw.length >= ct.length - 1)) return true;
  // A known name ("ওয়েবসাইট" = "website") matches by that name only — its
  // outline says nothing about other words ("অবস্থা").
  if (ct != t || cw != w) return false;
  final st = skeleton(ct);
  final sw = skeleton(cw);
  if (st.length < 2 || sw.length < 2) return false;
  // The outline is for one word written in two scripts ("ফেসবুক" ↔
  // "facebook"). Two Bengali words with the same few consonants are
  // usually different words ("অবস্থা" ↔ "ওয়েবসাইট"): only long outlines.
  final cross = _bengali.hasMatch(ct) != _bengali.hasMatch(cw);
  if (st == sw) return cross || st.length >= 4;
  return st.length >= (cross ? 4 : 5) && sw.length >= (cross ? 4 : 5) && _lev(st, sw) <= 1;
}
