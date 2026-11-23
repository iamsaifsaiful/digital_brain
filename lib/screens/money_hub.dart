// Owner, 22 Nov: "হিসাবের ইউআই আরো সুন্দর কর এবং আরো তথ্য যুক্ত কর" —
// আমার খাত (every part of the money on one page), অ্যাকাউন্ট (bank, mobile,
// card, cash), সাবস্ক্রিপশন, সামনের খরচ and the month's report on Home,
// and the eye that hides the amounts.
import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart' show cashOnHand, monthSums;
import '../logic/lang.dart';
import '../logic/ledger.dart' show totals;
import '../logic/money_more.dart';
import '../logic/upcoming.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/kit.dart' show AppCard, SectionHeading;
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_shell.dart' show goToTab, ShellTab;
import 'ledger_screen.dart' show MoneyPart, MoneyScreenState;
import 'money_more_screens.dart';

void _push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

// ───────────────────────── The eye ─────────────────────────

/// Whether the amounts are hidden (one switch for হিসাব and Home).
bool moneyHidden(BuildContext context) => BrainScope.of(context).flag('money_hidden');

/// [shown] as it is, or dots while the eye is closed.
String hid(BuildContext context, String shown) => moneyHidden(context) ? '৳ ••••' : shown;

/// The eye beside an amount: a tap hides every amount, another shows them.
class MoneyEye extends StatelessWidget {
  const MoneyEye({super.key, this.color, this.size = 20});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final off = brain.flag('money_hidden');
    return IconButton(
      key: const Key('money-eye'),
      tooltip: off ? tr('টাকা দেখান') : tr('টাকা লুকান'),
      visualDensity: VisualDensity.compact,
      onPressed: () => brain.setPref('money_hidden', !off),
      icon: Icon(off ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: size, color: color ?? C.muted),
    );
  }
}

String _daysText(DateTime d, DateTime now) {
  final n = dayOnly(d).difference(dayOnly(now)).inDays;
  if (n == 0) return tr('আজ');
  if (n == 1) return tr('আগামীকাল');
  if (n < 0) return trf('{0} দিন পার হয়েছে', [bnDigits(-n)]);
  return trf('{0} দিন পর', [bnDigits(n)]);
}

IconData accountIcon(AccountKind k) => switch (k) {
      AccountKind.cash => Icons.payments_outlined,
      AccountKind.bank => Icons.account_balance_outlined,
      AccountKind.card => Icons.credit_card_rounded,
      AccountKind.other => Icons.wallet_outlined,
      _ => Icons.phone_android_rounded,
    };

(Color, Color) accountColors(AccountKind k) => switch (k) {
      AccountKind.cash => (C.green, C.greenTint),
      AccountKind.bank => (C.blue, C.blueTint),
      AccountKind.card => (C.purple, C.purpleTint),
      AccountKind.other => (C.ochre, C.ochreTint),
      _ => (C.rose, C.roseTint),
    };

// ───────────────────────── আমার খাত ─────────────────────────

