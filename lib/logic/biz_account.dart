// ব্যবসার পুরো হিসাব (owner, 23 Nov: "হিসাবে কোন গড়মিল না থাকে"): the five
// sums now, how each came from where the business began, and the profit,
// loss and capital worked out from the same entries. Three ways round give
// the same capital, so the app can say "সব হিসাব মিলেছে" — or show where not.
import '../models/models.dart';
import 'bn.dart' show dayOnly;
import 'lang.dart' show tr;
import 'shop_logic.dart';

/// How much of sale [saleId]'s line [l] has been brought back already.
double returnedQty(ShopBook b, String saleId, SaleLine l) => b.customerReturns
    .where((r) => r.saleId == saleId)
    .expand((r) => r.lines)
    .where((x) => x.productId == l.productId && x.name == l.name)
    .fold(0.0, (s, x) => s + x.qty);

/// What a loan still owes: written in, plus taken, less paid back.
int loanDue(ShopBook b, Loan l) => b.loanMoves.where((m) => m.loanId == l.id).fold(l.opening, (s, m) => s + (m.take ? m.amount : -m.amount));

/// The five sums now, from the book as it stands.
BizSums bizSums(ShopBook b, Iterable<CashEntry> cash) => BizSums(
      cash: bizCashBalance(cash),
      stock: b.products.fold(0, (s, p) => s + p.value),
      dues: b.customers.fold(0, (s, c) => s + customerAccount(b, c).due),
      payable: b.dealers.fold(0, (s, d) => s + dealerAccount(b, d).due),
      loans: b.loans.fold(0, (s, l) => s + loanDue(b, l)),
    );

/// The ids of everything that moves the sums (kept in [BizStart.before]
/// when the business began in the app).
Set<String> bizEntryIds(ShopBook b, Iterable<CashEntry> cash) => {
      for (final e in cash) if (isBizCash(e)) e.id,
      for (final x in b.sales) x.id,
      for (final x in b.purchases) x.id,
      for (final x in b.collections) x.id,
      for (final x in b.payouts) x.id,
      for (final x in b.customerReturns) x.id,
      for (final x in b.supplierReturns) x.id,
      for (final x in b.loanMoves) x.id,
      for (final x in b.ownerMoves) x.id,
      for (final x in b.adjusts) x.id,
    };

/// The business's going over a stretch: every sale, purchase, payment and
/// cost in it, sorted into what the account page shows.
class BizFlows {
  // Profit and loss.
  int sales = 0; // all sales (cash, QR and credit)
  int salesPaid = 0; // of which paid when sold
  int salesCredit = 0; // of which on the customers' accounts
  int saleCount = 0;
  int returnsRefund = 0; // goods customers brought back: what they were charged
  int returnsCost = 0; // … and what those goods had cost
  int cost = 0; // what the goods sold had cost
  int lossOnSales = 0; // sold below cost
  int otherIncome = 0;
  int expenses = 0;
  int damaged = 0; // spoilt goods, at cost (written off, or brought back spoilt)
  int damagedOnShelf = 0; // … of which went bad on the shelf
  int ownerIn = 0;
  int ownerOut = 0;

  // Cash.
  int collected = 0;
  int purchasesPaid = 0;
  int dealersPaid = 0;
  int loanTaken = 0;
  int loanRepaid = 0;
  int refundsPaid = 0; // cash paid back on customers' returns
  int refundsGot = 0; // cash got back on returns to suppliers

  // Stock, dues, payable.
  int purchases = 0; // all goods bought, at cost
  int purchasesOwed = 0; // of which owed to the dealers
  int returnsBack = 0; // returned goods back on the shelf, at cost
  int supplierReturns = 0; // goods sent back to suppliers, at cost
  int supplierCredit = 0; // … taken off what is owed them
  int returnsOffDue = 0; // customers' returns taken off their dues

  // Corrections (what is not a sale, a purchase or a payment).
  BizSums adjust = const BizSums();
  int adjustCount = 0;

  /// Bought less sold: what the selling made, the loss on sales put back
  /// (it is shown as ক্ষতি).
  int get saleProfit => sales - returnsRefund - cost + returnsCost + lossOnSales;
  int get netProfit => saleProfit + otherIncome - expenses;

