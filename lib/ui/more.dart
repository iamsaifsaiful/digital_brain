import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../services/crypto.dart';
import '../state/hisab.dart';
import 'agent.dart';
import 'home.dart';
import 'kit.dart';
import '../core/lang.dart';
import 'lock_screen.dart';
import 'reports.dart';
import 'cash.dart';
import 'customers.dart';
import 'agent_app.dart' show NotesScreen;
import 'users.dart';
import '../state/agent_state.dart';
import 'txn.dart';

// ------------------------------------------------------------------ report

class ReportTab extends StatefulWidget {
  const ReportTab({super.key, required this.h});
  final Hisab h;

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  Period? _period;
  int _top = 0;

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h;
        final d = h.d;
        final now = h.now;
        if (!h.can('reports')) {
          return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
            Tx('রিপোর্ট', style: t(22, w: FontWeight.w700)),
            const SizedBox(height: 12),
            const Note('রিপোর্ট দেখার অনুমতি আপনার নেই। মূল এডমিনের কাছে চাইতে পারেন।', icon: Icons.lock_outline_rounded),
          ]);
        }
        final period = _period ?? Period.of('week', now);
        bool inP(DateTime t) => period.has(t);
        final daily = period.to.difference(period.from).inDays <= 8;
        final txns = d.txns.where((x) => !x.cancelled && inP(x.at)).toList();
        final sarSum = txns.fold<double>(0, (s, x) => s + x.sarAmount);
        final takaSum = txns.fold<double>(0, (s, x) => s + x.taka);
        final feeSum = txns.fold<double>(0, (s, x) => s + x.fee);
        final got = txns.fold<double>(0, (s, x) => s + x.sarPaid) + d.deposits.where((p) => inP(p.at)).fold<double>(0, (s, p) => s + p.sarAmount);
        final exp = d.expenses.where((e) => inP(e.at)).fold<double>(0, (s, e) => s + e.sarAmount);
        final paidAgent = d.agentPayments.where((p) => inP(p.at)).fold<double>(0, (s, p) => s + p.taka);
        final lost = d.losses.where((l) => inP(l.at)).fold<double>(0, (s, l) => s + l.sarAmount);
        final wrong = txns.where((x) => x.fault != null).length;
        final avgRate = sarSum == 0 ? 0.0 : takaSum / sarSum;
        // Chart: riyal per day for 7 days, or per month for 6 months.
        final List<DateTime> buckets;
        final List<String> labels;
        if (daily) {
          final end = period.isAll || period.to.isAfter(now) ? now : period.to.subtract(const Duration(days: 1));
          buckets = [for (var i = 6; i >= 0; i--) DateTime(end.year, end.month, end.day - i)];
          labels = [for (final b in buckets) bn('${b.day}')];
        } else {
          buckets = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
          labels = [for (final b in buckets) monthShort(b.month)];
        }
        final vals = [
          for (final b in buckets) d.txns.where((x) => !x.cancelled && (daily ? sameDay(x.at, b) : x.at.year == b.year && x.at.month == b.month)).fold<double>(0, (s, x) => s + x.sarAmount),
        ];
        Widget tile(String label, String value, {Color c = K.ink}) => Expanded(
              child: CardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx(label, style: t(12.5, c: K.muted)),
                  const SizedBox(height: 4),
                  Tx(value, style: t(16, w: FontWeight.w700, c: c), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
          Row(children: [
            Expanded(child: Tx('রিপোর্ট', style: t(22, w: FontWeight.w700))),
            CircleBtn(icon: Icons.picture_as_pdf_outlined, label: 'রিপোর্ট PDF', onTap: () => sharePdf(context, h, periodPdf(h, period), 'report')),
            const SizedBox(width: 8),
            CircleBtn(
              icon: Icons.file_download_outlined,
              label: 'CSV (এক্সেল) ফাইল',
              onTap: () async {
                final csv = '﻿${txnsCsv(d)}';
                await h.s.device.shareFile(Uint8List.fromList(utf8.encode(csv)), 'riyal-hisab-${now.year}-${now.month}-${now.day}.csv', 'text/csv');
                await h.note('sys', 'CSV ফাইল বানানো', '${bn('${d.txns.length}')} লেনদেন');
              },
            ),
          ]),
          const SizedBox(height: 12),
          PeriodChips(value: period, now: now, wrap: true, onChanged: (p) => setState(() => _period = p)),
          const SizedBox(height: 12),
          CardBox(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx('মোট পাঠানো', style: t(13, c: K.muted)),
              Tx(sar(sarSum), style: t(28, w: FontWeight.w700)),
              Tx('${taka(takaSum)} · ${bn('${txns.length}')}টা লেনদেন · গড় রেট ${rateText(avgRate)}', style: t(12.5, c: K.muted)),
              const SizedBox(height: 14),
              LineChart(values: vals, labels: labels, caption: 'সময় ধরে পাঠানো রিয়াল', markLabel: sar(vals.isEmpty ? 0 : vals.reduce((a, b) => a > b ? a : b))),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [tile('রিয়াল হাতে পেলাম', sar(got), c: K.green), const SizedBox(width: 10), tile('খরচ / বের', sar(exp), c: K.red)]),
          const SizedBox(height: 10),
          Row(children: [tile('এজেন্টকে দিলাম', taka(paidAgent)), const SizedBox(width: 10), tile('গ্রাহকদের খরচ (টাকা)', taka(feeSum))]),
          const SizedBox(height: 10),
          Row(children: [tile('লস (আদায় হবে না)', sar(lost), c: lost > 0 ? K.red : K.ink), const SizedBox(width: 10), tile('ভুল নম্বরে গেছে', '${bn('$wrong')}টা', c: wrong > 0 ? K.red : K.ink)]),
          const SizedBox(height: 10),
          Row(children: [tile('এখন মোট বাকি', sar(totalCustomerDue(d)), c: K.red), const SizedBox(width: 10), tile('হাতে থাকা উচিত', sar(cashInHand(d)))]),
          const SizedBox(height: 6),
          SectionHead('গ্রাহকদের তালিকা'),
          Seg<int>(items: const [(0, 'বেশি পাঠান'), (1, 'বেশি নগদ দেন'), (2, 'বেশি বাকি')], value: _top, onChanged: (v) => setState(() => _top = v)),
          const SizedBox(height: 8),
          ..._topList(h, period),
          const SizedBox(height: 12),
          SoftPill(label: 'সব লেনদেন দেখুন', icon: Icons.list_alt_rounded, onTap: () => push(context, AllTxnsScreen(h: h))),
          const SizedBox(height: 8),
          SoftPill(label: 'এই সময়ের পুরো রিপোর্ট PDF', icon: Icons.picture_as_pdf_outlined, onTap: () => sharePdf(context, h, periodPdf(h, period), 'report')),
        ]);
      });

  List<Widget> _topList(Hisab h, Period period) {
    final rows = topCustomers(h.d, _top, period.has, h.now);
    if (rows.isEmpty) return [Note(_top == 2 ? 'কারও কাছে বাকি নেই।' : 'এই সময়ে কিছু নেই।')];
    return [
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: [
          for (final (i, r) in rows.take(10).indexed)
            Row2(
              lead: dotLetter(bn('${i + 1}'), i < 3 ? K.navy : K.chip, i < 3 ? Colors.white : K.ink, size: 36),
              title: r.$1.name,
              sub: r.$3,
              value: sar(r.$2),
              valueColor: _top == 2 ? K.red : (_top == 1 ? K.green : K.ink),
              last: i == rows.take(10).length - 1,
              onTap: () => push(context, CustomerScreen(h: h, id: r.$1.id)),
            ),
        ]),
      ),
    ];
  }
}

