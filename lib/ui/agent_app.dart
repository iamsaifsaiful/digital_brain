import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/models.dart' show payWayName;
import '../state/agent_state.dart';
import 'home.dart' show KeepTab, push;
import 'kit.dart';
import '../core/lang.dart';
import 'reports.dart';
import '../services/pdf.dart';
import 'lock_screen.dart' show PinSetup;
import 'txn.dart' show Live, TxnScreen;
import 'agent.dart' show PaymentScreen;

/// The agent's app: requests to send, everything done, money received,
/// and their profile with notifications. Taka only.
class AgentShell extends StatefulWidget {
  const AgentShell({super.key, required this.st});
  final AgentState st;

  @override
  State<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends State<AgentShell> {
  final _pages = PageController();
  int _tab = 0;
  Timer? _timer;

  AgentState get st => widget.st;

  @override
  void initState() {
    super.initState();
    st.refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => st.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _tab = i);
    _pages.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    if (i == 3) st.loadNotes();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: st,
        builder: (context, _) {
          final tabs = [
            (Icons.home_rounded, 'হোম', st.waiting.length),
            (Icons.task_alt_rounded, 'সব কাজ', 0),
            (Icons.account_balance_wallet_rounded, 'হিসাব', 0),
            (Icons.person_rounded, 'প্রোফাইল', st.unread),
            (Icons.settings_rounded, 'সেটিংস', 0),
          ];
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: PageView(
                controller: _pages,
                physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
                onPageChanged: (i) {
                  setState(() => _tab = i);
                  if (i == 3) st.loadNotes();
                },
                children: [
                  KeepTab(child: _Requests(st: st)),
                  KeepTab(child: _AllWork(st: st)),
                  KeepTab(child: _Money(st: st)),
                  KeepTab(child: _Profile(st: st)),
                  KeepTab(child: _AgentSettings(st: st)),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.line))),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
              child: Row(children: [
                for (final (i, (icon, label, badge)) in tabs.indexed)
                  Expanded(
                    child: InkWell(
                      onTap: () => _go(i),
                      child: SizedBox(
                        height: 64,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Badge(
                            isLabelVisible: badge > 0,
                            label: Tx(bn('$badge'), style: t(10.5, c: Colors.white)),
                            backgroundColor: K.red,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              decoration: BoxDecoration(color: _tab == i ? K.blueTint : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                              child: Icon(icon, size: 23, color: _tab == i ? K.blue : const Color(0xFF8A8A8A)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Tx(label, style: t(11.5, w: _tab == i ? FontWeight.w600 : FontWeight.w400, c: _tab == i ? K.blue : const Color(0xFF8A8A8A))),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
          );
        },
      );
}

String _service(AgentTxn t) => switch (t.kind) {
      'recharge' => 'মোবাইল রিচার্জ${t.operator.isEmpty ? '' : ' · ${t.operator}'}',
      'mb' => 'এমবি প্যাক${t.operator.isEmpty ? '' : ' · ${t.operator}'}',
      'cashout' => '${_method(t.method)} · ক্যাশ আউট',
      _ => '${_method(t.method)} · সেন্ড মানি',
    };

String _method(String m) => const {'bkash': 'বিকাশ', 'nagad': 'নগদ', 'rocket': 'রকেট', 'bank': 'ব্যাংক'}[m] ?? 'বিকাশ';

Widget _header(String title, String sub, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(title, style: t(22, w: FontWeight.w700)),
            if (sub.isNotEmpty) Tx(sub, style: t(13, c: K.muted)),
          ]),
        ),
        if (trailing != null) trailing,
      ]),
    );

/// New requests, oldest first, each with "পাঠিয়েছি" and "সমস্যা".
class _Requests extends StatelessWidget {
  const _Requests({required this.st});
  final AgentState st;

