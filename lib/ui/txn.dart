import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'customers.dart';
import 'home.dart';
import 'kit.dart';
import 'send.dart';

/// Listens to the data so a screen redraws after every change.
class Live extends StatelessWidget {
  const Live({super.key, required this.h, required this.builder});
  final Hisab h;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: h, builder: (context, _) => builder(context));
}

class TxnScreen extends StatelessWidget {
  const TxnScreen({super.key, required this.h, required this.id, this.fresh = false});
  final Hisab h;
  final String id;
  final bool fresh;

  @override
  Widget build(BuildContext context) => Live(h: h, builder: (context) {
        final x = h.txnById(id);
        if (x == null) return const Screen(title: 'লেনদেন', body: SizedBox());
        return _TxnBody(h: h, x: x, fresh: fresh);
      });
}

class _TxnBody extends StatelessWidget {
  const _TxnBody({required this.h, required this.x, required this.fresh});
  final Hisab h;
  final Txn x;
  final bool fresh;

  Future<void> _enterTrx(BuildContext context) async {
    final clip = await h.s.device.clipboard();
    final found = clip == null ? <String>[] : trxIdsIn(clip);
    if (!context.mounted) return;
    final v = await askText(context, 'TrxID লিখুন', hint: 'যেমন BJ7K9X2Q1M', initial: found.isEmpty ? x.trxId : found.first);
    if (v == null || v.trim().isEmpty) return;
    final id = en(v).trim().toUpperCase();
    final usedBy = h.d.txns.where((o) => o.id != x.id && o.trxId == id).toList();
    if (usedBy.isNotEmpty && context.mounted) {
      if (!await confirm(context, 'এই TrxID আগে ব্যবহার হয়েছে', '#${bn('${usedBy.first.no}')}-এ এই TrxID আছে। তবুও বসাবেন?', yes: 'বসান')) return;
    }
    await h.setTrxId(x, id, from: found.contains(id) ? 'কপি থেকে' : 'হাতে লেখা');
  }

