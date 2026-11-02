import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'customers.dart';
import 'home.dart';
import 'kit.dart';
import 'txn.dart';

/// Step 1: find the customer by name or number, or make a quick profile.
class PickCustomer extends StatefulWidget {
  const PickCustomer({super.key, required this.h, required this.forDeposit});
  final Hisab h;
  final bool forDeposit;

  @override
  State<PickCustomer> createState() => _PickCustomerState();
}

class _PickCustomerState extends State<PickCustomer> {
  final _q = TextEditingController();
  Hisab get h => widget.h;

  void _open(Customer c) {
    if (widget.forDeposit) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DepositScreen(h: h, c: c)));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EntryScreen(h: h, c: c)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = h.searchCustomers(_q.text);
    final q = _q.text.trim();
    return Screen(
      title: widget.forDeposit ? 'কে রিয়াল দিলেন?' : 'কে পাঠাবেন?',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: TextField(
            controller: _q,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: t(16),
            decoration: InputDecoration(
              hintText: 'নাম বা মোবাইল নম্বর',
              hintStyle: t(15, c: const Color(0xFFA0A0A0)),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: K.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.blue, width: 2)),
            ),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
            CardBox(
              color: K.blueTint,
              onTap: () async {
                final digits = en(q).replaceAll(RegExp(r'[^0-9+]'), '');
                final c = await push<Customer>(context, QuickProfile(h: h, name: digits.length >= 5 ? '' : q, phone: digits.length >= 5 ? digits : ''));
                if (c != null && mounted) _open(c);
              },
              child: Row(children: [
                dotIcon(Icons.person_add_alt_1_rounded, Colors.white, K.blue),
                const SizedBox(width: 12),
                Expanded(child: Text(q.isEmpty ? 'নতুন গ্রাহক (দ্রুত প্রোফাইল)' : 'নতুন গ্রাহক: "$q"', style: t(15, w: FontWeight.w600, c: K.navy))),
                const Icon(Icons.chevron_right_rounded, color: K.navy),
              ]),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty && q.isNotEmpty) Note('"$q" নামে বা নম্বরে কেউ নেই। ওপরে চাপ দিয়ে প্রোফাইল বানান।'),
            if (list.isNotEmpty)
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, c) in list.take(40).indexed) _CustomerPickRow(h: h, c: c, last: i == list.take(40).length - 1, onTap: () => _open(c)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _CustomerPickRow extends StatelessWidget {
  const _CustomerPickRow({required this.h, required this.c, required this.last, required this.onTap});
  final Hisab h;
  final Customer c;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final due = customerDue(h.d, c.id);
    return Row2(
      lead: Avatar(h: h, name: c.name, photo: c.photo),
      title: c.name,
      sub: '${bn(c.phone)}${c.area.isEmpty ? '' : ' · ${c.area}'}',
      value: due > 0 ? sar(due) : (due < 0 ? 'অগ্রিম' : 'পরিষ্কার'),
      valueColor: due > 0 ? K.red : K.green,
      valueSub: due > 0 ? 'বাকি' : (due < 0 ? sar(-due) : null),
      last: last,
      onTap: onTap,
    );
  }
}

/// Quick profile: photo, name, phone, area. Returns the new customer.
class QuickProfile extends StatefulWidget {
  const QuickProfile({super.key, required this.h, this.name = '', this.phone = ''});
  final Hisab h;
  final String name;
  final String phone;

  @override
  State<QuickProfile> createState() => _QuickProfileState();
}