  @override
  Widget build(BuildContext context) {
    final w = st.waiting;
    final now = DateTime.now();
    final today = st.txns.where((x) => !x.cancelled && sameDay(x.at, now)).toList();
    final sentToday = st.txns.where((x) => x.status == 'sent' && x.sentAt != null && sameDay(x.sentAt!.toLocal(), now)).toList();
    final recent = st.txns.where((x) => !x.pending).toList()..sort((a, b) => (b.sentAt ?? b.at).compareTo(a.sentAt ?? a.at));
    Widget tile(String label, String big, String small, {Color c = K.ink}) => Expanded(
          child: CardBox(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx(label, style: t(12.5, c: K.muted)),
              Tx(big, style: t(17, w: FontWeight.w700, c: c)),
              if (small.isNotEmpty) Tx(small, style: t(12, c: K.muted)),
            ]),
          ),
        );
    return RefreshIndicator(
      onRefresh: st.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        _header('আসসালামু আলাইকুম,', st.name, trailing: CircleBtn(icon: Icons.refresh_rounded, label: 'নতুন করে আনুন', onTap: st.refresh)),
        if (st.error != null && st.at == null) const Note('সার্ভারে পৌঁছানো যাচ্ছে না। ইন্টারনেট দেখে নিচে টেনে আবার চেষ্টা করুন।', color: K.redTint, textColor: K.red),
        if (st.loading && st.at == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (st.at != null) ...[
          // At a glance: today, what waits, what is owed.
          Row(children: [
            tile('পাঠাতে হবে', '${bn('${w.length}')}টা', taka(w.fold<double>(0, (s, x) => s + x.total)), c: w.isEmpty ? K.ink : K.red),
            const SizedBox(width: 10),
            tile('আজ পাঠালেন', '${bn('${sentToday.length}')}টা', taka(sentToday.fold<double>(0, (s, x) => s + x.total)), c: K.green),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            tile('আজ অনুরোধ', '${bn('${today.length}')}টা', taka(today.fold<double>(0, (s, x) => s + x.total))),
            const SizedBox(width: 10),
            tile(st.owed >= 0 ? 'আরও পাবেন' : 'অগ্রিম আছে', taka(st.owed.abs()), st.owner),
          ]),
        ],
        SectionHead('নতুন অনুরোধ'),
        if (st.at != null && w.isEmpty) const Note('এখন পাঠানোর মতো কিছু নেই। নতুন অনুরোধ এলে নোটিফিকেশন আসবে।', icon: Icons.check_circle_outline_rounded),
        for (final x in w) ...[RequestCard(st: st, tx: x), const SizedBox(height: 12)],
        if (st.problems.isNotEmpty) ...[
          SectionHead('সমস্যা জানানো লেনদেন'),
          Tx('${st.owner} ঠিক করে আবার অনুরোধ দিলে এগুলো আবার "নতুন অনুরোধ"-এ আসবে।', style: t(12.5, c: K.muted)),
          const SizedBox(height: 8),
          for (final x in st.problems) ...[RequestCard(st: st, tx: x), const SizedBox(height: 12)],
        ],
        if (recent.isNotEmpty) ...[
          SectionHead('সাম্প্রতিক লেনদেন'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, x) in recent.take(8).indexed)
                Row2(
                  lead: dotIcon(x.cancelled ? Icons.block_rounded : Icons.check_rounded, x.cancelled ? K.chip : K.greenTint, x.cancelled ? K.muted : K.green, size: 38),
                  title: '#${bn('${x.no}')} · ${bdShow(x.number)}',
                  sub: '${_service(x)} · ${dateShort(x.sentAt ?? x.at)}, ${timeText(x.sentAt ?? x.at)}${x.reply.isNotEmpty ? ' · ${bn(x.reply)}' : ''}',
                  value: taka(x.total),
                  valueColor: x.cancelled ? K.muted : K.ink,
                  valueSub: x.cancelled ? 'বাতিল' : (x.paid ? 'টাকা পেয়েছি' : 'টাকা পাইনি'),
                  valueSubColor: x.paid ? K.green : K.muted,
                  last: i == recent.take(8).length - 1,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.st, required this.tx});
  final AgentState st;
  final AgentTxn tx;

  Future<void> _sent(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _SentSheet(st: st, t: tx));
    if (ok == true && context.mounted) snack(context, '#${bn('${tx.no}')} — পাঠানো হয়েছে, ${st.owner}-কে জানানো হলো');
  }

  Future<void> _problem(BuildContext context) async {
    final why = await askText(context, 'কী সমস্যা?', hint: 'যেমন নম্বর বন্ধ, ব্যালেন্স নেই', ok: '${st.owner}-কে জানান');
    if (why == null) return;
    try {
      await st.problem(tx, why);
      if (context.mounted) snack(context, '${st.owner}-কে জানানো হলো');
    } catch (_) {
      if (context.mounted) snack(context, 'পাঠানো যায়নি — ইন্টারনেট দেখুন');
    }
  }