  @override
  Widget build(BuildContext context) {
    final c = customerById(h.d, x.customerId);
    final a = agentById(h.d, x.agentId);
    final (status, color, tint) = switch (x.status) {
      TxnStatus.pending => ('TrxID বাকি', K.red, K.redTint),
      TxnStatus.sent => ('পৌঁছেছে', K.green, K.greenTint),
      TxnStatus.cancelled => ('বাতিল', K.muted, K.chip),
    };
    final logs = h.d.log.where((e) => e.ref == x.id).toList().reversed.toList();
    return Screen(
      title: 'লেনদেন #${bn('${x.no}')}',
      trailing: x.cancelled
          ? null
          : CircleBtn(
              icon: Icons.edit_outlined,
              label: 'সংশোধন',
              onTap: () {
                if (c == null) return;
                push(context, EntryScreen(h: h, c: c, editing: x));
              },
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        if (fresh && x.status == TxnStatus.pending) ...[
          const Note('মেসেজ হোয়াটসঅ্যাপে লেখা আছে — সেখানে Send চাপুন। এজেন্ট রিপ্লাইতে TrxID দিলে সেটা কপি করে অ্যাপে ফিরে আসুন, নিজে থেকেই ধরবে।', icon: Icons.info_outline_rounded),
          const SizedBox(height: 12),
        ],
        CardBox(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
              child: Text(status, style: t(13, w: FontWeight.w600, c: color)),
            ),
            const SizedBox(height: 10),
            Text(taka(x.taka), style: t(30, w: FontWeight.w700, c: x.cancelled ? K.muted : K.ink)),
            Text('${sar(x.sarAmount)} × ${rateText(x.rate)}${x.fee > 0 ? ' · খরচ ${taka(x.fee)}' : ''}', style: t(13.5, c: K.muted)),
            const SizedBox(height: 14),
            _Steps(x: x),
          ]),
        ),
        const SizedBox(height: 12),
        CardBox(
          child: Column(children: [
            _kv('গ্রাহক', c?.name ?? '—', onTap: c == null ? null : () => push(context, CustomerScreen(h: h, id: c.id))),
            _kv('প্রাপক', '${x.recipientLabel.isEmpty ? '' : '${x.recipientLabel} · '}${x.method.bnName} · ${x.kind.bnName}'),
            _kv('নম্বর', x.method == Method.bank ? bn(x.number) : bdShow(x.number)),
            _kv('রিয়াল', '${x.pay.bnName}${x.pay == Pay.partial ? ' · দিলেন ${sar(x.sarPaid)}' : ''}${x.sarDueAtSend > 0 ? ' · বাকি ${sar(x.sarDueAtSend)}' : ''}'),
            _kv('এজেন্ট', '${a?.name ?? '—'} · ${taka(x.agentTaka)}${x.agentPaymentId != null ? ' · শোধ' : ''}'),
            _kv('সময়', '${dateShort(x.at)}, ${timeText(x.at)}'),
            _kv('TrxID', x.trxId.isEmpty ? '—' : x.trxId, last: true, bold: true),
          ]),
        ),
        const SizedBox(height: 14),
        if (!x.cancelled) ...[
          if (x.status == TxnStatus.pending) ...[
            Pill(label: 'TrxID বসান (কপি থাকলে নিজে বসবে)', icon: Icons.content_paste_rounded, color: K.green, onTap: () => _enterTrx(context)),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(
              child: SoftPill(
                label: 'এজেন্টকে আবার',
                icon: Icons.chat_outlined,
                onTap: a == null
                    ? null
                    : () async {
                        final ok = await h.s.device.whatsapp(a.whatsapp, agentMessage(x));
                        await h.logMessage(x, ok ? 'এজেন্টকে আবার মেসেজ' : 'হোয়াটসঅ্যাপ খোলা যায়নি');
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SoftPill(
                label: 'গ্রাহককে রসিদ',
                icon: Icons.receipt_outlined,
                onTap: c == null
                    ? null
                    : () async {
                        final text = customerReceipt(h.d, x);
                        if (c.phone.trim().isNotEmpty) {
                          await h.s.device.whatsapp(c.phone, text);
                        } else {
                          await h.s.device.shareText(text);
                        }
                        await h.note('txn', 'গ্রাহককে রসিদ · #${bn('${x.no}')}', c.name);
                      },
              ),
            ),
          ]),
          if (x.status == TxnStatus.sent) ...[
            const SizedBox(height: 8),
            SoftPill(label: 'TrxID বদলান', icon: Icons.edit_note_rounded, onTap: () => _enterTrx(context)),
          ],
          const SizedBox(height: 8),
          SoftPill(
            label: 'লেনদেন বাতিল',
            icon: Icons.block_rounded,
            color: K.red,
            onTap: () async {
              final reason = await askText(context, 'কেন বাতিল?', hint: 'যেমন ভুল নম্বর', ok: 'বাতিল করুন');
              if (reason == null) return;
              await h.cancelTxn(x, reason);
              if (a != null && x.trxId.isEmpty && context.mounted && await confirm(context, 'এজেন্টকে জানাবেন?', 'এজেন্টকে "এটা পাঠাবেন না" মেসেজ যাবে।', yes: 'জানান')) {
                await h.s.device.whatsapp(a.whatsapp, agentCancelMessage(x));
                await h.logMessage(x, 'এজেন্টকে বাতিলের মেসেজ');
              }
            },
          ),
        ],
        const SizedBox(height: 10),
        SectionHead('এই লেনদেনের লগ'),
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: [for (final (i, e) in logs.indexed) LogRow(e: e, last: i == logs.length - 1)]),
        ),
      ]),
    );
  }

  Widget _kv(String k, String v, {bool last = false, bool bold = false, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 72, child: Text(k, style: t(13.5, c: K.muted))),
            Expanded(child: Text(v, textAlign: TextAlign.right, style: t(14.5, w: bold ? FontWeight.w700 : FontWeight.w500, c: onTap != null ? K.blue : K.ink))),
          ]),
        ),
      );
}

/// সংরক্ষিত → এজেন্টকে গেছে → TrxID → পৌঁছেছে
class _Steps extends StatelessWidget {
  const _Steps({required this.x});
  final Txn x;

