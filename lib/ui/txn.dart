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

  /// The agent's reply: the PIN (last digits of the number it went from)
  /// or the TrxID — one of the two is enough. A copied reply fills them in.
  Future<void> _enterReply(BuildContext context) async {
    final clip = await h.s.device.clipboard();
    final nos = [for (final o in h.d.txns) o.no];
    final r0 = clip == null ? null : parseReply(clip, nos: nos);
    final fromClip = r0 != null && r0.useful && clip!.trim().length <= 200;
    final pin = TextEditingController(text: x.replyTail.isNotEmpty ? x.replyTail : (fromClip ? r0.tail : ''));
    final trx = TextEditingController(text: x.trxId.isNotEmpty ? x.trxId : (fromClip ? (r0.trxIds.firstOrNull ?? '') : ''));
    if (!context.mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final any = en(pin.text).trim().isNotEmpty || trx.text.trim().isNotEmpty;
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Tx('এজেন্টের উত্তর', style: t(18, w: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Tx('পিন বা TrxID — যেকোনো একটা দিলেই হবে', style: t(13.5, c: K.muted), textAlign: TextAlign.center),
            if (fromClip) ...[
              const SizedBox(height: 10),
              Note('কপি করা উত্তর থেকে বসানো হয়েছে: ${clip.trim()}', icon: Icons.content_paste_rounded),
            ],
            const SizedBox(height: 14),
            Field(label: 'পিন (যে নম্বর থেকে গেছে, তার শেষ কয়েক সংখ্যা)', controller: pin, number: true, hint: 'যেমন 667', autofocus: !fromClip, onChanged: (_) => set(() {})),
            const SizedBox(height: 10),
            Field(label: 'TrxID', controller: trx, hint: 'যেমন BJ7K9X2Q1M', onChanged: (_) => set(() {})),
            const SizedBox(height: 16),
            Pill(label: 'বসান', color: K.green, onTap: any ? () => Navigator.pop(ctx, true) : null),
          ]),
        );
      }),
    );
    if (ok != true || !context.mounted) return;
    final p = en(pin.text).replaceAll(RegExp(r'[^0-9]'), '');
    final id = trx.text.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (p.isEmpty && id.isEmpty) return;
    if (p.isNotEmpty && (p.length < 2 || p.length > 6)) {
      snack(context, 'পিন ২ থেকে ৬ সংখ্যার হয়');
      return;
    }
    if (id.isNotEmpty && !RegExp(r'^[A-Z0-9]{6,20}$').hasMatch(id)) {
      snack(context, 'TrxID-তে শুধু ইংরেজি অক্ষর আর সংখ্যা থাকে');
      return;
    }
    final auto = fromClip && p == r0.tail && id == (r0.trxIds.firstOrNull ?? '').toUpperCase();
    if (auto && r0.no != null && r0.no != x.no) {
      if (!await confirm(context, 'অন্য লেনদেনের উত্তর?', 'উত্তরে লেনদেন নং #${bn('${r0.no}')}, কিন্তু এটা #${bn('${x.no}')}। তবুও এখানে বসাবেন?', yes: 'বসান')) return;
      if (!context.mounted) return;
    }
    final amount = auto ? r0.amount : null;
    if (amount != null && (x.agentTaka - amount).abs() >= 0.5 && (x.taka - amount).abs() >= 0.5) {
      if (!await confirm(context, 'টাকা মিলছে না', 'উত্তরে ${bnNum(amount)} টাকা, কিন্তু এই লেনদেনে ${taka(x.agentTaka)}। তবুও বসাবেন?', yes: 'বসান')) return;
      if (!context.mounted) return;
    }
    if (id.isNotEmpty && id != x.trxId) {
      final usedBy = h.d.txns.where((o) => o.id != x.id && o.trxId == id).toList();
      if (usedBy.isNotEmpty) {
        if (!await confirm(context, 'এই TrxID আগে ব্যবহার হয়েছে', '#${bn('${usedBy.first.no}')}-এ এই TrxID আছে। তবুও বসাবেন?', yes: 'বসান')) return;
      }
    }
    await h.markSent(x, trxId: id, reply: auto && amount != null ? en(clip.trim()) : '', tail: p, from: auto ? 'auto' : 'manual');
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
      TxnStatus.pending => (x.hasProblem ? 'এজেন্টের সমস্যা — আটকে আছে' : 'এজেন্টের পাঠানোর অপেক্ষায়', K.red, K.redTint),
      TxnStatus.sent => ('পৌঁছেছে', K.green, K.greenTint),
      TxnStatus.cancelled => ('বাতিল', K.muted, K.chip),
    };
    return Screen(
      title: 'লেনদেন #${bn('${x.no}')}',
      // Only before the agent sends it; after that, অতিরিক্ত হিসাব.
      trailing: x.status != TxnStatus.pending || !h.can('edit')
          ? null
          : CircleBtn(
              icon: Icons.edit_outlined,
              label: 'সংশোধন',
              onTap: () {
                push(context, EntryScreen(h: h, c: c ?? walkInCustomer(x.walkIn, x.walkInPhone), editing: x));
              },
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        if (fresh && x.status == TxnStatus.pending) ...[
          Note('মেসেজ হোয়াটসঅ্যাপে লেখা আছে — সেখানে Send চাপুন। এজেন্ট রিপ্লাই দিলে (যেমন ${x.no} ${x.agentTaka.round()}-667) সেটা কপি করে অ্যাপে ফিরে আসুন।', icon: Icons.info_outline_rounded),
          const SizedBox(height: 12),
        ],
        if (x.changeNotice == 'pending' && x.status == TxnStatus.pending) ...[
          CardBox(
            color: K.redTint,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                dotIcon(Icons.campaign_rounded, Colors.white, K.red, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Tx('সংশোধনের মেসেজ এজেন্টকে পাঠাতেই হবে', style: t(15, w: FontWeight.w600, c: K.red))),
              ]),
              const SizedBox(height: 6),
              Tx('টাকা বা নম্বর বদলেছে। এজেন্ট যেন পুরনো টাকা বা নম্বরে না পাঠান — হোয়াটসঅ্যাপে মেসেজটা Send করে নিচে "পাঠিয়েছি" চাপুন।', style: t(13, c: K.red, h: 1.45)),
              const SizedBox(height: 10),
              Row(children: [
                if (a != null)
                  Expanded(
                    child: Pill(
                      label: 'মেসেজ খুলুন',
                      height: 44,
                      color: K.red,
                      onTap: () async {
                        final ok = await h.s.device.whatsapp(a.whatsapp, agentChangeMessage(x, h.d));
                        await h.logMessage(x, ok ? 'এজেন্টকে সংশোধনের মেসেজ' : 'হোয়াটসঅ্যাপ খোলা যায়নি');
                      },
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(child: Pill(label: 'পাঠিয়েছি', height: 44, color: K.green, onTap: () => h.changeNoticeSent(x))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (x.hasProblem) ...[
          CardBox(
            color: K.redTint,
            border: K.red,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                dotIcon(Icons.report_outlined, Colors.white, K.red, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Tx('এজেন্ট সমস্যা জানিয়েছেন', style: t(15, w: FontWeight.w600, c: K.red)),
                    if (DateTime.tryParse(x.problemAt) != null) Tx('${dateShort(DateTime.parse(x.problemAt))}, ${timeText(DateTime.parse(x.problemAt))} · ${a?.name ?? ''}', style: t(12, c: K.red)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Tx('"${x.problem}"', style: t(15, w: FontWeight.w500, h: 1.45)),
              ),
              const SizedBox(height: 8),
              Tx('এজেন্ট এটা পাঠাবেন না যতক্ষণ না আবার অনুরোধ যায়। দরকার হলে উপরের পেন্সিল বোতাম দিয়ে নম্বর বা টাকা ঠিক করুন, বা লেনদেন বাতিল করুন। ঠিক হলে নিচে চাপুন।', style: t(13, c: K.red, h: 1.45)),
              if (h.can('send') || h.can('edit')) ...[
                const SizedBox(height: 10),
                Pill(
                  label: 'সমাধান হয়েছে — আবার অনুরোধ পাঠান',
                  icon: Icons.replay_rounded,
                  height: 46,
                  color: K.red,
                  onTap: () async {
                    if (await confirm(context, 'আবার অনুরোধ পাঠাবেন?', '${a?.name ?? 'এজেন্ট'}-এর কাছে #${bn('${x.no}')} (${taka(x.agentTaka)} · ${bdShow(x.number)}) আবার নতুন অনুরোধ হিসেবে যাবে।', yes: 'পাঠান')) {
                      await h.reRequest(x);
                      if (context.mounted) snack(context, 'এজেন্টের কাছে আবার অনুরোধ গেছে');
                    }
                  },
                ),
              ],
            ]),
          ),
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
            _kv('গ্রাহক', c != null ? c.name : '${customerNameOf(h.d, x)}${x.walkInPhone.isEmpty ? '' : ' · ${bn(x.walkInPhone)}'} (প্রোফাইল ছাড়া)', onTap: c == null ? null : () => push(context, CustomerScreen(h: h, id: c.id))),
            _kv('কী', '${x.kind.bnName}${x.kind.isTopUp ? (x.operator.isEmpty ? '' : ' · ${x.operator}') : ' · ${x.method.bnName}'}'),
            if (x.kind == Kind.mb) _kv('প্যাক', x.pack),
            _kv('প্রাপক', x.recipientLabel.isEmpty ? '—' : x.recipientLabel),
            _kv('নম্বর', x.method == Method.bank && !x.kind.isTopUp ? bn(x.number) : bdShow(x.number)),
            _kv('রিয়াল', '${x.pay.bnName}${x.pay == Pay.partial ? ' · দিলেন ${sar(x.sarPaid)}' : ''}${x.sarDueAtSend > 0 ? ' · বকেয়া ${sar(x.sarDueAtSend)}' : ''}'),
            _kv('এজেন্ট', '${a?.name ?? '—'} · ${taka(x.agentTaka)}${x.agentPaymentId != null ? ' · শোধ' : ''}'),
            _kv('সময়', '${dateShort(x.at)}, ${timeText(x.at)}'),
            if (x.byName.isNotEmpty) _kv('এডমিন', x.byName),
            _kv('এজেন্টের উত্তর', x.agentReply.isEmpty && x.trxId.isEmpty ? '—' : '${x.agentReply.isEmpty ? '' : bn(x.agentReply)}${switch (x.replyFrom) { 'auto' => ' · কপি থেকে অটো', 'manual' => ' · এডমিন নিজে বসালেন', 'agent' => ' · এজেন্টের অ্যাপ থেকে', _ => '' }}'),
            if (x.replyTail.isNotEmpty) _kv('পিন', bn(x.replyTail)),
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
            // WhatsApp to the agent until it is sent (also for an agent who
            // works in the app); once sent there is nothing to tell them.
            if (a != null && a.whatsapp.isNotEmpty && x.status == TxnStatus.pending)
              Expanded(
                child: SoftPill(
                  label: 'এজেন্টকে হোয়াটসঅ্যাপে',
                  icon: Icons.chat_outlined,
                  onTap: () async {
                    final ok = await h.s.device.whatsapp(a.whatsapp, agentMessage(x, h.d));
                    await h.logMessage(x, ok ? 'এজেন্টকে হোয়াটসঅ্যাপে মেসেজ' : 'হোয়াটসঅ্যাপ খোলা যায়নি');
                  },
                ),
              ),
            if (a != null && a.whatsapp.isNotEmpty && x.status == TxnStatus.pending) const SizedBox(width: 8),
            Expanded(
              child: SoftPill(
                label: 'গ্রাহককে রসিদ',
                icon: Icons.receipt_outlined,
                onTap: c == null && x.walkInPhone.isEmpty
                    ? () async {
                        final pin = await askPin(context, x);
                        if (pin == null || !context.mounted) return;
                        await h.s.device.shareText(customerReceipt(h.d, x, pin: pin));
                      }
                    : c == null
                        ? () async {
                            final pin = await askPin(context, x);
                            if (pin == null || !context.mounted) return;
                            await h.s.device.whatsapp(x.walkInPhone, customerReceipt(h.d, x, pin: pin));
                            await h.note('txn', 'গ্রাহককে রসিদ · #${bn('${x.no}')}', customerNameOf(h.d, x));
                          }
                        : () async {
                        final pin = await askPin(context, x);
                        if (pin == null || !context.mounted) return;
                        final text = customerReceipt(h.d, x, pin: pin);
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
              if (x.trxId.isEmpty) ...[
                Expanded(
                  child: SoftPill(
                    label: 'পিন / TrxID',
                    icon: Icons.edit_note_rounded,
                    onTap: () => _enterReply(context),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
            SoftPill(label: 'ভুল হয়েছে? অতিরিক্ত হিসাব লিখুন', icon: Icons.playlist_add_rounded, onTap: () => push(context, AdjustScreen(h: h, x: x))),
            const SizedBox(height: 8),
            const Note('এজেন্ট পাঠিয়ে দিয়েছেন, তাই এই লেনদেন আর বদলানো বা বাতিল করা যায় না। ভুল হলে "অতিরিক্ত হিসাব" লিখুন — চাইলে পরে সেটা মূল হিসাবে যোগ করবেন।', icon: Icons.lock_outline_rounded),
          ],
          if (h.d.adjusts.any((j) => j.txnId == x.id)) ...[
            SectionHead('অতিরিক্ত হিসাব'),
            for (final j in h.d.adjusts.where((j) => j.txnId == x.id)) AdjustCard(h: h, x: j),
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
                if (a != null && a.whatsapp.isNotEmpty && context.mounted && await confirm(context, a.usesApp ? 'হোয়াটসঅ্যাপেও জানাবেন?' : 'এজেন্টকে জানাবেন?', a.usesApp ? 'এজেন্টের অ্যাপে নোটিফিকেশন গেছে। হোয়াটসঅ্যাপেও "এটা পাঠাবেন না" মেসেজ যাবে।' : 'এজেন্টকে "এটা পাঠাবেন না" মেসেজ যাবে।', yes: 'জানান')) {
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
  const AllTxnsScreen({super.key, required this.h, this.filter = 0, this.title = 'সব লেনদেন', this.search = false, this.byAdmin, this.withOld = false});
  final Hisab h;

  /// 0 সব, 1 পাঠানোর অপেক্ষায়, 2 বকেয়ায়, 3 বাতিল, 4 ভুল নম্বর, 5 রিচার্জ/এমবি.
  final int filter;
  final String title;

  /// Opened from the search button: the keyboard comes up at once.
  final bool search;

  /// Only one admin's sends ([withOld]: also those from before the server,
  /// which are the main admin's).
  final int? byAdmin;
  final bool withOld;

  @override
  State<AllTxnsScreen> createState() => _AllTxnsScreenState();
}

class _AllTxnsScreenState extends State<AllTxnsScreen> {
  final _q = TextEditingController();
  late int _f = widget.filter;
  Period _p = Period.all();

  static const filters = [(0, 'সব'), (1, 'পাঠানোর অপেক্ষায়'), (2, 'বকেয়ায়'), (3, 'বাতিল'), (4, 'ভুল নম্বর'), (5, 'রিচার্জ/এমবি')];

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h;
        final q = en(_q.text).trim().toLowerCase();
        var list = [...h.d.txns]..sort((a, b) => b.at.compareTo(a.at));
        list = list.where((x) {
          if (!_p.has(x.at)) return false;
          if (widget.byAdmin != null && x.by != widget.byAdmin && !(widget.withOld && x.by == 0)) return false;
          if (_f == 1 && x.status != TxnStatus.pending) return false;
          if (_f == 2 && x.sarDueAtSend <= 0) return false;
          if (_f == 3 && !x.cancelled) return false;
          if (_f == 4 && x.fault == null) return false;
          if (_f == 5 && !x.kind.isTopUp) return false;
          if (q.isEmpty) return true;
          final c = customerById(h.d, x.customerId);
          final a = agentById(h.d, x.agentId);
          final digits = q.replaceAll(RegExp(r'[^0-9.]'), '');
          final amount = double.tryParse(digits);
          bool named(String s) => s.toLowerCase().contains(q) || (soundKey(q).length >= 2 && soundKey(s).contains(soundKey(q)));
          return (digits.isNotEmpty && '${x.no}'.contains(q.replaceAll('#', ''))) ||
              (digits.length >= 3 && x.number.contains(digits)) ||
              x.trxId.toLowerCase().contains(q) ||
              x.agentReply.toLowerCase().contains(q) ||
              (amount != null && (x.sarAmount == amount || x.taka.round() == amount || x.agentTaka.round() == amount)) ||
              (c != null && (named(c.name) || c.phone.contains(q))) ||
              (c == null && (named(x.walkIn) || x.walkInPhone.contains(q))) ||
              named(x.recipientLabel) ||
              (a != null && named(a.name)) ||
              named(x.byName) ||
              x.operator.toLowerCase().contains(q) ||
              x.note.toLowerCase().contains(q);
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
              autofocus: widget.search,
              onChanged: (_) => setState(() {}),
              style: t(15),
              decoration: InputDecoration(
                hintText: tr('নাম, নম্বর, #নং, TrxID, টাকা বা রিয়াল'),
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


/// Before a receipt goes out: the পিন line (last digits of the number the
/// agent sent from), which the admin can change or leave out.
Future<String?> askPin(BuildContext context, Txn x) async {
  if (x.kind.isTopUp) return '';
  final c = TextEditingController(text: en(x.replyTail));
  var on = x.replyTail.isNotEmpty;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Tx('গ্রাহককে রসিদ', style: t(18, w: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: on,
            onChanged: (v) => set(() => on = v),
            title: Tx('মেসেজে পিন দিন', style: t(15, w: FontWeight.w500)),
            subtitle: Tx('যে নম্বর থেকে টাকা গেছে তার শেষ কয়েক সংখ্যা — গ্রাহক মিলিয়ে নিতে পারবেন', style: t(12.5, c: K.muted)),
          ),
          if (on) Field(label: 'পিন (শেষ কয়েক সংখ্যা)', controller: c, number: true, hint: 'যেমন 167'),
          const SizedBox(height: 14),
          Pill(label: 'মেসেজ তৈরি করুন', onTap: () => Navigator.pop(ctx, on ? en(c.text).replaceAll(RegExp(r'[^0-9]'), '') : '')),
        ]),
      ),
    ),
  );
}

/// One correction, with "add to the main account" while it is apart.
class AdjustCard extends StatelessWidget {
  const AdjustCard({super.key, required this.h, required this.x});
  final Hisab h;
  final Adjust x;

  @override
  Widget build(BuildContext context) {
    final why = adjustWhy(x);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        color: x.applied ? K.card : K.amberTint,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Tx(why.isEmpty ? adjustText(x) : why, style: t(15, w: FontWeight.w600, h: 1.4))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: x.applied ? K.greenTint : Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Tx(x.applied ? 'মূল হিসাবে আছে' : 'আলাদা রাখা', style: t(12, w: FontWeight.w600, c: x.applied ? K.green : K.amberText)),
            ),
          ]),
          if (why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Tx(adjustText(x), style: t(13.5, w: FontWeight.w500))),
          const SizedBox(height: 4),
          Tx('${dateShort(x.at)}, ${timeText(x.at)}${x.byName.isEmpty ? '' : ' · ${x.byName}'}${x.applied && x.appliedAt != null ? ' · মূল হিসাবে যোগ ${dateShort(x.appliedAt!)}${x.appliedByName.isEmpty ? '' : ' (${x.appliedByName})'}' : ''}', style: t(12, c: K.muted)),
          if (!x.applied && h.can('edit')) ...[
            const SizedBox(height: 10),
            Pill(
              label: 'মূল হিসাবে যোগ করুন',
              height: 44,
              onTap: () async {
                if (await confirm(context, 'মূল হিসাবে যোগ করবেন?', '${adjustText(x)} — এরপর থেকে এটা হিসাবে ধরা হবে। যোগ করার পর আর ফেরানো যাবে না।', yes: 'যোগ করুন')) {
                  await h.applyAdjust(x);
                }
              },
            ),
          ],
        ]),
      ),
    );
  }
}

/// Writing a correction for a sent send, step by step: what went wrong,
/// whose mistake it was, then the riyal and taka that go to that one's
/// account (the customer's due, the agent's account or the admin's hand).
class AdjustScreen extends StatefulWidget {
  const AdjustScreen({super.key, required this.h, required this.x});
  final Hisab h;
  final Txn x;
  @override
  State<AdjustScreen> createState() => _AdjustScreenState();
}

class _AdjustScreenState extends State<AdjustScreen> {
  final _sar = TextEditingController(), _taka = TextEditingController(), _note = TextEditingController();
  String? _what, _who;
  late int _admin = widget.x.by;

  /// true: the one at fault makes it good (pays); false: they get it back.
  bool _pays = true;

  @override
  void initState() {
    super.initState();
    final f = widget.x.fault;
    if (f != null) {
      _what = 'number';
      _who = switch (f) { Fault.mine => 'admin', Fault.agent => 'agent', Fault.customer => 'customer' };
    }
  }

  double get _rate => widget.x.rate > 0 ? widget.x.rate : 1;

  /// Typing one fills the other at this send's rate.
  void _typed(bool sarSide) {
    final v = parseNum(sarSide ? _sar.text : _taka.text);
    final other = sarSide ? _taka : _sar;
    other.text = v == null ? '' : (sarSide ? '${(v * _rate).round()}' : (v / _rate).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), ''));
    setState(() {});
  }

  Map<int, String> _admins() {
    final h = widget.h, x = widget.x;
    final m = adminsIn(h.d);
    if (h.session != null) m[h.meId] = h.meName;
    m.putIfAbsent(x.by, () => x.byName.isEmpty ? h.ownerLabel : x.byName);
    if (m.containsKey(0)) {
      if (m.length > 1 && m.entries.any((e) => e.key != 0 && e.value == h.ownerLabel)) {
        m.remove(0);
      } else {
        m[0] = h.ownerLabel;
      }
    }
    return m;
  }

  Widget _option(String label, bool on, VoidCallback tap, {String sub = ''}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CardBox(
          border: on ? K.blue : null,
          onTap: tap,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? K.blue : K.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Tx(label, style: t(15, w: FontWeight.w500)),
                if (sub.isNotEmpty) Tx(sub, style: t(12.5, c: K.muted)),
              ]),
            ),
          ]),
        ),
      );

  Widget _step(int n, String title, {bool on = true}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? K.navy : K.chip),
            child: Tx(bn('$n'), style: t(13, w: FontWeight.w700, c: on ? Colors.white : K.muted)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Tx(title, style: t(16, w: FontWeight.w600, c: on ? K.ink : K.muted))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final h = widget.h, x = widget.x;
    final c = customerById(h.d, x.customerId);
    final a = agentById(h.d, x.agentId);
    final admins = _admins();
    final adminName = admins[_admin] ?? (x.byName.isEmpty ? h.ownerLabel : x.byName);
    final sarV = (parseNum(_sar.text) ?? 0).abs(), takaV = (parseNum(_taka.text) ?? 0).abs();
    final sign = _pays ? 1 : -1;
    // Where it goes: the customer's due, the agent's account or the admin's hand.
    final adj = Adjust(
      id: '',
      at: h.now,
      sarDue: _who == 'customer' ? sign * sarV : 0,
      takaAgent: _who == 'agent' ? -sign * takaV : 0,
      sarCash: _who == 'admin' ? sign * sarV : 0,
    );
    final amountOk = _who == 'agent' ? takaV >= 0.5 : sarV >= 0.005;
    final ready = _what != null && _who != null && amountOk && (_what != 'other' || _note.text.trim().isNotEmpty);
    final custName = c?.name ?? customerNameOf(h.d, x);
    final (payLabel, backLabel, payEffect, backEffect) = switch (_who) {
      'customer' => ('গ্রাহক দেবেন', 'গ্রাহক ফেরত পাবেন', '$custName-এর বকেয়া বাড়বে', '$custName-এর বকেয়া কমবে'),
      'agent' => ('এজেন্ট দেবেন', 'এজেন্ট পাবেন', '${a?.name ?? 'এজেন্ট'}-এর পাওনা কমবে', '${a?.name ?? 'এজেন্ট'}-এর পাওনা বাড়বে'),
      _ => ('এডমিন পূরণ করবেন', 'এডমিন ফেরত পাবেন', '$adminName-এর হাতে রিয়াল যোগ হবে', '$adminName-এর হাত থেকে রিয়াল কমবে'),
    };
    return Screen(
      title: 'অতিরিক্ত হিসাব · #${bn('${x.no}')}',
      bottom: Pill(
        label: 'আলাদা করে রাখুন',
        onTap: !ready
            ? null
            : () async {
                await h.addAdjust(x,
                    sarDue: adj.sarDue,
                    sarCash: adj.sarCash,
                    takaAgent: adj.takaAgent,
                    note: _note.text,
                    what: _what!,
                    who: _who!,
                    handBy: _who == 'admin' ? _admin : 0,
                    handByName: _who == 'admin' ? adminName : '');
                if (context.mounted) Navigator.of(context).pop();
              },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Tx('$custName · ${sar(x.sarAmount)} × ${rateText(x.rate)} = ${taka(x.taka)}\n${bdShow(x.number)} · ${a?.name ?? '—'}${x.byName.isEmpty ? '' : ' · ${x.byName}'}', style: t(13.5, c: K.muted, h: 1.5)),
        ),
        _step(1, 'কী ভুল হয়েছে?'),
        for (final e in adjustWhats.entries) _option(e.value, _what == e.key, () => setState(() => _what = e.key)),
        _step(2, 'কার ভুলে হয়েছে?', on: _what != null),
        if (_what != null) ...[
          _option('গ্রাহকের ভুল', _who == 'customer', () => setState(() => _who = 'customer'), sub: 'ক্ষতিপূরণ গ্রাহকের বকেয়ায় যাবে'),
          _option('এজেন্টের ভুল', _who == 'agent', () => setState(() => _who = 'agent'), sub: 'ক্ষতিপূরণ এজেন্টের হিসাবে যাবে'),
          _option('এডমিনের ভুল', _who == 'admin', () => setState(() => _who = 'admin'), sub: 'ক্ষতিপূরণ সেই এডমিনের হাতের হিসাবে যাবে'),
          if (_who == 'admin' && admins.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in admins.entries) ChoiceChipX(label: e.value, on: _admin == e.key, onTap: () => setState(() => _admin = e.key)),
              ]),
            ),
        ],
        _step(3, 'ক্ষতিপূরণ কত?', on: _who != null),
        if (_who != null) ...[
          Seg<bool>(items: [(true, payLabel), (false, backLabel)], value: _pays, onChanged: (v) => setState(() => _pays = v)),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Field(label: 'রিয়াল', controller: _sar, number: true, hint: 'যেমন 50', onChanged: (_) => _typed(true))),
            const SizedBox(width: 10),
            Expanded(child: Field(label: 'টাকা', controller: _taka, number: true, hint: 'যেমন ${(50 * _rate).round()}', onChanged: (_) => _typed(false))),
          ]),
          Tx('একটা লিখলে অন্যটা এই লেনদেনের রেট (${rateText(x.rate)}) দিয়ে বসে যায়, চাইলে বদলাতে পারেন।', style: t(12.5, c: K.muted)),
          const SizedBox(height: 12),
          Field(label: _what == 'other' ? 'কী হয়েছিল' : 'কী হয়েছিল (ইচ্ছা হলে)', controller: _note, hint: 'যেমন রিয়াল ৩০০ লিখেছিলাম, আসলে ৩৫০', maxLines: 3, onChanged: (_) => setState(() {})),
          if (amountOk) ...[
            const SizedBox(height: 12),
            CardBox(
              color: K.amberTint,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Tx('যা হবে', style: t(13, c: K.amberText, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Tx('${_pays ? payEffect : backEffect}: ${adjustText(adj)}', style: t(14.5, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Tx('এখন আলাদা থাকবে। লেনদেনের পাতায় "মূল হিসাবে যোগ করুন" চাপলে তবেই হিসাবে ঢুকবে।', style: t(12.5, c: K.amberText, h: 1.4)),
              ]),
            ),
          ],
        ],
      ]),
    );
  }
}