  @override
  Widget build(BuildContext context) => CardBox(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(12)),
              child: Tx('#${bn('${tx.no}')}', style: t(13, w: FontWeight.w700, c: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Tx(_service(tx), style: t(14, w: FontWeight.w600, c: K.navy))),
            Tx(timeText(tx.at), style: t(12.5, c: K.muted)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Tx(bdShow(tx.number), style: t(24, w: FontWeight.w700))),
            IconButton(
              tooltip: tr('নম্বর কপি'),
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: tx.number));
                snack(context, 'নম্বর কপি হয়েছে');
              },
            ),
          ]),
          Tx(taka(tx.total), style: t(28, w: FontWeight.w700, c: K.blue)),
          if (tx.fee > 0) Tx('খরচসহ — মূল ${taka(tx.taka)}, খরচ ${taka(tx.fee)}', style: t(13, c: K.muted)),
          if (tx.kind == 'mb' && tx.pack.isNotEmpty) Tx('প্যাক: ${tx.pack}', style: t(15, w: FontWeight.w600)),
          if (tx.hasProblem) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: K.redTint, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.report_outlined, color: K.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx('আপনি জানিয়েছেন: ${tx.problem}', style: t(14, w: FontWeight.w600, c: K.red)),
                    Tx('${tx.problemAt == null ? '' : '${dateShort(tx.problemAt!)}, ${timeText(tx.problemAt!)} · '}${st.owner}-এর আবার অনুরোধের অপেক্ষায়', style: t(12.5, c: K.red)),
                  ]),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (tx.hasProblem)
            SoftPill(label: 'তবুও পাঠিয়ে দিয়েছি', icon: Icons.check_rounded, color: K.green, onTap: () => _sent(context))
          else
            Row(children: [
              Expanded(flex: 2, child: Pill(label: 'পাঠিয়েছি', icon: Icons.check_rounded, color: K.green, height: 48, onTap: () => _sent(context))),
              const SizedBox(width: 8),
              Expanded(child: SoftPill(label: 'সমস্যা', icon: Icons.report_outlined, color: K.red, onTap: () => _problem(context))),
            ]),
        ]),
      );
}

class _SentSheet extends StatefulWidget {
  const _SentSheet({required this.st, required this.t});
  final AgentState st;
  final AgentTxn t;

  @override
  State<_SentSheet> createState() => _SentSheetState();
}

class _SentSheetState extends State<_SentSheet> {
  final _tail = TextEditingController();
  final _trx = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _go() async {
    final tail = en(_tail.text).replaceAll(RegExp(r'[^0-9]'), '');
    final trx = _trx.text.trim().toUpperCase();
    if (tail.length != 3 && trx.isEmpty) {
      setState(() => _err = 'যে নম্বর থেকে পাঠালেন তার শেষ ৩ সংখ্যা দিন (অথবা TrxID)');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await widget.st.sent(widget.t, tail: tail.length == 3 ? tail : '', trxId: trx);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() {
        _busy = false;
        _err = 'পাঠানো যায়নি — ইন্টারনেট দেখে আবার চাপুন';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Tx('#${bn('${widget.t.no}')} পাঠিয়েছেন', style: t(19, w: FontWeight.w600), textAlign: TextAlign.center),
          Tx('${bdShow(widget.t.number)} · ${taka(widget.t.total)}', style: t(14, c: K.muted), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Field(label: 'যে নম্বর থেকে পাঠালেন, তার শেষ ৩ সংখ্যা', controller: _tail, number: true, big: true, autofocus: true, hint: '৬৬৭'),
          const SizedBox(height: 12),
          Field(label: 'TrxID (থাকলে)', controller: _trx, hint: 'যেমন BJ7K9X2Q1M'),
          if (_err != null) ...[const SizedBox(height: 10), Note(_err!, color: K.redTint, textColor: K.red)],
          const SizedBox(height: 16),
          Pill(label: _busy ? 'পাঠানো হচ্ছে…' : '${widget.st.owner}-কে জানান', icon: Icons.send_rounded, color: K.green, onTap: _busy ? null : _go),
        ]),
      );
}

/// Everything sent for the shop, with dates.
class _AllWork extends StatefulWidget {
  const _AllWork({required this.st});
  final AgentState st;