/// Every part of the money on one page: the balance on top, a card for
/// each খাত (a tap opens it), what is coming to pay, and the other tools.
class MoneyHubView extends StatelessWidget {
  const MoneyHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final month = monthSums(d.cash, now);
    final owe = totals(d.ledger.where((e) => e.projectId == null));
    final hasAccounts = d.accounts.isNotEmpty;
    final total = hasAccounts ? totalBalance(d) : (cashOnHand(d) ?? month.balance);
    final subs = d.subscriptions.where((s) => !s.paused).toList()..sort((a, b) => a.next.compareTo(b.next));
    final subMonth = subs.fold(0, (a, s) => a + s.perMonth);
    final saved = d.goals.fold(0, (a, g) => a + g.saved);
    final inst = d.installments.where((i) => i.left > 0).toList();
    final openProjects = d.projects.where((p) => !p.closed).length;
    final up = upcomingCosts(d, now, days: 30);
    void tab(MoneyPart p) => context.findAncestorStateOfType<MoneyScreenState>()?.show(p);
    final spentShare = month.income <= 0 ? (month.expense > 0 ? 1.0 : 0.0) : (month.expense / month.income).clamp(0.0, 1.0).toDouble();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // The balance (approved look of Home's money card, in the accent tint).
      Container(
        key: const Key('hub-balance'),
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 16),
        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(hasAccounts ? tr('সব অ্যাকাউন্টে মোট') : tr('এখন আছে'), style: body(13.5, color: C.muted2))),
            const MoneyEye(),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(hid(context, '${total < 0 ? '−' : ''}${taka(total.abs())}'), style: display(32, weight: 700, color: total < 0 ? C.red : C.ink, height: 1.2)),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => tab(MoneyPart.accounts),
            child: Text(
              hasAccounts ? trf('{0}টি অ্যাকাউন্ট · দেখুন', [bnDigits(d.accounts.length)]) : tr('ব্যাংক, বিকাশ, কার্ড যোগ করুন'),
              style: body(12.5, weight: FontWeight.w600, color: C.greenDark),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(children: [
              Expanded(child: _MiniFig(label: tr('এ মাসে আয়'), value: hid(context, taka(month.income)), icon: Icons.south_west_rounded, color: C.blue)),
              Expanded(child: _MiniFig(label: tr('এ মাসে খরচ'), value: hid(context, taka(month.expense)), icon: Icons.north_east_rounded, color: C.red)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      SectionTitle(tr('আমার খাত')),
      _KhatCard(
        key: const Key('khat-cash'),
        icon: Icons.swap_vert_rounded,
        fg: C.green,
        bg: C.greenTint,
        title: tr('আয়-ব্যয়'),
        value: hid(context, taka(month.expense)),
        sub: month.income > 0 ? trf('আয়ের {0}% খরচ হয়েছে', [bnDigits((spentShare * 100).round())]) : trf('{0}-এর খরচ', [monthName(now.month)]),
        bar: month.income > 0 || month.expense > 0 ? spentShare : null,
        barColor: spentShare > 0.9 ? C.red : C.green,
        wide: true,
        onTap: () => tab(MoneyPart.cash),
      ),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _KhatCard(
            key: const Key('khat-loans'),
            icon: Icons.handshake_outlined,
            fg: C.blue,
            bg: C.blueTint,
            title: tr('ধার-দেনা'),
            value: owe.receivable == 0 && owe.payable == 0 ? tr('কিছু নেই') : trf('পাব {0}', [hid(context, taka(owe.receivable))]),
            sub: owe.receivable == 0 && owe.payable == 0 ? tr('কেউ টাকা পাবে না') : trf('দেব {0}', [hid(context, taka(owe.payable))]),
            onTap: () => tab(MoneyPart.loans),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KhatCard(
            key: const Key('khat-subs'),
            icon: Icons.autorenew_rounded,
            fg: C.purple,
            bg: C.purpleTint,
            title: tr('সাবস্ক্রিপশন'),
            value: subs.isEmpty ? tr('যোগ করুন') : hid(context, taka(subMonth)),
            sub: subs.isEmpty ? tr('ইন্টারনেট, জিম, অ্যাপ') : trf('মাসে · {0}টি', [bnDigits(subs.length)]),
            onTap: () => _push(context, const SubscriptionsScreen()),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _KhatCard(
            key: const Key('khat-savings'),
            icon: Icons.savings_outlined,
            fg: C.teal,
            bg: C.tealTint,
            title: tr('সঞ্চয় ও কিস্তি'),
            value: d.goals.isEmpty && inst.isEmpty ? tr('যোগ করুন') : hid(context, taka(saved)),
            sub: inst.isEmpty ? (d.goals.isEmpty ? tr('লক্ষ্য, DPS, লোন') : tr('জমেছে')) : trf('জমেছে · {0}টি কিস্তি চলছে', [bnDigits(inst.length)]),
            onTap: () => _push(context, const SavingsScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KhatCard(
            key: const Key('khat-projects'),
            icon: Icons.folder_special_outlined,
            fg: C.ochre,
            bg: C.ochreTint,
            title: tr('আলাদা হিসাব'),
            value: openProjects == 0 ? tr('যোগ করুন') : trf('{0}টি চলছে', [bnDigits(openProjects)]),
            sub: tr('বিয়ে, বাড়ি, ভ্রমণ'),
            onTap: () => tab(MoneyPart.projects),
          ),
        ),
      ]),
      const SizedBox(height: 20),
      SectionTitle(tr('সামনের খরচ'), action: tr('সাবস্ক্রিপশন'), onAction: () => _push(context, const SubscriptionsScreen())),
      UpcomingList(items: up.take(4).toList(), now: now),
      const SizedBox(height: 20),
      SectionTitle(tr('আরও কাজে লাগে')),
      Row(children: [
        Expanded(child: _ToolTile(icon: Icons.insert_chart_outlined_rounded, label: tr('মাসের রিপোর্ট'), fg: C.green, bg: C.greenTint, onTap: () => _push(context, const ReportScreen()))),
        const SizedBox(width: 10),
        Expanded(child: _ToolTile(icon: Icons.pie_chart_outline_rounded, label: tr('খরচ বিশ্লেষণ'), fg: C.orange, bg: C.orangeTint, onTap: () => _push(context, const SpendHealthScreen()))),
        const SizedBox(width: 10),
        Expanded(child: _ToolTile(icon: Icons.call_split_rounded, label: tr('খরচ ভাগাভাগি'), fg: C.teal, bg: C.tealTint, onTap: () => _push(context, const SplitScreen()))),
      ]),
    ]);
  }
}

class _MiniFig extends StatelessWidget {
  const _MiniFig({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted2)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: body(15, weight: FontWeight.w700))),
          ]),
        ),
      ]);
}

