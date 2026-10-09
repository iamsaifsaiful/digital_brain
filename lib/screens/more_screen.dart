import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/csv.dart';
import '../services/crypto.dart';
import '../services/data_store.dart';
import '../services/lock.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const appVersion = '1.1.0';

/// Security, encrypted backup, voice and reports.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool? _bioOn;
  bool _bioAvailable = false;
  int _autoLock = 30;
  String? _lastBackup;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final brain = BrainScope.read(context);
    final lock = brain.services.lock;
    final on = await lock.biometricsOn();
    final avail = await lock.biometrics.available();
    final secs = await lock.autoLockSeconds();
    final last = await lock.keys.read('last_backup');
    if (!mounted) return;
    setState(() {
      _bioOn = on;
      _bioAvailable = avail;
      _autoLock = secs;
      _lastBackup = last;
    });
  }

  Future<String?> _askPassword({required bool create}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final key = GlobalKey<FormState>();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(create ? 'ব্যাকআপের পাসওয়ার্ড' : 'ব্যাকআপের পাসওয়ার্ড দিন', style: display(20)),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (create)
              Text('এই পাসওয়ার্ড ছাড়া ব্যাকআপ খোলা যাবে না। ভুলে গেলে কেউ উদ্ধার করতে পারবে না — কোথাও লিখে রাখুন।',
                  style: body(14, color: C.muted, height: 1.5)),
            const SizedBox(height: 10),
            TextFormField(
              controller: a,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'পাসওয়ার্ড'),
              validator: (v) => create && (v ?? '').length < 8 ? 'অন্তত ৮ অক্ষর দিন' : ((v ?? '').isEmpty ? 'পাসওয়ার্ড দিন' : null),
            ),
            if (create) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: b,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'আবার দিন'),
                validator: (v) => v != a.text ? 'দুটো মেলেনি' : null,
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, a.text);
            },
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
    return r;
  }

  Future<void> _backup() async {
    final brain = BrainScope.read(context);
    if (!await verifyUser(context, reason: 'ব্যাকআপ নিতে যাচাই করুন')) return;
    final pass = await _askPassword(create: true);
    if (pass == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await Backup.export(brain.data, pass);
      final now = brain.services.now();
      final name = 'digital-brain-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.dbrain';
      await brain.services.files.shareFile(bytes, name, 'application/octet-stream', 'Digital Brain এনক্রিপ্টেড ব্যাকআপ');
      await brain.services.lock.keys.write('last_backup', now.toIso8601String());
      _lastBackup = now.toIso8601String();
    } catch (e) {
      if (mounted) toast(context, 'ব্যাকআপ নেওয়া যায়নি: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final brain = BrainScope.read(context);
    if (!await verifyUser(context, reason: 'ব্যাকআপ ফিরিয়ে আনতে যাচাই করুন')) return;
    final Uint8List? bytes = await brain.services.files.pickFile();
    if (bytes == null || !mounted) return;
    final pass = await _askPassword(create: false);
    if (pass == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final restored = await Backup.restore(bytes, pass);
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'ব্যাকআপ ফিরিয়ে আনবেন?',
        text: 'ব্যাকআপে আছে: ${bnDigits(restored.vault.length)}টি পাসওয়ার্ড, ${bnDigits(restored.contacts.length)} জন যোগাযোগ, '
            '${bnDigits(restored.ledger.length)}টি লেনদেন, ${bnDigits(restored.notes.length)}টি নোট, ${bnDigits(restored.reminders.length)}টি রিমাইন্ডার।\n\n'
            'এখনকার সব তথ্য এর বদলে যাবে।',
        yes: 'ফিরিয়ে আনুন',
        danger: true,
      );
      if (!ok) return;
      await brain.replaceAll(restored);
      if (mounted) toast(context, 'ব্যাকআপ ফিরিয়ে আনা হয়েছে');
    } on NotABackup {
      if (mounted) toast(context, 'এটা Digital Brain-এর ব্যাকআপ ফাইল নয়');
    } on WrongKey {
      if (mounted) toast(context, 'পাসওয়ার্ড মেলেনি, অথবা ফাইলটি নষ্ট');
    } catch (e) {
      if (mounted) toast(context, 'ফিরিয়ে আনা যায়নি: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _csv() async {
    final brain = BrainScope.read(context);
    if (brain.data.ledger.isEmpty) {
      toast(context, 'ধার-দেনার কোনো লেনদেন নেই');
      return;
    }
    final csv = ledgerCsv(brain.data.ledger);
    final now = brain.services.now();
    await brain.services.files.shareFile(
      Uint8List.fromList(utf8.encode(csv)),
      'dhar-dena-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv',
      'text/csv',
      'ধার-দেনার হিসাব',
    );
  }

  Future<void> _changePin() async {
    if (!await verifyUser(context, reason: 'PIN বদলাতে আগে যাচাই করুন')) return;
    if (!mounted) return;
    final lock = BrainScope.read(context).services.lock;
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _NewPinSheet(lock: lock));
    if (done == true && mounted) toast(context, 'নতুন PIN রাখা হয়েছে');
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final lock = brain.services.lock;
    final last = _lastBackup == null ? null : DateTime.tryParse(_lastBackup!);

    Widget switchRow(String title, String sub, bool value, ValueChanged<bool>? onChanged) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15, weight: FontWeight.w600)),
                Text(sub, style: body(13, color: C.muted)),
              ]),
            ),
            Switch(value: value, onChanged: onChanged, activeTrackColor: C.green),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('আরও', style: display(26, weight: 700)),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('নিরাপত্তা', style: body(16, weight: FontWeight.w600)),
            switchRow(
              'আঙুলের ছাপে খোলা',
              _bioAvailable ? 'না হলে PIN লাগবে' : 'এই ফোনে আঙুলের ছাপ চালু নেই',
              (_bioOn ?? false) && _bioAvailable,
              !_bioAvailable
                  ? null
                  : (v) async {
                      await lock.setBiometricsOn(v);
                      setState(() => _bioOn = v);
                    },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('নিজে থেকে লক হবে', style: body(15, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text('তখনই', style: body(13))),
                  ButtonSegment(value: 30, label: Text('৩০ সে.', style: body(13))),
                  ButtonSegment(value: 60, label: Text('১ মি.', style: body(13))),
                  ButtonSegment(value: 300, label: Text('৫ মি.', style: body(13))),
                ],
                selected: {_autoLock},
                onSelectionChanged: (s) async {
                  await lock.setAutoLockSeconds(s.first);
                  setState(() => _autoLock = s.first);
                },
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _changePin, child: Text('PIN বদলান', style: body(14, weight: FontWeight.w600, color: C.green))),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('এনক্রিপ্টেড ব্যাকআপ', style: body(16, weight: FontWeight.w600))),
              Text(last == null ? 'এখনো নেওয়া হয়নি' : 'শেষ: ${shortDate(last)}', style: body(13, color: C.muted)),
            ]),
            const SizedBox(height: 6),
            Text('সব তথ্য একটি ফাইলে, আলাদা পাসওয়ার্ড দিয়ে তালাবদ্ধ। নতুন ফোনে সেই পাসওয়ার্ড দিয়ে ফিরিয়ে আনা যায়।',
                style: body(14, color: C.muted, height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: PrimaryButton(label: 'ব্যাকআপ নিন', icon: Icons.download_rounded, height: 48, onPressed: _busy ? null : _backup)),
              const SizedBox(width: 8),
              Expanded(child: SecondaryButton(label: 'ফিরিয়ে আনুন', icon: Icons.upload_rounded, onPressed: _busy ? null : _restore)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Column(children: [
            switchRow('উত্তর কণ্ঠে শোনাও', 'পাসওয়ার্ড কখনো জোরে পড়া হয় না', brain.speakOn, (v) => brain.setSpeakOn(v)),
            const Divider(),
            ListRow(
              padding: const EdgeInsets.symmetric(vertical: 10),
              leading: const Icon(Icons.table_view_outlined, color: C.ink),
              title: 'ধার-দেনার রিপোর্ট (CSV)',
              subtitle: 'Excel বা Google Sheets-এ খোলা যায়',
              trailing: const Icon(Icons.ios_share_rounded, color: C.muted),
              onTap: _csv,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('শীঘ্রই আসছে', style: body(14, weight: FontWeight.w600, color: C.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in const ['ডিভাইসের মধ্যে সুরক্ষিত সিঙ্ক', 'PDF ও Excel রিপোর্ট', 'একাধিক মুদ্রা'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFB5BCB3)), borderRadius: BorderRadius.circular(10)),
              child: Text(s, style: body(13, color: C.muted2)),
            ),
        ]),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => showLicensePage(context: context, applicationName: 'Digital Brain', applicationVersion: appVersion),
            child: Text('Digital Brain ${bnDigits(appVersion)} · লাইসেন্স', style: body(13, color: C.muted)),
          ),
        ),
      ],
    );
  }
}

class _NewPinSheet extends StatefulWidget {
  const _NewPinSheet({required this.lock});
  final LockService lock;

  @override
  State<_NewPinSheet> createState() => _NewPinSheetState();
}

class _NewPinSheetState extends State<_NewPinSheet> {
  String? _first;
  String? _error;
  int _k = 0;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_first == null ? 'নতুন PIN দিন' : 'নতুন PIN আবার দিন', style: display(20)),
            SizedBox(height: 28, child: _error == null ? null : Text(_error!, style: body(14, color: C.red, weight: FontWeight.w600))),
            PinPad(
              key: ValueKey(_k),
              dark: false,
              onComplete: (pin, clear) async {
                if (_first == null) {
                  setState(() {
                    _first = pin;
                    _error = null;
                    _k++;
                  });
                  return;
                }
                if (pin != _first) {
                  setState(() {
                    _first = null;
                    _error = 'মেলেনি, আবার শুরু করুন';
                    _k++;
                  });
                  return;
                }
                await widget.lock.setPin(pin);
                if (context.mounted) Navigator.pop(context, true);
              },
            ),
          ]),
        ),
      );
}