  @override
  State<_AllWork> createState() => _AllWorkState();
}

class _AllWorkState extends State<_AllWork> {
  Period _p = Period.all();
  String _f = 'sent';

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final list = st.txns.where((x) {
      if (!_p.has(x.at)) return false;
      return switch (_f) {
        'sent' => x.status == 'sent',
        'unpaid' => x.status == 'sent' && !x.paid,
        'cancelled' => x.cancelled,
        'fault' => x.fault != null,
        _ => true,
      };
    }).toList();
    final total = list.where((x) => !x.cancelled).fold<double>(0, (s, x) => s + x.total);
    final groups = <String, List<AgentTxn>>{};
    for (final x in list.take(400)) {
      groups.putIfAbsent(dayLabel(x.at, DateTime.now()), () => []).add(x);
    }
    return RefreshIndicator(
      onRefresh: st.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        _header('সব কাজ', '${bn('${list.length}')}টা · ${taka(total)}'),
        PeriodChips(value: _p, now: DateTime.now(), wrap: true, onChanged: (p) => setState(() => _p = p)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, l) in const [('sent', 'পাঠানো'), ('unpaid', 'টাকা পাইনি'), ('all', 'সব'), ('cancelled', 'বাতিল'), ('fault', 'ভুল নম্বর')])
            ChoiceChipX(label: l, on: _f == k, onTap: () => setState(() => _f = k)),
        ]),
        if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 14), child: Note('কিছু নেই।')),
        for (final g in groups.entries) ...[
          SectionHead(g.key),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, x) in g.value.indexed)
                Row2(
                  lead: dotIcon(x.cancelled ? Icons.block_rounded : (x.pending ? Icons.hourglass_top_rounded : Icons.check_rounded), x.cancelled ? K.chip : (x.pending ? K.redTint : K.greenTint),
                      x.cancelled ? K.muted : (x.pending ? K.red : K.green),
                      size: 38),
                  title: '#${bn('${x.no}')} · ${bdShow(x.number)}',
                  sub: '${_service(x)} · ${timeText(x.at)}${x.reply.isNotEmpty ? ' · ${bn(x.reply)}' : ''}${x.trxId.isNotEmpty ? ' · ${x.trxId}' : ''}${x.fault != null ? ' · ভুল নম্বর' : ''}',
                  subColor: x.fault != null ? K.red : K.muted,
                  value: taka(x.total),
                  valueColor: x.cancelled ? K.muted : K.ink,
                  valueSub: x.cancelled ? 'বাতিল' : (x.pending ? 'পাঠাতে হবে' : (x.paid ? 'টাকা পেয়েছি' : 'টাকা পাইনি')),
                  valueSubColor: x.paid ? K.green : K.muted,
                  last: i == g.value.length - 1,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// What the shop owes and what it paid, with receipts.
/// হিসাব: the agent's account for a chosen period — a summary first
/// (requests, sent, cancelled, commission, received, still owed), then each
/// payment and each send, filterable.
class _Money extends StatefulWidget {
  const _Money({required this.st});
  final AgentState st;
  @override
  State<_Money> createState() => _MoneyState();
}

class _MoneyState extends State<_Money> {
  Period _p = Period.of('month', DateTime.now());
  String _show = 'all';

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final inP = st.txns.where((x) => _p.has(x.at)).toList()..sort((a, b) => b.at.compareTo(a.at));
    final live = inP.where((x) => !x.cancelled).toList();
    final sent = live.where((x) => x.status == 'sent').toList();
    final waiting = live.where((x) => x.pending).toList();
    final cancelled = inP.where((x) => x.cancelled).toList();
    final comm = live.fold<double>(0, (s, x) => s + x.commission);
    final pays = st.payments.where((p) => _p.has(p.at)).toList();
    final got = pays.fold<double>(0, (s, p) => s + p.taka);
    Widget tile(String label, String big, String small, {Color c = K.ink}) => Expanded(
          child: CardBox(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx(label, style: t(12.5, c: K.muted)),
              Tx(big, style: t(17, w: FontWeight.w700, c: c)),
              if (small.isNotEmpty) Tx(small, style: t(12, c: K.muted)),
            ]),
          ),
        );
    return RefreshIndicator(
      onRefresh: st.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        _header('হিসাব', '', trailing: CircleBtn(icon: Icons.picture_as_pdf_outlined, label: 'PDF ডাউনলোড', onTap: () => sharePdf(context, st.h, agentOwnPdf(st, _p), 'hisab-${st.name}'))),
        CardBox(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(st.owed >= 0 ? '${st.owner} আপনাকে দেবেন (এখন পর্যন্ত মোট)' : 'আপনার কাছে ${st.owner}-এর অগ্রিম', style: t(13.5, c: K.muted)),
            Tx(taka(st.owed.abs()), style: t(32, w: FontWeight.w700, c: K.navy)),
            if (st.commission > 0) Tx('কমিশন হাজারে ${bnNum(st.commission, decimals: 2)} টাকা', style: t(12.5, c: K.muted)),
          ]),
        ),
        const SizedBox(height: 12),
        PeriodChips(value: _p, now: DateTime.now(), wrap: true, onChanged: (p) => setState(() => _p = p)),
        SectionHead('সারসংক্ষেপ · ${_p.label}'),
        Row(children: [
          tile('অনুরোধ', '${bn('${live.length}')}টা', taka(live.fold<double>(0, (s, x) => s + x.total))),
          const SizedBox(width: 10),
          tile('পাঠিয়েছেন', '${bn('${sent.length}')}টা', taka(sent.fold<double>(0, (s, x) => s + x.total)), c: K.green),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          tile('পাঠানোর অপেক্ষায়', '${bn('${waiting.length}')}টা', taka(waiting.fold<double>(0, (s, x) => s + x.total)), c: waiting.isEmpty ? K.ink : K.red),
          const SizedBox(width: 10),
          tile('বাতিল', '${bn('${cancelled.length}')}টা', taka(cancelled.fold<double>(0, (s, x) => s + x.total))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          tile('${st.owner}-এর কাছ থেকে পেয়েছেন', taka(got), '${bn('${pays.length}')} বার', c: K.green),
          const SizedBox(width: 10),
          tile('কমিশন', taka(comm), ''),
        ]),
        const SizedBox(height: 12),
        Seg<String>(items: const [('all', 'সব'), ('pay', 'পেয়েছেন'), ('sent', 'পাঠানো'), ('unpaid', 'টাকা পাইনি')], value: _show, onChanged: (v) => setState(() => _show = v)),
        if (_show == 'all' || _show == 'pay') ...[
          SectionHead('${st.owner} যা দিয়েছেন'),
          if (pays.isEmpty) const Note('এই সময়ে কিছু দেওয়া হয়নি।'),
          if (pays.isNotEmpty)
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (final (i, p) in pays.indexed)
                  Row2(
                    lead: dotIcon(p.receipt != null ? Icons.receipt_long_rounded : Icons.payments_outlined, K.greenTint, K.green, size: 38),
                    title: '${payWayName(p.way)}${p.count > 0 ? ' · ${bn('${p.count}')}টা লেনদেনের' : ''}',
                    sub: '${dateShort(p.at)}, ${timeText(p.at)}${p.ref.isEmpty ? '' : ' · রেফ ${p.ref}'}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                    value: taka(p.taka),
                    valueColor: K.green,
                    valueSub: p.receipt != null ? 'রসিদ দেখুন' : null,
                    valueSubColor: K.blue,
                    last: i == pays.length - 1,
                    onTap: p.receipt == null ? null : () => push(context, _Receipt(st: st, p: p)),
                  ),
              ]),
            ),
        ],
        if (_show != 'pay') ...[
          SectionHead(_show == 'unpaid' ? 'যেগুলোর টাকা পাননি' : 'পাঠানো লেনদেন'),
          () {
            final list = sent.where((x) => _show != 'unpaid' || !x.paid).toList();
            if (list.isEmpty) return const Note('কিছু নেই।');
            return CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (final (i, x) in list.take(300).indexed)
                  Row2(
                    lead: dotIcon(Icons.check_rounded, K.greenTint, K.green, size: 36),
                    title: '#${bn('${x.no}')} · ${bdShow(x.number)}',
                    sub: '${_service(x)} · ${dateShort(x.at)}${x.reply.isNotEmpty ? ' · ${bn(x.reply)}' : ''}',
                    value: taka(x.total),
                    valueSub: x.paid ? 'টাকা পেয়েছি' : 'টাকা পাইনি',
                    valueSubColor: x.paid ? K.green : K.red,
                    last: i == list.take(300).length - 1,
                  ),
              ]),
            );
          }(),
        ],
      ]),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.st, required this.p});
  final AgentState st;
  final AgentPay p;

  @override
  Widget build(BuildContext context) => Screen(
        title: 'রসিদ',
        subtitle: '${taka(p.taka)} · ${dateShort(p.at)}',
        body: FutureBuilder<Uint8List?>(
          future: st.receipt(p.receipt!),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final b = snap.data;
            if (b == null) return const Padding(padding: EdgeInsets.all(18), child: Note('রসিদ আনা যায়নি।'));
            return InteractiveViewer(child: Center(child: Image.memory(b)));
          },
        ),
      );
}

