import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'agent.dart';
import 'cash.dart';
import 'customers.dart';
import 'kit.dart';
import '../core/lang.dart';
import 'more.dart';
import 'send.dart';
import 'txn.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.h});
  final Hisab h;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _tab = 0;
  ClipTrx? _clip;
  final _pages = PageController();
  Hisab get h => widget.h;

  static const tabs = [
    (Icons.home_rounded, 'হোম'),
    (Icons.people_alt_rounded, 'গ্রাহক'),
    (Icons.storefront_rounded, 'এজেন্ট'),
    (Icons.bar_chart_rounded, 'রিপোর্ট'),
    (Icons.grid_view_rounded, 'অন্যান্য'),
  ];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkClipboard());
    // Other admins' and the agents' changes come in while the app is open.
    if (h.session != null) _timer = Timer.periodic(const Duration(seconds: 30), (_) => h.sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Future<void> checkClipboard() async {
    final c = await h.clipboardTrx();
    if (mounted) setState(() => _clip = c);
  }

  void goTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _pages.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(h: h, clip: _clip, onClipDone: () => setState(() => _clip = null), onTab: goTab),
      CustomersTab(h: h),
      AgentTab(h: h),
      ReportTab(h: h),
      OthersTab(h: h),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pages,
          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
          onPageChanged: (i) => setState(() => _tab = i),
          children: [for (final p in pages) KeepTab(child: p)],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.line))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          for (final (i, (icon, label)) in tabs.indexed)
            Expanded(
              child: Semantics(
                selected: _tab == i,
                button: true,
                label: label,
                child: InkWell(
                  onTap: () => goTab(i),
                  child: SizedBox(
                    height: 64,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(color: _tab == i ? K.blueTint : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, size: 23, color: _tab == i ? K.blue : const Color(0xFF8A8A8A)),
                      ),
                      const SizedBox(height: 2),
                      Tx(label, style: t(11.5, w: _tab == i ? FontWeight.w600 : FontWeight.w400, c: _tab == i ? K.blue : const Color(0xFF8A8A8A))),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Keeps a tab's scroll position and state while swiping between tabs.
class KeepTab extends StatefulWidget {
  const KeepTab({super.key, required this.child});
  final Widget child;

  @override
  State<KeepTab> createState() => _KeepTabState();
}

class _KeepTabState extends State<KeepTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.h, required this.clip, required this.onClipDone, required this.onTab});
  final Hisab h;
  final ClipTrx? clip;
  final VoidCallback onClipDone;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final d = h.d;
        final now = h.now;
        final today = d.txns.where((x) => !x.cancelled && sameDay(x.at, now)).toList()..sort((a, b) => b.at.compareTo(a.at));
        final todaySar = today.fold<double>(0, (s, x) => s + x.sarAmount);
        final todayTaka = today.fold<double>(0, (s, x) => s + x.taka);
        final due = totalCustomerDue(d);
        final dueCount = d.customers.where((c) => customerDue(d, c.id) > 0).length;
        final agent = d.agents.isEmpty ? null : d.agents.first;
        final owed = agent == null ? 0.0 : agentOwed(d, agent.id);
        final waiting = h.waiting;
        final promises = h.promisesDue;
        final backupOld = d.settings.lastBackup == null ? d.txns.length > 5 : now.difference(d.settings.lastBackup!).inDays >= 7;
        final recent = [...d.txns]..sort((a, b) => b.at.compareTo(a.at));
        final shown = recent.take(8).toList();

        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Tx('আসসালামু আলাইকুম,', style: t(13.5, c: K.muted)),
                Tx(d.settings.ownerName, style: t(21, w: FontWeight.w700)),
              ]),
            ),
            SyncBadge(h: h),
            const SizedBox(width: 8),
            CircleBtn(icon: Icons.settings_outlined, label: 'সেটিংস', dot: backupOld && h.session == null, onTap: () => push(context, SettingsScreen(h: h))),
          ]),
          const SizedBox(height: 16),
          if (clip != null) ...[ClipCard(h: h, clip: clip!, onDone: onClipDone), const SizedBox(height: 12)],
          CardBox(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            onTap: () => push(context, CashScreen(h: h)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Tx(h.session == null ? 'হাতে থাকা উচিত' : 'আমার হাতে থাকা উচিত', style: t(13.5, c: K.muted))),
                Tx('সব লেনদেন', style: t(13, c: K.blue)),
                const Icon(Icons.chevron_right_rounded, color: K.blue, size: 20),
              ]),
              const SizedBox(height: 2),
              Tx(sar(h.myCash), style: t(32, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Tx('আজ ${bn('${today.length}')}টা লেনদেন · ${sar(todaySar)} · ${taka(todayTaka)}', style: t(13, c: K.muted)),
              if (h.session != null && h.isOwner && adminsIn(d).keys.any((k) => k != 0 && k != h.meId))
                Tx('সব এডমিন মিলে ${sar(cashInHand(d))}', style: t(13, w: FontWeight.w600, c: K.navy)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CardBox(
                onTap: () => onTab(1),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx('গ্রাহকের বাকি', style: t(13, c: K.muted)),
                  const SizedBox(height: 4),
                  Tx(sar(due), style: t(18, w: FontWeight.w700, c: due > 0 ? K.red : K.ink)),
                  Tx(dueCount > 0 ? '${bn('$dueCount')} জনের কাছে' : 'কারও বাকি নেই', style: t(12.5, c: K.muted)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CardBox(
                onTap: () => onTab(2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx(owed >= 0 ? 'এজেন্টকে দিতে হবে' : 'এজেন্টের কাছে অগ্রিম', style: t(13, c: K.muted)),
                  const SizedBox(height: 4),
                  Tx(taka(owed.abs()), style: t(18, w: FontWeight.w700, c: owed > 0 ? K.navy : K.ink)),
                  Tx(agent?.name ?? '', style: t(12.5, c: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (h.can('send') || h.can('deposit'))
            Row(children: [
              if (h.can('send')) Expanded(child: Pill(label: 'নতুন পাঠানো', icon: Icons.north_east_rounded, onTap: () => push(context, PickCustomer(h: h, forDeposit: false)))),
              if (h.can('send') && h.can('deposit')) const SizedBox(width: 10),
              if (h.can('deposit')) Expanded(child: Pill(label: 'রিয়াল জমা', icon: Icons.south_west_rounded, color: K.navy, onTap: () => push(context, PickCustomer(h: h, forDeposit: true)))),
            ]),
          if (h.can('agent_pay') && d.agents.isNotEmpty) ...[
            const SizedBox(height: 10),
            Pill(label: 'এজেন্টকে পরিশোধ', icon: Icons.payments_outlined, color: K.green, onTap: () => payAgentFlow(context, h)),
          ],
          if (waiting.isNotEmpty) ...[
            const SizedBox(height: 12),
            CardBox(
              color: K.redTint,
              onTap: () => waiting.length == 1 ? push(context, TxnScreen(h: h, id: waiting.first.id)) : push(context, WaitingScreen(h: h)),
              child: Row(children: [
                dotIcon(Icons.hourglass_top_rounded, Colors.white, K.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx('${bn('${waiting.length}')}টা লেনদেন এজেন্টের পাঠানোর অপেক্ষায়', style: t(15, w: FontWeight.w600, c: K.red)),
                    Tx('এজেন্টের রিপ্লাই (যেমন 1042 10000-667) কপি করে অ্যাপে ফিরুন', style: t(12.5, c: K.red)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: K.red),
              ]),
            ),
          ],
          if (promises.isNotEmpty) ...[
            const SizedBox(height: 12),
            CardBox(
              color: K.amberTint,
              onTap: () => promises.length == 1 ? push(context, CustomerScreen(h: h, id: promises.first.id)) : push(context, PromisesScreen(h: h)),
              child: Row(children: [
                dotIcon(Icons.notifications_active_outlined, Colors.white, K.amberText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx('${bn('${promises.length}')} জনের বাকি দেওয়ার দিন এসেছে', style: t(15, w: FontWeight.w600, c: K.amberText)),
                    Tx(promises.map((c) => c.name).take(3).join(', '), style: t(12.5, c: K.amberText), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: K.amberText),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          SectionHead('সাম্প্রতিক লেনদেন', action: recent.isEmpty ? null : 'সব দেখুন', onAction: () => push(context, AllTxnsScreen(h: h))),
          if (recent.isEmpty)
            const Note('এখনো কোনো লেনদেন নেই। "নতুন পাঠানো" চাপুন।', icon: Icons.lightbulb_outline_rounded)
          else
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (final (i, x) in shown.indexed) TxnRow(h: h, t: x, last: i == shown.length - 1),
              ]),
            ),
        ]);
      });
}

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// One send in a list: who, to which number, riyal and status.
class TxnRow extends StatelessWidget {
  const TxnRow({super.key, required this.h, required this.t, this.last = false, this.showCustomer = true});
  final Hisab h;
  final Txn t;
  final bool last;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final c = customerById(h.d, t.customerId);
    final (label, color) = switch (t.status) {
      TxnStatus.pending => ('পাঠানোর অপেক্ষায়', K.red),
      TxnStatus.sent => ('পৌঁছেছে', K.green),
      TxnStatus.cancelled => ('বাতিল', K.muted),
    };
    final due = t.sarDueAtSend;
    final (subLabel, subColor) = t.fault != null
        ? ('ভুল নম্বর', K.red)
        : t.status == TxnStatus.sent && due > 0
            ? ('বাকি ${bnNum(due, decimals: 2)}', K.red)
            : (label, color);
    return Row2(
      lead: showCustomer ? Avatar(h: h, name: c?.name ?? '?', photo: c?.photo, size: 42) : dotIcon(t.kind.isTopUp ? Icons.phone_android_rounded : Icons.north_east_rounded, K.blueTint, K.blue),
      title: showCustomer ? (c?.name ?? 'গ্রাহক নেই') : (t.recipientLabel.isEmpty ? bdShow(t.number) : t.recipientLabel),
      sub: '#${bn('${t.no}')} · ${dateShort(t.at)}, ${timeText(t.at)} · ${serviceName(t)} ${bdMasked(t.number)}${t.byName.isEmpty ? '' : ' · ${t.byName}'}',
      value: sar(t.sarAmount),
      valueColor: t.cancelled ? K.muted : K.ink,
      valueSub: subLabel,
      valueSubColor: subColor,
      last: last,
      onTap: () => push(context, TxnScreen(h: h, id: t.id)),
    );
  }
}

/// The agent's reply was copied in WhatsApp: put it on the right send.
/// Nothing is saved until a send is tapped.
class ClipCard extends StatelessWidget {
  const ClipCard({super.key, required this.h, required this.clip, required this.onDone});
  final Hisab h;
  final ClipTrx clip;
  final VoidCallback onDone;

  Future<void> _use(BuildContext context, Txn w) async {
    final amount = clip.reply.amount;
    if (amount != null && (w.agentTaka - amount).abs() >= 0.5 && (w.taka - amount).abs() >= 0.5) {
      final ok = await confirm(context, 'টাকা মিলছে না', 'উত্তরে ${bnNum(amount)} টাকা, কিন্তু #${bn('${w.no}')}-এ ${taka(w.agentTaka)}। তবুও এটাতে বসাবেন?', yes: 'বসান');
      if (!ok) return;
    }
    await h.markSent(w, trxId: clip.trxId, reply: clip.text.length <= 80 ? clip.text : clip.shown, tail: clip.reply.tail, who: 'me', from: 'auto');
    onDone();
    if (context.mounted) snack(context, '#${bn('${w.no}')} পৌঁছেছে');
  }

  @override
  Widget build(BuildContext context) {
    final one = clip.matches.length == 1 ? clip.matches.first : null;
    final choices = clip.matches.isEmpty ? h.waiting : clip.matches;
    return CardBox(
      color: K.greenTint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          dotIcon(Icons.content_paste_rounded, Colors.white, K.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx('এজেন্টের উত্তর কপি করা আছে', style: t(15, w: FontWeight.w600, c: K.green)),
              Tx(clip.shown, style: t(16, w: FontWeight.w700, c: K.ink)),
            ]),
          ),
          IconButton(onPressed: onDone, icon: const Icon(Icons.close_rounded), tooltip: tr('বাদ দিন')),
        ]),
        const SizedBox(height: 8),
        if (clip.reply.no == null) ...[
          Tx('এজেন্ট লেনদেন নং দেননি — নিজে মিলিয়ে দেখুন', style: t(12.5, w: FontWeight.w600, c: K.amberText)),
          const SizedBox(height: 4),
        ],
        if (one != null) ...[
          Tx('মিলেছে: #${bn('${one.no}')} · ${customerById(h.d, one.customerId)?.name ?? ''} · ${bdShow(one.number)} · ${taka(one.agentTaka)}', style: t(13.5)),
          if (clip.reply.tail.isNotEmpty) Tx('এজেন্ট যে নম্বর থেকে পাঠালেন তার শেষ ৩ সংখ্যা: ${bn(clip.reply.tail)}', style: t(12.5, c: K.muted)),
          const SizedBox(height: 10),
          Pill(label: 'ঠিক আছে, এই লেনদেনে বসান', color: K.green, height: 46, onTap: () => _use(context, one)),
        ] else ...[
          Tx(clip.matches.isEmpty ? 'কোনো লেনদেনের সাথে নিশ্চিত মিলছে না। নিজে দেখে বেছে নিন:' : 'একাধিক লেনদেনের সাথে মিলছে। কোনটা? বেছে নিন:', style: t(13.5)),
          const SizedBox(height: 6),
          for (final w in choices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Tx('#${bn('${w.no}')} · ${customerById(h.d, w.customerId)?.name ?? ''}', style: t(14.5, w: FontWeight.w500)),
              subtitle: Tx('${serviceName(w)} ${bdShow(w.number)} · ${taka(w.agentTaka)}', style: t(12.5, c: K.muted)),
              trailing: const Icon(Icons.check_circle_outline_rounded, color: K.green),
              onTap: () => _use(context, w),
            ),
        ],
      ]),
    );
  }
}

