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
  Hisab get h => widget.h;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkClipboard());
  }

  Future<void> checkClipboard() async {
    final c = await h.clipboardTrx();
    if (mounted) setState(() => _clip = c);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(h: h, clip: _clip, onClipDone: () => setState(() => _clip = null), onTab: (i) => setState(() => _tab = i)),
      CustomersTab(h: h),
      AgentTab(h: h),
      ReportTab(h: h),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.line))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          for (final (i, icon, label) in [
            (0, Icons.home_rounded, 'হোম'),
            (1, Icons.people_alt_rounded, 'গ্রাহক'),
            (2, Icons.storefront_rounded, 'এজেন্ট'),
            (3, Icons.bar_chart_rounded, 'রিপোর্ট'),
          ])
            Expanded(
              child: Semantics(
                selected: _tab == i,
                button: true,
                label: label,
                child: InkWell(
                  onTap: () => setState(() => _tab = i),
                  child: SizedBox(
                    height: 62,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 24, color: _tab == i ? K.blue : const Color(0xFF8A8A8A)),
                      const SizedBox(height: 2),
                      Text(label, style: t(12, w: _tab == i ? FontWeight.w600 : FontWeight.w400, c: _tab == i ? K.blue : const Color(0xFF8A8A8A))),
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

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.h, required this.clip, required this.onClipDone, required this.onTab});
  final Hisab h;
  final ClipTrx? clip;
  final VoidCallback onClipDone;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
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
    final backupOld = d.settings.lastBackup == null ? d.txns.length > 5 : now.difference(d.settings.lastBackup!).inDays >= 7;
    final recent = [...d.txns]..sort((a, b) => b.at.compareTo(a.at));

    return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('আসসালামু আলাইকুম,', style: t(13.5, c: K.muted)),
            Text(d.settings.ownerName, style: t(21, w: FontWeight.w700)),
          ]),
        ),
        CircleBtn(icon: Icons.history_rounded, label: 'কাজের লগ', onTap: () => push(context, LogScreen(h: h))),
        const SizedBox(width: 8),
        CircleBtn(icon: Icons.settings_outlined, label: 'সেটিংস', dot: backupOld, onTap: () => push(context, SettingsScreen(h: h))),
      ]),
      const SizedBox(height: 16),
      if (clip != null) ...[_ClipCard(h: h, clip: clip!, onDone: onClipDone), const SizedBox(height: 12)],
      CardBox(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('হাতে থাকা উচিত', style: t(13.5, c: K.muted)),
          const SizedBox(height: 2),
          Text(sar(cashInHand(d)), style: t(32, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('আজ ${bn('${today.length}')}টা লেনদেন · ${sar(todaySar)} · ${taka(todayTaka)}', style: t(13, c: K.muted)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Pill(label: 'নতুন পাঠানো', icon: Icons.north_east_rounded, onTap: () => push(context, PickCustomer(h: h, forDeposit: false)))),
            const SizedBox(width: 10),
            Expanded(child: Pill(label: 'রিয়াল জমা', icon: Icons.south_west_rounded, color: K.navy, onTap: () => push(context, PickCustomer(h: h, forDeposit: true)))),
          ]),
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
              Text(sar(due), style: t(18, w: FontWeight.w700, c: due > 0 ? K.red : K.green)),
              Text('${bn('$dueCount')} জনের কাছে', style: t(12.5, c: K.muted)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CardBox(
            onTap: () => onTab(2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('এজেন্টকে দিতে হবে', style: t(13, c: K.muted)),
              const SizedBox(height: 4),
              Text(taka(owed), style: t(18, w: FontWeight.w700, c: owed > 0 ? K.navy : K.green)),
              Text(agent?.name ?? '', style: t(12.5, c: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
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
                Text('${bn('${waiting.length}')}টা লেনদেনের TrxID বাকি', style: t(15, w: FontWeight.w600, c: K.red)),
                Text('এজেন্টের রিপ্লাই থেকে TrxID কপি করে অ্যাপে ফিরুন', style: t(12.5, c: K.red)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: K.red),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SoftPill(label: 'দিন শেষ', icon: Icons.nightlight_outlined, onTap: () => push(context, DayCloseScreen(h: h)))),
        const SizedBox(width: 8),
        Expanded(child: SoftPill(label: 'খরচ', icon: Icons.receipt_long_outlined, onTap: () => push(context, ExpenseScreen(h: h)))),
      ]),
      const SizedBox(height: 10),
      SectionHead('সাম্প্রতিক লেনদেন', action: recent.isEmpty ? null : 'সব দেখুন', onAction: () => push(context, AllTxnsScreen(h: h))),
      if (recent.isEmpty)
        const Note('এখনো কোনো লেনদেন নেই। "নতুন পাঠানো" চাপুন।', icon: Icons.lightbulb_outline_rounded)
      else
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: [
            for (final (i, x) in recent.take(8).indexed) TxnRow(h: h, t: x, last: i == recent.take(8).length - 1),
          ]),
        ),
    ]);
  }
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
      TxnStatus.pending => ('TrxID বাকি', K.red),
      TxnStatus.sent => ('পৌঁছেছে', K.green),
      TxnStatus.cancelled => ('বাতিল', K.muted),
    };
    final due = t.sarDueAtSend;
    return Row2(
      lead: showCustomer ? Avatar(h: h, name: c?.name ?? '?', photo: c?.photo, size: 42) : dotIcon(Icons.north_east_rounded, K.blueTint, K.blue),
      title: showCustomer ? (c?.name ?? 'গ্রাহক নেই') : (t.recipientLabel.isEmpty ? bdShow(t.number) : t.recipientLabel),
      sub: '#${bn('${t.no}')} · ${timeText(t.at)} · ${t.method.bnName} ${bdMasked(t.number)}',
      value: sar(t.sarAmount),
      valueColor: t.cancelled ? K.muted : K.ink,
      valueSub: t.status == TxnStatus.sent && due > 0 ? 'বাকি ${bnNum(due, decimals: 2)}' : label,
      valueSubColor: t.status == TxnStatus.sent && due > 0 ? K.red : color,
      last: last,
      onTap: () => push(context, TxnScreen(h: h, id: t.id)),
    );
  }
}

