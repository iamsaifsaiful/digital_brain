import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'home.dart';
import 'kit.dart';
import 'reports.dart';
import 'txn.dart';

/// The agent's account, in taka only.
class AgentTab extends StatefulWidget {
  const AgentTab({super.key, required this.h});
  final Hisab h;

  @override
  State<AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends State<AgentTab> {
  String? _agentId;
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h;
        final d = h.d;
        final a = agentById(d, _agentId ?? '') ?? d.agents.first;
        final owed = agentOwed(d, a.id);
        final unpaid = unpaidForAgent(d, a.id);
        _picked.removeWhere((id) => !unpaid.any((x) => x.id == id));
        final pickedList = unpaid.where((x) => _picked.contains(x.id)).toList();
        final pickedSum = pickedList.fold<double>(0, (s, x) => s + x.agentTaka + commissionOf(x, a));
        final now = h.now;
        final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
        final vals = [for (final day in days) d.txns.where((x) => x.agentId == a.id && !x.cancelled && sameDay(x.at, day)).fold<double>(0, (s, x) => s + x.agentTaka)];
        final pays = d.agentPayments.where((p) => p.agentId == a.id).toList()..sort((x, y) => y.at.compareTo(x.at));
        const wd = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
          Row(children: [
            Expanded(child: Text('এজেন্ট', style: t(22, w: FontWeight.w700))),
            CircleBtn(icon: Icons.picture_as_pdf_outlined, label: 'এজেন্টের হিসাব PDF', onTap: () => _pdf(context, h, a)),
            const SizedBox(width: 8),
            CircleBtn(icon: Icons.edit_outlined, label: 'এজেন্টের তথ্য', onTap: () => push(context, AgentEdit(h: h, a: a))),
          ]),
          if (d.agents.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in d.agents) ChoiceChipX(label: x.name, on: x.id == a.id, onTap: () => setState(() => _agentId = x.id)),
            ]),
          ],
          const SizedBox(height: 12),
          CardBox(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                dotIcon(Icons.storefront_rounded, K.navySoft, K.navy, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, style: t(16, w: FontWeight.w600)),
                    Text('হোয়াটসঅ্যাপ ${bn(a.whatsapp)}', style: t(12.5, c: K.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text(owed >= 0 ? 'এজেন্টকে দিতে হবে' : 'এজেন্টের কাছে অগ্রিম', style: t(13, c: K.muted)),
              Text(taka(owed.abs()), style: t(30, w: FontWeight.w700, c: owed > 0 ? K.navy : K.green)),
              if (a.commissionPerThousand > 0) Text('কমিশন হাজারে ${bnNum(a.commissionPerThousand, decimals: 2)} টাকা ধরে', style: t(12.5, c: K.muted)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Pill(
                    label: 'টাকা দিলাম',
                    height: 48,
                    onTap: () => push(context, AgentPayScreen(h: h, a: a, txns: const [])),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pill(
                    label: 'আজকের হিসাব',
                    color: K.navy,
                    height: 48,
                    onTap: () async {
                      await h.s.device.whatsapp(a.whatsapp, agentDayStatement(d, a, now));
                      await h.note('agent', 'এজেন্টকে দিনের হিসাব', a.name);
                    },
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('গত ৭ দিনে এজেন্ট যত টাকা পাঠালেন', style: t(15, w: FontWeight.w600)),
              const SizedBox(height: 10),
              LineChart(values: vals, labels: [for (final day in days) wd[day.weekday - 1]], caption: 'গত সাত দিনে এজেন্টের পাঠানো টাকা', markLabel: taka(vals.reduce((x, y) => x > y ? x : y))),
            ]),
          ),
          SectionHead('যেগুলোর টাকা দেওয়া হয়নি', action: unpaid.isEmpty ? null : (_picked.length == unpaid.length ? 'কোনোটা না' : 'সবগুলো'), onAction: () {
            setState(() {
              if (_picked.length == unpaid.length) {
                _picked.clear();
              } else {
                _picked
                  ..clear()
                  ..addAll(unpaid.map((x) => x.id));
              }
            });
          }),
          if (unpaid.isEmpty) const Note('সব লেনদেনের টাকা দেওয়া হয়ে গেছে।', color: K.greenTint, textColor: K.green),
          if (unpaid.isNotEmpty)
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(children: [
                for (final x in unpaid.reversed)
                  CheckboxListTile(
                    value: _picked.contains(x.id),
                    onChanged: (v) => setState(() => v == true ? _picked.add(x.id) : _picked.remove(x.id)),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('#${bn('${x.no}')} · ${bdMasked(x.number)}', style: t(14.5, w: FontWeight.w500)),
                    subtitle: Text('${dateShort(x.at)} · ${x.status == TxnStatus.pending ? 'উত্তর বাকি' : (proofText(x).isEmpty ? 'পাঠানো' : proofText(x))}',
                        style: t(12.5, c: x.status == TxnStatus.pending ? K.red : K.muted)),
                    secondary: Text(taka(x.agentTaka), style: t(14.5, w: FontWeight.w600)),
                  ),
              ]),
            ),
          if (pickedList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Pill(
              label: '${bn('${pickedList.length}')}টার টাকা দিলাম · ${taka(pickedSum)}',
              color: K.green,
              onTap: () async {
                final done = await push<bool>(context, AgentPayScreen(h: h, a: a, txns: pickedList));
                if (done == true) setState(() => _picked.clear());
              },
            ),
          ],
          if (pays.isNotEmpty) ...[
            SectionHead('এজেন্টকে দেওয়া টাকা'),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (final (i, p) in pays.take(30).indexed)
                  Row2(
                    lead: dotIcon(p.receipt != null ? Icons.receipt_long_rounded : Icons.payments_outlined, K.greenTint, K.green, size: 38),
                    title: p.txnIds.isEmpty ? 'টাকা দিলাম · ${payWayName(p.way)}' : '${bn('${p.txnIds.length}')}টা লেনদেনের টাকা · ${payWayName(p.way)}',
                    sub: '${dateShort(p.at)} · ${timeText(p.at)}${p.ref.isEmpty ? '' : ' · রেফ ${p.ref}'}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                    onTap: () => push(context, PaymentScreen(h: h, p: p)),
                    value: taka(p.taka),
                    valueColor: K.green,
                    last: i == pays.take(30).length - 1,
                  ),
              ]),
            ),
          ],
        ]);
      });
}