/// Top customers: 0 most riyal sent, 1 most riyal paid in cash (at the
/// send and deposits), 2 most owed now. (customer, riyal, detail).
List<(Customer, double, String)> topCustomers(AppData d, int which, bool Function(DateTime) inP, DateTime now) {
  final out = <(Customer, double, String)>[];
  for (final c in d.customers) {
    final txns = d.txns.where((t) => t.customerId == c.id && !t.cancelled && inP(t.at)).toList();
    switch (which) {
      case 0:
        final v = txns.fold<double>(0, (s, t) => s + t.sarAmount);
        if (v > 0) out.add((c, v, '${bn('${txns.length}')}বার · ${taka(txns.fold<double>(0, (s, t) => s + t.taka))}'));
      case 1:
        final paid = txns.fold<double>(0, (s, t) => s + t.sarPaid);
        final dep = d.deposits.where((p) => p.customerId == c.id && inP(p.at)).fold<double>(0, (s, p) => s + p.sarAmount);
        if (paid + dep > 0) out.add((c, paid + dep, 'পাঠানোর সময় ${sar(paid)} · পরে জমা ${sar(dep)}'));
      default:
        final due = customerDue(d, c.id);
        final days = oldestDueDays(d, c.id, now) ?? 0;
        if (due > 0) out.add((c, due, days > 0 ? '${bn('$days')} দিন ধরে' : 'আজকের'));
    }
  }
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return out;
}

// ------------------------------------------------------------------ others