/// Name, totals, notifications, password, sign out.
class _Profile extends StatelessWidget {
  const _Profile({required this.st});
  final AgentState st;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final live = st.txns.where((x) => !x.cancelled && x.status == 'sent');
    final month = live.where((x) => x.at.year == now.year && x.at.month == now.month);
    final received = st.payments.fold<double>(0, (s, p) => s + p.taka);
    Widget tile(String l, String v) => Expanded(
          child: CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx(l, style: t(12.5, c: K.muted)),
              const SizedBox(height: 4),
              Tx(v, style: t(16, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
    return RefreshIndicator(
      onRefresh: () async {
        await st.refresh();
        await st.loadNotes();
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        _header('প্রোফাইল', ''),
        CardBox(
          child: Row(children: [
            dotIcon(Icons.storefront_rounded, K.navySoft, K.navy, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Tx(st.name, style: t(17, w: FontWeight.w700)),
                Tx('এজেন্ট · লগইন ${bn(st.h.session?.login ?? '')}', style: t(13, c: K.muted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [tile('এ মাসে পাঠালেন', taka(month.fold<double>(0, (s, x) => s + x.total))), const SizedBox(width: 10), tile('মোট পাঠালেন', taka(live.fold<double>(0, (s, x) => s + x.total)))]),
        const SizedBox(height: 10),
        Row(children: [tile('${st.owner}-এর কাছ থেকে পেয়েছেন', taka(received)), const SizedBox(width: 10), tile(st.owed >= 0 ? 'আরও পাবেন' : 'অগ্রিম আছে', taka(st.owed.abs()))]),
        SectionHead('নোটিফিকেশন'),
        if (st.notes.isEmpty) const Note('কোনো নোটিফিকেশন নেই।'),
        if (st.notes.isNotEmpty)
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, n) in st.notes.take(100).indexed)
                noteRow(n, last: i == st.notes.take(100).length - 1, onTap: () => openNote(context, st, n)),
            ]),
          ),
      ]),
    );
  }
}

/// সেটিংস (agent): password, this phone, language, sign out.
class _AgentSettings extends StatefulWidget {
  const _AgentSettings({required this.st});
  final AgentState st;
  @override
  State<_AgentSettings> createState() => _AgentSettingsState();
}

class _AgentSettingsState extends State<_AgentSettings> {
  int _auto = 30;

