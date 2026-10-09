import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';

/// One login, opened after the user proved who they are. The password stays
/// hidden until asked for, and hides itself again after 30 seconds.
class VaultItemScreen extends StatefulWidget {
  const VaultItemScreen({super.key, required this.id});
  final String id;

  @override
  State<VaultItemScreen> createState() => _VaultItemScreenState();
}

class _VaultItemScreenState extends State<VaultItemScreen> {
  bool _show = false;
  Timer? _hide;
  int _left = 0;

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

  Future<void> _copy(String text, {bool secret = false}) async {
    await BrainScope.read(context).services.files.copy(text, clearAfter: secret ? const Duration(seconds: 30) : null);
    if (mounted) toast(context, secret ? 'কপি হয়েছে — ৩০ সেকেন্ড পর ক্লিপবোর্ড মুছে যাবে' : 'কপি হয়েছে');
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final v = brain.vaultById(widget.id);
    if (v == null) {
      return const Scaffold(body: SafeArea(child: Column(children: [TopBar(title: 'পাওয়া যায়নি')])));
    }
    final look = vaultLook(v.kind);
    final linked = brain.data.reminders.where((r) => r.vaultId == v.id).toList();
    final now = brain.services.now();

    Widget field(String label, String value, {bool copy = false, bool secret = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: body(13, color: C.muted)),
                    if (secret)
                      Text(_show ? value : '•' * 10,
                          style: _show
                              ? const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w600, color: C.ink, letterSpacing: 1)
                              : body(20, height: 1.3).copyWith(letterSpacing: 3))
                    else
                      Text(value, style: body(16, weight: FontWeight.w500)),
                  ],
                ),
              ),
              if (secret)
                IconButton.outlined(
                  tooltip: _show ? 'পাসওয়ার্ড লুকান' : 'পাসওয়ার্ড দেখুন',
                  onPressed: _toggle,
                  style: IconButton.styleFrom(side: const BorderSide(color: C.border), fixedSize: const Size(44, 44)),
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: C.ink),
                ),
              if (copy) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: secret ? 'পাসওয়ার্ড কপি করুন' : '$label কপি করুন',
                  onPressed: () => _copy(value, secret: secret),
                  style: IconButton.styleFrom(side: const BorderSide(color: C.border), fixedSize: const Size(44, 44)),
                  icon: const Icon(Icons.copy_rounded, color: C.ink, size: 20),
                ),
              ],
            ],
          ),
        );

    final fields = <Widget>[
      if (v.address.isNotEmpty) field(v.kind == VaultKind.wifi ? 'নেটওয়ার্কের নাম' : 'ঠিকানা', v.address, copy: true),
      if (v.username.isNotEmpty) field('ইউজারনেম', v.username, copy: true),
      if (v.email.isNotEmpty) field('ইমেইল', v.email, copy: true),
      if (v.password.isNotEmpty) field(v.kind == VaultKind.bank ? 'পাসওয়ার্ড / PIN' : 'পাসওয়ার্ড', v.password, copy: true, secret: true),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: '', trailing: [
              const Pill('আনলক করা'),
            ]),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  Row(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: look.bg, borderRadius: BorderRadius.circular(16)),
                      child: Icon(look.icon, color: look.fg, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v.name, style: display(26, weight: 700)),
                        Text('বিভাগ: ${v.kind.label}', style: body(14, color: C.muted)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (fields.isNotEmpty)
                    Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Rows(children: fields),
                    ),
                  if (_show) ...[
                    const SizedBox(height: 10),
                    InfoBanner(
                      text: '${bnDigits(_left)} সেকেন্ড পর পাসওয়ার্ড আবার লুকিয়ে যাবে',
                      icon: Icons.timer_outlined,
                      fg: C.orangeDark,
                      iconColor: C.orange,
                      bg: C.orangeTint,
                    ),
                  ],
                  if (v.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Panel(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('নোট', style: body(13, color: C.muted)),
                        const SizedBox(height: 4),
                        Text(v.note, style: body(15, height: 1.5)),
                      ]),
                    ),
                  ],
                  if (linked.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final r in linked)
                      InfoBanner(
                        text: '${r.title}: ${fullDate(r.nextDate(now))} (${daysLeftLabel(r.nextDate(now), now)})',
                        icon: Icons.notifications_none_rounded,
                        fg: C.orangeDark,
                        iconColor: C.orange,
                        bg: C.orangeTint,
                      ),
                  ],
                  const SizedBox(height: 14),
                  Text('• কপি করা পাসওয়ার্ড ৩০ সেকেন্ড পর ক্লিপবোর্ড থেকে মুছে যায়', style: body(13, color: C.muted, height: 1.6)),
                  Text('• ভয়েসে চাইলে অ্যাপ শুধু বলে “স্ক্রিনে দেখুন” — পাসওয়ার্ড জোরে পড়ে না', style: body(13, color: C.muted, height: 1.6)),
                  Text('• শেষ বদল: ${fullDate(v.updatedAt)}', style: body(13, color: C.muted, height: 1.6)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'সম্পাদনা',
                    icon: Icons.edit_outlined,
                    color: C.ink,
                    height: 52,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(vault: v))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: 'মুছুন',
                    icon: Icons.delete_outline_rounded,
                    fg: C.red,
                    borderColor: const Color(0xFFE3B9A8),
                    height: 52,
                    onPressed: () async {
                      final ok = await confirmDialog(context, title: '${v.name} মুছবেন?', text: 'এই লগইন তথ্য আর ফেরত আনা যাবে না (ব্যাকআপ থাকলে সেখান থেকে ছাড়া)।', yes: 'মুছুন', danger: true);
                      if (!ok || !context.mounted) return;
                      await brain.deleteVault(v.id);
                      if (context.mounted) {
                        toast(context, '${v.name} মুছে ফেলা হয়েছে');
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
