import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/file_view.dart' show viewFile;
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_parts.dart';

/// দোকানের তথ্য (owner, 6 Nov): the name, address, mobile and logo printed on
/// the PDF receipt, and the line at its foot.
class ShopProfilePage extends StatefulWidget {
  const ShopProfilePage({super.key});
  @override
  State<ShopProfilePage> createState() => _ShopProfilePageState();
}

class _ShopProfilePageState extends State<ShopProfilePage> {
  late final ShopProfile _p = BrainScope.read(context).shop.profile;
  late final _name = TextEditingController(text: _p.name);
  late final _address = TextEditingController(text: _p.address);
  late final _phone = TextEditingController(text: bnDigits(_p.phone));
  late final _note = TextEditingController(text: _p.receiptNote);
  late String _logo = _p.logo;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final brain = BrainScope.read(context);
    final camera = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(tr('গ্যালারি থেকে'), style: body(15)), onTap: () => Navigator.pop(ctx, false)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(tr('ক্যামেরায় তুলুন'), style: body(15)), onTap: () => Navigator.pop(ctx, true)),
        ]),
      ),
    );
    if (camera == null) return;
    final f = await brain.services.files.pickPhoto(camera: camera, side: 360);
    if (f == null || !mounted) return;
    setState(() => _logo = base64Encode(f.bytes));
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    if (!await bizCan(context) || !mounted) return;
    await brain.saveShopProfile(brain.shop.profile.copyWith(
      name: _name.text.trim(),
      address: _address.text.trim(),
      phone: asciiDigits(_phone.text).replaceAll(RegExp(r'[^0-9+]'), ''),
      logo: _logo,
      receiptNote: _note.text.trim(),
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
    toast(context, tr('দোকানের তথ্য রাখা হলো — রসিদে এগুলোই যাবে'));
  }

  @override
  Widget build(BuildContext context) {
    final logo = _logo.isEmpty ? null : base64Decode(_logo);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(title: tr('দোকানের তথ্য'), sub: tr('PDF রসিদ আর তাগাদায় এগুলো যাবে')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              Center(
                child: Column(children: [
                  InkWell(
                    key: const Key('biz-logo-pick'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickLogo,
                    child: Container(
                      width: 96,
                      height: 96,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border)),
                      child: logo == null
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_photo_alternate_outlined, color: C.green, size: 28),
                              const SizedBox(height: 4),
                              Text(tr('লোগো'), style: body(12, color: C.green, weight: FontWeight.w600)),
                            ])
                          : Image.memory(logo, fit: BoxFit.cover),
                    ),
                  ),
                  if (logo != null)
                    TextButton(key: const Key('biz-logo-remove'), onPressed: () => setState(() => _logo = ''), child: Text(tr('লোগো সরান'), style: body(13, color: C.red)))
                  else
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('চাপ দিয়ে দোকানের লোগো দিন (ইচ্ছামতো)'), style: body(12, color: C.muted))),
                ]),
              ),
              const SizedBox(height: 14),
              LabeledField(controller: _name, label: tr('দোকানের নাম'), hint: tr('যেমন: মা জেনারেল স্টোর'), fieldKey: const Key('biz-shop-name'), icon: Icons.storefront_outlined, onChanged: (_) => setState(() {})),
              LabeledField(controller: _address, label: tr('ঠিকানা'), hint: tr('যেমন: স্টেশন রোড, সিলেট'), fieldKey: const Key('biz-shop-address'), icon: Icons.place_outlined, onChanged: (_) => setState(() {})),
              LabeledField(controller: _phone, label: tr('মোবাইল নম্বর'), hint: '01XXXXXXXXX', keyboard: TextInputType.phone, fieldKey: const Key('biz-shop-phone'), icon: Icons.phone_outlined, onChanged: (_) => setState(() {})),
              LabeledField(controller: _note, label: tr('রসিদের নিচের লেখা'), hint: tr('যেমন: ধন্যবাদ, আবার আসবেন।'), fieldKey: const Key('biz-shop-note'), icon: Icons.short_text_rounded, onChanged: (_) => setState(() {})),
              SectionHeading(tr('রসিদ দেখতে যেমন হবে')),
              _ReceiptPreview(name: _name.text.trim(), address: _address.text.trim(), phone: _phone.text.trim(), note: _note.text.trim(), logo: logo),
              const SizedBox(height: 12),
              ListCard(rows: [
                ListRow(
                  key: const Key('biz-open-tagada'),
                  leading: const IconTile(Icons.sms_outlined),
                  title: tr('তাগাদার মেসেজ'),
                  subtitle: tr('নিজের মতো করে লিখুন'),
                  trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                  onTap: () => pushPage(context, const TagadaPage()),
                ),
              ]),
            ]),
          ),
          PageFoot(child: PrimaryButton(key: const Key('biz-shop-save'), label: tr('রাখুন'), icon: Icons.check_rounded, onPressed: _save)),
        ]),
      ),
    );
  }
}

