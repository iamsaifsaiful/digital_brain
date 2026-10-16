import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../services/crypto.dart' show WrongKey;
import '../services/data_store.dart';
import '../services/google_account.dart';
import '../state/brain.dart';
import '../ui/pin.dart' show verifyUser;
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'more_screen.dart' show appVersion, BackupScreen;

/// Google sign-in and automatic backup to the app's hidden Google Drive
/// folder; on a new phone, the same account brings the backup back.
class GoogleBackupPanel extends StatefulWidget {
  const GoogleBackupPanel({super.key});

  @override
  State<GoogleBackupPanel> createState() => _GoogleBackupPanelState();
}

class _GoogleBackupPanelState extends State<GoogleBackupPanel> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<String?> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await job();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = e;
    });
  }

  Future<void> _signIn() async {
    final brain = BrainScope.read(context);
    await _run(() => brain.signInGoogle(appVersion: appVersion));
    if (!mounted || !brain.signedIn || _error != null) return;
    // A fresh phone: look for an earlier backup.
    if (_looksEmpty(brain)) await _restore(fresh: true);
  }

  static bool _looksEmpty(Brain b) {
    final d = b.data;
    return d.ledger.isEmpty && d.cash.isEmpty && d.notes.isEmpty && d.reminders.isEmpty && d.tasks.isEmpty && d.vault.isEmpty && d.contacts.isEmpty;
  }

  Future<void> _turnOn() async {
    final brain = BrainScope.read(context);
    final pw = await askBackupPassword(context, create: true);
    if (pw == null || !mounted) return;
    await _run(() => brain.startDriveBackup(pw));
    if (mounted && _error == null) toast(context, tr('Google Drive-এ ব্যাকআপ হয়েছে। এখন থেকে নিজে থেকেই হবে।'));
  }

  Future<void> _restore({bool fresh = false}) async {
    final brain = BrainScope.read(context);
    if (!fresh && !await verifyUser(context, reason: tr('ব্যাকআপ ফিরিয়ে আনতে যাচাই করুন'))) return;
    List<DriveFile> list;
    setState(() => _busy = true);
    try {
      list = await brain.driveBackups();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is GoogleError ? e.message : '$e';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (list.isEmpty) {
      if (!fresh) toast(context, tr('এই Google অ্যাকাউন্টে কোনো ব্যাকআপ পাওয়া যায়নি'));
      return;
    }
    final f = list.first;
    final go = await confirmDialog(
      context,
      title: tr('আগের ব্যাকআপ পাওয়া গেছে'),
      text: trf('{0}-এর ব্যাকআপ আছে ({1})। ফিরিয়ে আনবেন? ব্যাকআপ-পাসওয়ার্ড লাগবে।', [fullDate(f.time.toLocal()), _size(f.size)]),
      yes: tr('ফিরিয়ে আনুন'),
    );
    if (!go || !mounted) return;
    final pw = await askBackupPassword(context, create: false);
    if (pw == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final (restored, files) = await brain.openDriveBackup(f, pw);
      if (!mounted) return;
      if (!_looksEmpty(brain)) {
        final ok = await confirmDialog(
          context,
          title: tr('ব্যাকআপ ফিরিয়ে আনবেন?'),
          text: trf('ব্যাকআপে আছে: {0}টি পাসওয়ার্ড, {1} জন যোগাযোগ, {2}টি ধার-দেনা, {3}টি আয়-ব্যয়, {4}টি নোট, {5}টি রিমাইন্ডার, {6}টি কাজ।\n\nএখনকার সব তথ্য এর বদলে যাবে (মেশানো হবে না)।',
              [bnDigits(restored.vault.length), bnDigits(restored.contacts.length), bnDigits(restored.ledger.length), bnDigits(restored.cash.length), bnDigits(restored.notes.length), bnDigits(restored.reminders.length), bnDigits(restored.tasks.length)]),
          yes: tr('ফিরিয়ে আনুন'),
          danger: true,
        );
        if (!ok) return;
      }
      await brain.replaceAll(restored, files: files);
      await brain.continueDriveBackup(pw);
      if (mounted) toast(context, tr('ব্যাকআপ ফিরিয়ে আনা হয়েছে। Drive-এ অটো ব্যাকআপ চালু থাকল।'));
    } on WrongKey {
      if (mounted) toast(context, tr('পাসওয়ার্ড মেলেনি। এখনকার তথ্যে কোনো পরিবর্তন হয়নি।'));
    } on NotABackup {
      if (mounted) toast(context, tr('ফাইলটি নষ্ট। এখনকার তথ্যে কোনো পরিবর্তন হয়নি।'));
    } on UnsupportedBackup {
      if (mounted) toast(context, tr('এই ব্যাকআপ অ্যাপের নতুন সংস্করণে বানানো। আগে অ্যাপ হালনাগাদ করুন।'));
    } on GoogleError catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, trf('ফিরিয়ে আনা যায়নি: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _size(int b) => b > 1024 * 1024 ? '${bnDigits((b / 1024 / 1024).toStringAsFixed(1))} MB' : '${bnDigits((b / 1024).ceil())} KB';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final busy = _busy || brain.driveBusy;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.cloud_outlined, color: C.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('Google Drive-এ অটো ব্যাকআপ'), style: body(16, weight: FontWeight.w700))),
          if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 8),
        if (!brain.signedIn) ...[
          Text(tr('Google দিয়ে লগইন করলে তথ্য নিজে থেকে আপনার Google Drive-এর অ্যাপের লুকানো ফোল্ডারে ব্যাকআপ হবে। নতুন ফোনে একই অ্যাকাউন্টে লগইন করলেই সব ফিরে আসবে। ব্যাকআপ আপনার পাসওয়ার্ডে তালাবদ্ধ — Google বা আমরা পড়তে পারি না।'),
              style: body(13, color: C.muted, height: 1.55)),
          const SizedBox(height: 12),
          PrimaryButton(key: const Key('google-sign-in'), label: tr('Google দিয়ে লগইন'), icon: Icons.login_rounded, height: 48, onPressed: busy ? null : _signIn),
        ] else ...[
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(brain.googleName.isEmpty ? brain.googleEmail : brain.googleName, style: body(15, weight: FontWeight.w600)),
                if (brain.googleName.isNotEmpty) Text(brain.googleEmail, style: body(13, color: C.muted)),
              ]),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await confirmDialog(context,
                          title: tr('লগআউট করবেন?'), text: tr('এই ফোন থেকে Drive-এ অটো ব্যাকআপ বন্ধ হবে। Drive-এ রাখা ব্যাকআপ থেকে যাবে।'), yes: tr('লগআউট'));
                      if (ok) await brain.signOutGoogle();
                    },
              child: Text(tr('লগআউট')),
            ),
          ]),
          const SizedBox(height: 8),
          if (!brain.driveOn) ...[
            Text(tr('একটা ব্যাকআপ-পাসওয়ার্ড ঠিক করুন — এটা দিয়ে ব্যাকআপ তালাবদ্ধ থাকবে, আর PIN ভুলে গেলে নতুন PIN দিতেও এটা লাগবে।'),
                style: body(13, color: C.muted, height: 1.55)),
            const SizedBox(height: 10),
            PrimaryButton(key: const Key('drive-on'), label: tr('অটো ব্যাকআপ চালু করুন'), icon: Icons.cloud_upload_outlined, height: 48, onPressed: busy ? null : _turnOn),
          ] else ...[
            Text(
                brain.lastDrive == null
                    ? tr('চালু আছে · এখনো ব্যাকআপ হয়নি')
                    : trf('চালু আছে · শেষ ব্যাকআপ {0}। কিছু বদলালে অ্যাপ বন্ধ করার সময় নিজে থেকে নতুন ব্যাকআপ হয়, পুরোনোটা মুছে যায়।', [daysLeftLabel(brain.lastDrive!, now)]),
                style: body(13, color: C.greenDark, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: SecondaryButton(label: tr('এখনই ব্যাকআপ'), icon: Icons.cloud_upload_outlined, onPressed: busy ? null : () => _run(brain.backupToDrive))),
              const SizedBox(width: 8),
              Expanded(child: SecondaryButton(label: tr('বন্ধ করুন'), onPressed: busy ? null : brain.stopDriveBackup)),
            ]),
          ],
          const SizedBox(height: 4),
          TextButton.icon(onPressed: busy ? null : () => _restore(), icon: const Icon(Icons.restore_rounded), label: Text(tr('Drive থেকে ফিরিয়ে আনুন'))),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: body(13, color: C.red, height: 1.45)),
        ],
      ]),
    );
  }
}