  @override
  void initState() {
    super.initState();
    widget.st.h.s.lock.autoLockSeconds().then((v) {
      if (mounted) setState(() => _auto = v);
    });
  }

  String _autoText(int s) => switch (s) {
        0 => 'সাথে সাথে',
        < 60 => '${bn('$s')} সেকেন্ড পর',
        _ => '${bn('${s ~/ 60}')} মিনিট পর',
      };

  @override
  Widget build(BuildContext context) {
    final st = widget.st, h = st.h;
    Widget row(IconData i, String title, String sub, VoidCallback? onTap, {Widget? trailing, bool last = false, Color fg = K.blue, Color bg = K.blueTint}) => Row2(
          lead: dotIcon(i, bg, fg, size: 40),
          title: title,
          sub: sub,
          onTap: onTap,
          trailing: trailing,
          value: trailing == null && onTap != null ? '›' : null,
          valueColor: K.muted,
          last: last,
        );
    return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
      _header('সেটিংস', ''),
      SectionHead('আমার লগইন'),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: [
          row(Icons.password_rounded, 'পাসওয়ার্ড বদলান', 'লগইন ${bn(h.session?.login ?? '')}', () async {
            final old = await askText(context, 'এখনকার পাসওয়ার্ড', obscure: true);
            if (old == null || old.isEmpty || !context.mounted) return;
            final nw = await askText(context, 'নতুন পাসওয়ার্ড (৬+ অক্ষর)', obscure: true);
            if (nw == null || !context.mounted) return;
            if (nw.length < 6) {
              snack(context, 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষর');
              return;
            }
            try {
              await st.changePassword(old, nw);
              if (context.mounted) snack(context, 'পাসওয়ার্ড বদলেছে');
            } catch (_) {
              if (context.mounted) snack(context, 'বদলানো যায়নি — এখনকার পাসওয়ার্ড ঠিক আছে?');
            }
          }, last: true),
        ]),
      ),
      SectionHead('এই ফোন'),
      CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: [
          row(Icons.pin_outlined, 'পিন বদলান', '৪ সংখ্যা', () {
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PinSetup(lock: h.s.lock, title: 'নতুন পিন', onDone: () => Navigator.of(ctx).pop())));
          }),
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
          }),
          row(Icons.notifications_active_outlined, 'নোটিফিকেশন পরীক্ষা', 'সাউন্ড আর ভাইব্রেশন ঠিক আছে কি না শুনে দেখুন', () async {
            await h.s.reminders.askPermission();
            final ok = await h.s.push.test('রেমিট খাতা', 'এই সাউন্ড আর ভাইব্রেশনেই নতুন অনুরোধ আসবে।');
            if (context.mounted) snack(context, ok ? 'নোটিফিকেশন পাঠানো হলো' : 'নোটিফিকেশন দেখানো যায়নি — ফোনের সেটিংসে অ্যাপের নোটিফিকেশন চালু করুন');
          }),
          row(Icons.translate_rounded, 'English', appEnglish ? 'The whole app is in English' : 'পুরো অ্যাপ ইংরেজিতে দেখাবে', null,
              trailing: Switch(
                value: appEnglish,
                onChanged: (v) async {
                  setEnglish(v);
                  await h.s.lock.setEnglish(v);
                },
              ),
              last: true),
        ]),
      ),
      const SizedBox(height: 16),
      SoftPill(
        label: 'লগআউট',
        icon: Icons.logout_rounded,
        color: K.red,
        onTap: () async {
          if (await confirm(context, 'লগআউট করবেন?', 'আবার ঢুকতে লগইন আর পাসওয়ার্ড লাগবে।', yes: 'লগআউট', danger: true)) await h.logout();
        },
      ),
      const SizedBox(height: 18),
      Center(child: Tx('রেমিট খাতা · সংস্করণ ১.২.০', style: t(12, c: K.muted))),
      MadeBy(h: h),
    ]);
  }
}