Future<void> _pdf(BuildContext context, Hisab h, Agent a) async {
  final p = await showModalBottomSheet<Period>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 14),
        Text('কোন সময়ের হিসাব?', style: t(17, w: FontWeight.w600)),
        for (final k in ['today', 'week', 'month', 'lastMonth', 'all'])
          ListTile(title: Text(k == 'all' ? 'সব সময়' : Period.of(k, h.now).label, style: t(15)), onTap: () => Navigator.pop(ctx, k == 'all' ? Period.all() : Period.of(k, h.now))),
      ]),
    ),
  );
  if (p == null || !context.mounted) return;
  await sharePdf(context, h, agentPdf(h, a, p), 'agent-hisab');
}

/// Paying the agent: how much, when, how, from which account, reference,
/// and a photo of the bank receipt if wanted.
class AgentPayScreen extends StatefulWidget {
  const AgentPayScreen({super.key, required this.h, required this.a, required this.txns});
  final Hisab h;
  final Agent a;

  /// The sends this payment is for; empty = a lump sum / advance.
  final List<Txn> txns;

  @override
  State<AgentPayScreen> createState() => _AgentPayScreenState();
}

class _AgentPayScreenState extends State<AgentPayScreen> {
  late final double _due = widget.txns.fold<double>(0, (s, x) => s + x.agentTaka + commissionOf(x, widget.a)).roundToDouble();
  late final _amount = TextEditingController(text: widget.txns.isEmpty ? '' : _due.round().toString());
  final _from = TextEditingController();
  final _ref = TextEditingController();
  final _note = TextEditingController();
  String _way = 'bank';
  late DateTime _at = widget.h.now;
  Uint8List? _receipt;
  bool _busy = false;

  Future<void> _pick(bool camera) async {
    final b = await widget.h.s.device.pickImage(camera: camera);
    if (b != null && mounted) setState(() => _receipt = b);
  }