class _QuickProfileState extends State<QuickProfile> {
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(text: widget.phone);
  final _area = TextEditingController();
  Uint8List? _photo;
  String? _err;
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'নাম লিখুন');
      return;
    }
    final phone = en(_phone.text).replaceAll(RegExp(r'[^0-9+]'), '');
    final same = phone.length >= 6 ? widget.h.d.customers.where((c) => en(c.phone).replaceAll(RegExp(r'[^0-9+]'), '') == phone).toList() : <Customer>[];
    if (same.isNotEmpty) {
      final use = await confirm(context, 'এই নম্বর আগেই আছে', '${same.first.name} — ${bn(same.first.phone)}। তাঁর প্রোফাইল নেবেন?', yes: 'হ্যাঁ, ওটা নিন', no: 'না, নতুন বানান');
      if (!mounted) return;
      if (use) {
        Navigator.pop(context, same.first);
        return;
      }
    }
    setState(() => _busy = true);
    final c = await widget.h.addCustomer(name: _name.text, phone: phone, area: _area.text, photo: _photo);
    if (mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) => Screen(
        title: 'নতুন গ্রাহক',
        bottom: Pill(label: 'সংরক্ষণ করে এগোন', icon: Icons.arrow_forward_rounded, onTap: _busy ? null : _save),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: [
          Center(
            child: Semantics(
              button: true,
              label: 'ছবি তুলুন',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  final b = await widget.h.s.device.takePhoto();
                  if (b != null && mounted) setState(() => _photo = b);
                },
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: K.card, border: Border.all(color: K.border, width: 2)),
                  clipBehavior: Clip.antiAlias,
                  child: _photo != null
                      ? Image.memory(_photo!, fit: BoxFit.cover)
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.photo_camera_outlined, size: 34, color: K.blue),
                          Text('ছবি তুলুন', style: t(13, c: K.blue)),
                        ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Field(label: 'নাম', controller: _name, autofocus: widget.name.isEmpty && widget.phone.isNotEmpty ? true : widget.name.isEmpty),
          const SizedBox(height: 12),
          Field(label: 'মোবাইল (সৌদি বা দেশের)', controller: _phone, phone: true, hint: '05XXXXXXXX'),
          const SizedBox(height: 12),
          Field(label: 'কোথায় থাকেন / কাজ করেন (ইচ্ছা হলে)', controller: _area),
          if (_err != null) ...[const SizedBox(height: 12), Note(_err!, color: K.redTint, textColor: K.red)],
          const SizedBox(height: 12),
          const Note('বাকি তথ্য (বাড়ি, বেতনের তারিখ, বাকির সীমা) পরে গ্রাহকের পাতা থেকে যোগ করা যাবে।'),
        ]),
      );
}