/// A small picture of the receipt's top, as it will print.
class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.name, required this.address, required this.phone, required this.note, this.logo});
  final String name, address, phone, note;
  final Uint8List? logo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
        child: DefaultTextStyle(
          style: body(12, color: const Color(0xFF1F2937)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isEmpty ? tr('রসিদ') : name, style: body(17, weight: FontWeight.w700, color: const Color(0xFF1F2937))),
                  if (address.isNotEmpty) Text(address, style: body(11.5, color: const Color(0xFF6B7280))),
                  if (phone.isNotEmpty) Text(trf('মোবাইল: {0}', [bnDigits(phone)]), style: body(11.5, color: const Color(0xFF6B7280))),
                ]),
              ),
              if (logo != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(logo!, width: 48, height: 48, fit: BoxFit.cover)),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Container(width: 40, height: 3, color: const Color(0xFF0F7A55))),
            const SizedBox(height: 10),
            Text(trf('রসিদ #{0} · মিনিকেট চাল ৫ কেজি — {1}', [bnDigits(12), taka(375)]), style: body(12, color: const Color(0xFF1F2937))),
            Text(trf('মোট: {0}', [taka(375)]), style: body(12.5, weight: FontWeight.w700, color: const Color(0xFF0F7A55))),
            const Divider(height: 18),
            Text(note.isEmpty ? tr('ধন্যবাদ, আবার আসবেন।') : note, style: body(11, color: const Color(0xFF6B7280))),
          ]),
        ),
      );
}

/// তাগাদার মেসেজ (owner, 6 Nov: "ইউজার নিজের ইচ্ছে মত তাগাদা মেসেজ পরিবর্তন
/// করতে পারবে"): the shop's own words; the [] words are filled in for each customer.
class TagadaPage extends StatefulWidget {
  const TagadaPage({super.key});
  @override
  State<TagadaPage> createState() => _TagadaPageState();
}

class _TagadaPageState extends State<TagadaPage> {
  late final _c = TextEditingController(text: tr(BrainScope.read(context).shop.profile.tagadaText));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _insert(String word) {
    final sel = _c.selection;
    final at = sel.isValid ? sel.start : _c.text.length;
    final end = sel.isValid ? sel.end : _c.text.length;
    _c.value = TextEditingValue(text: _c.text.replaceRange(at, end, word), selection: TextSelection.collapsed(offset: at + word.length));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final p = brain.shop.profile;
    final preview = fillTagada(_c.text, name: tr('রহিম মিয়া'), due: taka(1250), shop: p.name.isEmpty ? tr('দোকান') : p.name, phone: bnDigits(p.phone));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(title: tr('তাগাদার মেসেজ'), sub: tr('সব গ্রাহকের জন্য একই মেসেজ, নাম আর টাকা নিজে বসবে')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              TextField(textCapitalization: TextCapitalization.sentences, key: const Key('biz-tagada-field'), controller: _c, minLines: 4, maxLines: 8, onChanged: (_) => setState(() {}), style: body(15, height: 1.5), decoration: const InputDecoration(isDense: true)),
              const SizedBox(height: 10),
              Text(tr('চাপ দিলে লেখায় বসবে:'), style: body(12.5, color: C.muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (w, what) in [(bnEn('[নাম]', '[name]'), tr('গ্রাহকের নাম')), (bnEn('[বাকি]', '[due]'), tr('কত টাকা বাকি')), (bnEn('[দোকান]', '[shop]'), tr('দোকানের নাম')), (bnEn('[মোবাইল]', '[mobile]'), tr('দোকানের মোবাইল'))])
                  ActionChip(key: Key('biz-tagada-word-$w'), label: Text('$w · $what', style: body(12.5)), onPressed: () => _insert(w)),
              ]),
              SectionHeading(tr('গ্রাহক যেমন পাবেন')),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
                child: Text(preview, key: const Key('biz-tagada-preview'), style: body(14, height: 1.55)),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('biz-tagada-reset'),
                onPressed: () => setState(() => _c.text = tr(defaultTagada)),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(tr('আগের মেসেজে ফিরুন')),
              ),
            ]),
          ),
          PageFoot(
            child: PrimaryButton(
              key: const Key('biz-tagada-save'),
              label: tr('মেসেজ রাখুন'),
              icon: Icons.check_rounded,
              onPressed: () async {
                if (!await bizCan(context) || !context.mounted) return;
                final t = _c.text.trim();
                await brain.saveShopProfile(brain.shop.profile.copyWith(tagada: t == tr(defaultTagada) ? '' : t));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                toast(context, tr('তাগাদার মেসেজ রাখা হলো'));
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// The PDF receipt (owner, 6 Nov: "পিডিএফ আকারে রসিদ"): made on the phone,
/// shown with download, share and open-with.
Future<void> showReceiptPdf(BuildContext context, Sale s) async {
  if (!await bizCan(context) || !context.mounted) return;
  final brain = BrainScope.read(context);
  final p = brain.shop.profile;
  final c = s.customerId.isEmpty ? null : customerById(brain.shop, s.customerId);
  final due = c == null ? null : customerAccount(brain.shop, c).due;
  final spec = receiptSpec(s, p, taka: taka, digits: bnDigits, logo: p.logo.isEmpty ? null : base64Decode(p.logo), due: due);
  final bytes = await brain.services.files.pdfMake(spec);
  if (!context.mounted) return;
  if (bytes == null) return toast(context, tr('PDF তৈরি করা গেল না। আবার চেষ্টা করুন।'));
  await viewFile(context, bytes, name: 'receipt-${s.no}.pdf', mime: 'application/pdf', title: trf('রসিদ #{0}', [bnDigits(s.no)]));
}
