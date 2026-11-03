import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'home.dart';
import 'kit.dart';
import '../core/lang.dart';
import 'reports.dart';
import 'txn.dart';
import 'users.dart' show UsersScreen;

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

  /// Payments shown: this month at first; any period can be chosen.
  Period? _payP;

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h;
        final d = h.d;
        final live = d.liveAgents;
        final a = live.firstWhere((x) => x.id == _agentId, orElse: () => live.first);
        final owed = agentOwed(d, a.id);
        final unpaid = unpaidForAgent(d, a.id);
        _picked.removeWhere((id) => !unpaid.any((x) => x.id == id));
        final pickedList = unpaid.where((x) => _picked.contains(x.id)).toList();
        final pickedSum = pickedList.fold<double>(0, (s, x) => s + x.agentTaka + commissionOf(x, a));
        final now = h.now;
        final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
        final vals = [for (final day in days) d.txns.where((x) => x.agentId == a.id && x.status == TxnStatus.sent && sameDay(x.at, day)).fold<double>(0, (s, x) => s + x.agentTaka)];
        final payP = _payP ?? Period.of('month', now);
        final pays = d.agentPayments.where((p) => p.agentId == a.id && payP.has(p.at)).toList()..sort((x, y) => y.at.compareTo(x.at));
        final allPays = d.agentPayments.any((p) => p.agentId == a.id);
        final wd = appEnglish ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] : const ['সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
          Row(children: [
            Expanded(child: Tx('এজেন্ট', style: t(22, w: FontWeight.w700))),
            if (h.can('reports')) CircleBtn(icon: Icons.picture_as_pdf_outlined, label: 'এজেন্টের হিসাব PDF', onTap: () => _pdf(context, h, a)),
            const SizedBox(width: 8),
            CircleBtn(icon: Icons.settings_outlined, label: 'এজেন্টের সেটিংস', onTap: () => push(context, AgentSettingsScreen(h: h))),
          ]),
          if (live.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in live) ChoiceChipX(label: x.name, on: x.id == a.id, onTap: () => setState(() => _agentId = x.id)),
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
                    Tx(a.name, style: t(16, w: FontWeight.w600)),
                    Tx('${a.usesApp ? 'অ্যাপে কাজ করেন' : 'হোয়াটসঅ্যাপে'} · ${bn(a.whatsapp)}', style: t(12.5, c: K.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Tx(owed >= 0 ? 'এজেন্টকে দিতে হবে' : 'এজেন্টের কাছে অগ্রিম', style: t(13, c: K.muted)),
              Tx(taka(owed.abs()), style: t(30, w: FontWeight.w700, c: owed > 0 ? K.navy : K.green)),
              if (a.commissionPerThousand > 0) Tx('কমিশন হাজারে ${bnNum(a.commissionPerThousand, decimals: 2)} টাকা ধরে', style: t(12.5, c: K.muted)),
              const SizedBox(height: 14),
              Row(children: [
                if (h.can('agent_pay'))
                  Expanded(
                    child: Pill(
                      label: 'টাকা দিলাম',
                      height: 48,
                      onTap: () => push(context, AgentPayScreen(h: h, a: a, txns: const [])),
                    ),
                  ),
                if (h.can('agent_pay')) const SizedBox(width: 10),
                Expanded(
                    child: Pill(
                      label: 'আজকের হিসাব',
                      color: K.navy,
                      height: 48,
                      onTap: () => _previewDay(context, h, a),
                    ),
                  ),
              ]),
            ]),
          ),
          ..._agentSummary(context, h, a),
          const SizedBox(height: 12),
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx('গত ৭ দিনে এজেন্ট যত টাকা পাঠালেন', style: t(15, w: FontWeight.w600)),
              const SizedBox(height: 10),
              LineChart(values: vals, labels: [for (final day in days) wd[day.weekday - 1]], caption: 'গত সাত দিনে এজেন্টের পাঠানো টাকা', markLabel: taka(vals.reduce((x, y) => x > y ? x : y))),
            ]),
          ),
          SectionHead('দিনভিত্তিক অনুরোধ ও এজেন্টের কাজ'),
          AgentDaySection(key: ValueKey(a.id), h: h, a: a),
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
                    title: Tx('#${bn('${x.no}')} · ${bdMasked(x.number)}', style: t(14.5, w: FontWeight.w500)),
                    subtitle: Tx('${dateShort(x.at)} · ${x.status == TxnStatus.pending ? 'পাঠানোর অপেক্ষায়' : (proofText(x).isEmpty ? 'পাঠানো' : proofText(x))}',
                        style: t(12.5, c: x.status == TxnStatus.pending ? K.red : K.muted)),
                    secondary: Tx(taka(x.agentTaka), style: t(14.5, w: FontWeight.w600)),
                  ),
              ]),
            ),
          if (pickedList.isNotEmpty && h.can('agent_pay')) ...[
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
          if (allPays) ...[
            SectionHead('এজেন্টকে দেওয়া টাকা'),
            PeriodChips(value: payP, now: now, onChanged: (p) => setState(() => _payP = p)),
            const SizedBox(height: 8),
            Tx('${payP.label}: ${bn('${pays.length}')} বার · ${taka(pays.fold<double>(0, (s, p) => s + p.taka))}${pays.any((p) => p.sarAmount > 0) ? ' · ${sar(pays.fold<double>(0, (s, p) => s + p.sarAmount))}' : ''}', style: t(13, c: K.muted)),
            const SizedBox(height: 8),
            if (pays.isEmpty) const Note('এই সময়ে এজেন্টকে কিছু দেওয়া হয়নি।'),
            if (pays.isNotEmpty)
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (final (i, p) in pays.take(200).indexed)
                  Row2(
                    lead: dotIcon(p.receipt != null ? Icons.receipt_long_rounded : Icons.payments_outlined, K.greenTint, K.green, size: 38),
                    title: p.txnIds.isEmpty ? 'টাকা দিলাম · ${payWayName(p.way)}' : '${bn('${p.txnIds.length}')}টা লেনদেনের টাকা · ${payWayName(p.way)}',
                    sub: '${dateShort(p.at)} · ${timeText(p.at)}${p.ref.isEmpty ? '' : ' · রেফ ${p.ref}'}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                    onTap: () => push(context, PaymentScreen(h: h, p: p)),
                    value: taka(p.taka),
                    valueColor: K.green,
                    valueSub: p.sarAmount > 0 ? sar(p.sarAmount) : null,
                    last: i == pays.take(200).length - 1,
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
        Tx('কোন সময়ের হিসাব?', style: t(17, w: FontWeight.w600)),
        for (final k in ['today', 'week', 'month', 'lastMonth', 'all'])
          ListTile(title: Tx(k == 'all' ? 'সব সময়' : Period.of(k, h.now).label, style: t(15)), onTap: () => Navigator.pop(ctx, k == 'all' ? Period.all() : Period.of(k, h.now))),
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
  final _sar = TextEditingController();
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
    final r = parseNum(_sar.text);
    if (r == null || r <= 0) {
      snack(context, 'এই টাকার জন্য কত রিয়াল গেল, লিখুন — রিয়ালের হিসাব মেলাতে লাগবে');
      return;
    }
    setState(() => _busy = true);
    final h = widget.h;
    if (widget.txns.isEmpty) {
      await h.advanceAgent(widget.a, n, sarOut: r, way: _way, note: _note.text, ref: _ref.text, fromAccount: _from.text, receipt: _receipt, at: _at);
    } else {
      await h.payAgent(widget.a, widget.txns, sarOut: r, way: _way, note: _note.text, ref: _ref.text, fromAccount: _from.text, receipt: _receipt, at: _at, amount: n);
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
        const SizedBox(height: 12),
        Field(label: 'এর জন্য কত রিয়াল গেল (বাধ্যতামূলক)', controller: _sar, number: true, suffix: 'SAR', onChanged: (_) => setState(() {})),
        if (n != null && (parseNum(_sar.text) ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 6),
            child: Tx('রেট দাঁড়াল ${rateText(n / parseNum(_sar.text)!)} · আপনার হাতের রিয়াল থেকে বাদ যাবে', style: t(12.5, c: K.muted)),
          ),
        const SizedBox(height: 14),
        Tx('কীভাবে দিলেন', style: t(13, c: K.muted)),
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
            Expanded(child: Tx('কবে: ${dateShort(_at)} ${bn('${_at.year}')}, ${timeText(_at)}', style: t(15))),
            Tx('বদলান', style: t(13, c: K.blue)),
          ]),
        ),
        const SizedBox(height: 12),
        Field(label: _way == 'bank' ? 'কোন ব্যাংক/অ্যাকাউন্ট থেকে' : 'কোন নম্বর/অ্যাকাউন্ট থেকে (ইচ্ছা হলে)', controller: _from),
        const SizedBox(height: 12),
        Field(label: 'রেফারেন্স / ট্রানজেকশন নম্বর (ইচ্ছা হলে)', controller: _ref),
        const SizedBox(height: 12),
        Field(label: 'নোট (ইচ্ছা হলে)', controller: _note),
        const SizedBox(height: 14),
        Tx('ব্যাংকের রসিদ (ইচ্ছা হলে)', style: t(13, c: K.muted)),
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

  Future<void> _editSar(BuildContext context) async {
    final v = await askText(context, 'এই ${taka(p.taka)}-এর জন্য আসলে কত রিয়াল গেল?', initial: p.sarAmount > 0 ? groupEn(p.sarAmount, decimals: 2).replaceAll(',', '') : '', number: true, hint: 'SAR');
    final n = v == null ? null : parseNum(v);
    if (n == null || n <= 0 || !context.mounted) {
      if (v != null && context.mounted) snack(context, 'সঠিক রিয়াল লিখুন');
      return;
    }
    final why = await askText(context, 'কেন বদলালেন? (ইচ্ছা হলে)', ok: 'বদলান');
    if (why == null) return;
    await h.editPaymentSar(p, n, why: why);
    if (context.mounted) snack(context, 'রিয়াল ঠিক করা হলো');
  }

  @override
  Widget build(BuildContext context) => Live(h: h, builder: (context) => _body(context));

  Widget _body(BuildContext context) {
    final txns = [for (final id in p.txnIds) h.txnById(id)].whereType<Txn>().toList();
    final edits = h.d.log.where((e) => e.ref == p.agentId && e.title == 'এজেন্টকে পরিশোধের রিয়াল বদল' && e.detail.contains(dateShort(p.at)) && e.detail.contains(taka(p.taka))).toList();
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Tx(k, style: t(13.5, c: K.muted))),
            Expanded(child: Tx(v, textAlign: TextAlign.right, style: t(14.5, w: FontWeight.w500))),
          ]),
        );
    return Screen(
      title: 'এজেন্টকে দেওয়া',
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        CardBox(
          child: Column(children: [
            Tx(taka(p.taka), style: t(30, w: FontWeight.w700, c: K.green)),
            const SizedBox(height: 8),
            kv('এজেন্ট', agentById(h.d, p.agentId)?.name ?? ''),
            kv('কবে', '${dateShort(p.at)} ${bn('${p.at.year}')}, ${timeText(p.at)}'),
            Row(children: [
              Expanded(child: kv('রিয়াল', p.sarAmount > 0 ? sar(p.sarAmount) : 'লেখা হয়নি')),
              if (h.can('agent_pay'))
                IconButton(tooltip: tr('রিয়াল ঠিক করুন'), icon: const Icon(Icons.edit_outlined, size: 20, color: K.blue), onPressed: () => _editSar(context)),
            ]),
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
        if (h.can('agent_pay')) ...[
          const SizedBox(height: 10),
          const Note('টাকার অঙ্ক বদলানো বা পরিশোধ মোছা যায় না। শুধু রিয়াল ভুল হলে ঠিক করা যায়, আর প্রতিটা বদল নিচে আর কাজের লগে থাকে।'),
        ],
        if (edits.isNotEmpty) ...[
          SectionHead('রিয়ালের বদল'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [for (final (i, e) in edits.reversed.indexed) LogRow(e: e, last: i == edits.length - 1)]),
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
  Future<void> _delete(BuildContext context) async {
    final h = widget.h, a = widget.a!;
    if (h.d.liveAgents.length <= 1) {
      snack(context, 'এটাই একমাত্র এজেন্ট — আগে আরেকজন এজেন্ট যোগ করুন, তারপর এটা ডিলিট করুন');
      return;
    }
    final owed = agentOwed(h.d, a.id);
    final pending = h.d.txns.where((x) => x.agentId == a.id && x.status == TxnStatus.pending).length;
    final warn = [
      if (owed > 0) 'এজেন্টকে এখনো ${taka(owed)} দেওয়া বাকি।',
      if (owed < 0) 'এজেন্টের কাছে ${taka(-owed)} অগ্রিম আছে।',
      if (pending > 0) '${bn('$pending')}টা লেনদেন এখনো পাঠানোর অপেক্ষায়।',
    ].join(' ');
    if (!await confirm(context, '${a.name}-কে ডিলিট করবেন?',
        '${warn.isEmpty ? '' : '$warn\n\n'}এজেন্ট আর কোনো তালিকায় থাকবে না, নতুন লেনদেনে বাছাই করা যাবে না, আর তাঁর সব লগইন মুছে যাবে। আগের লেনদেন আর পরিশোধে তাঁর নাম থাকবে। এটা ফেরানো যাবে না।',
        yes: 'ডিলিট', danger: true)) {
      return;
    }
    await h.deleteAgent(a);
    await h.sync();
    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      snack(context, '${a.name} ডিলিট হলো');
    }
  }

  late final _name = TextEditingController(text: widget.a?.name ?? '');
  late final _wa = TextEditingController(text: widget.a?.whatsapp ?? '');
  late final _comm = TextEditingController(text: widget.a == null ? '0' : groupEn(widget.a!.commissionPerThousand, decimals: 2).replaceAll(',', ''));
  late String _channel = widget.a?.channel ?? 'whatsapp';

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
              final a = await widget.h.addAgent(_name.text, wa, comm);
              await widget.h.setAgentChannel(a, _channel);
            } else {
              await widget.h.updateAgent(widget.a!, name: _name.text, whatsapp: wa, commission: comm);
              await widget.h.setAgentChannel(widget.a!, _channel);
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
          Tx('অনুরোধ কীভাবে যাবে', style: t(13, c: K.muted)),
          const SizedBox(height: 6),
          Seg<String>(items: const [('whatsapp', 'হোয়াটসঅ্যাপে'), ('app', 'অ্যাপে (নোটিফিকেশন)')], value: _channel, onChanged: (v) => setState(() => _channel = v)),
          const SizedBox(height: 8),
          Note(_channel == 'app'
              ? 'এজেন্ট নিজের লগইনে এই অ্যাপ ব্যবহার করবেন। প্রতিটা অনুরোধ, সংশোধন, বাতিল আর টাকা দেওয়ার নোটিফিকেশন তাঁর ফোনে যাবে। লগইন বানাতে: অন্যান্য → লগইন ও অনুমতি।'
              : 'প্রতিটা অনুরোধ এজেন্টের হোয়াটসঅ্যাপ চ্যাটে লেখা অবস্থায় খুলবে, আপনি Send চাপবেন।'),
          const SizedBox(height: 14),
          if (widget.a != null)
            SoftPill(
              label: 'আরেকজন এজেন্ট যোগ করুন',
              icon: Icons.add_rounded,
              onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AgentEdit(h: widget.h))),
            ),
          if (widget.a != null && widget.h.isOwner) ...[
            const SizedBox(height: 10),
            SoftPill(label: 'এজেন্ট ডিলিট করুন', icon: Icons.delete_outline_rounded, color: K.red, onTap: () => _delete(context)),
          ],
        ]),
      );
}