  /// ক্ষতি: sold below cost, and spoilt goods.
  int get loss => lossOnSales + damaged;

  /// A returned-goods' settling with a supplier that differs from their cost.
  int get supplierReturnGain => supplierCredit + refundsGot - supplierReturns;

  int get adjustCapital => adjust.capital + supplierReturnGain;

  /// How the capital moved.
  int get capitalChange => netProfit - loss + ownerIn - ownerOut + adjustCapital;

  /// How each sum moved.
  BizSums get change => BizSums(
        cash: salesPaid + collected + otherIncome + ownerIn + loanTaken + refundsGot - purchasesPaid - dealersPaid - expenses - loanRepaid - ownerOut - refundsPaid + adjust.cash,
        stock: purchases - cost + returnsBack - supplierReturns - damagedOnShelf + adjust.stock,
        dues: salesCredit - collected - returnsOffDue + adjust.dues,
        payable: purchasesOwed - dealersPaid - supplierCredit + adjust.payable,
        loans: loanTaken - loanRepaid + adjust.loans,
      );
}

/// The category of the cash written in when the business is started.
const startCashCategory = 'শুরুর হিসাব';

/// The going of everything [counts] (by id and when it happened).
BizFlows bizFlows(ShopBook b, Iterable<CashEntry> cashList, bool Function(String id, DateTime at) counts) {
  final f = BizFlows();
  final linked = <String>{};
  for (final s in b.sales) {
    if (s.cashId != null) linked.add(s.cashId!);
    if (!counts(s.id, s.at)) continue;
    f.saleCount++;
    f.sales += s.total;
    f.salesPaid += s.paidNow;
    f.salesCredit += s.due;
    final net = s.netLines;
    for (final (i, l) in s.lines.indexed) {
      f.cost += l.cost;
      final margin = (i < net.length ? net[i] : l.amount) - l.cost;
      if (margin < 0) f.lossOnSales += -margin;
    }
  }
  for (final r in b.customerReturns) {
    if (r.cashId != null) linked.add(r.cashId!);
    if (!counts(r.id, r.at)) continue;
    f.returnsRefund += r.refund;
    f.returnsCost += r.cost;
    if (r.damaged) {
      f.damaged += r.cost;
    } else {
      f.returnsBack += r.cost;
    }
    if (r.cash) {
      f.refundsPaid += r.refund;
    } else {
      f.returnsOffDue += r.refund;
    }
  }
  for (final p in b.purchases) {
    if (p.cashId != null) linked.add(p.cashId!);
    if (!counts(p.id, p.at)) continue;
    f.purchases += p.total;
    f.purchasesPaid += p.paid;
    f.purchasesOwed += p.owed;
  }
  for (final r in b.supplierReturns) {
    if (r.cashId != null) linked.add(r.cashId!);
    if (!counts(r.id, r.at)) continue;
    f.supplierReturns += r.cost;
    if (r.pay == ReturnPay.cash) {
      f.refundsGot += r.credit;
    } else {
      f.supplierCredit += r.credit;
    }
  }
  for (final x in b.collections) {
    if (x.cashId != null) linked.add(x.cashId!);
    if (counts(x.id, x.at)) f.collected += x.amount;
  }
  for (final x in b.payouts) {
    if (x.cashId != null) linked.add(x.cashId!);
    if (counts(x.id, x.at)) f.dealersPaid += x.amount;
  }
  for (final m in b.loanMoves) {
    if (m.cashId != null) linked.add(m.cashId!);
    if (!counts(m.id, m.at)) continue;
    if (m.take) {
      f.loanTaken += m.amount;
    } else {
      f.loanRepaid += m.amount;
    }
  }
  for (final m in b.ownerMoves) {
    if (m.cashId != null) linked.add(m.cashId!);
    if (!counts(m.id, m.at)) continue;
    if (m.inward) {
      f.ownerIn += m.amount;
    } else {
      f.ownerOut += m.amount;
    }
  }
  var adj = const BizSums();
  for (final a in b.adjusts) {
    if (!counts(a.id, a.at)) continue;
    if (a.damaged) {
      // Spoilt goods: the shelf's loss (any other part is a correction).
      f.damaged += -a.change.stock;
      f.damagedOnShelf += -a.change.stock;
      adj = adj + BizSums(cash: a.change.cash, dues: a.change.dues, payable: a.change.payable, loans: a.change.loans);
    } else {
      adj = adj + a.change;
      f.adjustCount++;
    }
  }
  f.adjust = adj;
  // The rest of the business's own money: costs, and other income.
  for (final e in cashList) {
    if (!isBizCash(e) || linked.contains(e.id) || !counts(e.id, e.date)) continue;
    // The cash written in at the start is where the business began, not
    // income or a cost of that day.
    if (e.category == startCashCategory) continue;
    if (e.kind == CashKind.income) {
      f.otherIncome += e.amount;
    } else {
      f.expenses += e.amount;
    }
  }
  return f;
}

