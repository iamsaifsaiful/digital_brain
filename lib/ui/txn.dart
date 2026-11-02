import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'customers.dart';
import 'home.dart';
import 'kit.dart';
import '../core/lang.dart';
import 'reports.dart';
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
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
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

  /// The agent's reply, typed or pasted: "10000-667", a TrxID, or both.
  Future<void> _enterReply(BuildContext context, {bool onlyTrx = false}) async {
    final clip = await h.s.device.clipboard();
    final nos = [for (final o in h.d.txns) o.no];
    final fromClip = clip != null && parseReply(clip, nos: nos).useful ? clip.trim() : '';
    if (!context.mounted) return;
    final v = await askText(
      context,
      onlyTrx ? 'TrxID লিখুন' : 'এজেন্টের উত্তর',
      hint: onlyTrx ? 'যেমন BJ7K9X2Q1M' : 'যেমন ${x.no} ${x.agentTaka.round()}-667 বা TrxID',
      initial: fromClip.length <= 60 ? fromClip : (parseReply(fromClip, nos: nos).trxIds.firstOrNull ?? ''),
    );
    if (v == null || v.trim().isEmpty || !context.mounted) return;
    final text = en(v).trim();
    final r = parseReply(text, nos: nos);
    if (r.no != null && r.no != x.no) {
      if (!await confirm(context, 'অন্য লেনদেনের উত্তর?', 'উত্তরে লেনদেন নং #${bn('${r.no}')}, কিন্তু এটা #${bn('${x.no}')}। তবুও এখানে বসাবেন?', yes: 'বসান')) return;
      if (!context.mounted) return;
    }
    var trx = r.trxIds.isEmpty ? '' : r.trxIds.first;
    if (trx.isEmpty && !r.useful) {
      // Just letters and digits typed: take it as the TrxID if it looks like one.
      final one = text.replaceAll(RegExp(r'\s'), '').toUpperCase();
      if (RegExp(r'^[A-Z0-9]{6,14}$').hasMatch(one)) trx = one;
    }
    if (trx.isEmpty && r.amount == null) {
      snack(context, 'লেনদেন নং, টাকা-শেষের ৩ সংখ্যা (যেমন ${x.no} ${x.agentTaka.round()}-667) বা TrxID দিন');
      return;
    }
    final amount = r.amount;
    if (amount != null && (x.agentTaka - amount).abs() >= 0.5 && (x.taka - amount).abs() >= 0.5) {
      if (!await confirm(context, 'টাকা মিলছে না', 'উত্তরে ${bnNum(amount)} টাকা, কিন্তু এই লেনদেনে ${taka(x.agentTaka)}। তবুও বসাবেন?', yes: 'বসান')) return;
    }
    if (trx.isNotEmpty) {
      final usedBy = h.d.txns.where((o) => o.id != x.id && o.trxId == trx).toList();
      if (usedBy.isNotEmpty && context.mounted) {
        if (!await confirm(context, 'এই TrxID আগে ব্যবহার হয়েছে', '#${bn('${usedBy.first.no}')}-এ এই TrxID আছে। তবুও বসাবেন?', yes: 'বসান')) return;
      }
    }
    await h.markSent(x, trxId: trx, reply: r.amount != null ? text : '', tail: r.tail, from: fromClip.isNotEmpty && text == en(fromClip) ? 'auto' : 'manual');
  }

  Future<void> _markFault(BuildContext context) async {
    var fault = x.fault ?? Fault.mine;
    final note = TextEditingController(text: x.faultNote);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Tx('ভুল নম্বরে গেছে — কার ভুল?', style: t(18, w: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Tx('${bdShow(x.number)} · ${taka(x.agentTaka)}', style: t(13.5, c: K.muted), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            for (final f in Fault.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CardBox(
                  border: f == fault ? K.blue : null,
                  onTap: () => set(() => fault = f),
                  child: Row(children: [
                    Icon(f == fault ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: f == fault ? K.blue : K.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Tx(f.bnName, style: t(15, w: FontWeight.w500))),
                  ]),
                ),
              ),
            const SizedBox(height: 6),
            Field(label: 'কী হয়েছিল (ইচ্ছা হলে)', controller: note),
            const SizedBox(height: 14),
            Pill(label: 'চিহ্ন দিন', color: K.red, onTap: () => Navigator.pop(ctx, true)),
          ]),
        ),
      ),
    );
    if (ok == true) await h.markFault(x, fault, note.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = customerById(h.d, x.customerId);
    final a = agentById(h.d, x.agentId);
    final (status, color, tint) = switch (x.status) {
      TxnStatus.pending => ('এজেন্টের পাঠানোর অপেক্ষায়', K.red, K.redTint),
      TxnStatus.sent => ('পৌঁছেছে', K.green, K.greenTint),
      TxnStatus.cancelled => ('বাতিল', K.muted, K.chip),
    };
    return Screen(
      title: 'লেনদেন #${bn('${x.no}')}',
      trailing: x.cancelled || !h.can('edit')
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
          Note('মেসেজ হোয়াটসঅ্যাপে লেখা আছে — সেখানে Send চাপুন। এজেন্ট রিপ্লাই দিলে (যেমন ${x.no} ${x.agentTaka.round()}-667) সেটা কপি করে অ্যাপে ফিরে আসুন।', icon: Icons.info_outline_rounded),
          const SizedBox(height: 12),
        ],
        if (x.fault != null) ...[
          CardBox(
            color: K.redTint,
            child: Row(children: [
              dotIcon(Icons.report_gmailerrorred_rounded, Colors.white, K.red, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx('ভুল নম্বরে গেছে — ${x.fault!.short} ভুল', style: t(15, w: FontWeight.w600, c: K.red)),
                  if (x.faultNote.isNotEmpty) Tx(x.faultNote, style: t(13, c: K.red)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        CardBox(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
              child: Tx(status, style: t(13, w: FontWeight.w600, c: color)),
            ),
            const SizedBox(height: 10),
            Tx(taka(x.taka), style: t(30, w: FontWeight.w700, c: x.cancelled ? K.muted : K.ink)),
            Tx('${sar(x.sarAmount)} × ${rateText(x.rate)}${x.fee > 0 ? ' · খরচ ${taka(x.fee)}' : ''}', style: t(13.5, c: K.muted)),
            const SizedBox(height: 14),
            _Steps(x: x),
          ]),
        ),
        const SizedBox(height: 12),
        CardBox(
          child: Column(children: [
            _kv('গ্রাহক', c?.name ?? '—', onTap: c == null ? null : () => push(context, CustomerScreen(h: h, id: c.id))),
            _kv('কী', '${x.kind.bnName}${x.kind.isTopUp ? (x.operator.isEmpty ? '' : ' · ${x.operator}') : ' · ${x.method.bnName}'}'),
            if (x.kind == Kind.mb) _kv('প্যাক', x.pack),
            _kv('প্রাপক', x.recipientLabel.isEmpty ? '—' : x.recipientLabel),
            _kv('নম্বর', x.method == Method.bank && !x.kind.isTopUp ? bn(x.number) : bdShow(x.number)),
            _kv('রিয়াল', '${x.pay.bnName}${x.pay == Pay.partial ? ' · দিলেন ${sar(x.sarPaid)}' : ''}${x.sarDueAtSend > 0 ? ' · বাকি ${sar(x.sarDueAtSend)}' : ''}'),
            _kv('এজেন্ট', '${a?.name ?? '—'} · ${taka(x.agentTaka)}${x.agentPaymentId != null ? ' · শোধ' : ''}'),
            _kv('সময়', '${dateShort(x.at)}, ${timeText(x.at)}'),
            if (x.byName.isNotEmpty) _kv('এডমিন', x.byName),
            _kv('এজেন্টের উত্তর', x.agentReply.isEmpty && x.trxId.isEmpty ? '—' : '${x.agentReply.isEmpty ? '' : bn(x.agentReply)}${switch (x.replyFrom) { 'auto' => ' · কপি থেকে অটো', 'manual' => ' · এডমিন নিজে বসালেন', 'agent' => ' · এজেন্টের অ্যাপ থেকে', _ => '' }}'),
            if (x.replyTail.isNotEmpty) _kv('পাঠানোর নম্বর', 'শেষ ৩ সংখ্যা ${bn(x.replyTail)}'),
            _kv('TrxID', x.trxId.isEmpty ? '—' : x.trxId, last: true, bold: true),
          ]),
        ),
        const SizedBox(height: 14),
        if (!x.cancelled) ...[
          if (x.status == TxnStatus.pending && (h.can('send') || h.can('edit'))) ...[
            Pill(label: 'এজেন্টের উত্তর বসান', icon: Icons.content_paste_rounded, color: K.green, onTap: () => _enterReply(context)),
            const SizedBox(height: 10),
          ],
          Row(children: [
            if (a == null || !a.usesApp)
              Expanded(
                child: SoftPill(
                  label: 'এজেন্টকে আবার',
                  icon: Icons.chat_outlined,
                  onTap: a == null
                      ? null
                      : () async {
                          final ok = await h.s.device.whatsapp(a.whatsapp, agentMessage(x, h.d));
                          await h.logMessage(x, ok ? 'এজেন্টকে আবার মেসেজ' : 'হোয়াটসঅ্যাপ খোলা যায়নি');
                        },
                ),
              ),
            if (a == null || !a.usesApp) const SizedBox(width: 8),
            Expanded(
              child: SoftPill(
                label: 'গ্রাহককে রসিদ',
                icon: Icons.receipt_outlined,
                onTap: c == null
                    ? null
                    : () async {
                        final text = customerReceipt(h.d, x);
                        final wa = await whatsappOf(context, h, c);
                        if (wa != null) {
                          await h.s.device.whatsapp(wa, text);
                        } else {
                          await h.s.device.shareText(text);
                        }
                        await h.note('txn', 'গ্রাহককে রসিদ · #${bn('${x.no}')}', c.name);
                      },
              ),
            ),
          ]),
          if (x.status == TxnStatus.sent && h.can('edit')) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: SoftPill(
                  label: x.trxId.isEmpty ? 'TrxID যুক্ত করুন' : 'উত্তর/TrxID বদলান',
                  icon: Icons.edit_note_rounded,
                  onTap: () => _enterReply(context, onlyTrx: x.trxId.isEmpty),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SoftPill(
                  label: x.fault == null ? 'ভুল নম্বরে গেছে?' : 'ভুলের চিহ্ন বদলান',
                  icon: Icons.report_gmailerrorred_rounded,
                  color: K.red,
                  onTap: () => _markFault(context),
                ),
              ),
            ]),
            if (x.fault != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => h.markFault(x, null, ''), child: Tx('ভুলের চিহ্ন তুলে দিন', style: t(13, c: K.muted))),
              ),
            const SizedBox(height: 8),
            const Note('এজেন্ট পাঠিয়ে দিয়েছেন, তাই এই লেনদেন বাতিল করা যায় না। ভুল নম্বরে গেলে ওপরের বোতামে চিহ্ন দিন।', icon: Icons.lock_outline_rounded),
          ],
          if (x.status == TxnStatus.pending && h.can('edit')) ...[
            const SizedBox(height: 8),
            SoftPill(
              label: 'লেনদেন বাতিল',
              icon: Icons.block_rounded,
              color: K.red,
              onTap: () async {
                final reason = await askText(context, 'কেন বাতিল?', hint: 'যেমন ভুল নম্বর', ok: 'বাতিল করুন');
                if (reason == null) return;
                await h.cancelTxn(x, reason);
                if (a != null && !a.usesApp && context.mounted && await confirm(context, 'এজেন্টকে জানাবেন?', 'এজেন্টকে "এটা পাঠাবেন না" মেসেজ যাবে।', yes: 'জানান')) {
                  await h.s.device.whatsapp(a.whatsapp, agentCancelMessage(x, h.d));
                  await h.logMessage(x, 'এজেন্টকে বাতিলের মেসেজ');
                }
              },
            ),
          ],
        ],
        const SizedBox(height: 10),
        SectionHead('টাইমলাইন — কখন কী হয়েছে'),
        CardBox(padding: const EdgeInsets.fromLTRB(14, 14, 14, 4), child: TxnTimeline(h: h, x: x)),
      ]),
    );
  }

  Widget _kv(String k, String v, {bool last = false, bool bold = false, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 72, child: Tx(k, style: t(13.5, c: K.muted))),
            Expanded(child: Tx(v, textAlign: TextAlign.right, style: t(14.5, w: bold ? FontWeight.w700 : FontWeight.w500, c: onTap != null ? K.blue : K.ink))),
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
            Tx(labels[i], style: t(11.5, c: i < done ? K.ink : K.muted), textAlign: TextAlign.center),
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
              Expanded(child: Tx(e.title, style: t(14.5, w: FontWeight.w600))),
              Tx(timeText(e.at), style: t(12, c: K.muted)),
            ]),
            const SizedBox(height: 2),
            Tx(e.detail, style: t(13, c: const Color(0xFF4A4A4A), h: 1.45)),
            Tx('${dateShort(e.at)} · ${switch (e.who) { 'app' => 'অ্যাপ নিজে', 'me' || '' => 'আপনি', _ => e.who }}', style: t(11.5, c: K.muted)),
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
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final w = h.waiting;
        return Screen(
          title: 'এজেন্টের পাঠানোর অপেক্ষায়',
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

/// Every send, newest first: search, status and date filters, PDF.
class AllTxnsScreen extends StatefulWidget {
  const AllTxnsScreen({super.key, required this.h, this.filter = 0, this.title = 'সব লেনদেন'});
  final Hisab h;

  /// 0 সব, 1 পাঠানোর অপেক্ষায়, 2 বাকিতে, 3 বাতিল, 4 ভুল নম্বর, 5 রিচার্জ/এমবি.
  final int filter;
  final String title;

  @override
  State<AllTxnsScreen> createState() => _AllTxnsScreenState();
}

class _AllTxnsScreenState extends State<AllTxnsScreen> {
  final _q = TextEditingController();
  late int _f = widget.filter;
  Period _p = Period.all();

  static const filters = [(0, 'সব'), (1, 'পাঠানোর অপেক্ষায়'), (2, 'বাকিতে'), (3, 'বাতিল'), (4, 'ভুল নম্বর'), (5, 'রিচার্জ/এমবি')];

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h;
        final q = en(_q.text).trim().toLowerCase();
        var list = [...h.d.txns]..sort((a, b) => b.at.compareTo(a.at));
        list = list.where((x) {
          if (!_p.has(x.at)) return false;
          if (_f == 1 && x.status != TxnStatus.pending) return false;
          if (_f == 2 && x.sarDueAtSend <= 0) return false;
          if (_f == 3 && !x.cancelled) return false;
          if (_f == 4 && x.fault == null) return false;
          if (_f == 5 && !x.kind.isTopUp) return false;
          if (q.isEmpty) return true;
          final c = customerById(h.d, x.customerId);
          return '${x.no}' == q.replaceAll('#', '') ||
              x.number.contains(q) ||
              x.trxId.toLowerCase().contains(q) ||
              x.agentReply.toLowerCase().contains(q) ||
              (c?.name.toLowerCase().contains(q) ?? false) ||
              (soundKey(q).length >= 2 && c != null && soundKey(c.name).contains(soundKey(q)));
        }).toList();
        final live = list.where((x) => !x.cancelled);
        final sumSar = live.fold<double>(0, (s, x) => s + x.sarAmount);
        final sumTaka = live.fold<double>(0, (s, x) => s + x.taka);
        final groups = <String, List<Txn>>{};
        for (final x in list.take(400)) {
          groups.putIfAbsent(dayLabel(x.at, h.now), () => []).add(x);
        }
        final label = filters.firstWhere((f) => f.$1 == _f).$2;
        return Screen(
          title: widget.title,
          trailing: CircleBtn(
            icon: Icons.picture_as_pdf_outlined,
            label: 'PDF',
            onTap: () => sharePdf(context, h, txnsPdf(h, list, '${widget.title} · $label', _p), 'lenden'),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: t(15),
              decoration: InputDecoration(
                hintText: tr('নাম, নম্বর, #নং বা TrxID'),
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
                for (final (v, l) in filters) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChipX(label: l, on: _f == v, onTap: () => setState(() => _f = v))),
              ]),
            ),
            const SizedBox(height: 10),
            Tx('${bn('${list.length}')}টা লেনদেন · ${sar(sumSar)} · ${taka(sumTaka)}', style: t(13, c: K.muted)),
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

/// Everything that happened to one send, oldest first, with who did it:
/// saved, message to the agent, changes, the agent's reply (auto from the
/// copied reply, typed by an admin, or from the agent's app), wrong-number
/// marks, the agent paid for it, cancelled.
class TxnTimeline extends StatelessWidget {
  const TxnTimeline({super.key, required this.h, required this.x});
  final Hisab h;
  final Txn x;

  @override
  Widget build(BuildContext context) {
    final items = <(DateTime, String, String, String, String)>[
      for (final e in h.d.log.where((e) => e.ref == x.id)) (e.at, e.kind, e.title, e.detail, e.who == 'me' ? 'আপনি' : (e.who == 'app' ? 'অ্যাপ নিজে' : e.who)),
      for (final p in h.d.agentPayments.where((p) => p.txnIds.contains(x.id)))
        (p.at, 'agent', 'এজেন্টকে এর টাকা দেওয়া হলো', '${taka(p.taka)}${p.txnIds.length > 1 ? ' (${bn('${p.txnIds.length}')}টা লেনদেন একসাথে)' : ''} · ${payWayName(p.way)}${p.ref.isEmpty ? '' : ' · রেফ ${p.ref}'}', p.byName.isEmpty ? 'আপনি' : p.byName),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (items.isEmpty) return Padding(padding: const EdgeInsets.only(bottom: 10), child: Tx('এখনো কিছু নেই', style: t(13, c: K.muted)));
    return Column(children: [
      for (final (i, it) in items.indexed)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 34,
              child: Column(children: [
                () {
                  final (icon, bg, fg) = LogRow.look(it.$2);
                  return dotIcon(icon, bg, fg, size: 30);
                }(),
                if (i < items.length - 1) Expanded(child: Container(width: 2, color: K.line)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx(it.$3, style: t(14.5, w: FontWeight.w600)),
                  if (it.$4.isNotEmpty) Tx(it.$4, style: t(13, c: const Color(0xFF4A4A4A), h: 1.45)),
                  Tx('${dateShort(it.$1)}, ${timeText(it.$1)} · ${it.$5}', style: t(11.5, c: K.muted)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