/// One day of an agent: what was asked of them, what they sent, what was
/// changed or cancelled, payments, and every logged step, by time.
/// The day's statement for the agent: shown first, sent only if wanted.
Future<void> _previewDay(BuildContext context, Hisab h, Agent a) async {
  final text = agentDayStatement(h.d, a, h.now);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Tx('আজকের হিসাব · ${a.name}', style: t(18, w: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Flexible(child: SingleChildScrollView(child: CardBox(child: SelectableText(text, style: t(14, h: 1.55))))),
        const SizedBox(height: 14),
        Pill(
          label: 'হোয়াটসঅ্যাপে পাঠান',
          icon: Icons.send_rounded,
          color: K.green,
          onTap: () async {
            Navigator.pop(ctx);
            await h.s.device.whatsapp(a.whatsapp, text);
            await h.note('agent', 'এজেন্টকে দিনের হিসাব', a.name);
          },
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Tx('শুধু দেখা', style: t(14, c: K.muted))),
      ]),
    ),
  );
}

/// Agents and their logins, from the gear on the এজেন্ট tab.
class AgentSettingsScreen extends StatelessWidget {
  const AgentSettingsScreen({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) => Screen(
            title: 'এজেন্টের সেটিংস',
            body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
              SectionHead('এজেন্ট', action: h.can('agents') ? 'নতুন এজেন্ট' : null, onAction: () => push(context, AgentEdit(h: h))),
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, a) in h.d.liveAgents.indexed)
                    Row2(
                      lead: dotIcon(Icons.storefront_rounded, K.navySoft, K.navy, size: 38),
                      title: a.name,
                      sub: '${a.usesApp ? 'অ্যাপে কাজ করেন' : 'হোয়াটসঅ্যাপে'} · ${bn(a.whatsapp)}${a.commissionPerThousand > 0 ? ' · কমিশন হাজারে ${bnNum(a.commissionPerThousand, decimals: 2)}' : ''}',
                      value: h.can('agents') ? '›' : null,
                      valueColor: K.muted,
                      onTap: h.can('agents') ? () => push(context, AgentEdit(h: h, a: a)) : null,
                      last: i == h.d.liveAgents.length - 1,
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Tx(h.isOwner ? 'কোনো এজেন্টে চাপলে তথ্য বদলানো, যোগাযোগের ধরন আর ডিলিট করা যায়।' : 'এজেন্ট ডিলিট শুধু মূল এডমিন করতে পারেন।', style: t(12.5, c: K.muted)),
              if (h.session != null && h.can('users')) ...[
                SectionHead('এজেন্টের লগইন'),
                CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row2(
                    lead: dotIcon(Icons.manage_accounts_rounded, K.blueTint, K.blue, size: 38),
                    title: 'এজেন্টের লগইন বানান ও মুছুন',
                    sub: 'এজেন্ট নিজের লগইনে অ্যাপে অনুরোধ দেখবেন',
                    value: '›',
                    valueColor: K.muted,
                    onTap: () => push(context, UsersScreen(h: h, only: 'agent')),
                    last: true,
                  ),
                ),
              ],
            ]),
          ));
}