IconData _noteIcon(String k) => switch (k) {
      'new' => Icons.add_alert_rounded,
      'edit' => Icons.edit_rounded,
      'cancel' => Icons.block_rounded,
      'paid' => Icons.payments_rounded,
      'fault' => Icons.report_gmailerrorred_rounded,
      'sent' => Icons.check_rounded,
      'problem' => Icons.report_outlined,
      _ => Icons.notifications_rounded,
    };

Color _noteBg(String k) => switch (k) {
      'new' => K.blueTint,
      'paid' || 'sent' => K.greenTint,
      'cancel' || 'fault' || 'problem' => K.redTint,
      _ => K.amberTint,
    };

Color _noteFg(String k) => switch (k) {
      'new' => K.blue,
      'paid' || 'sent' => K.green,
      'cancel' || 'fault' || 'problem' => K.red,
      _ => K.amberText,
    };

/// For the admins' notification list too.
Widget noteRow(ServerNote n, {bool last = false, VoidCallback? onTap}) => Row2(
      lead: dotIcon(_noteIcon(n.kind), _noteBg(n.kind), _noteFg(n.kind), size: 38),
      title: n.title,
      sub: '${n.body}\n${dateShort(n.at)}, ${timeText(n.at)}',
      last: last,
      onTap: onTap,
      value: onTap == null ? null : '›',
      valueColor: K.muted,
    );

/// A tapped notification: all of it, and what it is about. An admin goes on
/// to the send (or the payment); an agent sees the request itself, with its
/// buttons.
Future<void> openNote(BuildContext context, AgentState st, ServerNote n) async {
  final h = st.h;
  final admin = h.session != null && !h.session!.isAgent;
  final txn = admin ? h.txnById(n.ref) : null;
  final pay = admin ? h.d.agentPayments.where((p) => p.id == n.ref).firstOrNull : null;
  final req = admin ? null : st.txns.where((x) => x.id == n.ref).firstOrNull;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).padding.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            dotIcon(_noteIcon(n.kind), _noteBg(n.kind), _noteFg(n.kind), size: 44),
            const SizedBox(width: 12),
            Expanded(child: Tx(n.title, style: t(17, w: FontWeight.w600))),
          ]),
          const SizedBox(height: 12),
          SelectableText(n.body, style: t(15, h: 1.5)),
          const SizedBox(height: 8),
          Tx('${weekdayName(n.at)}, ${dateShort(n.at)} ${bn('${n.at.year}')} · ${timeText(n.at)}', style: t(12.5, c: K.muted)),
          if (req != null) ...[
            const SizedBox(height: 14),
            RequestCard(st: st, tx: req),
          ],
          if (txn != null) ...[
            const SizedBox(height: 16),
            Pill(
              label: 'লেনদেন #${bn('${txn.no}')} দেখুন',
              onTap: () {
                Navigator.pop(ctx);
                push(context, TxnScreen(h: h, id: txn.id));
              },
            ),
          ],
          if (pay != null) ...[
            const SizedBox(height: 16),
            Pill(
              label: 'পরিশোধের বিস্তারিত',
              onTap: () {
                Navigator.pop(ctx);
                push(context, PaymentScreen(h: h, p: pay));
              },
            ),
          ],
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Tx('বন্ধ করুন', style: t(14, c: K.muted))),
        ]),
      ),
    ),
  );
}

