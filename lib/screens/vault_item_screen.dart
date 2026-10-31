import 'dart:async';
import '../ui/secure.dart';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/vault_age.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';
import '../logic/lang.dart';

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
    if (mounted) toast(context, secret ? tr('কপি হয়েছে — ৩০ সেকেন্ড পর ক্লিপবোর্ড মুছে যাবে') : tr('কপি হয়েছে'));
  }

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final v = brain.vaultById(widget.id);
    if (v == null) {
      return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('পাওয়া যায়নি'))])));
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
                              ? TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w600, color: C.ink, letterSpacing: 1)
                              : body(20, height: 1.3).copyWith(letterSpacing: 3))
                    else
                      Text(value, style: body(16, weight: FontWeight.w500)),
                  ],
                ),
              ),
              if (secret)
                IconButton.outlined(
                  tooltip: _show ? tr('পাসওয়ার্ড লুকান') : tr('পাসওয়ার্ড দেখুন'),
                  onPressed: _toggle,
                  style: IconButton.styleFrom(side: BorderSide(color: C.border), fixedSize: const Size(44, 44)),
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: C.ink),
                ),
              if (copy) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: secret ? tr('পাসওয়ার্ড কপি করুন') : trf('{0} কপি করুন', [label]),
                  onPressed: () => _copy(value, secret: secret),
                  style: IconButton.styleFrom(side: BorderSide(color: C.border), fixedSize: const Size(44, 44)),
                  icon: Icon(Icons.copy_rounded, color: C.ink, size: 20),
                ),
              ],
            ],
          ),
        );

    final fields = <Widget>[
      if (v.address.isNotEmpty) field(v.kind == VaultKind.wifi ? tr('নেটওয়ার্কের নাম') : tr('ঠিকানা'), v.address, copy: true),
      if (v.username.isNotEmpty) field(tr('ইউজারনেম'), v.username, copy: true),
      if (v.email.isNotEmpty) field(tr('ইমেইল'), v.email, copy: true),
      if (v.password.isNotEmpty) field(v.kind == VaultKind.bank ? tr('পাসওয়ার্ড / PIN') : tr('পাসওয়ার্ড'), v.password, copy: true, secret: true),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: '', trailing: [
              Pill(tr('আনলক করা')),
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
                        Text(trf('বিভাগ: {0}', [v.kind.label]), style: body(14, color: C.muted)),
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
                      text: trf('{0} সেকেন্ড পর পাসওয়ার্ড আবার লুকিয়ে যাবে', [bnDigits(_left)]),
                      icon: Icons.timer_outlined,
                      fg: C.orangeDark,
                      iconColor: C.orange,
                      bg: C.orangeTint,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _Dates(v: v, now: now),
                  if (v.old.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Panel(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(trf('আগের পাসওয়ার্ড ({0}টি)', [bnDigits(v.old.length)]), style: body(13, color: C.muted)),
                        for (final o in v.old)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Opacity(
                              opacity: 0.45,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_show ? o.password : '•' * 8,
                                    style: _show
                                        ? TextStyle(fontFamily: 'monospace', fontSize: 15, color: C.ink, decoration: TextDecoration.lineThrough)
                                        : body(16, height: 1.3).copyWith(letterSpacing: 3)),
                                Text(o.from == null ? trf('{0} পর্যন্ত চালু ছিল', [fullDate(o.until)]) : trf('{0} থেকে {1} পর্যন্ত চালু ছিল', [fullDate(o.from!), fullDate(o.until)]),
                                    style: body(12, color: C.muted)),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  ],
                  if (v.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Panel(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('নোট'), style: body(13, color: C.muted)),
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
                  Text(tr('• কপি করা পাসওয়ার্ড ৩০ সেকেন্ড পর ক্লিপবোর্ড থেকে মুছে যায়'), style: body(13, color: C.muted, height: 1.6)),
                  Text(tr('• ভয়েসে চাইলে অ্যাপ শুধু বলে “স্ক্রিনে দেখুন” — পাসওয়ার্ড জোরে পড়ে না'), style: body(13, color: C.muted, height: 1.6)),
                  Text(trf('• শেষ সম্পাদনা: {0}', [fullDate(v.updatedAt)]), style: body(13, color: C.muted, height: 1.6)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Expanded(
                  child: PrimaryButton(
                    label: tr('সম্পাদনা'),
                    icon: Icons.edit_outlined,
                    color: C.fill,
                    height: 52,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(vault: v))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: tr('মুছুন'),
                    icon: Icons.delete_outline_rounded,
                    fg: C.red,
                    borderColor: C.orangeTint,
                    height: 52,
                    onPressed: () async {
                      final ok = await confirmDialog(context, title: trf('{0} মুছবেন?', [v.name]), text: tr('এই লগইন তথ্য আর ফেরত আনা যাবে না (ব্যাকআপ থাকলে সেখান থেকে ছাড়া)।'), yes: tr('মুছুন'), danger: true);
                      if (!ok || !context.mounted) return;
                      await brain.deleteVault(v.id);
                      if (context.mounted) {
                        toast(context, trf('{0} মুছে ফেলা হয়েছে', [v.name]));
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

/// When it was put in and when its password was last set; "বা তার আগে"
/// for a login kept before the app noted these.
class _Dates extends StatelessWidget {
  const _Dates({required this.v, required this.now});
  final VaultItem v;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final known = [v.passwordSince, v.updatedAt, for (final o in v.old) ...[o.until, if (o.from != null) o.from!]];
    final earliest = known.reduce((a, b) => a.isBefore(b) ? a : b);
    final added = v.createdAt == null ? trf('{0} বা তার আগে', [fullDate(earliest)]) : fullDate(v.createdAt!);
    final set = v.passwordAt == null ? trf('{0} বা তার আগে', [fullDate(v.passwordSince)]) : fullDate(v.passwordAt!);
    final days = dayOnly(now).difference(dayOnly(v.passwordSince)).inDays;
    final stale = v.password.isNotEmpty && !now.isBefore(v.passwordSince.add(passwordMaxAge));
    Widget line(IconData icon, String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, size: 18, color: color ?? C.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: body(14, color: C.muted))),
            Flexible(child: Text(value, textAlign: TextAlign.end, style: body(14, weight: FontWeight.w600, color: color ?? C.ink))),
          ]),
        );
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(children: [
        line(Icons.event_available_outlined, tr('যোগ করা হয়েছে'), added),
        if (v.password.isNotEmpty) line(Icons.key_outlined, tr('পাসওয়ার্ড দেওয়া হয়েছে'), set),
        if (v.password.isNotEmpty)
          line(stale ? Icons.update_rounded : Icons.schedule_rounded, tr('পাসওয়ার্ডের বয়স'), days <= 0 ? tr('আজ') : trf('{0} দিন', [bnDigits(days)]), color: stale ? C.orangeDark : null),
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(tr('৬ মাসের বেশি পুরোনো — সম্পাদনায় গিয়ে নতুন পাসওয়ার্ড দিন; আগেরটা এখানে ঝাপসা করে রাখা থাকবে।'), style: body(13, color: C.orangeDark, height: 1.5)),
          ),
      ]),
    );
  }
}
