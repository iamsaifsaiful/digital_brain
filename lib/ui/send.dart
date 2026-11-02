import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'customers.dart';
import 'home.dart';
import 'kit.dart';
import '../core/lang.dart';
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
              hintText: tr('নাম বা মোবাইল নম্বর'),
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
                Expanded(child: Tx(q.isEmpty ? 'নতুন গ্রাহক (দ্রুত প্রোফাইল)' : 'নতুন গ্রাহক: "$q"', style: t(15, w: FontWeight.w600, c: K.navy))),
                const Icon(Icons.chevron_right_rounded, color: K.navy),
              ]),
            ),
            if (!widget.forDeposit) ...[
              const SizedBox(height: 10),
              CardBox(
                // Straight to the amount: only the riyal and the number it goes to.
                onTap: () => _open(walkInCustomer('', '')),
                child: Row(children: [
                  dotIcon(Icons.flash_on_rounded, K.amberTint, K.amberText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Tx('প্রোফাইল ছাড়া পাঠান', style: t(15, w: FontWeight.w600)),
                      Tx('শুধু রিয়াল আর যে নম্বরে যাবে · পুরো রিয়াল নগদে', style: t(12.5, c: K.muted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: K.muted),
                ]),
              ),
            ],
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
      value: due > 0 ? sar(due) : (due < 0 ? 'অগ্রিম' : 'বকেয়া নেই'),
      valueColor: due > 0 ? K.red : K.green,
      valueSub: due > 0 ? 'বকেয়া' : (due < 0 ? sar(-due) : null),
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
    final typed = _phone.text.trim();
    final phone = typed.isEmpty ? '' : (saMobile(typed) ?? '');
    if (typed.isNotEmpty && phone.isEmpty) {
      setState(() => _err = 'সৌদি মোবাইল নম্বর ঠিক নেই — 05 দিয়ে শুরু, মোট ১০ সংখ্যা');
      return;
    }
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
                          Tx('ছবি তুলুন', style: t(13, c: K.blue)),
                        ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Field(label: 'নাম', controller: _name, autofocus: widget.name.isEmpty && widget.phone.isNotEmpty ? true : widget.name.isEmpty),
          const SizedBox(height: 12),
          Field(label: 'সৌদি মোবাইল (হোয়াটসঅ্যাপ — রসিদ ও তাগাদা এখানে যায়)', controller: _phone, saudi: true, hint: '05XXXXXXXX'),
          const SizedBox(height: 12),
          Field(label: 'কোথায় থাকেন / কাজ করেন (ইচ্ছা হলে)', controller: _area),
          if (_err != null) ...[const SizedBox(height: 12), Note(_err!, color: K.redTint, textColor: K.red)],
          const SizedBox(height: 12),
          const Note('বাকি তথ্য (বাড়ি, বেতনের তারিখ, বকেয়ার সীমা) পরে গ্রাহকের পাতা থেকে যোগ করা যাবে।'),
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
  final _pack = TextEditingController();
  Method _method = Method.bkash;
  Kind _kind = Kind.send;

  /// 0 টাকা পাঠানো, 1 রিচার্জ, 2 এমবি.
  int _svc = 0;
  String _operator = '';
  bool _operatorByHand = false;
  bool _withFee = false;
  late String _agentId;

  /// Which of riyal / taka was typed last; the other one is worked out.
  String _src = 'sar';

  /// Editing a send the agent already sent: taka, number and fee stay.
  bool get _locked => widget.editing?.status == TxnStatus.sent;

  @override
  void initState() {
    super.initState();
    _agentId = h.d.liveAgents.first.id;
    final e = widget.editing;
    if (e != null) {
      _sar.text = _plain(e.sarAmount);
      _rate.text = _plain(e.rate);
      _taka.text = e.taka.round().toString();
      _number.text = e.number;
      _label.text = e.recipientLabel;
      _fee.text = e.fee > 0 ? e.fee.round().toString() : '';
      _withFee = e.fee > 0;
      _method = e.method;
      _kind = e.kind;
      _svc = switch (e.kind) { Kind.recharge => 1, Kind.mb => 2, _ => 0 };
      _operator = e.operator;
      _operatorByHand = e.operator.isNotEmpty;
      _pack.text = e.pack;
      _agentId = agentById(h.d, e.agentId)?.id ?? _agentId;
      _src = _locked || (takaFor(e.sarAmount, e.rate) - e.taka).abs() > 0.5 ? 'taka' : 'sar';
    } else {
      // Last rate used, so it is only typed when it changes.
      final last = [...h.d.txns.where((t) => !t.cancelled)]..sort((a, b) => b.at.compareTo(a.at));
      if (last.isNotEmpty) _rate.text = _plain(last.first.rate);
      if (widget.c.recipients.isNotEmpty) _pickRecipient(widget.c.recipients.last);
    }
  }

  /// 307.69, 32.5, 500 — no trailing zeros, no commas.
  static String _plain(double v, {int decimals = 2}) {
    var s = v.toStringAsFixed(decimals);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }

  void _pickRecipient(Recipient r) {
    _number.text = bdShowEn(r.number);
    _label.text = r.label;
    _method = r.method;
    if (!_operatorByHand) _operator = operatorOf(r.number);
  }

  Kind get _kindNow => switch (_svc) { 1 => Kind.recharge, 2 => Kind.mb, _ => _kind };

  /// Live: riyal × rate = taka, or taka ÷ rate = riyal, whichever was typed
  /// last. A wrong entry only blanks the result until it is put right.
  void _derive() {
    final r = parseNum(_rate.text);
    if (_locked) {
      final tk = parseNum(_taka.text);
      if (_src == 'rate') {
        _sar.text = tk != null && r != null && r > 0 ? _plain(tk / r) : '';
      } else {
        final s = parseNum(_sar.text);
        _rate.text = tk != null && s != null && s > 0 ? _plain(tk / s, decimals: 4) : _rate.text;
      }
      return;
    }
    if (_src == 'taka') {
      final tk = parseNum(_taka.text);
      _sar.text = tk != null && r != null && r > 0 ? _plain(tk / r) : '';
    } else {
      final s = parseNum(_sar.text);
      _taka.text = s != null && r != null && r > 0 ? takaFor(s, r).round().toString() : '';
    }
  }

  bool get _bank => _svc == 0 && _method == Method.bank;

  String? get _numErr {
    if (_number.text.trim().isEmpty || _bank) return null;
    return bdMobile(_number.text) == null ? '১১ সংখ্যার নম্বর দিন (01XXXXXXXXX)' : null;
  }

  Txn? _draft() {
    final s = parseNum(_sar.text), r = parseNum(_rate.text), tk = parseNum(_taka.text);
    final num = _bank ? en(_number.text.trim()) : bdMobile(_number.text);
    if (s == null || s <= 0 || r == null || r <= 0 || tk == null || tk <= 0 || num == null || num.isEmpty) return null;
    if (_svc == 2 && _pack.text.trim().isEmpty) return null;
    final kind = _kindNow;
    final fee = !kind.isTopUp && _withFee ? (parseNum(_fee.text) ?? 0) : 0.0;
    final e = widget.editing;
    final base = e?.copy() ??
        Txn(
          id: '',
          no: 0,
          customerId: widget.c.id,
          walkIn: widget.c.id.isEmpty ? (widget.c.name == 'প্রোফাইল ছাড়া' ? '' : widget.c.name) : '',
          walkInPhone: widget.c.id.isEmpty ? widget.c.phone : '',
          recipientLabel: '',
          number: '',
          method: Method.bkash,
          kind: Kind.send,
          sarAmount: 0,
          rate: 0,
          taka: 0,
          fee: 0,
          agentId: _agentId,
          pay: Pay.due,
          sarPaid: 0,
          at: h.now,
        );
    return base
      ..recipientLabel = _label.text.trim()
      ..number = num
      ..method = kind.isTopUp ? Method.bkash : _method
      ..kind = kind
      ..sarAmount = s
      ..rate = r
      ..taka = tk.roundToDouble()
      ..fee = fee
      ..agentId = _agentId
      ..operator = kind.isTopUp ? (_operator.isEmpty ? operatorOf(num) : _operator) : ''
      ..pack = kind == Kind.mb ? _pack.text.trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final due = customerDue(h.d, c.id);
    final draft = _draft();
    final topUp = _svc != 0;
    final sarAuto = _src == 'taka' || (_locked && _src == 'rate');
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
                Tx(c.name, style: t(16, w: FontWeight.w600)),
                if (c.phone.isNotEmpty) Tx(bn(c.phone), style: t(12.5, c: K.muted)),
              ]),
            ),
            if (c.id.isEmpty)
              Tx('পুরো রিয়াল নগদে', style: t(13, c: K.muted))
            else
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Tx(due > 0 ? sar(due) : 'বকেয়া নেই', style: t(14.5, w: FontWeight.w700, c: due > 0 ? K.red : K.ink)),
                if (due > 0) Tx('আগের বকেয়া', style: t(12, c: K.muted)),
              ]),
          ]),
        ),
        if (_locked) ...[
          const SizedBox(height: 12),
          const Note('এজেন্ট এটা পাঠিয়ে দিয়েছেন, তাই টাকা, নম্বর আর খরচ বদলানো যাবে না। রিয়াল বা রেট বদলালে অন্যটা মিলিয়ে নেবে।',
              color: K.amberTint, textColor: K.amberText, icon: Icons.lock_outline_rounded),
        ],
        const SizedBox(height: 14),
        if (!_locked)
          Seg<int>(
            items: const [(0, 'টাকা পাঠানো'), (1, 'রিচার্জ'), (2, 'এমবি প্যাক')],
            value: _svc,
            onChanged: (v) => setState(() {
              _svc = v;
              if (!_operatorByHand) _operator = operatorOf(bdMobile(_number.text) ?? '');
            }),
          ),
        if (!_locked) const SizedBox(height: 14),
        Field(
          label: sarAuto ? 'কত রিয়াল (অটো)' : 'কত রিয়াল',
          controller: _sar,
          number: true,
          big: true,
          suffix: 'SAR',
          autofocus: widget.editing == null,
          hint: '০',
          onChanged: (_) => setState(() {
            _src = 'sar';
            _derive();
          }),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Field(
              label: _locked && !sarAuto ? 'রেট (অটো)' : 'রেট (১ রিয়াল = ? টাকা)',
              controller: _rate,
              number: true,
              hint: '৩২.৫০',
              onChanged: (_) => setState(() {
                if (_locked) _src = 'rate';
                _derive();
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Field(
              label: _locked ? 'টাকা (বদলাবে না)' : (_src == 'sar' ? 'টাকা (অটো)' : 'টাকা'),
              controller: _taka,
              number: true,
              prefix: '৳ ',
              readOnly: _locked,
              onChanged: (_) => setState(() {
                _src = 'taka';
                _derive();
              }),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 6, top: 6),
          child: Tx(
            _locked ? 'টাকা ঠিক রেখে রিয়াল ↔ রেট মিলছে' : 'রিয়াল লিখলে টাকা, টাকা লিখলে রিয়াল নিজে হিসাব হবে',
            style: t(12, c: K.muted),
          ),
        ),
        const SizedBox(height: 16),
        Tx(topUp ? 'কোন নম্বরে' : 'কার কাছে যাবে', style: t(13, c: K.muted)),
        const SizedBox(height: 6),
        if (c.recipients.isNotEmpty && !_locked) ...[
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
        if (!topUp && !_locked) ...[
          Seg<Method>(items: [for (final m in Method.values) (m, m.bnName)], value: _method, onChanged: (m) => setState(() => _method = m)),
          const SizedBox(height: 10),
        ],
        Field(
          label: topUp ? 'মোবাইল নম্বর' : (_method == Method.bank ? 'অ্যাকাউন্ট নম্বর' : '${_method.bnName} নম্বর'),
          controller: _number,
          phone: !_bank,
          hint: '01XXXXXXXXX',
          error: _numErr,
          readOnly: _locked,
          onChanged: (_) => setState(() {
            // A new number: its operator again (can still be changed by hand).
            final op = operatorOf(bdMobile(_number.text) ?? '');
            if (op.isNotEmpty) {
              _operator = op;
              _operatorByHand = false;
            } else if (!_operatorByHand) {
              _operator = '';
            }
          }),
        ),
        if (topUp) ...[
          const SizedBox(height: 10),
          Tx('অপারেটর', style: t(13, c: K.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in operators)
              ChoiceChipX(
                label: o,
                on: o == _operator,
                onTap: _locked
                    ? () {}
                    : () => setState(() {
                          _operator = o;
                          _operatorByHand = true;
                        }),
              ),
          ]),
          if (_svc == 2) ...[
            const SizedBox(height: 10),
            Field(label: 'কোন প্যাক (যেমন ৩০ জিবি ৩০ দিন)', controller: _pack, readOnly: _locked, onChanged: (_) => setState(() {})),
          ],
        ],
        const SizedBox(height: 10),
        if (widget.c.id.isNotEmpty) Field(label: 'প্রাপক কে (যেমন স্ত্রী, বাবা — ইচ্ছা হলে)', controller: _label, onChanged: (_) => setState(() {})),
        if (bdMobile(_number.text) != null && parseNum(_taka.text) != null && !_locked) ..._dupWarning(),
        const SizedBox(height: 14),
        if (!topUp && !_locked) ...[
          Seg<Kind>(items: const [(Kind.send, 'সেন্ড মানি'), (Kind.cashout, 'ক্যাশ আউট')], value: _kind == Kind.cashout ? Kind.cashout : Kind.send, onChanged: (k) => setState(() => _kind = k)),
          const SizedBox(height: 14),
          CardBox(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Column(children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _withFee,
                onChanged: (v) => setState(() => _withFee = v),
                title: Tx('খরচ (ক্যাশ আউট চার্জ) দেবেন?', style: t(15, w: FontWeight.w500)),
                subtitle: Tx('দিলে এজেন্টকে মূল টাকার সাথে খরচও পাঠাতে বলা হবে', style: t(12.5, c: K.muted)),
              ),
              if (_withFee)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                  child: Field(label: 'খরচ কত টাকা', controller: _fee, number: true, prefix: '৳ ', onChanged: (_) => setState(() {})),
                ),
            ]),
          ),
        ],
        if (h.d.liveAgents.length > 1 && !_locked) ...[
          const SizedBox(height: 14),
          Tx('কোন এজেন্ট', style: t(13, c: K.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in h.d.liveAgents) ChoiceChipX(label: a.name, on: a.id == _agentId, onTap: () => setState(() => _agentId = a.id)),
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

/// Step 3: check everything, choose নগদ / বকেয়া / আংশিক, see the agent's
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
  // Without a profile there is no account to owe on: cash only.
  late Pay _pay = widget.c.id.isEmpty ? Pay.cash : (widget.editing?.pay ?? Pay.due);
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
    final agent = agentById(h.d, widget.draft.agentId) ?? h.d.liveAgents.first;
    final e = widget.editing;
    if (e == null) {
      final Txn saved;
      try {
        saved = await h.addTxn(_txn);
      } on NoNumbers {
        if (mounted) {
          setState(() => _busy = false);
          snack(context, 'ইন্টারনেট নেই — নতুন লেনদেনের নম্বর পাওয়া যায়নি। ইন্টারনেট চালু করে আবার চাপুন।');
        }
        return;
      }
      if (agent.usesApp) {
        // The server tells the agent (notification in their app); WhatsApp
        // stays on the send's page if wanted.
        await h.sync();
      } else {
        final ok = await h.s.device.whatsapp(agent.whatsapp, agentMessage(saved, h.d));
        await h.logMessage(saved, ok ? 'এজেন্টকে হোয়াটসঅ্যাপ খোলা হলো' : 'হোয়াটসঅ্যাপ খোলা যায়নি');
      }
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => TxnScreen(h: h, id: saved.id, fresh: true)));
    } else {
      final changed = _txn;
      final diffs = await h.editTxn(e, changed);
      final agentSide = e.number != changed.number ||
          e.taka != changed.taka ||
          e.fee != changed.fee ||
          e.method != changed.method ||
          e.kind != changed.kind ||
          e.agentId != changed.agentId ||
          e.operator != changed.operator ||
          e.pack != changed.pack;
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => TxnScreen(h: h, id: e.id)));
      if (diffs.isNotEmpty && agentSide) {
        // Required: the agent must not send the old amount or number. An
        // agent in the app also gets a notification from the server.
        final ok = await h.s.device.whatsapp(agent.whatsapp, agentChangeMessage(h.txnById(e.id)!, h.d));
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
    final agent = agentById(h.d, t0.agentId) ?? h.d.liveAgents.first;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCFCFCF), borderRadius: BorderRadius.circular(2))),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 14, 18, 8), children: [
            Tx('মিলিয়ে দেখুন', style: t(19, w: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            CardBox(
              child: Column(children: [
                _kv('গ্রাহক', c.name),
                _kv('রিয়াল', sar(t0.sarAmount), bold: true),
                _kv('রেট', rateText(t0.rate)),
                _kv('টাকা যাবে', taka(t0.taka), bold: true),
                if (t0.fee > 0) _kv('খরচ', taka(t0.fee)),
                _kv('প্রাপক', '${t0.recipientLabel.isEmpty ? '' : '${t0.recipientLabel} · '}${serviceName(t0)}'),
                if (t0.kind == Kind.mb) _kv('প্যাক', t0.pack),
                _kv('নম্বর', t0.method == Method.bank ? bn(t0.number) : bdShow(t0.number), bold: true),
                _kv('ধরন', t0.kind.bnName, last: true),
              ]),
            ),
            const SizedBox(height: 14),
            Tx('রিয়াল কীভাবে পেলেন', style: t(13, c: K.muted)),
            const SizedBox(height: 6),
            if (widget.c.id.isEmpty)
              const Note('প্রোফাইল ছাড়া পাঠানো: পুরো রিয়াল নগদে নিতে হবে, বকেয়া রাখা যায় না।')
            else
              Seg<Pay>(items: const [(Pay.cash, 'নগদে'), (Pay.due, 'বকেয়া'), (Pay.partial, 'আংশিক')], value: _pay, onChanged: (p) => setState(() => _pay = p)),
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
                    Tx('এরপর মোট বকেয়া: ${sar(dueAfter > 0 ? dueAfter : 0)}', style: t(15, w: FontWeight.w600, c: dueAfter > 0 ? K.red : K.green)),
                    Tx('বকেয়ার সীমা ${sar(limit)}', style: t(12.5, c: K.muted)),
                  ]),
                ),
              ]),
            ),
            if (pct > 100) ...[
              const SizedBox(height: 10),
              Note('সীমার বেশি বকেয়া হয়ে যাচ্ছে। ঠিক থাকলে তবুও পাঠাতে পারেন।', color: K.redTint, textColor: K.red, icon: Icons.error_outline_rounded),
            ],
            const SizedBox(height: 14),
            Tx(agent.usesApp ? '${agent.name}-এর অ্যাপে নোটিফিকেশন যাবে (রিয়ালের কথা নেই)' : '${agent.name}-কে হোয়াটসঅ্যাপে যাবে (রিয়ালের কথা নেই)', style: t(13, c: K.muted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFE7F6E3), borderRadius: BorderRadius.circular(14)),
              child: Text(widget.editing == null ? agentMessage(_withNo(t0), h.d) : agentChangeMessage(t0, h.d), style: t(14, h: 1.55)),
            ),
            const SizedBox(height: 8),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.line))),
          child: Pill(
            label: widget.editing == null ? (agent.usesApp ? 'সংরক্ষণ ও এজেন্টকে পাঠান' : 'সংরক্ষণ ও হোয়াটসঅ্যাপে পাঠান') : 'সংশোধন সংরক্ষণ',
            icon: Icons.send_rounded,
            onTap: _busy ? null : _save,
          ),
        ),
      ]),
    );
  }

  /// Preview with the number the send will get.
  Txn _withNo(Txn t) => Txn.fromJson({...t.toJson(), 'no': h.nextNoPreview});

  Widget _kv(String k, String v, {bool bold = false, bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.line))),
        child: Row(children: [
          Tx(k, style: t(14, c: K.muted)),
          const SizedBox(width: 12),
          Expanded(child: Tx(v, textAlign: TextAlign.right, style: t(bold ? 16 : 14.5, w: bold ? FontWeight.w700 : FontWeight.w500))),
        ]),
      );
}
