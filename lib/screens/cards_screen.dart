import 'dart:async';
import '../ui/secure.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../services/files.dart' show PickedDoc;
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// ডকুমেন্টস › ব্যাংক কার্ড (owner, 28 Oct): ATM, debit and credit cards,
/// several, each with its bank and kind — a photo of each side, or the number
/// typed. The list shows only the last four digits; the full number and the
/// photos open after the fingerprint (or PIN). No PIN or CVV is kept.
const cardColors = [
  [Color(0xFF0E5A4A), Color(0xFF1F8F72)],
  [Color(0xFF1D2B53), Color(0xFF3A5BA0)],
  [Color(0xFF5B1A2E), Color(0xFFA33A5C)],
  [Color(0xFF2E2E2E), Color(0xFF5E5E5E)],
  [Color(0xFF6B4A12), Color(0xFFC08A2D)],
  [Color(0xFF3B2470), Color(0xFF6C4BC2)],
];

/// "1234 5678 9012 3456"; an AMEX card "3782 822463 10005".
String groupedNumber(String digits, {String company = ''}) {
  final amex = (company.isEmpty ? BankCard.networkOf(digits) : company) == 'AMEX';
  final sizes = amex ? const [4, 6, 5] : const [4, 4, 4, 4, 4];
  final out = <String>[];
  var i = 0;
  for (final n in sizes) {
    if (i >= digits.length) break;
    final end = i + n > digits.length ? digits.length : i + n;
    out.add(digits.substring(i, end));
    i = end;
  }
  if (i < digits.length) out.add(digits.substring(i));
  return out.join(' ');
}

/// The card companies to pick from (the number usually tells it by itself).
const cardCompanies = ['VISA', 'Mastercard', 'AMEX', 'UnionPay', 'Nexus', 'JCB'];

/// Typing a card number (owner, 28 Oct): digits only, no more than the card
/// has (AMEX 15, the others 16), with the gaps as printed on the card.
class CardNumberFormatter extends TextInputFormatter {
  CardNumberFormatter(this.company);

  /// The company picked ('' = from the number).
  final String Function() company;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = asciiDigits(newValue.text).replaceAll(RegExp(r'\D'), '');
    final c = company().isEmpty ? BankCard.networkOf(digits) : company();
    final max = BankCard.digitsFor(c);
    if (digits.length > max) digits = digits.substring(0, max);
    final text = groupedNumber(digits, company: c);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Typing the expiry: "MM/YY" — the slash put in by itself, four digits at most.
class ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = asciiDigits(newValue.text).replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    // Deleting the slash takes the digit before it too.
    final deleting = newValue.text.length < oldValue.text.length;
    var text = digits.length > 2 || (digits.length == 2 && !deleting) ? '${digits.substring(0, 2)}/${digits.substring(2)}' : digits;
    if (deleting && oldValue.text.endsWith('/') && newValue.text.length == 2) text = digits.substring(0, 1);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// The Luhn check every card number passes (a typing mistake usually fails it).
bool luhnOk(String digits) {
  if (digits.length < 12) return false;
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = digits.codeUnitAt(digits.length - 1 - i) - 48;
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

/// The card itself, drawn like a bank card. [open] shows the whole number.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card, this.open = false});
  final BankCard card;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final c = cardColors[card.color % cardColors.length];
    const white = Colors.white;
    final number = card.number.isEmpty
        ? tr('শুধু ছবি রাখা')
        : open
            ? groupedNumber(card.number, company: card.network)
            : '•••• •••• •••• ${card.last4}';
    return AspectRatio(
      aspectRatio: 85.6 / 54,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: c[0].withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(card.bank, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w700, color: white))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
              child: Text(tr(card.kind.label), style: body(12, weight: FontWeight.w600, color: white)),
            ),
          ]),
          const Spacer(),
          // The chip.
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(colors: [Color(0xFFE9D38C), Color(0xFFB8963E)]),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(number, key: const Key('card-number'), style: TextStyle(fontFamily: 'monospace', fontSize: 20, letterSpacing: 2, color: white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Text(card.holder.isEmpty ? '' : card.holder.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: white.withValues(alpha: 0.9))),
            ),
            if (card.expiry.isNotEmpty) ...[
              Text(tr('মেয়াদ '), style: body(10, color: white.withValues(alpha: 0.7))),
              Text(card.expiry, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: white)),
              const SizedBox(width: 10),
            ],
            if (card.network.isNotEmpty) Text(card.network, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: white)),
          ]),
        ]),
      ),
    );
  }
}