  Future<void> _save() async {
    final n = parseNum(_amount.text);
    if (n == null || n <= 0) {
      snack(context, 'কত টাকা দিলেন লিখুন');
      return;
    }
    setState(() => _busy = true);
    final h = widget.h;
    if (widget.txns.isEmpty) {
      await h.advanceAgent(widget.a, n, way: _way, note: _note.text, ref: _ref.text, fromAccount: _from.text, receipt: _receipt, at: _at);
    } else {
      await h.payAgent(widget.a, widget.txns, way: _way, note: _note.text, ref: _ref.text, fromAccount: _from.text, receipt: _receipt, at: _at, amount: n);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final n = parseNum(_amount.text);
    return Screen(
      title: 'এজেন্টকে টাকা দিলাম',
      subtitle: widget.a.name,
      bottom: Pill(label: 'সংরক্ষণ', onTap: _busy ? null : _save),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        if (widget.txns.isNotEmpty) ...[
          Note('${bn('${widget.txns.length}')}টা লেনদেনের টাকা: ${taka(_due)} (কমিশনসহ)', icon: Icons.checklist_rounded),
          const SizedBox(height: 12),
        ],
        Field(label: 'কত টাকা দিলেন', controller: _amount, number: true, big: true, prefix: '৳ ', autofocus: widget.txns.isEmpty, onChanged: (_) => setState(() {})),
        if (widget.txns.isNotEmpty && n != null && (n - _due).abs() >= 1) ...[
          const SizedBox(height: 8),
          Note(n < _due ? '${taka(_due - n)} কম দিচ্ছেন — বাকিটা এজেন্টের পাওনা থেকে যাবে' : '${taka(n - _due)} বেশি দিচ্ছেন — অগ্রিম হিসেবে থাকবে', color: K.amberTint, textColor: K.amberText),
        ],
        const SizedBox(height: 14),
        Text('কীভাবে দিলেন', style: t(13, c: K.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in payWays.entries) ChoiceChipX(label: e.value, on: _way == e.key, onTap: () => setState(() => _way = e.key)),
        ]),
        const SizedBox(height: 14),
        CardBox(
          onTap: () async {
            final day = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime(2024), lastDate: widget.h.now, cancelText: 'বাতিল', confirmText: 'ঠিক আছে');
            if (day == null || !context.mounted) return;
            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at), cancelText: 'বাতিল', confirmText: 'ঠিক আছে');
            setState(() => _at = DateTime(day.year, day.month, day.day, time?.hour ?? _at.hour, time?.minute ?? _at.minute));
          },
          child: Row(children: [
            dotIcon(Icons.event_outlined, K.blueTint, K.blue, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Text('কবে: ${dateShort(_at)} ${bn('${_at.year}')}, ${timeText(_at)}', style: t(15))),
            Text('বদলান', style: t(13, c: K.blue)),
          ]),
        ),
        const SizedBox(height: 12),
        Field(label: _way == 'bank' ? 'কোন ব্যাংক/অ্যাকাউন্ট থেকে' : 'কোন নম্বর/অ্যাকাউন্ট থেকে (ইচ্ছা হলে)', controller: _from),
        const SizedBox(height: 12),
        Field(label: 'রেফারেন্স / ট্রানজেকশন নম্বর (ইচ্ছা হলে)', controller: _ref),
        const SizedBox(height: 12),
        Field(label: 'নোট (ইচ্ছা হলে)', controller: _note),
        const SizedBox(height: 14),
        Text('ব্যাংকের রসিদ (ইচ্ছা হলে)', style: t(13, c: K.muted)),
        const SizedBox(height: 6),
        if (_receipt != null)
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_receipt!, height: 220, width: double.infinity, fit: BoxFit.cover)),
            Positioned(
              right: 8,
              top: 8,
              child: CircleBtn(icon: Icons.close_rounded, label: 'রসিদ বাদ দিন', onTap: () => setState(() => _receipt = null)),
            ),
          ])
        else
          Row(children: [
            Expanded(child: SoftPill(label: 'ছবি তুলুন', icon: Icons.photo_camera_outlined, onTap: () => _pick(true))),
            const SizedBox(width: 8),
            Expanded(child: SoftPill(label: 'গ্যালারি থেকে', icon: Icons.photo_library_outlined, onTap: () => _pick(false))),
          ]),
      ]),
    );
  }
}