class AgentDayScreen extends StatelessWidget {
  const AgentDayScreen({super.key, required this.h, required this.a});
  final Hisab h;
  final Agent a;
  @override
  Widget build(BuildContext context) => Screen(
        title: '${a.name} · দিনের কাজ',
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [AgentDaySection(h: h, a: a)]),
      );
}

/// One day of an agent, inside the এজেন্ট tab: a day picker, the counts,
/// the requests and everything that happened.
class AgentDaySection extends StatefulWidget {
  const AgentDaySection({super.key, required this.h, required this.a});
  final Hisab h;
  final Agent a;
  @override
  State<AgentDaySection> createState() => _AgentDaySectionState();
}

class _AgentDaySectionState extends State<AgentDaySection> {
  bool _allLog = false;

  late DateTime _day = DateTime(widget.h.now.year, widget.h.now.month, widget.h.now.day);

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h, d = h.d, a = widget.a;
        final today = DateTime(h.now.year, h.now.month, h.now.day);
        final mine = d.txns.where((x) => x.agentId == a.id).toList();
        final asked = mine.where((x) => sameDay(x.at, _day)).toList()..sort((x, y) => x.at.compareTo(y.at));
        final sent = mine.where((x) => !x.cancelled && x.sentAt != null && sameDay(x.sentAt!, _day)).toList();
        final cancelled = asked.where((x) => x.cancelled).toList();
        final waiting = asked.where((x) => !x.cancelled && x.status == TxnStatus.pending).toList();
        final faults = asked.where((x) => x.fault == Fault.agent).length;
        final paid = d.agentPayments.where((p) => p.agentId == a.id && sameDay(p.at, _day)).toList();
        final refs = {a.id, for (final x in mine) x.id};
        final log = d.log.where((e) => refs.contains(e.ref) && sameDay(e.at, _day)).toList()..sort((x, y) => y.at.compareTo(x.at));
        final label = sameDay(_day, today) ? 'আজ' : (sameDay(_day, today.subtract(const Duration(days: 1))) ? 'গতকাল' : dateShort(_day));
        final logShown = _allLog ? log : log.take(6).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(tooltip: tr('আগের দিন'), icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _day = DateTime(_day.year, _day.month, _day.day - 1))),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final p = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2024), lastDate: today);
                    if (p != null) setState(() => _day = p);
                  },
                  child: Column(children: [
                    Tx(label, style: t(17, w: FontWeight.w700)),
                    Tx('${weekdayName(_day)} · ${dateShort(_day)}', style: t(12, c: K.muted)),
                  ]),
                ),
              ),
              IconButton(
                tooltip: tr('পরের দিন'),
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: sameDay(_day, today) ? null : () => setState(() => _day = DateTime(_day.year, _day.month, _day.day + 1)),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _stat('অনুরোধ', '${bn('${asked.length}')}টা', taka(asked.where((x) => !x.cancelled).fold<double>(0, (s, x) => s + x.agentTaka))),
              _stat('পাঠালেন', '${bn('${sent.length}')}টা', taka(sent.fold<double>(0, (s, x) => s + x.agentTaka))),
              _stat('পাঠানোর অপেক্ষায়', '${bn('${waiting.length}')}টা', taka(waiting.fold<double>(0, (s, x) => s + x.agentTaka)), warn: waiting.isNotEmpty),
              _stat('বাতিল', '${bn('${cancelled.length}')}টা', faults > 0 ? 'এজেন্টের ভুল ${bn('$faults')}টা' : '', warn: faults > 0),
              _stat('পরিশোধ পেলেন', '${bn('${paid.length}')} বার', taka(paid.fold<double>(0, (s, p) => s + p.taka))),
            ]),
            const SizedBox(height: 10),
            Tx('এই দিনে পাঠানো অনুরোধ', style: t(14, w: FontWeight.w600)),
            const SizedBox(height: 6),
            if (asked.isEmpty) const Note('এই দিনে কোনো অনুরোধ পাঠানো হয়নি।'),
            if (asked.isNotEmpty)
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [for (final (i, x) in asked.reversed.indexed) TxnRow(h: h, t: x, last: i == asked.length - 1)]),
              ),
            const SizedBox(height: 10),
            Tx('কখন কী হলো', style: t(14, w: FontWeight.w600)),
            const SizedBox(height: 6),
            if (log.isEmpty) const Note('এই দিনের কোনো কাজের রেকর্ড নেই।'),
            if (log.isNotEmpty)
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [for (final (i, e) in logShown.indexed) LogRow(e: e, last: i == logShown.length - 1)]),
              ),
            if (log.length > logShown.length)
              TextButton(onPressed: () => setState(() => _allLog = true), child: Tx('আরও ${bn('${log.length - logShown.length}')}টা দেখুন', style: t(13, c: K.blue))),
          ]);
      });

  Widget _stat(String label, String big, String small, {bool warn = false}) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 36 - 8) / 2,
        child: CardBox(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(label, style: t(12.5, c: K.muted)),
            Tx(big, style: t(18, w: FontWeight.w700, c: warn ? K.red : K.ink)),
            if (small.isNotEmpty) Tx(small, style: t(12.5, c: K.muted)),
          ]),
        ),
      );
}