class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});

  Future<void> _open(BuildContext context, BankCard c) async {
    final ok = await verifyUser(context, reason: trf('{0} কার্ড — দেখতে যাচাই করুন', [c.bank]));
    if (ok && context.mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardDetailScreen(id: c.id)));
  }

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final cards = [...brain.data.cards]..sort((a, b) => a.bank.compareTo(b.bank));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('ব্যাংক কার্ড'), trailing: [Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.lock_outline_rounded, color: C.green))]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              PrimaryButton(
                key: const Key('card-add'),
                label: tr('নতুন কার্ড'),
                icon: Icons.add_card_outlined,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardFormScreen())),
              ),
              const SizedBox(height: 10),
              InfoBanner(text: tr('শুধু এই ফোনে, তালাবদ্ধ অবস্থায় থাকে। পুরো নম্বর আর ছবি দেখতে আঙুলের ছাপ বা PIN লাগে। আমাদের সার্ভারে কখনো যায় না। কার্ডের PIN বা পিছনের CVV কোথাও লিখে রাখবেন না।')),
              const SizedBox(height: 14),
              if (cards.isEmpty)
                EmptyState(
                  icon: Icons.credit_card_rounded,
                  title: tr('প্রথম কার্ডটা রাখুন'),
                  text: tr('এটিএম, ডেবিট বা ক্রেডিট কার্ড — ছবি তুলে, বা নম্বর লিখে।'),
                  action: tr('কার্ড যোগ করুন'),
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CardFormScreen())),
                )
              else
                for (final c in cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GestureDetector(key: Key('card-${c.id}'), onTap: () => _open(context, c), child: CardFace(card: c)),
                  ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One card, after the fingerprint: the whole number (hidden again after 30
/// seconds), copy (the clipboard is cleared after 30 seconds), the photos.
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  bool _show = false;
  int _left = 0;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _toggle() {
    _hide?.cancel();
    setState(() {
      _show = !_show;
      _left = 30;
    });
    if (_show) {
      _hide = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          setState(() => _show = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final c = brain.data.cards.where((x) => x.id == widget.id).firstOrNull;
    if (c == null) return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('পাওয়া যায়নি'))])));
    Widget photo(String label, DocFile f) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: body(13, color: C.muted)),
            const SizedBox(height: 6),
            FutureBuilder<Uint8List?>(
              future: brain.docBytes(f),
              builder: (_, s) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: s.data == null ? Container(height: 160, color: C.surface) : Image.memory(s.data!, fit: BoxFit.contain),
              ),
            ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: '', trailing: [Pill(tr('আনলক করা'))]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
              CardFace(card: c, open: _show),
              const SizedBox(height: 12),
              if (c.number.isNotEmpty)
                Row(children: [
                  Expanded(
                    child: SecondaryButton(
                      key: const Key('card-show'),
                      label: _show ? trf('লুকান ({0})', [bnDigits(_left)]) : tr('পুরো নম্বর দেখুন'),
                      icon: _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      onPressed: _toggle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      key: const Key('card-copy'),
                      label: tr('নম্বর কপি'),
                      icon: Icons.copy_rounded,
                      onPressed: () async {
                        await brain.services.files.copy(c.number, clearAfter: const Duration(seconds: 30));
                        if (context.mounted) toast(context, tr('কপি হয়েছে — ৩০ সেকেন্ড পর ক্লিপবোর্ড মুছে যাবে'));
                      },
                    ),
                  ),
                ]),
              if (c.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Panel(padding: const EdgeInsets.all(14), child: Text(c.note, style: body(15, height: 1.5))),
              ],
              if (c.front != null) photo(tr('সামনের ছবি'), c.front!),
              if (c.back != null) photo(tr('পিছনের ছবি'), c.back!),
              const SizedBox(height: 14),
              Text(trf('• শেষ বদল: {0}', [fullDate(c.updatedAt)]), style: body(13, color: C.muted)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Expanded(
                child: PrimaryButton(
                  key: const Key('card-edit'),
                  label: tr('সম্পাদনা'),
                  icon: Icons.edit_outlined,
                  color: C.fill,
                  height: 52,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardFormScreen(card: c))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  key: const Key('card-delete'),
                  label: tr('মুছুন'),
                  icon: Icons.delete_outline_rounded,
                  fg: C.red,
                  height: 52,
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: trf('{0} কার্ড মুছবেন?', [c.bank]), text: tr('৩০ দিন “মুছে ফেলা”-তে থাকবে, সেখান থেকে ফেরানো যাবে।'), yes: tr('মুছুন'), danger: true);
                    if (!ok || !context.mounted) return;
                    await brain.deleteCard(c.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A new card, or one changed.
class CardFormScreen extends StatefulWidget {
  const CardFormScreen({super.key, this.card});
  final BankCard? card;

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  late final _bank = TextEditingController(text: widget.card?.bank ?? '');
  late final _number = TextEditingController(text: groupedNumber(widget.card?.number ?? '', company: widget.card?.network ?? ''));
  late final _holder = TextEditingController(text: widget.card?.holder ?? '');
  late final _expiry = TextEditingController(text: widget.card?.expiry ?? '');
  late final _note = TextEditingController(text: widget.card?.note ?? '');
  late CardKind _kind = widget.card?.kind ?? CardKind.debit;
  late int _color = widget.card?.color ?? 0;
  late String _company = widget.card?.company ?? '';
  late DocFile? _front = widget.card?.front;
  late DocFile? _back = widget.card?.back;
  final _kept = <String>[];
  bool _saving = false;

  static const banks = ['ডাচ-বাংলা ব্যাংক', 'ব্র্যাক ব্যাংক', 'ইসলামী ব্যাংক', 'সোনালী ব্যাংক', 'সিটি ব্যাংক', 'ইস্টার্ন ব্যাংক', 'জনতা ব্যাংক', 'অগ্রণী ব্যাংক', 'প্রাইম ব্যাংক', 'ইউসিবি'];

  String get _digits => asciiDigits(_number.text).replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    _number.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_bank, _number, _holder, _expiry, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _photo(bool front, bool camera) async {
    final brain = BrainScope.read(context);
    final PickedDoc? p = await brain.services.files.pickPhoto(camera: camera);
    if (p == null || !mounted) return;
    final f = await brain.keepCardPhoto(p);
    _kept.add(f.id);
    setState(() => front ? _front = f : _back = f);
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final bank = _bank.text.trim();
    if (bank.isEmpty) return toast(context, tr('ব্যাংকের নাম লিখুন'));
    final digits = _digits;
    if (digits.isEmpty && _front == null && _back == null) return toast(context, tr('কার্ডের নম্বর লিখুন, অথবা ছবি তুলুন'));
    final company = _company.isNotEmpty ? _company : BankCard.networkOf(digits);
    final need = BankCard.digitsFor(company);
    if (digits.isNotEmpty && digits.length != need) return toast(context, trf('এই কার্ডের নম্বর {0} অঙ্কের — এখন {1}টা লেখা হয়েছে', [bnDigits(need), bnDigits(digits.length)]));
    final exp = asciiDigits(_expiry.text.trim());
    if (exp.isNotEmpty && !RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(exp)) return toast(context, tr('মেয়াদ লিখুন মাস/বছর করে, যেমন 08/29'));
    setState(() => _saving = true);
    await brain.saveCard(BankCard(
      id: widget.card?.id,
      bank: bank,
      kind: _kind,
      number: digits,
      holder: _holder.text.trim(),
      expiry: exp,
      note: _note.text.trim(),
      color: _color,
      company: _company,
      front: _front,
      back: _back,
      updatedAt: brain.services.now(),
    ));
    _kept.clear();
    if (!mounted) return;
    toast(context, digits.isNotEmpty && !luhnOk(digits) ? tr('রাখা হয়েছে — তবে নম্বরটা একবার মিলিয়ে নিন, কোথাও ভুল হতে পারে') : tr('কার্ড রাখা হয়েছে'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final preview = BankCard(bank: _bank.text.trim().isEmpty ? tr('ব্যাংকের নাম') : _bank.text.trim(), kind: _kind, number: _digits, holder: _holder.text, expiry: _expiry.text, color: _color, company: _company);
    final detected = BankCard.networkOf(_digits);
    Widget photoRow(String label, DocFile? f, bool front) => Panel(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            Icon(f == null ? Icons.add_a_photo_outlined : Icons.check_circle_rounded, color: f == null ? C.muted : C.green),
            const SizedBox(width: 10),
            Expanded(child: Text(f == null ? label : trf('{0} — রাখা হয়েছে', [label]), style: body(14.5))),
            IconButton(key: Key(front ? 'card-front-camera' : 'card-back-camera'), tooltip: tr('ছবি তুলুন'), onPressed: () => _photo(front, true), icon: const Icon(Icons.photo_camera_outlined)),
            IconButton(tooltip: tr('গ্যালারি'), onPressed: () => _photo(front, false), icon: const Icon(Icons.photo_library_outlined)),
          ]),
        );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Photos taken but the card not saved: they go.
        if (didPop) {
          for (final id in _kept) {
            BrainScope.read(context).services.store.deleteDocFile(id);
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: widget.card == null ? tr('নতুন কার্ড') : tr('কার্ড বদলান')),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
                CardFace(card: preview, open: true),
                const SizedBox(height: 14),
                TextField(key: const Key('card-bank'), controller: _bank, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('ব্যাংকের নাম'))),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final b in banks) ActionChip(label: Text(tr(b), style: body(12.5)), onPressed: () => setState(() => _bank.text = tr(b))),
                ]),
                const SizedBox(height: 12),
                Text(tr('কার্ডের ধরন'), style: body(13, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final k in CardKind.values) ChoiceChip(key: Key('card-kind-${k.name}'), label: Text(tr(k.label)), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('card-number-field'),
                  controller: _number,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [CardNumberFormatter(() => _company)],
                  decoration: InputDecoration(
                    labelText: tr('কার্ডের নম্বর (ঐচ্ছিক, ছবি থাকলে)'),
                    hintText: (_company.isEmpty ? detected : _company) == 'AMEX' ? '3782 822463 10005' : '1234 5678 9012 3456',
                    helperText: trf('{0} অঙ্ক', [bnDigits(BankCard.digitsFor(_company.isEmpty ? detected : _company))]),
                  ),
                ),
                const SizedBox(height: 10),
                Text(tr('কার্ডের কোম্পানি'), style: body(13, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in cardCompanies)
                    ChoiceChip(
                      key: Key('card-company-$c'),
                      label: Text(c == detected && _company.isEmpty ? trf('{0} (নম্বর থেকে)', [c]) : c),
                      selected: _company == c || (_company.isEmpty && detected == c),
                      onSelected: (on) => setState(() {
                        _company = on ? c : '';
                        // Fewer digits for the new company: the extra ones go.
                        final d = _digits;
                        final max = BankCard.digitsFor(_company.isEmpty ? BankCard.networkOf(d) : _company);
                        _number.text = groupedNumber(d.length > max ? d.substring(0, max) : d, company: _company.isEmpty ? BankCard.networkOf(d) : _company);
                      }),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 3, child: TextField(controller: _holder, onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: tr('কার্ডে লেখা নাম (ঐচ্ছিক)')))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const Key('card-expiry'),
                      controller: _expiry,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      inputFormatters: [ExpiryFormatter()],
                      decoration: InputDecoration(labelText: tr('মেয়াদ'), hintText: 'MM/YY'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(tr('রং'), style: body(13, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 10, children: [
                  for (var i = 0; i < cardColors.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _color = i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: cardColors[i]),
                          border: Border.all(color: _color == i ? C.ink : Colors.transparent, width: 3),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                photoRow(tr('সামনের ছবি'), _front, true),
                const SizedBox(height: 8),
                photoRow(tr('পিছনের ছবি'), _back, false),
                const SizedBox(height: 12),
                TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: tr('নোট (ঐচ্ছিক)'), hintText: tr('যেমন: বেতনের একাউন্টের কার্ড'))),
                const SizedBox(height: 10),
                Text(tr('কার্ডের PIN বা পিছনের ৩ অঙ্কের CVV এখানে রাখার কোনো ঘর নেই — এগুলো কোথাও লিখে রাখবেন না।'), style: body(12.5, color: C.muted, height: 1.5)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PrimaryButton(key: const Key('card-save'), label: _saving ? tr('রাখছি…') : tr('রাখুন'), icon: Icons.lock_outline_rounded, height: 52, onPressed: _saving ? null : _save),
            ),
          ]),
        ),
      ),
    );
  }
}
