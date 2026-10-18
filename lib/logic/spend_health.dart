/// Where the income goes: spending by খাত as a share of income, split into
/// needs, wants (spending that can be cut — eating out, shopping, outings)
/// and giving, against the common 50/30/20 guide (needs at most half,
/// wants at most 30%, at least 20% kept). Worked out on the phone from the
/// user's own records; nothing is guessed when a record is missing.
library;

import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';
import 'money_more.dart' show reportCategory;

enum SpendGroup { need, want, give, other }

/// Business costs (a shop's stock, wages, rent) are not household spending.
const _business = {'মাল কেনা', 'মজুরি', 'দোকান ভাড়া'};
const _wants = {'খাবার', 'কেনাকাটা', 'বেড়ানো', 'উপহার', 'ব্যক্তিগত'};
const _needs = {'বাজার', 'যাতায়াত', 'বাসা ভাড়া', 'বিল', 'মোবাইল', 'চিকিৎসা', 'শিক্ষা', 'কিস্তি-লোন'};
const _give = {'দান-সদকা'};

SpendGroup spendGroup(String category) {
  if (_needs.contains(category)) return SpendGroup.need;
  if (_wants.contains(category)) return SpendGroup.want;
  if (_give.contains(category)) return SpendGroup.give;
  return SpendGroup.other;
}

String groupName(SpendGroup g) => switch (g) {
      SpendGroup.need => tr('প্রয়োজনীয়'),
      SpendGroup.want => tr('শখের / কমানো যায়'),
      SpendGroup.give => tr('দান-সদকা'),
      SpendGroup.other => tr('খাত জানা নেই'),
    };

/// How each খাত is shown here: "খাবার" is mostly eating out and snacks
/// (the kitchen's shopping is বাজার).
String spendLabel(String category) => category == 'খাবার' ? tr('বাইরের খাবার-নাস্তা') : tr(category);

/// The guide: needs ≤ 50%, wants ≤ 30%, kept ≥ 20% of income.
const needCap = 50, wantCap = 30, keepGoal = 20;

class SpendShare {
  const SpendShare(this.category, this.amount, this.group);
  final String category;
  final int amount;
  final SpendGroup group;
}

class SpendHealth {
  SpendHealth({required this.days, required this.from, required this.income, required this.spent, required this.shares, required this.lastWants});

  /// 7 (this week) or 30 (this month).
  final int days;
  final DateTime from;

  /// Income for the period: for a week, the last 30 days' income scaled to
  /// 7 days (salary comes once a month); for 30 days, as it came.
  final int income;
  final int spent;

  /// Largest first.
  final List<SpendShare> shares;

  /// The period before's wants, to compare.
  final int lastWants;

  bool get hasIncome => income > 0;

  /// What the shares are of: income, or (none written) all spending.
  int get base => hasIncome ? income : spent;
  int pct(int x) => base <= 0 ? 0 : (x * 100 / base).round();
  int sum(SpendGroup g) => shares.where((s) => s.group == g).fold(0, (a, s) => a + s.amount);
  int get needs => sum(SpendGroup.need);
  int get wants => sum(SpendGroup.want);
  int get kept => income - spent;
  List<SpendShare> get wantShares => shares.where((s) => s.group == SpendGroup.want).toList();
}

SpendHealth spendHealth(AppData d, DateTime now, {int days = 7}) {
  final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final from = end.subtract(Duration(days: days));
  final lastFrom = from.subtract(Duration(days: days));
  final month = end.subtract(const Duration(days: 30));
  var income30 = 0, lastWants = 0;
  final by = <String, int>{};
  for (final e in d.cash) {
    if (e.projectId != null || e.shopId != null || !e.date.isBefore(end)) continue;
    if (e.kind == CashKind.income) {
      if (!e.date.isBefore(month)) income30 += e.amount;
      continue;
    }
    final cat = reportCategory(e);
    if (_business.contains(cat)) continue;
    if (!e.date.isBefore(from)) {
      by[cat] = (by[cat] ?? 0) + e.amount;
    } else if (!e.date.isBefore(lastFrom) && spendGroup(cat) == SpendGroup.want) {
      lastWants += e.amount;
    }
  }
  final shares = [for (final e in by.entries) SpendShare(e.key, e.value, spendGroup(e.key))]..sort((a, b) => b.amount.compareTo(a.amount));
  return SpendHealth(
    days: days,
    from: from,
    income: days >= 30 ? income30 : (income30 * days / 30).round(),
    spent: by.values.fold(0, (a, b) => a + b),
    shares: shares,
    lastWants: lastWants,
  );
}

String _noIncome() => tr('গত ৩০ দিনে কোনো আয় লেখা নেই, তাই ভাগগুলো মোট খরচের হিসেবে দেখাচ্ছি। আয় লিখলে আয়ের কত ভাগ কোথায় যাচ্ছে দেখাতে পারব।');