/// অন্যান্য: everything that is not daily work on the home page.
class OthersTab extends StatelessWidget {
  const OthersTab({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final d = h.d;
        final wrong = d.txns.where((x) => x.fault != null && !x.cancelled).length;
        final promises = d.customers.where((c) => c.promiseAt != null && customerDue(d, c.id) > 0).length;
        final backupOld = d.settings.lastBackup == null || h.now.difference(d.settings.lastBackup!).inDays >= 7;
        Widget tile(IconData i, Color bg, Color fg, String title, String sub, VoidCallback onTap, {bool last = false}) => Row2(
              lead: dotIcon(i, bg, fg, size: 40),
              title: title,
              sub: sub,
              onTap: onTap,
              last: last,
              value: '›',
              valueColor: K.muted,
            );
        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
          Row(children: [
            Expanded(child: Tx('অন্যান্য', style: t(22, w: FontWeight.w700))),
            LangButton(h: h),
          ]),
          const SizedBox(height: 12),
          if (h.session != null) ...[
            CardBox(
              child: Row(children: [
                dotIcon(h.session!.isOwner ? Icons.verified_user_rounded : Icons.admin_panel_settings_rounded, K.blueTint, K.blue, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx(h.session!.name, style: t(16, w: FontWeight.w600)),
                    Tx('${h.session!.isOwner ? 'মূল এডমিন' : 'এডমিন'} · ${bn(h.session!.login)}', style: t(12.5, c: K.muted)),
                  ]),
                ),
                SyncBadge(h: h),
              ]),
            ),
            const SizedBox(height: 4),
          ],
          if (h.can('expense')) ...[
            SectionHead('দিনের হিসাব'),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                tile(Icons.receipt_long_outlined, K.redTint, K.red, 'খরচ / রিয়াল বের', 'হাত থেকে যে রিয়াল বের হলো', () => push(context, ExpenseScreen(h: h))),
                tile(Icons.nightlight_outlined, K.navySoft, K.navy, 'দিন শেষের হিসাব', 'হাতের রিয়াল গুনে মিলিয়ে রাখুন', () => push(context, DayCloseScreen(h: h)), last: true),
              ]),
            ),
          ],
          SectionHead('লেনদেন'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              tile(Icons.account_balance_wallet_outlined, K.greenTint, K.green, h.isOwner ? 'এডমিনদের হাতের হিসাব' : 'আমার হাতের হিসাব', 'প্রতিদিনের রিয়াল আসা-যাওয়া, কালেকশন বুঝে নেওয়া', () => push(context, CashScreen(h: h))),
              tile(Icons.list_alt_rounded, K.blueTint, K.blue, 'সব লেনদেন', 'তারিখ দিয়ে খুঁজুন, PDF', () => push(context, AllTxnsScreen(h: h))),
              tile(Icons.report_gmailerrorred_rounded, K.redTint, K.red, 'ভুল নম্বরে যাওয়া', wrong == 0 ? 'নেই' : '${bn('$wrong')}টা লেনদেন',
                  () => push(context, AllTxnsScreen(h: h, filter: 4, title: 'ভুল নম্বরে যাওয়া'))),
              tile(Icons.phone_android_rounded, K.blueTint, K.blue, 'রিচার্জ ও এমবি', 'মোবাইল রিচার্জ আর এমবি প্যাক', () => push(context, AllTxnsScreen(h: h, filter: 5, title: 'রিচার্জ ও এমবি')),
                  last: true),
            ]),
          ),
          SectionHead('গ্রাহকের বাকি'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              tile(Icons.notifications_active_outlined, K.amberTint, K.amberText, 'তাগাদার তালিকা', promises == 0 ? 'কোনো তারিখ দেওয়া নেই' : '${bn('$promises')} জনের তারিখ দেওয়া',
                  () => push(context, PromisesScreen(h: h))),
              tile(Icons.money_off_rounded, K.redTint, K.red, 'লস (আদায় হবে না)', lossOf(d) > 0 ? 'মোট ${sar(lossOf(d))}' : 'নেই', () => push(context, LossScreen(h: h)), last: true),
            ]),
          ),
          SectionHead('রেকর্ড ও নিরাপত্তা'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              if (h.session != null) tile(Icons.notifications_rounded, K.amberTint, K.amberText, 'নোটিফিকেশন', 'এজেন্টরা কী জানালেন', () => push(context, NotesScreen(st: AgentState(h)))),
              if (h.can('users')) tile(Icons.manage_accounts_rounded, K.blueTint, K.blue, 'লগইন ও অনুমতি', 'এডমিন ও এজেন্টের লগইন, কে কী করতে পারবেন', () => push(context, UsersScreen(h: h))),
              if (h.can('reports')) tile(Icons.history_rounded, K.chip, K.ink, 'কাজের লগ', 'কখন কী হয়েছে, PDF', () => push(context, LogScreen(h: h))),
              tile(Icons.chat_outlined, K.greenTint, K.green, 'মেসেজের টেমপ্লেট', 'এজেন্ট ও গ্রাহককে যাওয়া মেসেজের লেখা', () => push(context, TemplatesScreen(h: h))),
              tile(Icons.settings_outlined, K.chip, K.ink, 'সেটিংস', 'পিন, আঙুলের ছাপ, এজেন্ট, বাকির সীমা', () => push(context, SettingsScreen(h: h))),
              if (h.can('settings'))
                tile(Icons.cloud_upload_outlined, backupOld ? K.redTint : K.blueTint, backupOld ? K.red : K.blue, 'ব্যাকআপ', backupOld ? 'ব্যাকআপ নেওয়া দরকার' : 'ব্যাকআপ ফাইল বানান বা ফিরিয়ে আনুন', () => push(context, BackupScreen(h: h)),
                    last: h.session == null),
              if (h.session != null)
                tile(Icons.logout_rounded, K.redTint, K.red, 'লগআউট', 'এই ফোন থেকে বের হন (হিসাব সার্ভারে থাকবে)', () async {
                  if (await confirm(context, 'লগআউট করবেন?', 'হিসাব সার্ভারে থাকবে। এই ফোনের কপি মুছে যাবে, আবার লগইন করলে ফিরে আসবে।', yes: 'লগআউট', danger: true)) {
                    await h.sync();
                    await h.logout();
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                }, last: true),
            ]),
          ),
        ]);
      });
}