/// One payment to the agent, with its receipt.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key, required this.h, required this.p});
  final Hisab h;
  final AgentPayment p;

  @override
  Widget build(BuildContext context) {
    final txns = [for (final id in p.txnIds) h.txnById(id)].whereType<Txn>().toList();
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: t(13.5, c: K.muted))),
            Expanded(child: Text(v, textAlign: TextAlign.right, style: t(14.5, w: FontWeight.w500))),
          ]),
        );
    return Screen(
      title: 'এজেন্টকে দেওয়া',
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        CardBox(
          child: Column(children: [
            Text(taka(p.taka), style: t(30, w: FontWeight.w700, c: K.green)),
            const SizedBox(height: 8),
            kv('এজেন্ট', agentById(h.d, p.agentId)?.name ?? ''),
            kv('কবে', '${dateShort(p.at)} ${bn('${p.at.year}')}, ${timeText(p.at)}'),
            kv('কীভাবে', payWayName(p.way)),
            if (p.fromAccount.isNotEmpty) kv('কোথা থেকে', p.fromAccount),
            if (p.ref.isNotEmpty) kv('রেফারেন্স', p.ref),
            if (p.note.isNotEmpty) kv('নোট', p.note),
          ]),
        ),
        if (p.receipt != null) ...[
          SectionHead('রসিদ'),
          FutureBuilder<Uint8List?>(
            future: h.photo(p.receipt!),
            builder: (context, snap) {
              final b = snap.data;
              if (b == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
              return Column(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: InteractiveViewer(child: Image.memory(b))),
                const SizedBox(height: 8),
                SoftPill(label: 'রসিদ শেয়ার করুন', icon: Icons.ios_share_rounded, onTap: () => h.s.device.shareFile(b, 'rosid-${p.at.year}-${p.at.month}-${p.at.day}.jpg', 'image/jpeg')),
              ]);
            },
          ),
        ],
        if (txns.isNotEmpty) ...[
          SectionHead('যে লেনদেনগুলোর টাকা'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [for (final (i, x) in txns.indexed) TxnRow(h: h, t: x, last: i == txns.length - 1)]),
          ),
        ],
      ]),
    );
  }
}

class AgentEdit extends StatefulWidget {
  const AgentEdit({super.key, required this.h, this.a});
  final Hisab h;
  final Agent? a;

  @override
  State<AgentEdit> createState() => _AgentEditState();
}

class _AgentEditState extends State<AgentEdit> {
  late final _name = TextEditingController(text: widget.a?.name ?? '');
  late final _wa = TextEditingController(text: widget.a?.whatsapp ?? '');
  late final _comm = TextEditingController(text: widget.a == null ? '0' : groupEn(widget.a!.commissionPerThousand, decimals: 2).replaceAll(',', ''));

  @override
  Widget build(BuildContext context) => Screen(
        title: widget.a == null ? 'নতুন এজেন্ট' : 'এজেন্টের তথ্য',
        bottom: Pill(
          label: 'সংরক্ষণ',
          onTap: () async {
            final wa = en(_wa.text).replaceAll(RegExp(r'[^0-9+]'), '');
            if (_name.text.trim().isEmpty || wa.replaceAll('+', '').length < 9) {
              snack(context, 'নাম আর হোয়াটসঅ্যাপ নম্বর ঠিকমতো দিন');
              return;
            }
            final comm = parseNum(_comm.text) ?? 0;
            if (widget.a == null) {
              await widget.h.addAgent(_name.text, wa, comm);
            } else {
              await widget.h.updateAgent(widget.a!, name: _name.text, whatsapp: wa, commission: comm);
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
          Field(label: 'নাম', controller: _name),
          const SizedBox(height: 12),
          Field(label: 'হোয়াটসঅ্যাপ নম্বর (সব মেসেজ এই চ্যাটে যাবে)', controller: _wa, phone: true),
          const SizedBox(height: 12),
          Field(label: 'কমিশন (প্রতি হাজার টাকায়)', controller: _comm, number: true, suffix: '৳/হাজার'),
          const SizedBox(height: 14),
          if (widget.a != null)
            SoftPill(
              label: 'আরেকজন এজেন্ট যোগ করুন',
              icon: Icons.add_rounded,
              onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AgentEdit(h: widget.h))),
            ),
        ]),
      );
}