/// The whole account: where the business began, how it went since, and the
/// sums now — with what does not add up, if anything.
class BizAccount {
  BizAccount({required this.start, required this.flows, required this.now});
  final BizStart start;
  final BizFlows flows;
  final BizSums now;

  /// Began + went = now, sum by sum (all zero when it adds up).
  BizSums get gap => now - (start.sums + flows.change);

  /// The capital by its sums equals the capital by its going.
  bool get adds => gap.isZero && now.capital == start.capital + flows.capitalChange;
}

/// Where the business began: the start kept, or — before the questions
/// were answered — an empty one, everything counted.
BizStart startOf(ShopBook b) => b.start ?? BizStart(at: DateTime(2000));

BizAccount bizAccount(ShopBook b, Iterable<CashEntry> cash) {
  final start = startOf(b);
  final flows = bizFlows(b, cash, (id, at) => !start.before.contains(id));
  return BizAccount(start: start, flows: flows, now: bizSums(b, cash));
}

/// The going over [from] … [to] (days, inclusive), whatever began when.
BizFlows bizFlowsBetween(ShopBook b, Iterable<CashEntry> cash, DateTime from, DateTime to) {
  final a = dayOnly(from), z = dayOnly(to).add(const Duration(days: 1));
  return bizFlows(b, cash, (id, at) => !at.isBefore(a) && at.isBefore(z));
}

/// This calendar month's going.
BizFlows bizMonth(ShopBook b, Iterable<CashEntry> cash, DateTime now) =>
    bizFlowsBetween(b, cash, DateTime(now.year, now.month), DateTime(now.year, now.month + 1, 0));

/// Today's going.
BizFlows bizToday(ShopBook b, Iterable<CashEntry> cash, DateTime now) => bizFlowsBetween(b, cash, now, now);

/// What kind of entry a [BizTx] is (its icon and colour on the list).
enum TxKind { sale, collect, purchase, payout, expense, income, owner, loan, returnIn, returnOut, damage, adjust }

/// One line of "সব লেনদেন": when, what, with whom, and the money it moved.
class BizTx {
  const BizTx({required this.id, required this.at, required this.kind, required this.title, this.party = '', required this.amount, this.cashIn = 0, this.cashOut = 0, this.left = 0, this.ref});
  final String id;
  final DateTime at;
  final TxKind kind;
  final String title;
  final String party;

  /// What it came to.
  final int amount;

  /// The cash it brought in or took out.
  final int cashIn;
  final int cashOut;

  /// Still owed on it (a sale's বাকি, a purchase's দেনা).
  final int left;

  /// The record behind it (a [Sale], [Purchase] …) to open.
  final Object? ref;
}

