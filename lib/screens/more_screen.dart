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
import 'alarm_screens.dart';
import 'help_screen.dart';
import 'sound_screen.dart';

const appVersion = '2.5.1';

/// "আমি": Pro, reminder check, backup and security, voice, and the rest.
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

  Future<void> _csv() async {
    final brain = BrainScope.read(context);
    if (brain.data.ledger.isEmpty) {
      toast(context, 'এখনো কোনো লেনদেন নেই');
      return;
    }
    final csv = ledgerCsv(brain.data.ledger);
    final now = brain.services.now();
    await brain.services.files.shareFile(
      Uint8List.fromList(utf8.encode(csv)),
      'dhar-dena-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv',
      'text/csv',
      'লেনদেনের হিসাব',
    );
  }

  Future<void> _setAiKey() async {
    final brain = BrainScope.read(context);
    final c = TextEditingController(text: brain.services.ai.key);
    String? status;
    bool testing = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Claude API key', style: display(20)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('platform.claude.com → API Keys থেকে একটা key বানিয়ে এখানে বসান (sk-ant- দিয়ে শুরু)।',
                  style: body(14, color: C.muted, height: 1.5)),
              const SizedBox(height: 10),
              TextField(
                controller: c,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'API key'),
              ),
              if (status != null) ...[
                const SizedBox(height: 10),
                Text(status!, style: body(14, height: 1.5, color: status!.startsWith('✓') ? C.greenDark : C.red)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      final key = c.text.trim();
                      if (key.isEmpty) return;
                      setD(() {
                        testing = true;
                        status = 'পরীক্ষা করছি…';
                      });
                      final old = brain.services.ai.key;
                      brain.services.ai.key = key;
                      try {
                        final r = await brain.services.ai.route('হ্যালো, তুমি কেমন আছো?', brain.aiContext());
                        final reply = r?['reply'];
                        status = '✓ কাজ করছে! AI বলল: ${reply ?? 'ঠিক আছে'}';
                        await brain.setAiKey(key);
                      } catch (e) {
                        brain.services.ai.key = old;
                        status = '$e';
                      }
                      if (ctx.mounted) setD(() => testing = false);
                    },
              child: const Text('পরীক্ষা করে রাখুন'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVoice() async {
    final brain = BrainScope.read(context);
    final list = await brain.services.voice.voices();
    if (!mounted) return;
    const sample = 'আসসালামু আলাইকুম! আমি আপনার সহকারী। বলুন, কী করে দিতে পারি?';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final current = brain.services.voice.preferredVoice;
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text(
                    'ফোনে কোনো বাংলা কণ্ঠ পাওয়া যায়নি। Play Store থেকে “Speech Services by Google” হালনাগাদ করে, ফোনের Settings › ভাষা › Text-to-speech থেকে বাংলা (বাংলাদেশ) কণ্ঠ ডাউনলোড করে নিন।',
                    style: body(15, height: 1.6),
                  ),
                );
              }
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text('▶ চেপে শুনুন, পছন্দ হলে বেছে নিন। “ইন্টারনেট” লেখাগুলো সাধারণত বেশি স্বাভাবিক শোনায়।',
                        style: body(14, color: C.muted, height: 1.5)),
                  ),
                  ListTile(
                    leading: Icon(current == null ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: C.green),
                    title: const Text('নিজে থেকে সেরাটা বেছে নাও'),
                    onTap: () async {
                      await brain.setVoice(null);
                      setSheet(() {});
                    },
                  ),
                  for (var i = 0; i < list.length; i++)
                    ListTile(
                      leading: Icon(current == list[i].name ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: C.green),
                      title: Text('কণ্ঠ ${bnDigits(i + 1)}${list[i].locale.toLowerCase().contains('bd') ? ' · বাংলাদেশ' : ' · ভারত'}'),
                      subtitle: Text(list[i].online ? 'ইন্টারনেট লাগে, বেশি স্বাভাবিক' : 'ইন্টারনেট ছাড়াও চলে'),
                      trailing: IconButton(
                        tooltip: 'শুনুন',
                        icon: const Icon(Icons.play_circle_outline_rounded, color: C.green),
                        onPressed: () async {
                          await brain.services.voice.useVoice(list[i]);
                          await brain.services.voice.speakAndWait(sample);
                          // Back to the saved choice.
                          await brain.services.voice.useVoice(list.where((v) => v.name == current).firstOrNull);
                        },
                      ),
                      onTap: () async {
                        await brain.setVoice(list[i]);
                        brain.services.voice.speak(sample);
                        setSheet(() {});
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickRingtone() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoundScreen()));

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
    final now = brain.services.now();
    final backupOld = last == null || now.difference(last).inDays > 7;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w)).then((_) => _load());

    Widget switchRow(IconData icon, String title, String sub, bool value, ValueChanged<bool>? onChanged) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Icon(icon, color: C.muted2, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15)),
                Text(sub, style: body(12, color: C.muted)),
              ]),
            ),
            Switch(value: value, onChanged: onChanged),
          ]),
        );

    Widget linkRow(IconData icon, String title, {String? sub, Color subColor = C.muted, VoidCallback? onTap, Widget? trailing}) => ListRow(
          leading: Icon(icon, color: C.muted2, size: 22),
          title: title,
          subtitle: sub,
          subtitleColor: subColor,
          trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: C.muted),
          onTap: onTap,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const TabTitle('আমি'),
        const SizedBox(height: 14),
        Material(
          color: C.ink,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => push(const ProScreen()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('My Assistant Pro', style: body(16, weight: FontWeight.w700, color: Colors.white)),
                    Text('AI সহকারী, বিজ্ঞাপন নেই — শীঘ্রই', style: body(13, color: C.mint)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: C.onDarkMuted),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: linkRow(Icons.lightbulb_outline_rounded, 'অ্যাপ দিয়ে কী কী করা যায়', sub: 'সব সুবিধা, আর মাইকে কী বলবেন', onTap: () => push(const HelpScreen())),
        ),
        const SizedBox(height: 10),
        Panel(child: linkRow(Icons.notifications_active_outlined, 'রিমাইন্ডার ঠিকমতো বাজবে তো?', sub: 'ফোনের সেটিং দেখে নিন, ১ মিনিটে পরীক্ষা করুন', onTap: () => push(const ReminderCheckScreen()))),
        const SizedBox(height: 16),
        const SectionTitle('তথ্য নিরাপদ রাখা'),
        Panel(
          child: Rows(children: [
            linkRow(Icons.cloud_download_outlined, 'ব্যাকআপ',
                sub: last == null ? 'এখনো নেওয়া হয়নি' : 'শেষ ব্যাকআপ ${daysLeftLabel(last, now)}',
                subColor: backupOld ? C.orange : C.muted,
                onTap: () => push(const BackupScreen())),
            linkRow(Icons.lock_outline_rounded, 'PIN বদলান', onTap: _changePin),
            switchRow(
              Icons.fingerprint_rounded,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('অ্যাপ বন্ধ করলে নিজে থেকে লক হবে', style: body(15)),
                const SizedBox(height: 8),
                SegTabs<int>(
                  items: const [(0, 'তখনই'), (30, '৩০ সে.'), (60, '১ মি.'), (300, '৫ মি.')],
                  value: _autoLock,
                  onChanged: (v) async {
                    await lock.setAutoLockSeconds(v);
                    setState(() => _autoLock = v);
                  },
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionTitle('রিমাইন্ডার ও কণ্ঠ'),
        Panel(
          child: Rows(children: [
            switchRow(Icons.alarm_rounded, 'অ্যালার্মের মতো বাজবে', 'বন্ধ না করা পর্যন্ত, ফোন পকেটে থাকলেও শোনা যায়', brain.alarmInsistent,
                (v) => brain.setAlarmInsistent(v)),
            linkRow(Icons.music_note_outlined, 'রিমাইন্ডারের রিংটোন',
                sub: brain.alarmSoundTitle.isEmpty ? 'ফোনের অ্যালার্ম টোন' : brain.alarmSoundTitle, onTap: _pickRingtone),
            switchRow(Icons.volume_up_outlined, 'উত্তর কণ্ঠে শোনাও', 'পাসওয়ার্ড কখনো জোরে পড়া হয় না', brain.speakOn, (v) => brain.setSpeakOn(v)),
            linkRow(Icons.record_voice_over_outlined, 'কণ্ঠ বেছে নিন', sub: 'ফোনে থাকা বাংলা কণ্ঠগুলো শুনে দেখুন', onTap: _pickVoice),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionTitle('অন্যান্য'),
        Panel(
          child: Rows(children: [
            linkRow(Icons.auto_awesome_outlined, 'AI সহকারী (Claude)',
                sub: brain.aiOn ? 'চালু আছে' : 'বন্ধ · নিজের API key দিয়ে চালু করা যায়', subColor: brain.aiOn ? C.green : C.muted, onTap: _setAiKey),
            if (brain.aiOn)
              switchRow(Icons.psychology_outlined, 'সবচেয়ে ভালো বোঝা (Sonnet)', 'বন্ধ করলে দ্রুত ও সস্তা Haiku — তবে কম বোঝে', brain.aiBest,
                  (v) => brain.setAiBest(v)),
            linkRow(Icons.table_view_outlined, 'ধার-দেনার রিপোর্ট (CSV)', sub: 'Excel বা Google Sheets-এ খোলা যায়', onTap: _csv,
                trailing: const Icon(Icons.ios_share_rounded, color: C.muted)),
            linkRow(Icons.info_outline_rounded, 'লাইসেন্স ও সংস্করণ',
                sub: 'My Assistant ${bnDigits(appVersion)}',
                onTap: () => showLicensePage(context: context, applicationName: 'My Assistant', applicationVersion: appVersion)),
          ]),
        ),
        if (brain.aiOn) ...[
          const SizedBox(height: 8),
          Text('AI চালু থাকলে আপনার বলা বাক্য, লেনদেনের মানুষের নাম আর টাকার হিসাবের সারাংশ Anthropic-এ যায়, যাতে ঠিকঠাক উত্তর আর পরামর্শ দিতে পারে; পাসওয়ার্ড, ভল্ট, PIN, ফোন নম্বর, নোট বা কাজের লেখা কখনো যায় না।',
              style: body(12, color: C.muted, height: 1.5)),
        ],
      ],
    );
  }
}

/// Backup in three plain steps: take it, keep it somewhere safe, bring it back.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _lastBackup;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final last = await BrainScope.read(context).services.lock.keys.read('last_backup');
      if (mounted) setState(() => _lastBackup = last);
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

  Future<void> _backup({bool toPhone = true}) async {
    final brain = BrainScope.read(context);
    if (!await verifyUser(context, reason: 'ব্যাকআপ নিতে যাচাই করুন')) return;
    final pass = await _askPassword(create: true);
    if (pass == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await Backup.export(brain.data, pass);
      final now = brain.services.now();
      final name = 'my-assistant-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.dbrain';
      if (toPhone) {
        final saved = await brain.services.files.saveFile(bytes, name);
        if (!saved) {
          if (mounted) toast(context, 'সেভ করা হয়নি');
          return;
        }
        if (mounted) toast(context, 'ব্যাকআপ ফোনে সেভ হয়েছে: $name');
      } else {
        await brain.services.files.shareFile(bytes, name, 'application/octet-stream', 'My Assistant এনক্রিপ্টেড ব্যাকআপ');
      }
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
            '${bnDigits(restored.ledger.length)}টি ধার-দেনা, ${bnDigits(restored.cash.length)}টি আয়-ব্যয়, ${bnDigits(restored.notes.length)}টি নোট, '
            '${bnDigits(restored.reminders.length)}টি রিমাইন্ডার, ${bnDigits(restored.tasks.length)}টি কাজ।\n\n'
            'এখনকার সব তথ্য এর বদলে যাবে।',
        yes: 'ফিরিয়ে আনুন',
        danger: true,
      );
      if (!ok) return;
      await brain.replaceAll(restored);
      if (mounted) toast(context, 'ব্যাকআপ ফিরিয়ে আনা হয়েছে');
    } on NotABackup {
      if (mounted) toast(context, 'এটা My Assistant-এর ব্যাকআপ ফাইল নয়');
    } on WrongKey {
      if (mounted) toast(context, 'পাসওয়ার্ড মেলেনি, অথবা ফাইলটি নষ্ট');
    } catch (e) {
      if (mounted) toast(context, 'ফিরিয়ে আনা যায়নি: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _step(String n, String title, String text, List<Widget> actions) => Panel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle),
              child: Text(n, style: body(13, weight: FontWeight.w700, color: Colors.white, height: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: body(16, weight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          Text(text, style: body(13, color: C.muted, height: 1.55)),
          if (actions.isNotEmpty) ...[const SizedBox(height: 12), ...actions],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final last = _lastBackup == null ? null : DateTime.tryParse(_lastBackup!);
    final old = last == null || now.difference(last).inDays > 7;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'ব্যাকআপ'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              InfoBanner(
                text: last == null
                    ? 'এখনো কোনো ব্যাকআপ নেওয়া হয়নি। ফোন হারালে বা বদলালে সব তথ্য হারিয়ে যাবে।'
                    : 'শেষ ব্যাকআপ ${daysLeftLabel(last, now)} (${fullDate(last)})।${old ? ' এর পরের তথ্য ফোন হারালে হারিয়ে যাবে।' : ''}',
                icon: old ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                fg: old ? C.orangeDark : C.greenDark,
                iconColor: old ? C.orange : C.green,
                bg: old ? C.orangeTint : C.greenTint,
              ),
              const SizedBox(height: 12),
              _step('১', 'ব্যাকআপ নিন', 'কাজ, হিসাব, যোগাযোগ, নোট, পাসওয়ার্ড — সব একটা ফাইলে, আপনার দেওয়া পাসওয়ার্ড দিয়ে তালাবদ্ধ।', [
                Row(children: [
                  Expanded(child: PrimaryButton(label: 'ফোনে সেভ', icon: Icons.save_alt_rounded, height: 48, onPressed: _busy ? null : () => _backup())),
                  const SizedBox(width: 8),
                  Expanded(child: SecondaryButton(label: 'শেয়ার', icon: Icons.ios_share_rounded, onPressed: _busy ? null : () => _backup(toPhone: false))),
                ]),
              ]),
              const SizedBox(height: 10),
              _step('২', 'নিরাপদ জায়গায় রাখুন', '“শেয়ার” চেপে Google Drive বা নিজের WhatsApp-এ পাঠিয়ে রাখুন — ফোন হারালেও ফাইল থাকবে।', const []),
              const SizedBox(height: 10),
              _step('৩', 'নতুন ফোনে ফিরিয়ে আনুন', 'অ্যাপ খুলে এখানে এসে ফাইলটা বেছে দিন, আর একই পাসওয়ার্ড দিন।', [
                SecondaryButton(label: 'ফাইল থেকে ফিরিয়ে আনুন', icon: Icons.restore_rounded, onPressed: _busy ? null : _restore),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// What Pro will give. Payments are not live yet, so it says so honestly.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget point(String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: C.greenTint, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 16, color: C.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15, weight: FontWeight.w600)),
                Text(text, style: body(13, color: C.muted, height: 1.45)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      backgroundColor: C.surface,
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: '', close: true),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              Text('My Assistant Pro', style: display(28, weight: 700)),
              Text('মুখে বলুন, বাকিটা সহকারী সামলাবে', style: body(15, color: C.muted2)),
              const SizedBox(height: 20),
              point('যেকোনো কথা বুঝবে', 'AI দিয়ে লম্বা, এলোমেলো কথাও গুছিয়ে কাজ, হিসাব, রিমাইন্ডার করে'),
              point('কোনো বিজ্ঞাপন নেই', 'কাজের মাঝে কিছু বাধা দেবে না'),
              point('হিসাবের প্রশ্নের উত্তর', '“এই মাসে বাজারে কত গেল?” — সাথে সাথে বলে দেবে'),
              point('গোপন তথ্য সবসময় ফোনেই', 'পাসওয়ার্ড, PIN, কার্ড — AI-তে কখনো যায় না'),
              const SizedBox(height: 8),
              Panel(
                color: C.greenSoft,
                borderColor: C.green,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('বছরে ৳৯৯৯', style: body(17, weight: FontWeight.w700)),
                      Text('মাসে মাত্র ৳৮৩ · অথবা মাসে ৳৯৯', style: body(13, color: C.green)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'শীঘ্রই চালু হবে', color: C.ink, onPressed: null),
              const SizedBox(height: 8),
              Text('এখন সব সুবিধা বিনামূল্যে ব্যবহার করুন। Pro চালু হলে অ্যাপেই জানিয়ে দেব।', textAlign: TextAlign.center, style: body(13, color: C.muted)),
            ]),
          ),
        ]),
      ),
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