/// Customers who said when they would pay.
class PromisesScreen extends StatelessWidget {
  const PromisesScreen({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final list = h.d.customers.where((c) => c.promiseAt != null && customerDue(h.d, c.id) > 0).toList()..sort((a, b) => a.promiseAt!.compareTo(b.promiseAt!));
        return Screen(
          title: 'তাগাদার তালিকা',
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
            if (list.isEmpty) const Note('কোনো গ্রাহকের বাকি ফেরতের তারিখ দেওয়া নেই। গ্রাহকের পাতায় "তারিখ দিন" চাপুন।'),
            if (list.isNotEmpty)
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, c) in list.indexed)
                    Row2(
                      lead: Avatar(h: h, name: c.name, photo: c.photo, size: 42),
                      title: c.name,
                      sub: '${dayLabel(c.promiseAt!, h.now)}, ${timeText(c.promiseAt!)}${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}',
                      subColor: c.promiseAt!.isAfter(h.now) ? K.muted : K.amberText,
                      value: sar(customerDue(h.d, c.id)),
                      valueColor: K.red,
                      valueSub: c.promiseAt!.isAfter(h.now) ? 'সামনে' : 'দিন এসেছে',
                      valueSubColor: c.promiseAt!.isAfter(h.now) ? K.muted : K.amberText,
                      last: i == list.length - 1,
                      onTap: () => push(context, CustomerScreen(h: h, id: c.id)),
                    ),
                ]),
              ),
          ]),
        );
      });
}

/// Riyal that will not come back.
class LossScreen extends StatelessWidget {
  const LossScreen({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final list = [...h.d.losses]..sort((a, b) => b.at.compareTo(a.at));
        return Screen(
          title: 'লস (আদায় হবে না)',
          trailing: CircleBtn(icon: Icons.picture_as_pdf_outlined, label: 'লস PDF', onTap: () => sharePdf(context, h, lossPdf(h), 'loss')),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
            CardBox(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Tx('মোট লস', style: t(13, c: K.muted)),
                Tx(sar(lossOf(h.d)), style: t(28, w: FontWeight.w700, c: K.red)),
              ]),
            ),
            const SizedBox(height: 10),
            const Note('গ্রাহক টাকা না দিয়ে চলে গেলে তাঁর পাতায় "আদায় হবে না (লস)" চাপুন। বাকি থেকে বাদ যাবে, এখানে আর রিপোর্টে লস হিসেবে থাকবে।'),
            const SizedBox(height: 10),
            if (list.isNotEmpty)
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, l) in list.indexed)
                    Row2(
                      lead: dotIcon(Icons.money_off_rounded, K.redTint, K.red, size: 40),
                      title: customerById(h.d, l.customerId)?.name ?? '',
                      sub: '${dateShort(l.at)} ${bn('${l.at.year}')}${l.note.isEmpty ? '' : ' · ${l.note}'}',
                      value: sar(l.sarAmount),
                      valueColor: K.red,
                      last: i == list.length - 1,
                      onTap: () => push(context, CustomerScreen(h: h, id: l.customerId)),
                    ),
                ]),
              ),
          ]),
        );
      });
}

// ---------------------------------------------------------------- day close