/// Step 2: riyal, rate → taka, bKash number, fee.
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, required this.h, required this.c, this.editing});
  final Hisab h;
  final Customer c;

  /// When set, the screen changes this send instead of making a new one.
  final Txn? editing;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  Hisab get h => widget.h;
  final _sar = TextEditingController();
  final _rate = TextEditingController();
  final _taka = TextEditingController();
  final _number = TextEditingController();
  final _label = TextEditingController();
  final _fee = TextEditingController();
  Method _method = Method.bkash;
  Kind _kind = Kind.send;
  bool _withFee = false;
  late String _agentId;
  bool _takaByHand = false;

  @override
  void initState() {
    super.initState();
    _agentId = h.d.agents.first.id;
    final e = widget.editing;
    if (e != null) {
      _sar.text = groupEn(e.sarAmount, decimals: 2).replaceAll(',', '');
      _rate.text = e.rate.toStringAsFixed(2);
      _taka.text = e.taka.round().toString();
      _number.text = e.number;
      _label.text = e.recipientLabel;
      _fee.text = e.fee > 0 ? e.fee.round().toString() : '';
      _withFee = e.fee > 0;
      _method = e.method;
      _kind = e.kind;
      _agentId = agentById(h.d, e.agentId)?.id ?? _agentId;
      _takaByHand = (takaFor(e.sarAmount, e.rate) - e.taka).abs() > 0.5;
    } else {
      // Last rate used, so it is only typed when it changes.
      final last = [...h.d.txns.where((t) => !t.cancelled)]..sort((a, b) => b.at.compareTo(a.at));
      if (last.isNotEmpty) _rate.text = last.first.rate.toStringAsFixed(2);
      if (widget.c.recipients.isNotEmpty) _pickRecipient(widget.c.recipients.last);
    }
  }

  void _pickRecipient(Recipient r) {
    _number.text = bdShowEn(r.number);
    _label.text = r.label;
    _method = r.method;
  }

  void _recalc() {
    if (_takaByHand) return;
    final s = parseNum(_sar.text), r = parseNum(_rate.text);
    _taka.text = s != null && r != null ? takaFor(s, r).round().toString() : '';
  }

  String? get _numErr {
    if (_number.text.trim().isEmpty) return null;
    if (_method == Method.bank) return null;
    return bdMobile(_number.text) == null ? '১১ সংখ্যার নম্বর দিন (01XXXXXXXXX)' : null;
  }

  Txn? _draft() {
    final s = parseNum(_sar.text), r = parseNum(_rate.text), tk = parseNum(_taka.text);
    final num = _method == Method.bank ? en(_number.text.trim()) : bdMobile(_number.text);
    if (s == null || s <= 0 || r == null || r <= 0 || tk == null || tk <= 0 || num == null || num.isEmpty) return null;
    final fee = _withFee ? (parseNum(_fee.text) ?? 0) : 0.0;
    final e = widget.editing;
    return Txn(
      id: e?.id ?? '',
      no: e?.no ?? 0,
      customerId: widget.c.id,
      recipientLabel: _label.text.trim(),
      number: num,
      method: _method,
      kind: _kind,
      sarAmount: s,
      rate: r,
      taka: tk.roundToDouble(),
      fee: fee,
      agentId: _agentId,
      pay: e?.pay ?? Pay.due,
      sarPaid: e?.sarPaid ?? 0,
      at: e?.at ?? h.now,
      status: e?.status ?? TxnStatus.pending,
      trxId: e?.trxId ?? '',
      sentAt: e?.sentAt,
      agentPaymentId: e?.agentPaymentId,
      note: e?.note ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final due = customerDue(h.d, c.id);
    final draft = _draft();
    return Screen(
      title: widget.editing == null ? 'কত পাঠাবেন' : 'লেনদেন সংশোধন #${bn('${widget.editing!.no}')}',
      bottom: Pill(
        label: widget.editing == null ? 'পরের ধাপ' : 'পরের ধাপ (মিলিয়ে দেখুন)',
        icon: Icons.arrow_forward_rounded,
        onTap: draft == null
            ? null
            : () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => ConfirmSheet(h: h, c: c, draft: draft, editing: widget.editing),
                ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        CardBox(
          child: Row(children: [
            Avatar(h: h, name: c.name, photo: c.photo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: t(16, w: FontWeight.w600)),
                Text(bn(c.phone), style: t(12.5, c: K.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(due > 0 ? sar(due) : 'পরিষ্কার', style: t(14.5, w: FontWeight.w700, c: due > 0 ? K.red : K.green)),
              Text(due > 0 ? 'আগের বাকি' : 'বাকি নেই', style: t(12, c: K.muted)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Field(label: 'কত রিয়াল', controller: _sar, number: true, big: true, suffix: 'SAR', autofocus: widget.editing == null, hint: '০', onChanged: (_) => setState(_recalc)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Field(label: 'রেট (১ রিয়াল = ? টাকা)', controller: _rate, number: true, hint: '৩২.৫০', onChanged: (_) => setState(_recalc))),
          const SizedBox(width: 10),
          Expanded(
            child: Field(
              label: _takaByHand ? 'টাকা (হাতে লেখা)' : 'টাকা (অটো)',
              controller: _taka,
              number: true,
              prefix: '৳ ',
              onChanged: (_) => setState(() => _takaByHand = true),
            ),
          ),
        ]),
        if (_takaByHand)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _takaByHand = false;
                _recalc();
              }),
              child: Text('রিয়াল × রেট থেকে আবার হিসাব', style: t(13, c: K.blue)),
            ),
          ),
        const SizedBox(height: 16),
        Text('কার কাছে যাবে', style: t(13, c: K.muted)),
        const SizedBox(height: 6),
        if (c.recipients.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in c.recipients)
              ChoiceChipX(
                label: '${r.label.isEmpty ? '' : '${r.label} · '}${bdMasked(r.number)}',
                on: bdMobile(_number.text) == r.number || en(_number.text.trim()) == r.number,
                onTap: () => setState(() => _pickRecipient(r)),
              ),
          ]),
          const SizedBox(height: 10),
        ],
        Seg<Method>(items: [for (final m in Method.values) (m, m.bnName)], value: _method, onChanged: (m) => setState(() => _method = m)),
        const SizedBox(height: 10),
        Field(
          label: _method == Method.bank ? 'অ্যাকাউন্ট নম্বর' : '${_method.bnName} নম্বর',
          controller: _number,
          phone: _method != Method.bank,
          hint: '01XXXXXXXXX',
          error: _numErr,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Field(label: 'প্রাপক কে (যেমন স্ত্রী, বাবা — ইচ্ছা হলে)', controller: _label, onChanged: (_) => setState(() {})),
        if (bdMobile(_number.text) != null && parseNum(_taka.text) != null) ..._dupWarning(),
        const SizedBox(height: 14),
        if (_method != Method.bank) ...[
          Seg<Kind>(items: [for (final k in Kind.values) (k, k.bnName)], value: _kind, onChanged: (k) => setState(() => _kind = k)),
          const SizedBox(height: 14),
        ],
        CardBox(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _withFee,
              onChanged: (v) => setState(() => _withFee = v),
              title: Text('খরচ (ক্যাশ আউট চার্জ) দেবেন?', style: t(15, w: FontWeight.w500)),
              subtitle: Text('দিলে এজেন্টকে মূল টাকার সাথে খরচও পাঠাতে বলা হবে', style: t(12.5, c: K.muted)),
            ),
            if (_withFee)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                child: Field(label: 'খরচ কত টাকা', controller: _fee, number: true, prefix: '৳ ', onChanged: (_) => setState(() {})),
              ),
          ]),
        ),
        if (h.d.agents.length > 1) ...[
          const SizedBox(height: 14),
          Text('কোন এজেন্ট', style: t(13, c: K.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in h.d.agents) ChoiceChipX(label: a.name, on: a.id == _agentId, onTap: () => setState(() => _agentId = a.id)),
          ]),
        ],
      ]),
    );
  }

  List<Widget> _dupWarning() {
    final dups = duplicates(h.d, number: bdMobile(_number.text)!, taka: parseNum(_taka.text)!, now: h.now, exceptId: widget.editing?.id);
    if (dups.isEmpty) return const [];
    final x = dups.first;
    return [
      const SizedBox(height: 10),
      Note('সাবধান: ${bn('${h.now.difference(x.at).inMinutes}')} মিনিট আগে এই নম্বরে একই টাকা পাঠানো হয়েছে (#${bn('${x.no}')})। দুইবার যাচ্ছে না তো?',
          color: K.amberTint, textColor: K.amberText, icon: Icons.warning_amber_rounded),
    ];
  }
}