  @override
  Widget build(BuildContext context) {
    final done = x.cancelled ? 1 : (x.status == TxnStatus.sent ? 3 : 2);
    const labels = ['সংরক্ষিত', 'এজেন্টকে গেছে', 'পৌঁছেছে'];
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        Expanded(
          child: Column(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: i < done ? (x.cancelled ? K.muted : K.blue) : const Color(0xFFE6E6E6)),
              child: Icon(i < done ? Icons.check_rounded : Icons.more_horiz_rounded, size: 16, color: i < done ? Colors.white : K.muted),
            ),
            const SizedBox(height: 4),
            Text(labels[i], style: t(11.5, c: i < done ? K.ink : K.muted), textAlign: TextAlign.center),
          ]),
        ),
      ],
    ]);
  }
}

class LogRow extends StatelessWidget {
  const LogRow({super.key, required this.e, this.last = false});
  final LogEntry e;
  final bool last;

  static (IconData, Color, Color) look(String kind) => switch (kind) {
        'txn' => (Icons.north_east_rounded, K.blueTint, K.blue),
        'recv' => (Icons.south_west_rounded, K.greenTint, K.green),
        'agent' => (Icons.storefront_rounded, K.navySoft, K.navy),
        'edit' => (Icons.edit_rounded, K.amberTint, K.amberText),
        'cust' => (Icons.person_rounded, const Color(0xFFEDE7FB), const Color(0xFF5B36B0)),
        _ => (Icons.settings_rounded, K.chip, K.muted),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = look(e.kind);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        dotIcon(icon, bg, fg, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(e.title, style: t(14.5, w: FontWeight.w600))),
              Text(timeText(e.at), style: t(12, c: K.muted)),
            ]),
            const SizedBox(height: 2),
            Text(e.detail, style: t(13, c: const Color(0xFF4A4A4A), h: 1.45)),
            Text('${dateShort(e.at)} · ${e.who == 'app' ? 'অ্যাপ নিজে' : 'আপনি'}', style: t(11.5, c: K.muted)),
          ]),
        ),
      ]),
    );
  }
}

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) => Live(h: h, builder: (context) {
        final w = h.waiting;
        return Screen(
          title: 'TrxID বাকি',
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
            if (w.isEmpty) const Note('সব লেনদেনের TrxID এসে গেছে।', color: K.greenTint, textColor: K.green),
            if (w.isNotEmpty)
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [for (final (i, x) in w.indexed) TxnRow(h: h, t: x, last: i == w.length - 1)]),
              ),
          ]),
        );
      });
}

/// Every send, newest first, with a search.
class AllTxnsScreen extends StatefulWidget {
  const AllTxnsScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<AllTxnsScreen> createState() => _AllTxnsScreenState();
}

class _AllTxnsScreenState extends State<AllTxnsScreen> {
  final _q = TextEditingController();
  int _f = 0;

  @override
  Widget build(BuildContext context) => Live(h: widget.h, builder: (context) {
        final h = widget.h;
        final q = en(_q.text).trim().toLowerCase();
        var list = [...h.d.txns]..sort((a, b) => b.at.compareTo(a.at));
        list = list.where((x) {
          if (_f == 1 && x.status != TxnStatus.pending) return false;
          if (_f == 2 && x.sarDueAtSend <= 0) return false;
          if (_f == 3 && !x.cancelled) return false;
          if (q.isEmpty) return true;
          final c = customerById(h.d, x.customerId);
          return '${x.no}' == q.replaceAll('#', '') || x.number.contains(q) || x.trxId.toLowerCase().contains(q) || (c?.name.toLowerCase().contains(q) ?? false);
        }).toList();
        final groups = <String, List<Txn>>{};
        for (final x in list.take(300)) {
          groups.putIfAbsent(dayLabel(x.at, h.now), () => []).add(x);
        }
        return Screen(
          title: 'সব লেনদেন',
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: t(15),
              decoration: InputDecoration(
                hintText: 'নাম, নম্বর, #নং বা TrxID',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: K.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
              ),
            ),
            const SizedBox(height: 10),
            Seg<int>(items: const [(0, 'সব'), (1, 'TrxID বাকি'), (2, 'বাকিতে'), (3, 'বাতিল')], value: _f, onChanged: (v) => setState(() => _f = v)),
            const SizedBox(height: 6),
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Note('কিছু পাওয়া যায়নি।')),
            for (final g in groups.entries) ...[
              SectionHead(g.key),
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [for (final (i, x) in g.value.indexed) TxnRow(h: h, t: x, last: i == g.value.length - 1)]),
              ),
            ],
          ]),
        );
      });
}