class DayCloseScreen extends StatefulWidget {
  const DayCloseScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends State<DayCloseScreen> {
  final _counted = TextEditingController();
  final _note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final expected = h.myCash;
    final counted = parseNum(_counted.text);
    final diff = counted == null ? null : counted - expected;
    final closes = [...h.d.closes]..sort((a, b) => b.at.compareTo(a.at));
    return Screen(
      title: 'দিন শেষের হিসাব',
      bottom: Pill(
        label: 'হিসাব মিলিয়ে রাখুন',
        onTap: counted == null
            ? null
            : () async {
                await h.closeDay(counted, _note.text);
                if (context.mounted) Navigator.pop(context);
              },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx('হিসাবে হাতে থাকার কথা', style: t(13, c: K.muted)),
            Tx(sar(expected), style: t(28, w: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        Field(label: 'গুনে কত পেলেন', controller: _counted, number: true, big: true, suffix: 'SAR', autofocus: true, onChanged: (_) => setState(() {})),
        if (diff != null) ...[
          const SizedBox(height: 10),
          diff.abs() < 0.01
              ? const Note('মিলেছে।', color: K.greenTint, textColor: K.green, icon: Icons.check_circle_outline_rounded)
              : Note(diff > 0 ? '${sar(diff)} বেশি আছে' : '${sar(-diff)} কম আছে', color: K.amberTint, textColor: K.amberText, icon: Icons.warning_amber_rounded),
        ],
        const SizedBox(height: 12),
        Field(label: 'নোট (ইচ্ছা হলে)', controller: _note),
        if (closes.isNotEmpty) ...[
          const SizedBox(height: 6),
          SectionHead('আগের দিনগুলো'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, c) in closes.take(14).indexed)
                Row2(
                  lead: dotIcon(c.difference.abs() < 0.01 ? Icons.check_rounded : Icons.priority_high_rounded, c.difference.abs() < 0.01 ? K.greenTint : K.amberTint,
                      c.difference.abs() < 0.01 ? K.green : K.amberText,
                      size: 36),
                  title: dateShort(c.at),
                  sub: 'হিসাবে ${sar(c.expected)}',
                  value: sar(c.counted),
                  valueSub: c.difference.abs() < 0.01 ? 'মিলেছে' : 'পার্থক্য ${sar(c.difference)}',
                  last: i == closes.take(14).length - 1,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ expenses

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _cat = 'নিজের খরচ';
  static const cats = ['নিজের খরচ', 'দোকান/ভাড়া', 'যাতায়াত', 'রিয়াল জমা দিলাম (ব্যাংকে/কাউকে)', 'অন্যান্য'];

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final list = [...h.d.expenses]..sort((a, b) => b.at.compareTo(a.at));
    return Screen(
      title: 'খরচ / রিয়াল বের',
      bottom: Pill(
        label: 'সংরক্ষণ',
        onTap: (parseNum(_amount.text) ?? 0) <= 0
            ? null
            : () async {
                await h.addExpense(_cat, parseNum(_amount.text)!, _note.text);
                if (context.mounted) Navigator.pop(context);
              },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        const Note('হাত থেকে যে রিয়াল বের হলো সেটা লিখুন, তাহলে "হাতে থাকা উচিত" ঠিক থাকবে।'),
        const SizedBox(height: 14),
        Field(label: 'কত রিয়াল', controller: _amount, number: true, big: true, suffix: 'SAR', autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final c in cats) ChoiceChipX(label: c, on: c == _cat, onTap: () => setState(() => _cat = c))]),
        const SizedBox(height: 12),
        Field(label: 'নোট', controller: _note),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 6),
          SectionHead('আগের খরচ'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, e) in list.take(30).indexed)
                Row2(
                  lead: dotIcon(Icons.receipt_long_outlined, K.redTint, K.red, size: 36),
                  title: e.category,
                  sub: '${dateShort(e.at)}${e.note.isEmpty ? '' : ' · ${e.note}'}',
                  value: '−${sar(e.sarAmount)}',
                  valueColor: K.red,
                  last: i == list.take(30).length - 1,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------- log

class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  String _k = '';
  final _q = TextEditingController();
  Period _p = Period.all();

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h;
        final q = en(_q.text).trim().toLowerCase();
        final all = h.d.log.reversed.where((e) => _p.has(e.at) && (_k.isEmpty || e.kind == _k) && (q.isEmpty || '${e.title} ${en(e.detail)}'.toLowerCase().contains(q))).toList();
        final list = all.take(500).toList();
        final groups = <String, List<LogEntry>>{};
        for (final e in list) {
          groups.putIfAbsent(dayLabel(e.at, h.now), () => []).add(e);
        }
        return Screen(
          title: 'কাজের লগ',
          subtitle: 'কখন কী হয়েছে — কিছুই মোছা যায় না',
          trailing: CircleBtn(
            icon: Icons.picture_as_pdf_outlined,
            label: 'লগ PDF',
            onTap: () => sharePdf(context, h, logPdf(h, all.reversed.toList(), _p.label), 'log'),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: t(15),
              decoration: InputDecoration(
                hintText: tr('খুঁজুন (নাম, #নং, TrxID)'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: K.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
              ),
            ),
            const SizedBox(height: 10),
            PeriodChips(value: _p, now: h.now, onChanged: (p) => setState(() => _p = p)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (k, l) in const [('', 'সব'), ('txn', 'লেনদেন'), ('recv', 'জমা'), ('agent', 'এজেন্ট'), ('edit', 'সংশোধন'), ('cust', 'গ্রাহক'), ('sys', 'অন্যান্য')])
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChipX(label: l, on: _k == k, onTap: () => setState(() => _k = k))),
              ]),
            ),
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Note('কিছু নেই।')),
            for (final g in groups.entries) ...[
              SectionHead(g.key),
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, e) in g.value.indexed)
                    InkWell(
                      onTap: h.txnById(e.ref) == null ? null : () => push(context, TxnScreen(h: h, id: e.ref)),
                      child: LogRow(e: e, last: i == g.value.length - 1),
                    ),
                ]),
              ),
            ],
          ]),
        );
      });
}

