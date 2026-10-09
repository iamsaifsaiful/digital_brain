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

  void add(CashEntry e) {
    if (e.kind == CashKind.income) {
      income += e.amount;
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
  'বাজার': ['বাজার', 'মাছ', 'মাংস', 'সবজি', 'চাল', 'ডাল', 'মুদি', 'গ্রোসারি', 'ডিম', 'দুধ'],
  'খাবার': ['খাবার', 'নাস্তা', 'রেস্টুরেন্ট', 'লাঞ্চ', 'ডিনার', 'খেলাম', 'বিরিয়ানি'],
  'যাতায়াত': ['রিকশা', 'বাস ভাড়া', 'সিএনজি', 'উবার', 'পাঠাও', 'ট্রেন', 'লঞ্চ', 'পেট্রোল', 'অকটেন', 'যাতায়াত', 'গাড়ি ভাড়া', 'ভাড়া গাড়ি'],
  'বাসা ভাড়া': ['বাসা ভাড়া', 'বাড়ি ভাড়া', 'ঘর ভাড়া', 'ফ্ল্যাট ভাড়া'],
  'দোকান ভাড়া': ['দোকান ভাড়া', 'অফিস ভাড়া'],
  'বিল': ['বিদ্যুৎ', 'কারেন্ট', 'গ্যাস', 'পানির বিল', 'ইন্টারনেট', 'ওয়াইফাই', 'wifi', 'বিল'],
  'মোবাইল': ['রিচার্জ', 'ফ্লেক্সি', 'মোবাইল'],
  'চিকিৎসা': ['ওষুধ', 'ঔষধ', 'ডাক্তার', 'হাসপাতাল', 'চিকিৎসা', 'টেস্ট'],
  'শিক্ষা': ['স্কুল', 'কলেজ', 'টিউশন', 'কোচিং', 'বই', 'পরীক্ষার ফি'],
  'কেনাকাটা': ['জামা', 'কাপড়', 'জুতা', 'শপিং', 'কেনাকাটা'],
  'মজুরি': ['মজুরি', 'কর্মচারী', 'স্টাফ', 'লেবার', 'মিস্ত্রি', 'বেতন দিলাম'],
  'মাল কেনা': ['মাল কিনলাম', 'মাল কেনা', 'পণ্য কিনলাম', 'স্টক'],
};

const _incomeCats = <String, List<String>>{
  'বেতন': ['বেতন', 'স্যালারি', 'salary'],
  'বিক্রি': ['বিক্রি', 'সেল'],
  'ভাড়া আয়': ['ভাড়া পেলাম', 'ভাড়া পাইছি', 'ভাড়া এসেছে'],
  'ব্যবসা': ['লাভ', 'ব্যবসা', 'কমিশন'],
};

const _incomeWords = [
  'পেলাম', 'পেয়েছি', 'পাইছি', 'পাইলাম', 'এসেছে', 'এলো', 'আসলো', 'আসছে', 'আয়', 'ইনকাম', 'income', 'বিক্রি করলাম', 'বিক্রি হলো',
  'বিক্রি হয়েছে', 'লাভ', 'জমা হলো', 'জমা হয়েছে', 'salary', 'বেতন পেলাম',
];
const _expenseWords = [
  'খরচ', 'কিনলাম', 'কিনেছি', 'কিনছি', 'কেনা', 'বিল', 'পেমেন্ট', 'payment', 'খেলাম', 'রিচার্জ', 'ভাড়া দিলাম', 'দিলাম', 'দিয়েছি', 'দিছি',
  'spent', 'cost', 'মজুরি', 'বাজার করলাম',
];

bool _has(String text, List<String> keys) => keys.any((k) => text.contains(normalize(k)));

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

/// Every খাত the user has used, then the usual ones.
List<String> knownCategories(AppData d, CashKind kind) {
  final used = <String>{for (final e in d.cash) if (e.kind == kind) e.category};
  return {...used, ...(kind == CashKind.income ? _incomeCats.keys : _expenseCats.keys)}.toList();
}
