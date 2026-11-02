import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'agent.dart';
import 'customers.dart';
import 'kit.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkClipboard());
  }

  @override
  void dispose() {
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
          children: [for (final p in pages) KeepAlive(child: p)],
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
                      Text(label, style: t(11.5, w: _tab == i ? FontWeight.w600 : FontWeight.w400, c: _tab == i ? K.blue : const Color(0xFF8A8A8A))),
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
class KeepAlive extends StatefulWidget {
  const KeepAlive({super.key, required this.child});
  final Widget child;

  @override
  State<KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<KeepAlive> with AutomaticKeepAliveClientMixin {
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
                Text('আসসালামু আলাইকুম,', style: t(13.5, c: K.muted)),
                Text(d.settings.ownerName, style: t(21, w: FontWeight.w700)),
              ]),
            ),
            CircleBtn(icon: Icons.settings_outlined, label: 'সেটিংস', dot: backupOld, onTap: () => push(context, SettingsScreen(h: h))),
          ]),
          const SizedBox(height: 16),
          if (clip != null) ...[ClipCard(h: h, clip: clip!, onDone: onClipDone), const SizedBox(height: 12)],
          CardBox(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('হাতে থাকা উচিত', style: t(13.5, c: K.muted)),
              const SizedBox(height: 2),
              Text(sar(cashInHand(d)), style: t(32, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('আজ ${bn('${today.length}')}টা লেনদেন · ${sar(todaySar)} · ${taka(todayTaka)}', style: t(13, c: K.muted)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CardBox(
                onTap: () => onTab(1),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('গ্রাহকের বাকি', style: t(13, c: K.muted)),
                  const SizedBox(height: 4),
                  Text(sar(due), style: t(18, w: FontWeight.w700, c: due > 0 ? K.red : K.ink)),
                  Text(dueCount > 0 ? '${bn('$dueCount')} জনের কাছে' : 'কারও বাকি নেই', style: t(12.5, c: K.muted)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CardBox(
                onTap: () => onTab(2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(owed >= 0 ? 'এজেন্টকে দিতে হবে' : 'এজেন্টের কাছে অগ্রিম', style: t(13, c: K.muted)),
                  const SizedBox(height: 4),
                  Text(taka(owed.abs()), style: t(18, w: FontWeight.w700, c: owed > 0 ? K.navy : K.ink)),
                  Text(agent?.name ?? '', style: t(12.5, c: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Pill(label: 'নতুন পাঠানো', icon: Icons.north_east_rounded, onTap: () => push(context, PickCustomer(h: h, forDeposit: false)))),
            const SizedBox(width: 10),
            Expanded(child: Pill(label: 'রিয়াল জমা', icon: Icons.south_west_rounded, color: K.navy, onTap: () => push(context, PickCustomer(h: h, forDeposit: true)))),
          ]),
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
                    Text('${bn('${waiting.length}')}টা লেনদেনে এজেন্টের উত্তর বাকি', style: t(15, w: FontWeight.w600, c: K.red)),
                    Text('এজেন্টের রিপ্লাই (যেমন 1042 10000-667) কপি করে অ্যাপে ফিরুন', style: t(12.5, c: K.red)),
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
                    Text('${bn('${promises.length}')} জনের বাকি দেওয়ার দিন এসেছে', style: t(15, w: FontWeight.w600, c: K.amberText)),
                    Text(promises.map((c) => c.name).take(3).join(', '), style: t(12.5, c: K.amberText), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      TxnStatus.pending => ('উত্তর বাকি', K.red),
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
      sub: '#${bn('${t.no}')} · ${dateShort(t.at)}, ${timeText(t.at)} · ${serviceName(t)} ${bdMasked(t.number)}',
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
    await h.markSent(w, trxId: clip.trxId, reply: clip.text.length <= 80 ? clip.text : clip.shown, tail: clip.reply.tail, who: 'me', from: 'কপি থেকে');
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
              Text('এজেন্টের উত্তর কপি করা আছে', style: t(15, w: FontWeight.w600, c: K.green)),
              Text(clip.shown, style: t(16, w: FontWeight.w700, c: K.ink)),
            ]),
          ),
          IconButton(onPressed: onDone, icon: const Icon(Icons.close_rounded), tooltip: 'বাদ দিন'),
        ]),
        const SizedBox(height: 8),
        if (clip.reply.no == null) ...[
          Text('এজেন্ট লেনদেন নং দেননি — নিজে মিলিয়ে দেখুন', style: t(12.5, w: FontWeight.w600, c: K.amberText)),
          const SizedBox(height: 4),
        ],
        if (one != null) ...[
          Text('মিলেছে: #${bn('${one.no}')} · ${customerById(h.d, one.customerId)?.name ?? ''} · ${bdShow(one.number)} · ${taka(one.agentTaka)}', style: t(13.5)),
          if (clip.reply.tail.isNotEmpty && !one.number.endsWith(clip.reply.tail))
            Text('শেষ ৩ সংখ্যা ${bn(clip.reply.tail)} — প্রাপকের নম্বরের সাথে মেলে না (এজেন্টের নম্বর হতে পারে)', style: t(12.5, c: K.muted)),
          const SizedBox(height: 10),
          Pill(label: 'ঠিক আছে, এই লেনদেনে বসান', color: K.green, height: 46, onTap: () => _use(context, one)),
        ] else ...[
          Text(clip.matches.isEmpty ? 'কোনো লেনদেনের সাথে নিশ্চিত মিলছে না। নিজে দেখে বেছে নিন:' : 'একাধিক লেনদেনের সাথে মিলছে। কোনটা? বেছে নিন:', style: t(13.5)),
          const SizedBox(height: 6),
          for (final w in choices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('#${bn('${w.no}')} · ${customerById(h.d, w.customerId)?.name ?? ''}', style: t(14.5, w: FontWeight.w500)),
              subtitle: Text('${serviceName(w)} ${bdShow(w.number)} · ${taka(w.agentTaka)}', style: t(12.5, c: K.muted)),
              trailing: const Icon(Icons.check_circle_outline_rounded, color: K.green),
              onTap: () => _use(context, w),
            ),
        ],
      ]),
    );
  }
}