// --------------------------------------------------------------- settings

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _bio;
  bool _hasBio = false;
  int _auto = 30;

  Hisab get h => widget.h;

  @override
  void initState() {
    super.initState();
    () async {
      final on = await h.s.lock.biometricsOn();
      final has = await h.s.lock.biometrics.available();
      final a = await h.s.lock.autoLockSeconds();
      if (mounted) {
        setState(() {
          _bio = on;
          _hasBio = has;
          _auto = a;
        });
      }
    }();
  }

  Future<void> _edit(String title, String now, Future<void> Function(String v) save, {bool number = false}) async {
    final v = await askText(context, title, initial: now, number: number);
    if (v == null || v.trim().isEmpty) return;
    await save(v.trim());
  }

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final st = h.d.settings;
        Widget row(IconData i, String title, String sub, VoidCallback? onTap, {Widget? trailing}) => ListTile(
              leading: dotIcon(i, K.blueTint, K.blue, size: 38),
              title: Tx(title, style: t(15, w: FontWeight.w500)),
              subtitle: Tx(sub, style: t(12.5, c: K.muted)),
              trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
              onTap: onTap,
            );
        return Screen(
          title: 'সেটিংস',
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
            SectionHead('ভাষা / Language'),
            CardBox(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SwitchListTile(
                secondary: dotIcon(Icons.translate_rounded, K.blueTint, K.blue, size: 38),
                title: Text('English', style: t(15, w: FontWeight.w500)),
                subtitle: Text(appEnglish ? 'The whole app is in English' : 'পুরো অ্যাপ ইংরেজিতে দেখাবে', style: t(12.5, c: K.muted)),
                value: appEnglish,
                onChanged: (v) async {
                  setEnglish(v);
                  await h.s.lock.setEnglish(v);
                },
              ),
            ),
            if (h.can('settings')) ...[
              SectionHead('হিসাব'),
              CardBox(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  row(
                      Icons.person_outline_rounded,
                      h.session == null ? 'আপনার নাম' : 'দোকানের মালিকের নাম (রসিদে যায়)',
                      st.ownerName,
                      () => _edit('আপনার নাম', st.ownerName, (v) async {
                            final old = st.ownerName;
                            st.ownerName = v;
                            await h.saveSettings('নাম $old → $v');
                          })),
                  if (h.can('agents'))
                    row(Icons.storefront_outlined, 'এজেন্ট', h.d.agents.map((a) => a.name).join(', '), () => push(context, AgentListScreen(h: h))),
                  row(Icons.chat_outlined, 'মেসেজের টেমপ্লেট', 'এজেন্ট ও গ্রাহককে যাওয়া সব মেসেজের লেখা', () => push(context, TemplatesScreen(h: h))),
                  row(
                      Icons.speed_rounded,
                      'সাধারণ বাকির সীমা',
                      sar(st.defaultDueLimit),
                      () => _edit('বাকির সীমা (রিয়াল)', groupEn(st.defaultDueLimit).replaceAll(',', ''), (v) async {
                            final n = parseNum(v);
                            if (n == null) return;
                            final old = st.defaultDueLimit;
                            st.defaultDueLimit = n;
                            await h.saveSettings('বাকির সীমা ${sar(old)} → ${sar(n)}');
                          }, number: true)),
                  row(
                      Icons.schedule_rounded,
                      'পুরনো বাকি ধরা হবে',
                      '${bn('${st.oldDueDays}')} দিন পর',
                      () => _edit('কত দিন পর পুরনো বাকি?', '${st.oldDueDays}', (v) async {
                            final n = parseNum(v);
                            if (n == null || n < 1) return;
                            st.oldDueDays = n.round();
                            await h.saveSettings('পুরনো বাকি ${bn('${n.round()}')} দিন');
                          }, number: true)),
                  row(
                      Icons.copy_all_rounded,
                      'একই লেনদেন দুইবারের সতর্কতা',
                      '${bn('${st.dupMinutes}')} মিনিটের মধ্যে',
                      () => _edit('কত মিনিটের মধ্যে?', '${st.dupMinutes}', (v) async {
                            final n = parseNum(v);
                            if (n == null || n < 1) return;
                            st.dupMinutes = n.round();
                            await h.saveSettings('দুইবারের সতর্কতা ${bn('${n.round()}')} মিনিট');
                          }, number: true)),
                ]),
              ),
            ],
            SectionHead('নিরাপত্তা'),
            CardBox(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                row(Icons.pin_outlined, 'পিন বদলান', '৪ সংখ্যা', () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => PinSetup(
                      lock: h.s.lock,
                      title: 'নতুন পিন',
                      onDone: () async {
                        Navigator.of(ctx).pop();
                        await h.saveSettings('পিন বদল');
                      },
                    ),
                  ));
                }),
                if (_hasBio)
                  SwitchListTile(
                    secondary: dotIcon(Icons.fingerprint_rounded, K.blueTint, K.blue, size: 38),
                    title: Tx('আঙুলের ছাপে খোলা', style: t(15, w: FontWeight.w500)),
                    value: _bio ?? true,
                    onChanged: (v) async {
                      await h.s.lock.setBiometricsOn(v);
                      setState(() => _bio = v);
                      await h.saveSettings('আঙুলের ছাপ ${v ? 'চালু' : 'বন্ধ'}');
                    },
                  ),
                row(Icons.lock_clock_outlined, 'নিজে থেকে লক', _autoText(_auto), () async {
                  final v = await showDialog<int>(
                    context: context,
                    builder: (c) => SimpleDialog(title: Tx('অ্যাপ থেকে বের হলে কতক্ষণ পর লক', style: t(16, w: FontWeight.w600)), children: [
                      for (final s in const [0, 30, 60, 300, 900])
                        SimpleDialogOption(onPressed: () => Navigator.pop(c, s), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Tx(_autoText(s), style: t(15)))),
                    ]),
                  );
                  if (v == null) return;
                  await h.s.lock.setAutoLockSeconds(v);
                  setState(() => _auto = v);
                  await h.saveSettings('নিজে থেকে লক: ${_autoText(v)}');
                }),
              ]),
            ),
            const SizedBox(height: 16),
            Center(child: Tx('আমানত · সংস্করণ ১.২.০', style: t(12, c: K.muted))),
          ]),
        );
      });

  String _autoText(int s) => switch (s) {
        0 => 'সাথে সাথে',
        < 60 => '${bn('$s')} সেকেন্ড পর',
        _ => '${bn('${s ~/ 60}')} মিনিট পর',
      };
}