/// Every business entry, newest first.
List<BizTx> bizTransactions(ShopBook b, Iterable<CashEntry> cash) {
  final out = <BizTx>[];
  final linked = <String>{};
  for (final s in b.sales) {
    if (s.cashId != null) linked.add(s.cashId!);
    out.add(BizTx(id: s.id, at: s.at, kind: TxKind.sale, title: s.no > 0 ? 'বিক্রি · মেমো #${s.no}' : 'বিক্রি', party: s.customer, amount: s.total, cashIn: s.paidNow, left: s.due, ref: s));
  }
  for (final x in b.collections) {
    if (x.cashId != null) linked.add(x.cashId!);
    out.add(BizTx(id: x.id, at: x.at, kind: TxKind.collect, title: 'বকেয়া আদায়', party: customerById(b, x.party)?.name ?? '', amount: x.amount, cashIn: x.amount, ref: x));
  }
  for (final p in b.purchases) {
    if (p.cashId != null) linked.add(p.cashId!);
    out.add(BizTx(id: p.id, at: p.at, kind: TxKind.purchase, title: p.lines.isEmpty ? 'স্টক যোগ' : 'স্টক যোগ · ${p.lines.map((l) => l.name).take(2).join(', ')}', party: p.dealer, amount: p.total, cashOut: p.paid, left: p.owed, ref: p));
  }
  for (final x in b.payouts) {
    if (x.cashId != null) linked.add(x.cashId!);
    out.add(BizTx(id: x.id, at: x.at, kind: TxKind.payout, title: 'সাপ্লায়ারকে পরিশোধ', party: dealerById(b, x.party)?.name ?? '', amount: x.amount, cashOut: x.amount, ref: x));
  }
  for (final m in b.ownerMoves) {
    if (m.cashId != null) linked.add(m.cashId!);
    out.add(BizTx(id: m.id, at: m.at, kind: TxKind.owner, title: m.inward ? 'মালিকের জমা' : 'মালিক নিলেন', party: m.note, amount: m.amount, cashIn: m.inward ? m.amount : 0, cashOut: m.inward ? 0 : m.amount, ref: m));
  }
  for (final m in b.loanMoves) {
    if (m.cashId != null) linked.add(m.cashId!);
    final l = b.loans.where((x) => x.id == m.loanId).firstOrNull;
    out.add(BizTx(id: m.id, at: m.at, kind: TxKind.loan, title: m.take ? 'ঋণ নেওয়া' : 'ঋণের কিস্তি', party: l?.name ?? '', amount: m.amount, cashIn: m.take ? m.amount : 0, cashOut: m.take ? 0 : m.amount, ref: m));
  }
  for (final r in b.customerReturns) {
    if (r.cashId != null) linked.add(r.cashId!);
    out.add(BizTx(id: r.id, at: r.at, kind: TxKind.returnIn, title: r.saleNo > 0 ? 'মাল ফেরত · মেমো #${r.saleNo}' : 'মাল ফেরত', party: r.customer, amount: r.refund, cashOut: r.cash ? r.refund : 0, ref: r));
  }
  for (final r in b.supplierReturns) {
    if (r.cashId != null) linked.add(r.cashId!);
    out.add(BizTx(id: r.id, at: r.at, kind: TxKind.returnOut, title: 'সাপ্লায়ারকে ফেরত', party: r.dealer, amount: r.credit, cashIn: r.pay == ReturnPay.cash ? r.credit : 0, ref: r));
  }
  for (final a in b.adjusts) {
    if (a.damaged) out.add(BizTx(id: a.id, at: a.at, kind: TxKind.damage, title: a.why, amount: -a.change.stock, ref: a));
  }
  for (final e in cash) {
    if (!isBizCash(e) || linked.contains(e.id)) continue;
    final inc = e.kind == CashKind.income;
    if (e.category == startCashCategory) {
      out.add(BizTx(id: e.id, at: e.date, kind: TxKind.adjust, title: startCashCategory, party: e.note, amount: e.amount, cashIn: inc ? e.amount : 0, cashOut: inc ? 0 : e.amount, ref: e));
      continue;
    }
    out.add(BizTx(id: e.id, at: e.date, kind: inc ? TxKind.income : TxKind.expense, title: inc ? (e.category.isEmpty ? 'আয়' : e.category) : 'খরচ · ${e.category}', party: e.note, amount: e.amount, cashIn: inc ? e.amount : 0, cashOut: inc ? 0 : e.amount, ref: e));
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

/// What a customer owed when memo [s] was made, and from which earlier
/// memos (owner, 23 Nov: "আগের বকেয়া এবং তার মেমো নাম্বার, আপডেট মোট
/// বকেয়া"): everything charged and paid before it, payments clearing the
/// oldest first (the due written in at the start before any memo).
class MemoDue {
  const MemoDue({this.before = 0, this.memos = const [], this.opening = false, this.now = 0});

  /// Owed before this memo.
  final int before;

  /// The earlier memos (numbers) still open then, oldest first.
  final List<int> memos;

  /// Part of [before] is the old due written in at the start.
  final bool opening;

  /// This memo's own unpaid part.
  final int now;

  int get after => before + now;
}

MemoDue memoDue(ShopBook b, Sale s) {
  if (s.customerId.isEmpty) return MemoDue(now: s.due);
  final c = b.customers.where((x) => x.id == s.customerId).firstOrNull;
  if (c == null) return MemoDue(now: s.due);
  bool earlier(DateTime at, String id) => at.isBefore(s.at);
  final owed = <(int no, int left)>[
    if (c.opening > 0) (0, c.opening),
    for (final x in [for (final x in b.sales) if (x.customerId == c.id && x.id != s.id && x.due > 0 && (x.at.isBefore(s.at) || (x.at == s.at && x.no < s.no))) x]..sort((a, z) => a.at.compareTo(z.at))) (x.no, x.due),
  ];
  var paid = [
    for (final p in b.collections) if (p.party == c.id && earlier(p.at, p.id)) p.amount,
    for (final r in b.customerReturns) if (r.customerId == c.id && !r.cash && earlier(r.at, r.id)) r.refund,
  ].fold<int>(0, (a, x) => a + x);
  final left = <(int, int)>[];
  for (final (no, due) in owed) {
    final off = paid >= due ? due : paid;
    paid -= off;
    if (due - off > 0) left.add((no, due - off));
  }
  return MemoDue(
    before: left.fold(0, (a, x) => a + x.$2),
    memos: [for (final (no, _) in left) if (no > 0) no],
    opening: left.any((x) => x.$1 == 0),
    now: s.due,
  );
}

String _dt(DateTime d, String Function(String) digits) =>
    digits('${d.day}/${d.month}/${d.year}  ${d.hour % 12 == 0 ? 12 : d.hour % 12}:${'${d.minute}'.padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}');

String _memoList(List<int> nos, String Function(String) digits) => nos.length <= 4 ? nos.map((n) => '#${digits('$n')}').join(', ') : '${nos.take(3).map((n) => '#${digits('$n')}').join(', ')} +${digits('${nos.length - 3}')}';

/// The memo as a PDF (owner, 23 Nov: "প্রতিটি লেনদেনের সুন্দর PDF মেমো,
/// আগের বকেয়া ও তার মেমো নম্বর, আপডেট মোট বকেয়া"): the shop on top, the
/// buyer, the goods with rate, the sum, what was paid, then the customer's
/// due — before (with the memos it came from), this memo's, and the total.
Map<String, Object?> memoSpec(Sale s, ShopProfile profile, MemoDue d, {required String Function(int) taka, required String Function(String) digits, Customer? customer, Object? logo}) {
  final paidLabel = switch (s.pay) {
    SalePay.cash => 'নগদ',
    SalePay.qr => 'বিকাশ/QR',
    SalePay.credit => s.paidNow > 0 ? 'আংশিক' : 'বাকি',
  };
  return {
    'title': profile.name.isEmpty ? 'ক্যাশ মেমো' : profile.name,
    'subtitle': [
      if (profile.address.isNotEmpty) profile.address,
      if (profile.phone.isNotEmpty) 'মোবাইল: ${digits(profile.phone)}',
    ].join('\n'),
    if (logo != null) 'logo': logo,
    'page': [420, 595],
    'footer': profile.receiptNote.isNotEmpty ? profile.receiptNote : 'আবার আসবেন · ধন্যবাদ',
    'pageWord': 'পাতা',
    'bnDigits': true,
    'blocks': [
      {'t': 'h2', 'text': 'ক্যাশ মেমো  #${digits('${s.no}')}'},
      {
        't': 'kv',
        'rows': [
          ['তারিখ', _dt(s.at, digits)],
          if (s.customer.isNotEmpty) ['গ্রাহক', s.customer],
          if (customer != null && customer.phone.isNotEmpty) ['মোবাইল', digits(customer.phone)],
          ['পরিশোধ', paidLabel],
        ],
      },
      {
        't': 'table',
        'cols': ['#', 'পণ্য', 'পরিমাণ', 'দর', 'টাকা'],
        'w': [0.7, 4.2, 2.2, 1.6, 2.2],
        'a': ['l', 'l', 'r', 'r', 'r'],
        'rows': [
          for (final (i, l) in s.lines.indexed)
            [digits('${i + 1}'), l.name, '${digits(qtyText(l.qty))} ${tr(l.unit)}', l.qty > 0 ? digits('${(l.amount / l.qty).round()}') : '', taka(l.amount)],
          if (s.amountOnly > 0) [digits('1'), 'বিক্রি', '', '', taka(s.amountOnly)],
          ['', {'s': 'মোট', 'c': 'm'}, '', '', taka(s.subtotal)],
          if (s.discount > 0) ['', {'s': discountLabel(s, digits), 'c': 'g'}, '', '', {'s': '− ${taka(s.discount)}', 'c': 'g'}],
          ['', {'s': 'এই মেমো', 'b': true}, '', '', {'s': taka(s.total), 'b': true}],
          ['', {'s': 'পরিশোধ ($paidLabel)', 'c': 'm'}, '', '', taka(s.paidNow)],
          if (s.due > 0) ['', {'s': 'এই মেমোর বাকি', 'c': 'o'}, '', '', {'s': taka(s.due), 'c': 'o'}],
        ],
      },
      if (s.customerId.isNotEmpty && (d.before > 0 || d.now > 0))
        {
          't': 'table',
          'cols': ['বকেয়ার হিসাব', 'টাকা'],
          'w': [7, 3],
          'a': ['l', 'r'],
          'rows': [
            [
              d.before <= 0
                  ? 'আগের বকেয়া'
                  : 'আগের বকেয়া (${[if (d.opening) 'শুরুর বকেয়া', if (d.memos.isNotEmpty) 'মেমো ${_memoList(d.memos, digits)}'].join(' + ')})',
              taka(d.before),
            ],
            ['এই মেমোর বাকি', taka(d.now)],
            [
              {'s': 'মোট বকেয়া', 'b': true, 'c': 'o'},
              {'s': taka(d.after), 'b': true, 'c': 'o'},
            ],
          ],
        },
      {'t': 'p', 'text': '\n_______________                                   _______________\nগ্রাহকের সই                                              বিক্রেতার সই', 'muted': true},
    ],
  };
}

/// A return's memo ("#১২৬-ফ"): what came back, what it was worth, and how
/// it was settled.
Map<String, Object?> returnMemoSpec(CustomerReturn r, ShopProfile profile, {required String Function(int) taka, required String Function(String) digits, int? dueAfter, Object? logo}) => {
      'title': profile.name.isEmpty ? 'ফেরত মেমো' : profile.name,
      'subtitle': [
        if (profile.address.isNotEmpty) profile.address,
        if (profile.phone.isNotEmpty) 'মোবাইল: ${digits(profile.phone)}',
      ].join('\n'),
      if (logo != null) 'logo': logo,
      'page': [420, 595],
      'footer': profile.receiptNote.isNotEmpty ? profile.receiptNote : 'ধন্যবাদ',
      'pageWord': 'পাতা',
      'bnDigits': true,
      'blocks': [
        {'t': 'h2', 'text': 'ফেরত মেমো  #${digits('${r.saleNo}')}-ফ'},
        {
          't': 'kv',
          'rows': [
            ['তারিখ', _dt(r.at, digits)],
            ['মূল মেমো', '#${digits('${r.saleNo}')}'],
            if (r.customer.isNotEmpty) ['গ্রাহক', r.customer],
            ['মালের অবস্থা', r.damaged ? 'নষ্ট' : 'ভালো'],
            if (r.note.isNotEmpty) ['কারণ', r.note],
          ],
        },
        {
          't': 'table',
          'cols': ['পণ্য', 'পরিমাণ', 'টাকা'],
          'w': [5, 2.4, 2.6],
          'a': ['l', 'r', 'r'],
          'rows': [
            for (final l in r.lines) [l.name, '${digits(qtyText(l.qty))} ${tr(l.unit)}', taka(l.amount)],
            [
              {'s': r.cash ? 'নগদ ফেরত দেওয়া হলো' : 'বকেয়া থেকে কাটা হলো', 'b': true},
              '',
              {'s': taka(r.refund), 'b': true, 'c': 'g'},
            ],
            if (dueAfter != null) [{'s': 'এখন মোট বকেয়া', 'c': 'o', 'b': true}, '', {'s': taka(dueAfter), 'c': 'o', 'b': true}],
          ],
        },
      ],
    };