/// One খাত on আমার খাত: its icon, name, main figure and a line under it.
class _KhatCard extends StatelessWidget {
  const _KhatCard(
      {super.key, required this.icon, required this.fg, required this.bg, required this.title, required this.value, required this.sub, required this.onTap, this.bar, this.barColor, this.wide = false});
  final IconData icon;
  final Color fg;
  final Color bg;
  final String title;
  final String value;
  final String sub;
  final VoidCallback onTap;
  final double? bar;
  final Color? barColor;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tile = Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg, size: 22));
    final texts = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: C.muted2)),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: display(19, weight: 700, height: 1.3))),
      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
    ]);
    return Panel(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: wide
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [tile, const SizedBox(width: 12), Expanded(child: texts), Icon(Icons.chevron_right_rounded, color: C.muted)]),
                  if (bar != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: bar, minHeight: 6, color: barColor, backgroundColor: C.surface2)),
                  ],
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [tile, const Spacer(), Icon(Icons.chevron_right_rounded, color: C.muted, size: 20)]),
                  const SizedBox(height: 10),
                  texts,
                ]),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.label, required this.fg, required this.bg, required this.onTap});
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: fg, size: 20)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, maxLines: 2, style: body(12, weight: FontWeight.w500, height: 1.25)),
            ]),
          ),
        ),
      );
}

// ───────────────────────── সামনের খরচ ─────────────────────────