/// Plain advice, most important first.
List<String> spendAdvice(SpendHealth h) {
  final out = <String>[];
  if (h.spent == 0) return [tr('এই সময়ে কোনো খরচ লেখা নেই। খরচ লিখলে কোথায় কত যাচ্ছে দেখাতে পারব।')];
  if (!h.hasIncome) {
    out.add(_noIncome());
  }
  final wantPct = h.pct(h.wants);
  if (h.hasIncome && h.spent > h.income) {
    out.add(trf('আয়ের চেয়ে {0} বেশি খরচ হয়েছে — সঞ্চয় হচ্ছে না, উল্টো ঘাটতি।', [taka(h.spent - h.income)]));
  }
  if (h.hasIncome && wantPct > wantCap) {
    out.add(trf('শখের বা কমানো যায় এমন খরচে গেছে আয়ের {0}% — {1}%-এর মধ্যে রাখা ভালো।', [bnDigits(wantPct), bnDigits(wantCap)]));
  }
  for (final s in h.wantShares.take(3)) {
    final p = h.pct(s.amount);
    if (p < 10) continue;
    final tip = switch (s.category) {
      'খাবার' => tr('সপ্তাহে কয়েক দিন বাসা থেকে খাবার নিন'),
      'কেনাকাটা' => tr('কেনার আগে এক দিন অপেক্ষা করে দেখুন — সত্যিই দরকার কিনা'),
      'বেড়ানো' => tr('ঘোরাঘুরির একটা মাসিক সীমা ঠিক করুন'),
      _ => tr('এই খাতের একটা সীমা ঠিক করুন'),
    };
    out.add(h.hasIncome
        ? trf('{0} খাতে আয়ের {1}% ({2}) — অর্ধেক কমালেই {4} বাঁচবে। {3}।', [spendLabel(s.category), bnDigits(p), taka(s.amount), tip, taka(s.amount ~/ 2)])
        : trf('{0} খাতে খরচের {1}% ({2}) — অর্ধেক কমালেই {4} বাঁচবে। {3}।', [spendLabel(s.category), bnDigits(p), taka(s.amount), tip, taka(s.amount ~/ 2)]));
  }
  if (h.hasIncome && h.pct(h.needs) > needCap) {
    out.add(trf('প্রয়োজনীয় খরচই আয়ের {0}% — ভাড়া আর বিলগুলো দেখে কমানোর সুযোগ খুঁজুন।', [bnDigits(h.pct(h.needs))]));
  }
  if (h.hasIncome && h.kept >= 0) {
    final keep = h.pct(h.kept);
    out.add(keep >= keepGoal
        ? trf('আয়ের {0}% বেঁচে আছে — ভালো! এটা সঞ্চয়ে সরিয়ে রাখুন।', [bnDigits(keep)])
        : trf('আয়ের মাত্র {0}% বেঁচেছে — অন্তত {1}% রাখার চেষ্টা করুন।', [bnDigits(keep), bnDigits(keepGoal)]));
  }
  final unknown = h.sum(SpendGroup.other);
  if (unknown > 0 && h.pct(unknown) >= 10) {
    out.add(trf('{0} খরচের খাত লেখা নেই — খাত ঠিক করলে হিসাব আরও ঠিক হবে।', [taka(unknown)]));
  }
  if (h.lastWants > 0 && h.wants != h.lastWants) {
    final what = h.days >= 30 ? tr('আগের ৩০ দিনের') : tr('আগের সপ্তাহের');
    out.add(h.wants > h.lastWants
        ? trf('শখের খরচ {0} চেয়ে {1} বেশি।', [what, taka(h.wants - h.lastWants)])
        : trf('শখের খরচ {0} চেয়ে {1} কম — চমৎকার!', [what, taka(h.lastWants - h.wants)]));
  }
  return out;
}

/// The answer in the chat: "এ সপ্তাহে আয়ের ৬৮% খরচ…"
String spendHealthSaid(SpendHealth h) {
  final when = h.days >= 30 ? tr('গত ৩০ দিনে') : tr('গত ৭ দিনে');
  if (h.spent == 0) return trf('{0} কোনো খরচ লেখা নেই।', [when]);
  final of = h.hasIncome ? tr('আয়ের') : tr('খরচের');
  final parts = [
    for (final s in h.shares.take(4)) trf('{0} {1}%', [spendLabel(s.category), bnDigits(h.pct(s.amount))]),
  ];
  final head = h.hasIncome
      ? trf('{0} খরচ {1} — আয়ের {2}%। প্রয়োজনীয় খাতে {3}%, শখের/কমানো যায় এমন খাতে {4}% (ভালো হয়: প্রয়োজনে ৫০%, শখে ৩০%, সঞ্চয়ে ২০%)।',
          [when, taka(h.spent), bnDigits(h.pct(h.spent)), bnDigits(h.pct(h.needs)), bnDigits(h.pct(h.wants))])
      : trf('{0} খরচ {1}।', [when, taka(h.spent)]);
  final advice = spendAdvice(h).where((a) => a != _noIncome()).take(2).join(' ');
  return '$head ${trf('{0} ভাগ: {1}।', [of, parts.join(', ')])}${advice.isEmpty ? '' : ' $advice'}';
}