/// Live list for the admin app.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.st});
  final AgentState st;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  void initState() {
    super.initState();
    widget.st.loadNotes();
  }

  @override
  Widget build(BuildContext context) => Live(
        h: widget.st.h,
        builder: (context) => ListenableBuilder(
          listenable: widget.st,
          builder: (context, _) => Screen(
            title: 'নোটিফিকেশন',
            body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
              if (widget.st.notes.isEmpty) const Note('কোনো নোটিফিকেশন নেই।'),
              if (widget.st.notes.isNotEmpty)
                CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(children: [for (final (i, n) in widget.st.notes.indexed) noteRow(n, last: i == widget.st.notes.length - 1, onTap: () => openNote(context, widget.st, n))]),
                ),
            ]),
          ),
        ),
      );
}


/// The agent's own account as a PDF, in taka only: what came, what was
/// sent, commission, what is still owed, for the chosen period.
PdfDoc agentOwnPdf(AgentState st, Period p) {
  final now = DateTime.now();
  final txns = st.txns.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final sent = txns.where((x) => x.status == 'sent').toList();
  final waiting = txns.where((x) => x.pending).toList();
  final pays = st.payments.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final doc = PdfDoc(
    '${st.name} — হিসাব',
    subtitle: '${p.label} · ${st.owner}-এর সাথে · সব হিসাব টাকায়',
    footer: 'রেমিট খাতা (Owlgorithm Labs) · ${st.name} · তৈরি ${dateShort(now)} ${bn('${now.year}')}, ${timeText(now)}',
  );
  doc.tiles([
    (st.owed >= 0 ? '${st.owner} আপনাকে দেবেন (এখন পর্যন্ত মোট)' : 'আপনার কাছে ${st.owner}-এর অগ্রিম', taka(st.owed.abs())),
    ('এই সময়ে পাঠালেন', '${bn('${sent.length}')}টা · ${taka(sent.fold<double>(0, (s, x) => s + x.total))}'),
    ('এই সময়ে কমিশন', taka(sent.fold<double>(0, (s, x) => s + x.commission))),
    ('এই সময়ে পেয়েছেন', '${bn('${pays.length}')} বার · ${taka(pays.fold<double>(0, (s, x) => s + x.taka))}'),
    if (waiting.isNotEmpty) ('পাঠানোর অপেক্ষায়', '${bn('${waiting.length}')}টা · ${taka(waiting.fold<double>(0, (s, x) => s + x.total))}'),
  ]);
  doc.heading('যা পাঠালেন');
  doc.table(['নং / সময়', 'কী / নম্বর', 'টাকা', 'উত্তর / TrxID', 'টাকা পেয়েছেন'], [
    for (final x in sent)
      [
        '#${bn('${x.no}')}\n${dateShort(x.sentAt ?? x.at)}\n${timeText(x.sentAt ?? x.at)}',
        '${_service(x)}\n${bdShow(x.number)}',
        bnNum(x.total),
        [if (x.reply.isNotEmpty) bn(x.reply), if (x.trxId.isNotEmpty) x.trxId, if (x.fault != null) 'ভুল নম্বর'].join('\n'),
        x.paid ? 'পেয়েছি' : 'পাইনি',
      ],
  ], flex: [1.3, 2, 1.2, 2, 1.1], right: {2});
  doc.heading('${st.owner} যা দিলেন');
  doc.table(['সময়', 'কীভাবে', 'রেফ / নোট', 'টাকা'], [
    for (final x in pays)
      [
        '${dateShort(x.at)}\n${timeText(x.at)}',
        '${payWayName(x.way)}${x.count > 0 ? '\n${bn('${x.count}')}টা লেনদেনের' : ''}',
        [if (x.ref.isNotEmpty) 'রেফ ${x.ref}', if (x.note.isNotEmpty) x.note].join('\n'),
        bnNum(x.taka),
      ],
  ], flex: [1.3, 1.6, 2, 1.2], right: {3});
  if (waiting.isNotEmpty) {
    doc.heading('এখনো পাঠানো হয়নি');
    doc.table(['নং / সময়', 'কী / নম্বর', 'টাকা', 'অবস্থা'], [
      for (final x in waiting)
        ['#${bn('${x.no}')}\n${dateShort(x.at)}', '${_service(x)}\n${bdShow(x.number)}', bnNum(x.total), x.hasProblem ? 'সমস্যা: ${x.problem}' : 'অপেক্ষায়'],
    ], flex: [1.3, 2, 1.2, 2], right: {2});
  }
  return doc;
}
