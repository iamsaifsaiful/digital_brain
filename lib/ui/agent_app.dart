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
import 'txn.dart' show Live;

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
            (Icons.notifications_active_rounded, 'অনুরোধ', st.waiting.length),
            (Icons.task_alt_rounded, 'সব কাজ', 0),
            (Icons.account_balance_wallet_rounded, 'টাকা', 0),
            (Icons.person_rounded, 'প্রোফাইল', st.unread),
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
    return RefreshIndicator(
      onRefresh: st.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        _header('অনুরোধ', 'আসসালামু আলাইকুম, ${st.name}', trailing: CircleBtn(icon: Icons.refresh_rounded, label: 'নতুন করে আনুন', onTap: st.refresh)),
        if (st.error != null && st.at == null) const Note('সার্ভারে পৌঁছানো যাচ্ছে না। ইন্টারনেট দেখে নিচে টেনে আবার চেষ্টা করুন।', color: K.redTint, textColor: K.red),
        if (st.loading && st.at == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (st.at != null && w.isEmpty) const Note('এখন পাঠানোর মতো কিছু নেই। নতুন অনুরোধ এলে নোটিফিকেশন আসবে।', icon: Icons.check_circle_outline_rounded),
        for (final x in w) ...[RequestCard(st: st, tx: x), const SizedBox(height: 12)],
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
    if (ok == true && context.mounted) snack(context, '#${bn('${tx.no}')} — পাঠানো হয়েছে, দোকানকে জানানো হলো');
  }

  Future<void> _problem(BuildContext context) async {
    final why = await askText(context, 'কী সমস্যা?', hint: 'যেমন নম্বর বন্ধ, ব্যালেন্স নেই', ok: 'দোকানকে জানান');
    if (why == null) return;
    try {
      await st.problem(tx, why);
      if (context.mounted) snack(context, 'দোকানকে জানানো হলো');
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
          const SizedBox(height: 12),
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
          Pill(label: _busy ? 'পাঠানো হচ্ছে…' : 'দোকানকে জানান', icon: Icons.send_rounded, color: K.green, onTap: _busy ? null : _go),
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
class _Money extends StatelessWidget {
  const _Money({required this.st});
  final AgentState st;

  @override
  Widget build(BuildContext context) {
    final comm = st.txns.where((x) => !x.cancelled).fold<double>(0, (s, x) => s + x.commission);
    return RefreshIndicator(
      onRefresh: st.refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
        _header('টাকা', ''),
        CardBox(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(st.owed >= 0 ? 'দোকান আপনাকে দেবে' : 'আপনার কাছে দোকানের অগ্রিম', style: t(13.5, c: K.muted)),
            Tx(taka(st.owed.abs()), style: t(32, w: FontWeight.w700, c: K.navy)),
            if (st.commission > 0) Tx('কমিশন হাজারে ${bnNum(st.commission, decimals: 2)} টাকা · মোট কমিশন ${taka(comm)}', style: t(12.5, c: K.muted)),
          ]),
        ),
        SectionHead('দোকান যা দিয়েছে'),
        if (st.payments.isEmpty) const Note('এখনো কিছু দেওয়া হয়নি।'),
        if (st.payments.isNotEmpty)
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, p) in st.payments.indexed)
                Row2(
                  lead: dotIcon(p.receipt != null ? Icons.receipt_long_rounded : Icons.payments_outlined, K.greenTint, K.green, size: 38),
                  title: '${payWayName(p.way)}${p.count > 0 ? ' · ${bn('${p.count}')}টা লেনদেনের' : ''}',
                  sub: '${dateShort(p.at)}, ${timeText(p.at)}${p.ref.isEmpty ? '' : ' · রেফ ${p.ref}'}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                  value: taka(p.taka),
                  valueColor: K.green,
                  valueSub: p.receipt != null ? 'রসিদ দেখুন' : null,
                  valueSubColor: K.blue,
                  last: i == st.payments.length - 1,
                  onTap: p.receipt == null ? null : () => push(context, _Receipt(st: st, p: p)),
                ),
            ]),
          ),
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
        _header('প্রোফাইল', '', trailing: LangButton(h: st.h)),
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
        Row(children: [tile('দোকান থেকে পেয়েছেন', taka(received)), const SizedBox(width: 10), tile(st.owed >= 0 ? 'আরও পাবেন' : 'অগ্রিম আছে', taka(st.owed.abs()))]),
        SectionHead('নোটিফিকেশন'),
        if (st.notes.isEmpty) const Note('কোনো নোটিফিকেশন নেই।'),
        if (st.notes.isNotEmpty)
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, n) in st.notes.take(100).indexed)
                Row2(
                  lead: dotIcon(_noteIcon(n.kind), _noteBg(n.kind), _noteFg(n.kind), size: 38),
                  title: n.title,
                  sub: '${n.body}\n${dateShort(n.at)}, ${timeText(n.at)}',
                  last: i == st.notes.take(100).length - 1,
                ),
            ]),
          ),
        const SizedBox(height: 14),
        SoftPill(
          label: 'পাসওয়ার্ড বদলান',
          icon: Icons.password_rounded,
          onTap: () async {
            final old = await askText(context, 'এখনকার পাসওয়ার্ড', obscure: true);
            if (old == null || old.isEmpty || !context.mounted) return;
            final nw = await askText(context, 'নতুন পাসওয়ার্ড (৬+ অক্ষর)', obscure: true);
            if (nw == null || nw.length < 6 || !context.mounted) return;
            try {
              await st.changePassword(old, nw);
              if (context.mounted) snack(context, 'পাসওয়ার্ড বদলেছে');
            } catch (_) {
              if (context.mounted) snack(context, 'বদলানো যায়নি — এখনকার পাসওয়ার্ড ঠিক আছে?');
            }
          },
        ),
        const SizedBox(height: 8),
        SoftPill(
          label: 'লগআউট',
          icon: Icons.logout_rounded,
          color: K.red,
          onTap: () async {
            if (await confirm(context, 'লগআউট করবেন?', 'আবার ঢুকতে লগইন আর পাসওয়ার্ড লাগবে।', yes: 'লগআউট', danger: true)) await st.h.logout();
          },
        ),
        const SizedBox(height: 16),
        MadeBy(h: st.h),
      ]),
    );
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
Widget noteRow(ServerNote n, {bool last = false}) => Row2(
      lead: dotIcon(_noteIcon(n.kind), _noteBg(n.kind), _noteFg(n.kind), size: 38),
      title: n.title,
      sub: '${n.body}\n${dateShort(n.at)}, ${timeText(n.at)}',
      last: last,
    );

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
                  child: Column(children: [for (final (i, n) in widget.st.notes.indexed) noteRow(n, last: i == widget.st.notes.length - 1)]),
                ),
            ]),
          ),
        ),
      );
}
