/// Where a new piece of information goes when it is not a password, a
/// contact, money or a date: into the category it matches, or a new one.
library;

import '../models/models.dart';
import 'parser.dart';
import 'search.dart' show score;

class CategoryGuess {
  const CategoryGuess(this.name, {required this.isNew});
  final String name;

  /// No note uses this category yet: it will be created.
  final bool isNew;
}

/// Topic → words that point to it.
const _topicsRaw = <String, List<String>>{
  'যানবাহন': ['গাড়ি', 'গাড়ির', 'বাইক', 'মোটরসাইকেল', 'সাইকেল', 'রেজিস্ট্রেশন নম্বর', 'ফিটনেস', 'ট্যাক্স টোকেন', 'তেল'],
  'স্বাস্থ্য': ['ওষুধ', 'ঔষধ', 'ডাক্তার', 'হাসপাতাল', 'প্রেসক্রিপশন', 'রক্তের গ্রুপ', 'ব্লাড গ্রুপ', 'টিকা', 'ডোজ'],
  'বিল': ['বিল', 'বিদ্যুৎ', 'গ্যাস', 'মিটার', 'ভাড়া', 'প্রিপেইড'],
  'ব্যাংক ও টাকা': ['ব্যাংক', 'অ্যাকাউন্ট নম্বর', 'একাউন্ট নম্বর', 'বিকাশ', 'নগদ', 'রকেট', 'কার্ড নম্বর', 'সঞ্চয়', 'এফডিআর', 'ডিপিএস'],
  'কাগজপত্র': ['পাসপোর্ট', 'এনআইডি', 'জাতীয় পরিচয়পত্র', 'আইডি কার্ড', 'দলিল', 'সার্টিফিকেট', 'লাইসেন্স', 'টিন', 'জন্ম নিবন্ধন'],
  'ঠিকানা': ['ঠিকানা', 'বাসা নম্বর', 'রোড নম্বর', 'ফ্ল্যাট', 'হোল্ডিং'],
  'জন্মদিন ও অনুষ্ঠান': ['জন্মদিন', 'বিবাহবার্ষিকী', 'বিয়ের', 'অনুষ্ঠান', 'দাওয়াত'],
  'কেনাকাটা': ['বাজার', 'কিনতে', 'কিনব', 'কেনাকাটা', 'লিস্ট', 'তালিকা', 'দোকান'],
  'জিনিস কোথায় রাখা': ['রাখা আছে', 'রেখেছি', 'আলমারি', 'ড্রয়ার', 'চাবি', 'তাকে', 'বাক্সে'],
  'কাজ': ['অফিস', 'মিটিং', 'প্রজেক্ট', 'ক্লায়েন্ট', 'ডেডলাইন'],
  'পড়াশোনা': ['পরীক্ষা', 'ক্লাস', 'রোল', 'রেজাল্ট', 'কোর্স'],
  'ডিভাইস': ['মোবাইল', 'ল্যাপটপ', 'আইএমইআই', 'imei', 'সিরিয়াল', 'ওয়ারেন্টি', 'চার্জার'],
};

/// Picks the category for [text]:
/// 1. an existing category whose name or notes share words with it;
/// 2. a known topic (যানবাহন, স্বাস্থ্য, বিল…);
/// 3. otherwise a new category named after the sentence's first main word.
CategoryGuess guessCategory(AppData d, String text) {
  final norm = normalize(text);
  final terms = searchTerms(norm);
  final existing = d.noteCategories;

  // 1. Existing categories.
  String? best;
  var bestScore = 0;
  for (final c in existing) {
    if (c == defaultNoteCategory) continue;
    var s = norm.contains(normalize(c)) ? 3 : 0;
    for (final n in d.notes.where((n) => n.category == c)) {
      s += score(terms, [n.title, n.body]);
    }
    s += score(terms, [c]) * 2;
    if (s > bestScore) {
      bestScore = s;
      best = c;
    }
  }
  if (best != null && bestScore >= 2) return CategoryGuess(best, isNew: false);

  // 2. Known topics. Single keywords must start a word ("বিল" must not
  // match inside another word); phrases may appear anywhere.
  final ws = words(norm);
  bool hit(String k) {
    final nk = normalize(k);
    return nk.contains(' ') ? norm.contains(nk) : ws.any((w) => w.startsWith(nk));
  }

  for (final e in _topicsRaw.entries) {
    if (e.value.any(hit)) {
      return CategoryGuess(e.key, isNew: !existing.contains(e.key));
    }
  }

  // 3. A new category from the first main word.
  final mains = terms.where((t) => !RegExp(r'^\d').hasMatch(t) && t.length >= 2).toList();
  if (mains.isEmpty) return CategoryGuess(defaultNoteCategory, isNew: !existing.contains(defaultNoteCategory));
  var name = mains.first;
  if (RegExp(r'^[a-z]').hasMatch(name)) name = name[0].toUpperCase() + name.substring(1);
  final match = existing.where((c) => normalize(c) == normalize(name)).firstOrNull;
  return CategoryGuess(match ?? name, isNew: match == null);
}

/// Title for a note made from a sentence: its first five words.
String noteTitleFrom(String text) {
  final w = text.trim().split(RegExp(r'\s+'));
  return w.take(5).join(' ') + (w.length > 5 ? '…' : '');
}
