// ব্যবসার পুরো হিসাব (owner, 23 Nov: "হিসাবে কোন গড়মিল না থাকে"): the five
// sums now, how each came from where the business began, and the profit,
// loss and capital worked out from the same entries. Three ways round give
// the same capital, so the app can say "সব হিসাব মিলেছে" — or show where not.
import '../models/models.dart';
import 'bn.dart' show dayOnly;
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