/// The coming payments, each with its date, what it is and how much.
class UpcomingList extends StatelessWidget {
  const UpcomingList({super.key, required this.items, required this.now, this.home = false});
  final List<Upcoming> items;
  final DateTime now;
  final bool home;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final empty = Row(children: [
        Icon(Icons.event_available_outlined, color: C.green),
        const SizedBox(width: 10),
        Expanded(child: Text(tr('৩০ দিনে কোনো খরচ বাকি নেই। সাবস্ক্রিপশন, কিস্তি বা ফেরতের তারিখ দিলে এখানে আগে থেকে দেখাবে।'), style: body(13, color: C.muted, height: 1.45))),
      ]);
      return home
          ? AppCard(key: const Key('upcoming-empty'), onTap: () => _push(context, const SubscriptionsScreen()), child: empty)
          : Panel(key: const Key('upcoming-empty'), padding: const EdgeInsets.all(14), child: empty);
    }
    final total = items.fold(0, (a, u) => a + u.amount);
    final rows = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, u) in items.indexed) ...[
        if (i > 0) Divider(height: 1, color: C.line),
        _UpcomingRow(u: u, now: now),
      ],
      Divider(height: 1, color: C.line),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
        child: Row(children: [
          Expanded(child: Text(tr('এগুলোতে মোট লাগবে'), style: body(12.5, color: C.muted))),
          Text(hid(context, taka(total)), style: body(14.5, weight: FontWeight.w700)),
        ]),
      ),
    ]);
    return home
        ? AppCard(key: const Key('upcoming'), padding: const EdgeInsets.fromLTRB(12, 6, 12, 10), child: rows)
        : Panel(key: const Key('upcoming'), padding: const EdgeInsets.fromLTRB(12, 6, 12, 10), child: rows);
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.u, required this.now});
  final Upcoming u;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final n = dayOnly(u.date).difference(dayOnly(now)).inDays;
    final soon = n <= 3;
    final (kind, icon, fg) = switch (u.kind) {
      UpcomingKind.subscription => (tr('সাবস্ক্রিপশন'), Icons.autorenew_rounded, C.purple),
      UpcomingKind.installment => (tr('কিস্তি'), Icons.event_repeat_outlined, C.teal),
      UpcomingKind.loan => (tr('ধার শোধ'), Icons.handshake_outlined, C.blue),
    };
    return InkWell(
      onTap: () => switch (u.kind) {
        UpcomingKind.subscription => _push(context, const SubscriptionsScreen()),
        UpcomingKind.installment => _push(context, const SavingsScreen()),
        UpcomingKind.loan => goToTab(context, ShellTab.money, money: MoneyPart.loans),
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: soon ? C.warnBg : C.surface2, borderRadius: BorderRadius.circular(10), border: soon ? Border.all(color: C.warnBorder) : null),
            child: Column(children: [
              Text(bnDigits(u.date.day), style: body(16, weight: FontWeight.w700, color: soon ? C.warn : C.ink, height: 1.15)),
              Text(monthShort(u.date.month), style: body(10.5, color: soon ? C.warn : C.muted, height: 1.15)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w600)),
              Row(children: [
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 4),
                Flexible(child: Text('$kind · ${_daysText(u.date, now)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: n < 0 ? C.red : C.muted))),
              ]),
            ]),
          ),
          Text(hid(context, taka(u.amount)), style: body(15, weight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ───────────────────────── অ্যাকাউন্ট ─────────────────────────

/// The অ্যাকাউন্ট tab: the sum, then each account by its kind — what it
/// holds and what went in and out this month; moves between them under.
class AccountsView extends StatelessWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final total = totalBalance(d);
    final moves = [...d.transfers]..sort((a, b) => b.date.compareTo(a.date));
    String nameOf(String id) => accountLabel(d.accounts.firstWhere((a) => a.id == id, orElse: () => MoneyAccount(id: id, name: '?')));
    // In and out of each account this month.
    final inM = <String, int>{}, outM = <String, int>{};
    for (final e in d.cash) {
      if (e.accountId == null || e.projectId != null || e.date.year != now.year || e.date.month != now.month) continue;
      final m = e.kind == CashKind.income ? inM : outM;
      m[e.accountId!] = (m[e.accountId!] ?? 0) + e.amount;
    }
    final groups = <(String, List<AccountKind>)>[
      (tr('নগদ'), [AccountKind.cash]),
      (tr('মোবাইল ব্যাংকিং'), [AccountKind.bkash, AccountKind.nagad, AccountKind.rocket]),
      (tr('ব্যাংক'), [AccountKind.bank]),
      (tr('ক্রেডিট কার্ড'), [AccountKind.card]),
      (tr('অন্যান্য'), [AccountKind.other]),
    ];
    int sumOf(List<AccountKind> ks) => d.accounts.where((a) => ks.contains(a.kind)).fold(0, (s, a) => s + accountBalance(d, a));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        key: const Key('accounts-total'),
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text(tr('সব অ্যাকাউন্টে মোট'), style: body(13.5, color: C.muted))), const MoneyEye()]),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(hid(context, '${total < 0 ? '−' : ''}${taka(total.abs())}'), style: display(30, weight: 700, color: total < 0 ? C.red : C.ink, height: 1.2)),
          ),
          if (d.accounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (label, ks) in groups)
                if (d.accounts.any((a) => ks.contains(a.kind)))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: accountColors(ks.first).$2, borderRadius: BorderRadius.circular(20)),
                    child: Text('$label ${hid(context, taka(sumOf(ks)))}', style: body(12, weight: FontWeight.w600, color: accountColors(ks.first).$1)),
                  ),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: SecondaryButton(
            key: const Key('accounts-move'),
            label: tr('টাকা সরান'),
            icon: Icons.swap_horiz_rounded,
            height: 44,
            onPressed: () => moveMoney(context),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (d.accounts.isEmpty)
        EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: tr('নগদ, বিকাশ, ব্যাংক, কার্ড — আলাদা রাখুন'),
          text: tr('প্রতিটার এখনকার টাকা দিয়ে যোগ করুন। লেনদেন লেখার সময় কোন অ্যাকাউন্ট থেকে গেল বা এল, বেছে নিলে ব্যালেন্স নিজে মিলবে।'),
          action: tr('প্রথম অ্যাকাউন্ট যোগ'),
          onAction: () => editAccount(context, null),
        )
      else
        for (final (label, ks) in groups)
          if (d.accounts.any((a) => ks.contains(a.kind))) ...[
            SectionTitle(label),
            for (final a in d.accounts.where((a) => ks.contains(a.kind)))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AccountCard(account: a, balance: accountBalance(d, a), inMonth: inM[a.id] ?? 0, outMonth: outM[a.id] ?? 0),
              ),
            const SizedBox(height: 6),
          ],
      if (moves.isNotEmpty) ...[
        SectionTitle(tr('টাকা সরানো')),
        Panel(
          child: Rows(children: [
            for (final t in moves.take(10))
              ListRow(
                leading: Icon(Icons.swap_horiz_rounded, color: C.muted2),
                title: '${nameOf(t.from)} → ${nameOf(t.to)}',
                subtitle: '${shortDate(t.date)}${t.fee > 0 ? trf(' · চার্জ {0}', [taka(t.fee)]) : ''}',
                trailing: Text(taka(t.amount), style: body(15, weight: FontWeight.w600)),
                onTap: () async {
                  final pick = await editOrDelete(context);
                  if (!context.mounted) return;
                  if (pick == 'edit') await moveMoney(context, t);
                  if (pick == 'delete' && context.mounted && await confirmDialog(context, title: tr('মুছবেন?'), text: tr('এই টাকা সরানোর হিসাবটা মুছে যাবে।'), yes: tr('মুছুন'), danger: true)) {
                    await brain.deleteTransfer(t.id);
                  }
                },
              ),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      Text(tr('প্রতিটা লেনদেন কোনো না কোনো অ্যাকাউন্ট থেকে হয় — নগদ সবসময় থাকে। ক্রেডিট কার্ডে খরচ করলে কার্ডের দেনা বাড়ে।'), style: body(12.5, color: C.muted, height: 1.5)),
    ]);
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.balance, required this.inMonth, required this.outMonth});
  final MoneyAccount account;
  final int balance;
  final int inMonth;
  final int outMonth;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final (fg, bg) = accountColors(a.kind);
    final card = a.kind == AccountKind.card;
    final kindName = isEn ? a.kind.en : a.kind.bn;
    return Panel(
      key: Key('account-${a.id}'),
      child: InkWell(
        onTap: () => editAccount(context, a),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)), child: Icon(accountIcon(a.kind), color: fg)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(accountLabel(a), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700)),
                Text(
                  [
                    if (a.name.trim().isNotEmpty) kindName,
                    if (inMonth > 0) '+${hid(context, taka(inMonth))}',
                    if (outMonth > 0) '−${hid(context, taka(outMonth))}',
                    if (inMonth == 0 && outMonth == 0) tr('এ মাসে লেনদেন নেই'),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12, color: C.muted),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (card) Text(balance < 0 ? tr('দেনা') : tr('বাকি নেই'), style: body(11, color: C.muted)),
              Text(hid(context, '${balance < 0 && !card ? '−' : ''}${taka(balance.abs())}'),
                  style: display(17, weight: 700, color: balance < 0 ? (card ? C.purple : C.red) : C.ink)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── সাবস্ক্রিপশন ─────────────────────────

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final list = [...d.subscriptions]..sort((a, b) => (a.paused ? 1 : 0).compareTo(b.paused ? 1 : 0) != 0 ? (a.paused ? 1 : 0).compareTo(b.paused ? 1 : 0) : a.next.compareTo(b.next));
    final on = list.where((s) => !s.paused);
    final perMonth = on.fold(0, (a, s) => a + s.perMonth);
    return Scaffold(
      floatingActionButton: AddButton(key: const Key('sub-add'), label: tr('সাবস্ক্রিপশন যোগ করুন'), onPressed: () => editSubscription(context, null)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('সাবস্ক্রিপশন')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              Panel(
                padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [Expanded(child: Text(tr('মাসে মোট যায়'), style: body(13.5, color: C.muted))), const MoneyEye()]),
                  Text(hid(context, taka(perMonth)), style: display(30, weight: 700, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(trf('বছরে {0} · {1}টি চালু', [hid(context, taka(perMonth * 12)), bnDigits(on.length)]), style: body(12.5, color: C.muted)),
                ]),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                EmptyState(
                  icon: Icons.autorenew_rounded,
                  title: tr('প্রতি মাসে যা কাটে, এক জায়গায়'),
                  text: tr('ইন্টারনেট, ডিশ, জিম, নেটফ্লিক্স, মোবাইল প্যাকেজ — টাকা আর তারিখ দিন। দেওয়ার দিন আসার আগে হোমে দেখাবে, “দেওয়া হলো” চাপলে খরচে উঠবে।'),
                  action: tr('প্রথমটা যোগ করুন'),
                  onAction: () => editSubscription(context, null),
                )
              else
                for (final s in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _SubCard(sub: s, now: now)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.sub, required this.now});
  final Subscription sub;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final s = sub;
    final n = dayOnly(s.next).difference(dayOnly(now)).inDays;
    final soon = !s.paused && n <= 3;
    final acc = s.accountId == null ? null : brain.data.accounts.where((a) => a.id == s.accountId).firstOrNull;
    return Panel(
      key: Key('sub-${s.id}'),
      borderColor: soon ? C.warnBorder : null,
      child: InkWell(
        onTap: () => editSubscription(context, s),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: C.purpleTint, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(s.name.trim().isEmpty ? '?' : s.name.trim().characters.first.toUpperCase(), style: display(18, weight: 700, color: C.purple))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700, color: s.paused ? C.muted : C.ink)),
                  Text([isEn ? s.cycle.en : s.cycle.bn, if (acc != null) accountLabel(acc), if (s.paused) tr('বন্ধ আছে')].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                ]),
              ),
              Padding(padding: const EdgeInsets.only(right: 6), child: Text(hid(context, taka(s.amount)), style: display(17, weight: 700))),
            ]),
            if (!s.paused) ...[
              const SizedBox(height: 6),
              Divider(height: 1, color: C.line),
              Row(children: [
                Icon(Icons.event_outlined, size: 15, color: soon ? C.warn : C.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(trf('পরের তারিখ {0} · {1}', [shortDate(s.next), _daysText(s.next, now)]),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: soon ? FontWeight.w600 : FontWeight.w400, color: n < 0 ? C.red : (soon ? C.warn : C.muted))),
                ),
                TextButton.icon(
                  key: Key('sub-pay-${s.id}'),
                  onPressed: () async {
                    await brain.paySubscription(s);
                    if (context.mounted) toast(context, trf('{0} খরচে লিখে রাখলাম', [taka(s.amount)]));
                  },
                  icon: Icon(Icons.check_circle_outline_rounded, size: 18, color: C.green),
                  label: Text(tr('দেওয়া হলো'), style: body(13, weight: FontWeight.w600, color: C.green)),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// A new subscription, or [old] changed (or paused, or deleted).
Future<void> editSubscription(BuildContext context, Subscription? old) async {
  final brain = BrainScope.read(context);
  final now = brain.services.now();
  final name = TextEditingController(text: old?.name ?? '');
  final amount = TextEditingController(text: old == null ? '' : '${old.amount}');
  var cycle = old?.cycle ?? SubCycle.monthly;
  var next = old?.next ?? DateTime(now.year, now.month + (now.day > 5 ? 1 : 0), 5);
  var paused = old?.paused ?? false;
  String? accountId = old?.accountId ?? defaultAccountIdOf(brain.data);
  final ok = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(old == null ? tr('নতুন সাবস্ক্রিপশন') : tr('সাবস্ক্রিপশন বদলান'), style: display(20, weight: 700)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in [tr('ইন্টারনেট'), tr('ডিশ/কেবল'), tr('মোবাইল প্যাকেজ'), tr('নেটফ্লিক্স'), tr('ইউটিউব প্রিমিয়াম'), tr('জিম')])
                ActionChip(label: Text(t), onPressed: () => set(() => name.text = t)),
            ]),
            FieldLabel(tr('নাম')),
            TextField(key: const Key('sub-name'), textCapitalization: TextCapitalization.sentences, controller: name, decoration: InputDecoration(hintText: tr('যেমন: ইন্টারনেট বিল'))),
            FieldLabel(tr('কত টাকা')),
            TextField(key: const Key('sub-amount'), controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: tr('৳ '))),
            FieldLabel(tr('কতদিন পরপর')),
            ChoiceChips<SubCycle>(items: [for (final c in SubCycle.values) (c, isEn ? c.en : c.bn)], value: cycle, onChanged: (v) => set(() => cycle = v)),
            FieldLabel(tr('পরের তারিখ')),
            OutlinedButton.icon(
              onPressed: () async {
                final p = await showDatePicker(context: ctx, initialDate: next, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
                if (p != null) set(() => next = p);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(fullDate(next)),
            ),
            if (brain.data.accounts.isNotEmpty) ...[
              FieldLabel(tr('কোন অ্যাকাউন্ট থেকে')),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in brain.data.accounts)
                  ChoiceChip(
                    avatar: Icon(accountIcon(a.kind), size: 16),
                    label: Text(accountLabel(a), style: body(13)),
                    selected: accountId == a.id,
                    onSelected: (_) => set(() => accountId = a.id),
                  ),
              ]),
            ],
            if (old != null) ...[
              const SizedBox(height: 8),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: paused, onChanged: (v) => set(() => paused = v), title: Text(tr('আপাতত বন্ধ'), style: body(15))),
            ],
            const SizedBox(height: 14),
            PrimaryButton(label: tr('রাখুন'), onPressed: () => Navigator.pop(ctx, true)),
            if (old != null)
              TextButton(
                onPressed: () async {
                  await brain.deleteSubscription(old);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text(tr('মুছে ফেলুন'), style: body(15, weight: FontWeight.w600, color: C.red)),
              ),
          ]),
        ),
      ),
    ),
  );
  final a = readInt(amount.text) ?? 0;
  if (ok == true && name.text.trim().isNotEmpty && a > 0) {
    final base = old ?? Subscription(name: name.text.trim(), amount: a, next: next);
    await brain.saveSubscription(base.copyWith(name: name.text.trim(), amount: a, cycle: cycle, next: next, accountId: accountId, paused: paused));
  }
  name.dispose();
  amount.dispose();
}