/// Backup on its own: make a file, bring one back.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.h});
  final Hisab h;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  Hisab get h => widget.h;

  Future<void> _backup() async {
    final p1 = await askText(context, 'ব্যাকআপের পাসওয়ার্ড দিন', hint: 'কমপক্ষে ৬ অক্ষর, মনে রাখবেন', obscure: true);
    if (p1 == null || !mounted) return;
    if (p1.length < 6) {
      snack(context, 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষর');
      return;
    }
    final p2 = await askText(context, 'আরেকবার একই পাসওয়ার্ড', obscure: true);
    if (p2 != p1) {
      if (mounted) snack(context, 'দুইবার একই হয়নি');
      return;
    }
    final bytes = await h.exportBackup(p1);
    final n = h.now;
    await h.s.device.shareFile(bytes, 'riyal-hisab-backup-${n.year}-${n.month}-${n.day}.rhb', 'application/octet-stream', text: 'আমানতের ব্যাকআপ (পাসওয়ার্ড ছাড়া খোলা যাবে না)');
  }

  Future<void> _restore() async {
    if (!await confirm(context, 'ব্যাকআপ থেকে ফিরিয়ে আনবেন?', 'এখনকার সব হিসাব ব্যাকআপের হিসাব দিয়ে বদলে যাবে।', yes: 'ফাইল বাছুন', danger: true)) return;
    final bytes = await h.s.device.pickFile();
    if (bytes == null || !mounted) return;
    final pass = await askText(context, 'ব্যাকআপের পাসওয়ার্ড', obscure: true);
    if (pass == null || pass.isEmpty) return;
    try {
      await h.restoreBackup(bytes, pass);
      if (mounted) snack(context, 'ফিরিয়ে আনা হলো');
    } on WrongKey {
      if (mounted) snack(context, 'পাসওয়ার্ড ভুল');
    } catch (_) {
      if (mounted) snack(context, 'এটা এই অ্যাপের ব্যাকআপ ফাইল না');
    }
  }

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final st = h.d.settings;
        Widget row(IconData i, String title, String sub, VoidCallback? onTap, {Widget? trailing}) => ListTile(
              leading: dotIcon(i, K.blueTint, K.blue, size: 38),
              title: Tx(title, style: t(15, w: FontWeight.w500)),
              subtitle: Tx(sub, style: t(12.5, c: K.muted)),
              trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
              onTap: onTap,
            );
        return Screen(
          title: 'ব্যাকআপ',
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
              CardBox(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  row(Icons.cloud_upload_outlined, 'ব্যাকআপ ফাইল বানান', st.lastBackup == null ? 'এখনো হয়নি' : 'শেষ: ${dateShort(st.lastBackup!)}, ${timeText(st.lastBackup!)}', _backup,
                      trailing: st.lastBackup == null || h.now.difference(st.lastBackup!).inDays >= 7 ? const CircleAvatar(radius: 5, backgroundColor: K.red) : null),
                  row(Icons.restore_rounded, 'ব্যাকআপ থেকে ফিরিয়ে আনুন', 'নতুন ফোনে বা ভুল হলে', _restore),
                ]),
              ),
              const SizedBox(height: 12),
              const Note('হিসাব সার্ভারে থাকে। তবুও মাঝে মাঝে ব্যাকআপ ফাইল নিজের কাছে রাখুন — পাসওয়ার্ড ছাড়া কেউ খুলতে পারবে না।'),
            if (h.session != null) ...[
              const SizedBox(height: 8),
              const Note('সার্ভারের পাতা থেকেও পুরো ব্যাকআপ নামানো যায়, আর চালু থাকলে প্রতিদিন গুগল ড্রাইভে নিজে থেকে ব্যাকআপ যায়।'),
            ],
          ]),
        );
      });
}

/// Settings → এজেন্ট: every agent, open one to change it, or add one.
class AgentListScreen extends StatelessWidget {
  const AgentListScreen({super.key, required this.h});
  final Hisab h;
  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) => Screen(
            title: 'এজেন্ট',
            bottom: Pill(label: 'নতুন এজেন্ট', onTap: () => push(context, AgentEdit(h: h))),
            body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, a) in h.d.agents.indexed)
                    Row2(
                      lead: dotIcon(Icons.storefront_rounded, K.navySoft, K.navy, size: 38),
                      title: a.name,
                      sub: '${a.usesApp ? 'অ্যাপে কাজ করেন' : 'হোয়াটসঅ্যাপে'} · ${bn(a.whatsapp)}${a.commissionPerThousand > 0 ? ' · কমিশন হাজারে ${bnNum(a.commissionPerThousand, decimals: 2)}' : ''}',
                      value: taka(agentOwed(h.d, a.id)),
                      onTap: () => push(context, AgentEdit(h: h, a: a)),
                      last: i == h.d.agents.length - 1,
                    ),
                ]),
              ),
            ]),
          ));
}

/// Every message's wording, by who it goes to.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key, required this.h});
  final Hisab h;
  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final own = h.d.settings.templates;
        Widget group(String to) {
          final list = msgTemplates.where((x) => x.to == to).toList();
          return CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, x) in list.indexed)
                Row2(
                  lead: dotIcon(to == 'agent' ? Icons.storefront_rounded : Icons.person_rounded, to == 'agent' ? K.navySoft : K.greenTint, to == 'agent' ? K.navy : K.green, size: 38),
                  title: x.title,
                  sub: own.containsKey(x.key) ? 'নিজের লেখা' : 'আগের মতো (অ্যাপের লেখা)',
                  onTap: () => push(context, TemplateEdit(h: h, tpl: x)),
                  last: i == list.length - 1,
                ),
            ]),
          );
        }

        return Screen(
          title: 'মেসেজের টেমপ্লেট',
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
            if (!h.can('settings')) const Note('টেমপ্লেট বদলানোর অনুমতি আপনার নেই, শুধু দেখতে পারবেন।'),
            SectionHead('এজেন্টকে'),
            group('agent'),
            SectionHead('গ্রাহককে'),
            group('customer'),
            const SizedBox(height: 12),
            const Note('{ } এর ভেতরের অংশ অ্যাপ নিজে বসায়। কোনো লাইনের সব { } খালি হলে সেই লাইন বাদ যায়।'),
          ]),
        );
      });
}