/// The agent at a glance: this month's requests, what was sent, what still
/// waits, what was paid to them, and the commission.
List<Widget> _agentSummary(BuildContext context, Hisab h, Agent a) {
  final d = h.d, now = h.now;
  final month = Period.of('month', now);
  final mine = d.txns.where((x) => x.agentId == a.id && !x.cancelled).toList();
  final inMonth = mine.where((x) => month.has(x.at)).toList();
  final sent = inMonth.where((x) => x.status == TxnStatus.sent).toList();
  final waiting = mine.where((x) => x.status == TxnStatus.pending).toList();
  final paid = d.agentPayments.where((p) => p.agentId == a.id && month.has(p.at)).toList();
  final comm = inMonth.fold<double>(0, (s, x) => s + commissionOf(x, a));
  final wrong = inMonth.where((x) => x.fault == Fault.agent).length;
  Widget box(String label, String big, String small, {Color c = K.ink}) => Expanded(
        child: CardBox(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tx(label, style: t(12.5, c: K.muted)),
            Tx(big, style: t(17, w: FontWeight.w700, c: c)),
            if (small.isNotEmpty) Tx(small, style: t(12, c: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
  return [
    SectionHead('সারসংক্ষেপ · এ মাসে'),
    Row(children: [
      box('অনুরোধ', '${bn('${inMonth.length}')}টা', taka(inMonth.fold<double>(0, (s, x) => s + x.agentTaka))),
      const SizedBox(width: 10),
      box('পাঠিয়েছেন', '${bn('${sent.length}')}টা', taka(sent.fold<double>(0, (s, x) => s + x.agentTaka)), c: K.green),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      box('পাঠানোর অপেক্ষায়', '${bn('${waiting.length}')}টা', taka(waiting.fold<double>(0, (s, x) => s + x.agentTaka)), c: waiting.isEmpty ? K.ink : K.red),
      const SizedBox(width: 10),
      box('এ মাসে দিলাম', taka(paid.fold<double>(0, (s, p) => s + p.taka)), paid.any((p) => p.sarAmount > 0) ? sar(paid.fold<double>(0, (s, p) => s + p.sarAmount)) : '${bn('${paid.length}')} বার'),
    ]),
    if (comm > 0 || wrong > 0) ...[
      const SizedBox(height: 10),
      Row(children: [
        box('কমিশন', taka(comm), 'হাজারে ${bnNum(a.commissionPerThousand, decimals: 2)}'),
        const SizedBox(width: 10),
        box('এজেন্টের ভুল', '${bn('$wrong')}টা', 'ভুল নম্বরে', c: wrong > 0 ? K.red : K.ink),
      ]),
    ],
  ];
}