/// A TrxID was copied in WhatsApp: put it on the right send with one tap.
class _ClipCard extends StatelessWidget {
  const _ClipCard({required this.h, required this.clip, required this.onDone});
  final Hisab h;
  final ClipTrx clip;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final one = clip.matches.length == 1 ? clip.matches.first : null;
    return CardBox(
      color: K.greenTint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          dotIcon(Icons.content_paste_rounded, Colors.white, K.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('কপি করা TrxID পাওয়া গেছে', style: t(15, w: FontWeight.w600, c: K.green)),
              Text(clip.trxId, style: t(16, w: FontWeight.w700, c: K.ink)),
            ]),
          ),
          IconButton(onPressed: onDone, icon: const Icon(Icons.close_rounded), tooltip: 'বাদ দিন'),
        ]),
        const SizedBox(height: 8),
        if (one != null) ...[
          Text('#${bn('${one.no}')} · ${customerById(h.d, one.customerId)?.name ?? ''} · ${bdShow(one.number)} · ${taka(one.agentTaka)}', style: t(13.5)),
          const SizedBox(height: 10),
          Pill(
            label: 'এই লেনদেনে বসান',
            color: K.green,
            height: 46,
            onTap: () async {
              await h.setTrxId(one, clip.trxId, who: 'app', from: 'কপি থেকে');
              onDone();
              if (context.mounted) snack(context, '#${bn('${one.no}')} পৌঁছেছে');
            },
          ),
        ] else ...[
          Text('কোন লেনদেনের? বেছে নিন:', style: t(13.5)),
          const SizedBox(height: 6),
          for (final w in (clip.matches.isEmpty ? h.waiting : clip.matches))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('#${bn('${w.no}')} · ${customerById(h.d, w.customerId)?.name ?? ''}', style: t(14.5, w: FontWeight.w500)),
              subtitle: Text('${bdShow(w.number)} · ${taka(w.agentTaka)}', style: t(12.5, c: K.muted)),
              trailing: const Icon(Icons.check_circle_outline_rounded, color: K.green),
              onTap: () async {
                await h.setTrxId(w, clip.trxId, who: 'app', from: 'কপি থেকে');
                onDone();
                if (context.mounted) snack(context, '#${bn('${w.no}')} পৌঁছেছে');
              },
            ),
        ],
      ]),
    );
  }
}