/// The backup password: new (twice, at least 8 characters) or to open one.
Future<String?> askBackupPassword(BuildContext context, {required bool create}) async {
  final a = TextEditingController();
  final b = TextEditingController();
  final key = GlobalKey<FormState>();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(create ? tr('ব্যাকআপ-পাসওয়ার্ড ঠিক করুন') : tr('ব্যাকআপ-পাসওয়ার্ড দিন'), style: display(20)),
      content: Form(
        key: key,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (create)
            Text(tr('এই পাসওয়ার্ড ছাড়া ব্যাকআপ খোলা যাবে না, কেউ উদ্ধারও করতে পারবে না — কোথাও লিখে রাখুন।'), style: body(14, color: C.muted, height: 1.5)),
          const SizedBox(height: 10),
          TextFormField(
            key: const Key('backup-pw'),
            controller: a,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: tr('পাসওয়ার্ড')),
            validator: (v) => create && (v ?? '').length < 8 ? tr('অন্তত ৮ অক্ষর দিন') : ((v ?? '').isEmpty ? tr('পাসওয়ার্ড দিন') : null),
          ),
          if (create) ...[
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('backup-pw2'),
              controller: b,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: tr('আবার দিন')),
              validator: (v) => v != a.text ? tr('দুটো মেলেনি') : null,
            ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
        TextButton(
          key: const Key('backup-pw-ok'),
          onPressed: () {
            if (key.currentState!.validate()) Navigator.pop(ctx, a.text);
          },
          child: Text(tr('ঠিক আছে')),
        ),
      ],
    ),
  );
  return r;
}

/// On a fresh install: "আগে ব্যবহার করেছেন?" — sign in to bring the backup back.
class GoogleStartCard extends StatelessWidget {
  const GoogleStartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final fresh = d.ledger.isEmpty && d.cash.isEmpty && d.notes.isEmpty && d.reminders.isEmpty && d.tasks.isEmpty && d.vault.isEmpty;
    if (brain.signedIn || !fresh || brain.flag('g_card_off')) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: C.blueTint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(children: [
              Icon(Icons.cloud_download_outlined, color: C.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('আগে ব্যবহার করেছেন?'), style: body(15, weight: FontWeight.w600, color: C.blueText)),
                  Text(tr('Google দিয়ে লগইন করলে আগের ব্যাকআপ ফিরে আসবে'), style: body(13, color: C.blueText)),
                ]),
              ),
              IconButton(tooltip: tr('বন্ধ করুন'), onPressed: () => brain.setPref('g_card_off', true), icon: Icon(Icons.close_rounded, color: C.blueText, size: 20)),
            ]),
          ),
        ),
      ),
    );
  }
}