/// Whether this phone and the server agree: tap to sync now.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) {
    if (h.session == null) return const SizedBox();
    final (icon, label, color) = h.syncing
        ? (Icons.sync_rounded, 'মিলছে…', K.blue)
        : h.syncError != null
            ? (Icons.cloud_off_rounded, 'সার্ভারে পৌঁছানো যায়নি — চাপ দিয়ে আবার চেষ্টা করুন', K.red)
            : (Icons.cloud_done_rounded, h.syncedAt == null ? 'সার্ভার' : 'সার্ভারের সাথে মিলেছে · ${timeText(h.syncedAt!)}', K.green);
    return Tooltip(
      message: tr(label),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          await h.sync();
          if (context.mounted) snack(context, h.syncError == null ? 'সার্ভারের সাথে মিলেছে' : 'সার্ভারে পৌঁছানো যাচ্ছে না — ইন্টারনেট দেখুন');
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: K.card, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE6E6E6))),
          child: Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }
}

/// From the home page: choose the agent (when there are several), then pay
/// for the sends not paid yet.
Future<void> payAgentFlow(BuildContext context, Hisab h) async {
  var agents = h.d.agents;
  Agent? a = agents.length == 1 ? agents.first : null;
  a ??= await showModalBottomSheet<Agent>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Tx('কোন এজেন্টকে?', style: t(17, w: FontWeight.w600)),
        for (final x in agents)
          ListTile(
            title: Tx(x.name, style: t(15)),
            subtitle: Tx('দিতে হবে ${taka(agentOwed(h.d, x.id))}', style: t(12.5, c: K.muted)),
            onTap: () => Navigator.pop(ctx, x),
          ),
      ]),
    ),
  );
  if (a == null || !context.mounted) return;
  await push(context, AgentPayScreen(h: h, a: a, txns: unpaidForAgent(h.d, a.id)));
}