/// Step 3: check everything, choose নগদ / বাকি / আংশিক, see the agent's
/// message (taka only), save and open WhatsApp.
class ConfirmSheet extends StatefulWidget {
  const ConfirmSheet({super.key, required this.h, required this.c, required this.draft, this.editing});
  final Hisab h;
  final Customer c;
  final Txn draft;
  final Txn? editing;

  @override
  State<ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<ConfirmSheet> {
  Hisab get h => widget.h;
  late Pay _pay = widget.editing?.pay ?? Pay.due;
  late final _paid = TextEditingController(text: widget.editing != null && widget.editing!.pay == Pay.partial ? groupEn(widget.editing!.sarPaid, decimals: 2).replaceAll(',', '') : '');
  bool _busy = false;

  double get _sarPaid => switch (_pay) {
        Pay.cash => widget.draft.sarAmount,
        Pay.due => 0,
        Pay.partial => (parseNum(_paid.text) ?? 0).clamp(0, widget.draft.sarAmount).toDouble(),
      };

  Txn get _txn {
    final t = widget.draft.copy()
      ..pay = _pay
      ..sarPaid = _sarPaid;
    return t;
  }

  Future<void> _save() async {
    if (_pay == Pay.partial && (_sarPaid <= 0 || _sarPaid >= widget.draft.sarAmount)) {
      snack(context, 'আংশিক হলে কত রিয়াল দিলেন লিখুন (পুরোটার চেয়ে কম)');
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final agent = agentById(h.d, widget.draft.agentId) ?? h.d.agents.first;
    final e = widget.editing;
    if (e == null) {
      final saved = await h.addTxn(_txn);
      final ok = await h.s.device.whatsapp(agent.whatsapp, agentMessage(saved));
      await h.logMessage(saved, ok ? 'এজেন্টকে হোয়াটসঅ্যাপ খোলা হলো' : 'হোয়াটসঅ্যাপ খোলা যায়নি');
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => TxnScreen(h: h, id: saved.id, fresh: true)));
    } else {
      final changed = _txn;
      final diffs = await h.editTxn(e, changed);
      final agentSide = e.number != changed.number || e.taka != changed.taka || e.fee != changed.fee || e.method != changed.method || e.kind != changed.kind || e.agentId != changed.agentId;
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => TxnScreen(h: h, id: e.id)));
      if (diffs.isNotEmpty && agentSide && e.status == TxnStatus.pending) {
        final ok = await h.s.device.whatsapp(agent.whatsapp, agentChangeMessage(h.txnById(e.id)!));
        await h.logMessage(h.txnById(e.id)!, ok ? 'এজেন্টকে সংশোধনের মেসেজ' : 'হোয়াটসঅ্যাপ খোলা যায়নি');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t0 = _txn;
    final c = widget.c;
    final dueBefore = customerDue(h.d, c.id) - (widget.editing?.sarDueAtSend ?? 0);
    final dueAfter = dueBefore + t0.sarDueAtSend;
    final limit = dueLimitOf(h.d, c);
    final pct = limit <= 0 ? 0.0 : dueAfter / limit * 100;
    final agent = agentById(h.d, t0.agentId) ?? h.d.agents.first;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCFCFCF), borderRadius: BorderRadius.circular(2))),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 14, 18, 8), children: [
            Text('মিলিয়ে দেখুন', style: t(19, w: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            CardBox(
              child: Column(children: [
                _kv('গ্রাহক', c.name),
                _kv('রিয়াল', sar(t0.sarAmount), bold: true),
                _kv('রেট', rateText(t0.rate)),
                _kv('টাকা যাবে', taka(t0.taka), bold: true),
                if (t0.fee > 0) _kv('খরচ', taka(t0.fee)),
                _kv('প্রাপক', '${t0.recipientLabel.isEmpty ? '' : '${t0.recipientLabel} · '}${t0.method.bnName}'),
                _kv('নম্বর', t0.method == Method.bank ? bn(t0.number) : bdShow(t0.number), bold: true),
                _kv('ধরন', t0.kind.bnName, last: true),
              ]),
            ),
            const SizedBox(height: 14),
            Text('রিয়াল কীভাবে পেলেন', style: t(13, c: K.muted)),
            const SizedBox(height: 6),
            Seg<Pay>(items: const [(Pay.cash, 'নগদ'), (Pay.due, 'বাকি'), (Pay.partial, 'আংশিক')], value: _pay, onChanged: (p) => setState(() => _pay = p)),
            if (_pay == Pay.partial) ...[
              const SizedBox(height: 10),
              Field(label: 'এখন কত রিয়াল দিলেন', controller: _paid, number: true, suffix: 'SAR', autofocus: true, onChanged: (_) => setState(() {})),
            ],
            const SizedBox(height: 12),
            CardBox(
              child: Row(children: [
                Ring(percent: pct, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('এরপর মোট বাকি: ${sar(dueAfter > 0 ? dueAfter : 0)}', style: t(15, w: FontWeight.w600, c: dueAfter > 0 ? K.red : K.green)),
                    Text('বাকির সীমা ${sar(limit)}', style: t(12.5, c: K.muted)),
                  ]),
                ),
              ]),
            ),
            if (pct > 100) ...[
              const SizedBox(height: 10),
              Note('সীমার বেশি বাকি হয়ে যাচ্ছে। ঠিক থাকলে তবুও পাঠাতে পারেন।', color: K.redTint, textColor: K.red, icon: Icons.error_outline_rounded),
            ],
            const SizedBox(height: 14),
            Text('${agent.name}-কে হোয়াটসঅ্যাপে যাবে (রিয়ালের কথা নেই)', style: t(13, c: K.muted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFE7F6E3), borderRadius: BorderRadius.circular(14)),
              child: Text(widget.editing == null ? agentMessage(_withNo(t0)) : agentChangeMessage(t0), style: t(14, h: 1.55)),
            ),
            const SizedBox(height: 8),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.line))),
          child: Pill(
            label: widget.editing == null ? 'সংরক্ষণ ও হোয়াটসঅ্যাপে পাঠান' : 'সংশোধন সংরক্ষণ',
            icon: Icons.send_rounded,
            onTap: _busy ? null : _save,
          ),
        ),
      ]),
    );
  }

  /// Preview with the number the send will get.
  Txn _withNo(Txn t) => Txn.fromJson({...t.toJson(), 'no': h.d.settings.nextNo});

  Widget _kv(String k, String v, {bool bold = false, bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.line))),
        child: Row(children: [
          Text(k, style: t(14, c: K.muted)),
          const SizedBox(width: 12),
          Expanded(child: Text(v, textAlign: TextAlign.right, style: t(bold ? 16 : 14.5, w: bold ? FontWeight.w700 : FontWeight.w500))),
        ]),
      );
}