String? defaultAccountIdOf(AppData d) => (d.accounts.where((a) => a.kind == AccountKind.cash).firstOrNull ?? d.accounts.firstOrNull)?.id;

// ───────────────────────── Home ─────────────────────────

/// সামনের খরচ on Home: the next few payments in 30 days.
class HomeUpcoming extends StatelessWidget {
  const HomeUpcoming({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final up = upcomingCosts(brain.data, now, days: 30);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('সামনের খরচ'), link: tr('সাবস্ক্রিপশন'), onLink: () => _push(context, const SubscriptionsScreen())),
      UpcomingList(items: up.take(4).toList(), now: now, home: true),
    ]);
  }
}

/// রিপোর্ট on Home: the month in a glance — income against spending, how
/// much was kept, the top খাত and last month beside it; "বিস্তারিত" opens
/// the whole report.
class HomeReport extends StatelessWidget {
  const HomeReport({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final r = monthReport(brain.data, DateTime(now.year, now.month));
    final palette = [C.green, C.blue, C.orange, C.purple];
    final top = r.byCategory.take(4).toList();
    final most = [r.income, r.expense].reduce((a, b) => a > b ? a : b);
    final kept = r.income <= 0 ? null : ((r.income - r.expense) * 100 / r.income).round();
    // Spent so far against last month by this same day.
    final lastSoFar = _lastMonthSoFar(brain.data, now);
    final change = lastSoFar <= 0 ? null : ((r.expense - lastSoFar) * 100 / lastSoFar).round();
    void open() => _push(context, const ReportScreen());

    Widget bar(String label, int v, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 44, child: Text(label, style: body(12.5, color: C.muted))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(value: most <= 0 ? 0 : v / most, minHeight: 10, color: c, backgroundColor: C.surface2),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 84, child: Text(hid(context, taka(v)), textAlign: TextAlign.right, style: body(13.5, weight: FontWeight.w700))),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('রিপোর্ট'), link: tr('বিস্তারিত'), onLink: open, linkKey: const Key('home-report-more')),
      AppCard(
        key: const Key('home-report'),
        onTap: open,
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(monthTitle(now), style: body(14, weight: FontWeight.w700))),
            const MoneyEye(),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              bar(tr('আয়'), r.income, C.blue),
              bar(tr('খরচ'), r.expense, C.red),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _Pill(
                    icon: Icons.savings_outlined,
                    text: kept == null ? tr('আয় লেখা নেই') : (kept >= 0 ? trf('আয়ের {0}% জমেছে', [bnDigits(kept)]) : trf('আয়ের চেয়ে {0}% বেশি খরচ', [bnDigits(-kept)])),
                    color: kept == null ? C.muted : (kept >= 0 ? C.green : C.red),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Pill(
                    icon: change == null ? Icons.history_rounded : (change <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded),
                    text: change == null ? tr('গত মাসের হিসাব নেই') : (change <= 0 ? trf('গত মাসের চেয়ে {0}% কম', [bnDigits(-change)]) : trf('গত মাসের চেয়ে {0}% বেশি', [bnDigits(change)])),
                    color: change == null ? C.muted : (change <= 0 ? C.green : C.warn),
                  ),
                ),
              ]),
              if (top.isNotEmpty && r.expense > 0) ...[
                const SizedBox(height: 12),
                Text(tr('বেশি খরচ যেখানে'), style: body(12.5, weight: FontWeight.w600, color: C.muted2)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final (i, e) in top.indexed) ...[
                        if (i > 0) const SizedBox(width: 2),
                        Expanded(flex: (e.value * 1000 ~/ r.expense).clamp(1, 1000), child: ColoredBox(color: palette[i])),
                      ],
                      if (top.fold(0, (a, e) => a + e.value) < r.expense) ...[
                        const SizedBox(width: 2),
                        Expanded(flex: ((r.expense - top.fold(0, (a, e) => a + e.value)) * 1000 ~/ r.expense).clamp(1, 1000), child: ColoredBox(color: C.line)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                for (final (i, e) in top.take(3).indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: palette[i], borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tr(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13))),
                      Text('${bnDigits((e.value * 100 / r.expense).round())}%', style: body(12.5, color: C.muted)),
                      const SizedBox(width: 10),
                      SizedBox(width: 72, child: Text(hid(context, taka(e.value)), textAlign: TextAlign.right, style: body(13, weight: FontWeight.w600))),
                    ]),
                  ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('home-report-open'),
                  onPressed: open,
                  icon: const Icon(Icons.insert_chart_outlined_rounded, size: 18),
                  label: Text(tr('বিস্তারিত রিপোর্ট')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

int _lastMonthSoFar(AppData d, DateTime now) {
  final last = DateTime(now.year, now.month - 1);
  var s = 0;
  for (final e in d.cash) {
    if (e.projectId != null || e.kind != CashKind.expense) continue;
    if (e.date.year == last.year && e.date.month == last.month && e.date.day <= now.day) s += e.amount;
  }
  return s;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Expanded(child: Text(text, maxLines: 2, style: body(11.5, weight: FontWeight.w600, color: color, height: 1.25))),
        ]),
      );
}