class TemplateEdit extends StatefulWidget {
  const TemplateEdit({super.key, required this.h, required this.tpl});
  final Hisab h;
  final MsgTemplate tpl;
  @override
  State<TemplateEdit> createState() => _TemplateEditState();
}

class _TemplateEditState extends State<TemplateEdit> {
  late final _c = TextEditingController(text: widget.h.d.settings.templates[widget.tpl.key] ?? widget.tpl.def)..addListener(() => setState(() {}));

  void _insert(String f) {
    final v = _c.value;
    final at = v.selection.isValid ? v.selection.start : v.text.length;
    final end = v.selection.isValid ? v.selection.end : v.text.length;
    final text = v.text.replaceRange(at, end, '{$f}');
    _c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at + f.length + 2));
  }

  /// The message as it would go now, with sample values.
  String _sample() {
    final vals = {
      for (final (f, _) in widget.tpl.fields)
        f: switch (f) {
          'নং' => '26110001',
          'মাধ্যম' => 'বিকাশ',
          'নম্বর' => '01712-345678',
          'টাকা' => '10,000',
          'খরচ' => '',
          'ধরন' => widget.tpl.key == 'agent_topup' ? 'রিচার্জ' : 'সেন্ড মানি',
          'অপারেটর' => 'গ্রামীণফোন',
          'প্যাক' => '',
          'উত্তরের_নিয়ম' => fillTemplate(widget.h.d.settings.templates['agent_reply_rule'] ?? templateOf('agent_reply_rule').def, {'নং': '26110001', 'টাকা': '10000'}),
          'বিস্তারিত' => 'নম্বর: 01712-345678\nটাকা: 10,000',
          'তারিখ' => '2/11/2026',
          'তালিকা' => '#26110001 · 01712-345678 · 10,000 · 10000-667',
          'মোট' => '10,000',
          'সংখ্যা' => '1',
          'পাওনা' => '25,000',
          'নাম' => 'করিম',
          'খবর' => 'আপনার টাকা পৌঁছেছে।',
          'প্রাপক' => 'মা · 01712-345678',
          'TrxID' => 'BK7X2Q9',
          'রিয়াল' => '300.00',
          'বাকি' => '150.00 রিয়াল',
          'স্বাক্ষর' => widget.h.d.settings.ownerName,
          _ => f,
        },
    };
    return fillTemplate(_c.text, vals);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.h, x = widget.tpl;
    final can = h.can('settings');
    final unknown = unknownFields(x, _c.text);
    final isDefault = _c.text == x.def;
    return Screen(
      title: x.title,
      bottom: can
          ? Pill(
              label: 'সংরক্ষণ',
              onTap: () async {
                if (_c.text.trim().isEmpty) {
                  snack(context, 'মেসেজ খালি রাখা যাবে না');
                  return;
                }
                if (isDefault) {
                  h.d.settings.templates.remove(x.key);
                } else {
                  h.d.settings.templates[x.key] = _c.text;
                }
                await h.saveSettings('মেসেজের টেমপ্লেট বদল: ${x.title}');
                if (context.mounted) Navigator.of(context).pop();
              },
            )
          : null,
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        TextField(
          controller: _c,
          readOnly: !can,
          minLines: 6,
          maxLines: 14,
          style: t(14.5, h: 1.5),
          decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        ),
        if (unknown.isNotEmpty) ...[
          const SizedBox(height: 8),
          Note('অ্যাপ এগুলো চেনে না, যেমন লেখা তেমনই যাবে: ${unknown.map((f) => '{$f}').join(', ')}', color: K.amberTint, textColor: K.amberText),
        ],
        if (can) ...[
          SectionHead('বসাতে চাপুন'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (f, what) in x.fields) Tooltip(message: tr(what), child: ActionChip(label: Tx('{$f}', style: t(13)), onPressed: () => _insert(f))),
          ]),
          const SizedBox(height: 6),
          for (final (f, what) in x.fields) Tx('{$f} — $what', style: t(12, c: K.muted)),
          if (!isDefault) ...[
            const SizedBox(height: 10),
            SoftPill(label: 'অ্যাপের আগের লেখায় ফেরত', icon: Icons.restart_alt_rounded, onTap: () => _c.text = x.def),
          ],
        ],
        if (x.key == 'agent_reply_rule' || x.key == 'agent_send' || x.key == 'agent_topup') ...[
          const SizedBox(height: 10),
          const Note('এজেন্টের রিপ্লাই "লেনদেন নং টাকা-শেষ ৩ সংখ্যা" ধরনেই অ্যাপ নিজে পড়ে নেয়। নিয়মের লেখা বদলালেও এই ধরনটা রাখুন।'),
        ],
        SectionHead('দেখতে এমন হবে'),
        CardBox(child: SelectableText(_sample(), style: t(14, h: 1.55))),
      ]),
    );
  }
}
