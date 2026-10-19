/// Income and spending (monthly and per project), and the loan summary
/// split into "ধার দেওয়া" and "ঋণ নেওয়া".
library;

import '../models/models.dart';
import 'ledger.dart';
import 'parser.dart';

class MoneySums {
  int income = 0;
  int expense = 0;
  int get balance => income - expense;

  /// Spending per খাত, largest first when read through [topExpenses].
  final byCategory = <String, int>{};

  List<MapEntry<String, int>> get topExpenses => byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  /// Income per খাত, largest first.
  final incomeByCategory = <String, int>{};
  List<MapEntry<String, int>> get topIncome => incomeByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  void add(CashEntry e) {
    if (e.kind == CashKind.income) {
      income += e.amount;
      incomeByCategory[e.category] = (incomeByCategory[e.category] ?? 0) + e.amount;
    } else {
      expense += e.amount;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
  }
}

/// Personal (non-project) money in [month]'s calendar month.
MoneySums monthSums(Iterable<CashEntry> cash, DateTime month) {
  final s = MoneySums();
  for (final e in cash) {
    if (e.projectId == null && e.date.year == month.year && e.date.month == month.month) s.add(e);
  }
  return s;
}

MoneySums projectSums(Iterable<CashEntry> cash, String projectId) {
  final s = MoneySums();
  for (final e in cash) {
    if (e.projectId == projectId) s.add(e);
  }
  return s;
}

/// Money left across all open projects.
int openProjectsBalance(AppData d) {
  var total = 0;
  for (final p in d.projects.where((p) => !p.closed)) {
    total += projectSums(d.cash, p.id).balance;
  }
  return total;
}

Project? projectByName(AppData d, String name) {
  final n = normalize(name);
  if (n.isEmpty) return null;
  for (final p in d.projects) {
    if (normalize(p.name) == n) return p;
  }
  for (final p in d.projects) {
    final pn = normalize(p.name);
    if (pn.contains(n) || n.contains(pn)) return p;
  }
  return null;
}

/// "ধার দেওয়া": total lent, got back, still owed to the user;
/// "ঋণ নেওয়া": total borrowed, paid back, still to pay.
class LoanSummary {
  int lent = 0, received = 0, borrowed = 0, repaid = 0, receivable = 0, payable = 0;
}

LoanSummary loanSummary(Iterable<LedgerEntry> ledger) {
  final s = LoanSummary();
  for (final e in ledger) {
    switch (e.kind) {
      case LedgerKind.lent:
        s.lent += e.amount;
      case LedgerKind.received:
        s.received += e.amount;
      case LedgerKind.borrowed:
        s.borrowed += e.amount;
      case LedgerKind.repaid:
        s.repaid += e.amount;
    }
  }
  final t = totals(ledger);
  s.receivable = t.receivable;
  s.payable = t.payable;
  return s;
}

// ── Reading spending and income from speech ──

const _expenseCats = <String, List<String>>{
  'বাজার': ['বাজার', 'চা পাতা', 'চাপাতা', 'পেয়াজ', 'পিয়াজ', 'রসুন', 'আদা', 'লবণ', 'হ্যান্ডওয়াশ', 'ডিটারজেন্ট', 'টুথপেস্ট', 'মাছ', 'মাংস', 'সবজি', 'চাল', 'ডাল', 'মুদি', 'গ্রোসারি', 'ডিম', 'দুধ', 'মুরগি', 'গরুর', 'তেল', 'চিনি', 'আটা', 'পেঁয়াজ', 'আলু', 'ফল', 'সাবান', 'শ্যাম্পু'],
  'খাবার': ['খাবার', 'নাস্তা', 'চা', 'রুটি', 'পরোটা', 'সিংগাড়া', 'সিঙ্গাড়া', 'সিঙাড়া', 'সমুচা', 'পুরি', 'বিস্কুট', 'কেক', 'চটপটি', 'ঝালমুড়ি', 'জুস', 'কোক', 'পানি খেলাম', 'আইসক্রিম', 'ভাত', 'রেস্টুরেন্ট', 'লাঞ্চ', 'ডিনার', 'খেলাম', 'বিরিয়ানি', 'কফি', 'ফুচকা', 'হোটেল', 'পার্সেল খাবার', 'ফুডপান্ডা', 'foodpanda'],
  'যাতায়াত': ['রিকশা', 'রিক্সা', 'রিকসা', 'রিক্সা ভাড়া', 'বাস ভাড়া', 'সিএনজি', 'উবার', 'পাঠাও', 'ট্রেন', 'লঞ্চ', 'পেট্রোল', 'অকটেন', 'যাতায়াত', 'গাড়ি ভাড়া', 'ভাড়া গাড়ি'],
  'বাসা ভাড়া': ['বাসা ভাড়া', 'বাড়ি ভাড়া', 'ঘর ভাড়া', 'ফ্ল্যাট ভাড়া'],
  'দোকান ভাড়া': ['দোকান ভাড়া', 'অফিস ভাড়া'],
  'বিল': ['বিদ্যুৎ', 'কারেন্ট', 'গ্যাস', 'পানির বিল', 'ইন্টারনেট', 'ওয়াইফাই', 'wifi', 'বিল'],
  'মোবাইল': ['রিচার্জ', 'ফ্লেক্সি', 'মোবাইল'],
  'চিকিৎসা': ['ওষুধ', 'ঔষধ', 'ডাক্তার', 'হাসপাতাল', 'চিকিৎসা', 'টেস্ট', 'ক্লিনিক', 'ফার্মেসি', 'দাঁত'],
  'শিক্ষা': ['স্কুল', 'কলেজ', 'টিউশন', 'কোচিং', 'বই', 'পরীক্ষার ফি'],
  'কেনাকাটা': ['জামা', 'কাপড়', 'জুতা', 'শপিং', 'কেনাকাটা', 'শাড়ি', 'পাঞ্জাবি', 'ফার্নিচার', 'মোবাইল কিনলাম', 'দারাজ', 'daraz'],
  'দান-সদকা': ['দান', 'সদকা', 'যাকাত', 'মসজিদ', 'মাদ্রাসা', 'ফিতরা'],
  'উপহার': ['উপহার', 'গিফট', 'gift', 'সালামি'],
  'কিস্তি-লোন': ['কিস্তি', 'ইএমআই', 'emi', 'লোন শোধ', 'ঋণ শোধ'],
  'বেড়ানো': ['বেড়াতে', 'ট্যুর', 'tour', 'পিকনিক', 'সিনেমা'],
  'ব্যক্তিগত': ['সেলুন', 'চুল কাটা', 'পার্লার', 'লন্ড্রি', 'ধোপা'],
  'মজুরি': ['মজুরি', 'কর্মচারী', 'স্টাফ', 'লেবার', 'মিস্ত্রি', 'বেতন দিলাম'],
  'মাল কেনা': ['মাল কিনলাম', 'মাল কেনা', 'পণ্য কিনলাম', 'স্টক'],
};

const _incomeCats = <String, List<String>>{
  'বেতন': ['বেতন', 'স্যালারি', 'salary'],
  'রেমিট্যান্স': ['রেমিট্যান্স', 'রেমিটেন্স', 'বিদেশ থেকে', 'প্রবাস থেকে'],
  'বিক্রি': ['বিক্রি', 'সেল'],
  'ভাড়া আয়': ['ভাড়া পেলাম', 'ভাড়া পাইছি', 'ভাড়া এসেছে'],
  'ব্যবসা': ['লাভ', 'ব্যবসা', 'কমিশন'],
};

const _incomeWords = [
  'পেলাম', 'পেয়েছি', 'পাইছি', 'পাইলাম', 'এসেছে', 'এলো', 'আসলো', 'আসছে', 'আয়', 'ইনকাম', 'income', 'বিক্রি করলাম', 'বিক্রি হলো',
  'বিক্রি হয়েছে', 'লাভ', 'জমা হলো', 'জমা হয়েছে', 'salary', 'বেতন পেলাম',
  // Someone else gave it: "নাহিয়ান ২০০০ টাকা দিয়েছে বেতন হিসেবে".
  'দিয়েছে', 'দিয়েছে', 'দিয়ে গেছে', 'পাঠিয়েছে', 'পাঠিয়েছে', 'পাঠাইছে', 'পাঠাইসে', 'পাঠাইছেন', 'রেমিট্যান্স',
];
const _expenseWords = [
  'খরচ', 'কিনলাম', 'কিনেছি', 'কিনছি', 'কেনা', 'বিল', 'পেমেন্ট', 'payment', 'খেলাম', 'রিচার্জ', 'ভাড়া দিলাম', 'দিলাম', 'দিয়েছি', 'দিছি',
  'spent', 'cost', 'মজুরি', 'বাজার করলাম', 'বাজার করেছি', 'বাজার এনেছি', 'বাজার আনলাম', 'এনেছি', 'আনলাম',
];

/// A key of two letters or fewer ("চা") is a word of its own, so "চাল",
/// "চাকরি" or "চাবি" are not tea.
bool _has(String text, List<String> keys) => keys.any((k) {
      final n = normalize(k);
      if (n.runes.length > 2) return text.contains(n);
      return RegExp('(?:^|\\s)${RegExp.escape(n)}(?:\\s|\$)').hasMatch(text);
    });

/// What the money was for, in the user's words: "চা গেলাম ২০ টাকার" →
/// "চা", "মাছ কিনলাম ১২৫০ টাকার" → "মাছ". Empty when nothing short is left.
String cashItem(String said) {
  final drop = {
    for (final w in const [
      'টাকা', 'টাকার', 'টাকায়', 'টাকাতে', 'টাকাই', 'হাজার', 'শত', 'আজ', 'আজকে', 'সকালে', 'দুপুরে', 'বিকালে', 'বিকেলে', 'রাতে', 'সন্ধ্যায়',
      'গতকাল', 'কাল', 'কিনলাম', 'কিনেছি', 'কিনছি', 'কেনা', 'খরচ', 'করলাম', 'করেছি', 'হলো', 'হল', 'হয়েছে', 'দিলাম', 'দিছি', 'দিয়েছি',
      'খেলাম', 'গেলাম', 'গেল', 'এনেছি', 'আনলাম', 'বাবদ', 'জন্য', 'জন্যে', 'আর', 'ও', 'এবং', 'মোট', 'যুক্ত', 'কর', 'করো', 'লেখ', 'লিখ',
      'লিখো', 'রাখো', 'আমার', 'আমি', 'দিয়ে', 'একটা', 'একটু', 'প্রায়', 'মাত্র', 'দিয়েছে', 'দিয়েছে', 'দিল', 'দিলো', 'হিসেবে',
      'হিসাবে', 'এসেছে', 'এলো', 'পেলাম', 'পেয়েছি', 'পেয়েছি', 'পাঠিয়েছে', 'পাঠিয়েছে', 'পাঠাইছে', 'পাঠাইসে', 'পাঠাইছেন', 'বাবদ', 'থেকে', 'বিদেশ', 'প্রবাস', 'দান',
      // Where and how much, not what: "বাজারে পেয়াজ ৩ কেজি" is পেয়াজ.
      'বাজারে', 'দোকানে', 'কেজি', 'গ্রাম', 'লিটার', 'পিস', 'হালি', 'ডজন', 'প্যাকেট', 'বোতল', 'টা', 'টি', 'একটা', 'দুটা', 'দুইটা', 'দুটো', 'দুটি',
      'তিনটা', 'চারটা', 'পাঁচটা',
    ])
      normalize(w),
  };
  final t = normalize(said).replaceAll(RegExp(r'[0-9০-৯,.।:/-]+'), ' ');
  final ws = [for (final w in t.split(RegExp(r'\s+'))) if (w.isNotEmpty && !drop.contains(w)) w];
  if (ws.isEmpty || ws.length > 4) return '';
  return ws.join(' ');
}

/// Income, spending, or neither (null) — [text] is normalized.
CashKind? cashKindOf(String text) {
  final strongExpense = _has(text, const ['খরচ', 'কিনলাম', 'কিনেছি', 'বিল', 'পেমেন্ট', 'ভাড়া দিলাম', 'মজুরি', 'বেতন দিলাম']);
  if (!strongExpense && _has(text, _incomeWords)) return CashKind.income;
  if (_has(text, _expenseWords)) return CashKind.expense;
  return null;
}

String categoryFor(String text, CashKind kind) {
  final cats = kind == CashKind.income ? _incomeCats : _expenseCats;
  for (final e in cats.entries) {
    if (_has(text, e.value)) return e.key;
  }
  return kind == CashKind.income ? 'অন্যান্য আয়' : 'অন্যান্য';
}

/// The usual খাত names (spending and income), for reading them in questions.
final List<String> knownCategoryWords = [..._expenseCats.keys, ..._incomeCats.keys];

/// Every খাত the user has used, then the usual ones.
List<String> knownCategories(AppData d, CashKind kind) {
  final used = <String>{for (final e in d.cash) if (e.kind == kind) e.category};
  return {...used, ...(kind == CashKind.income ? _incomeCats.keys : _expenseCats.keys)}.toList();
}


/// The separate account (অন্যান্য হিসাব) [said] names. Null when none is
/// named — then the user is asked which one, even if there is only one.
Project? projectMeant(AppData d, String said) {
  final t = ' ${normalize(said)} ';
  final open = [for (final p in d.projects) if (!p.closed) p];
  // "বাড়ির মেরামত এ" names "বাড়ি মেরামত": each word of the name, with any ending.
  final said0 = words(normalize(said));
  bool names(Project p) {
    final ws = words(normalize(p.name));
    return ws.isNotEmpty && ws.every((w) => said0.any((x) => x.startsWith(w) && x.length - w.length <= 3));
  }
  final named = [for (final p in open) if (t.contains(normalize(p.name)) || names(p)) p];
  return named.length == 1 ? named.single : null;
}

/// Only the page is named ("অন্যান্য হিসাবে রাখো"), not which account.
bool projectPageNamed(String said) => RegExp(r'(?:অন্যান্য|আলাদা)\s+হিস(?:া|ে)ব|প্রজেক্ট|প্রকল্প').hasMatch(fold(normalize(said)));
