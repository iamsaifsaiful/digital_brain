import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
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
import 'assistant_settings.dart';
import 'settings_parts.dart';
import 'sound_screen.dart';
import 'store_more_screens.dart' show DonorPanel;
import 'feedback_screen.dart';
import 'requests_screen.dart';
import 'trash_screen.dart';
import 'trace_screen.dart';
import '../services/trace.dart';
import 'pro_screen.dart';
import 'google_backup.dart';
import '../logic/pro.dart';
import '../ui/pro_gate.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';

const appVersion = '2.25.0';

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
      toast(context, tr('এখনো কোনো লেনদেন নেই'));
      return;
    }
    final csv = ledgerCsv(brain.data.ledger);
    final now = brain.services.now();
    await brain.services.files.shareFile(
      Uint8List.fromList(utf8.encode(csv)),
      'dhar-dena-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv',
      'text/csv',
      tr('লেনদেনের হিসাব'),
    );
  }

  Future<void> _setName() async {
    final brain = BrainScope.read(context);
    final c = TextEditingController(text: brain.userName);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('আপনাকে কী নামে ডাকবো?'), style: body(18, weight: FontWeight.w600)),
        content: TextField(controller: c, autofocus: true, style: body(16), decoration: InputDecoration(hintText: tr('যেমন: সাইফুল ভাই'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাদ দিন'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('রাখুন'), style: body(15, weight: FontWeight.w600, color: C.green))),
        ],
      ),
    );
    c.dispose();
    if (v != null) await brain.setUserName(v);
  }

  Future<void> _setDistrict() async {
    final brain = BrainScope.read(context);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('আপনার জেলা/শহর'), style: body(18, weight: FontWeight.w600)),
        children: [
          for (final p in bdPlaces)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p.name),
              child: Text(p.label, style: body(16, weight: p.name == brain.district ? FontWeight.w700 : FontWeight.w400, color: p.name == brain.district ? C.green : C.ink)),
            ),
        ],
      ),
    );
    if (v != null) await brain.setDistrict(v);
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
              Text(tr('platform.claude.com → API Keys থেকে একটা key বানিয়ে এখানে বসান (sk-ant- দিয়ে শুরু)।'),
                  style: body(14, color: C.muted, height: 1.5)),
              const SizedBox(height: 6),
              Text(tr('key দিলে AI চালু হবে: আপনার বলা বা লেখা বাক্য আর হিসাবের সারাংশ Anthropic-এ যাবে (কী কী যায়, সেটিংসে নিচে লেখা আছে)। পাসওয়ার্ড, ভল্ট, PIN/OTP আর ফোন-কার্ড-NID নম্বর কখনো যায় না। key মুছে দিলেই AI বন্ধ। key এই ফোনে তালাবদ্ধ থাকে।'),
                  style: body(13, color: C.muted, height: 1.5)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      final key = c.text.trim();
                      if (key.isEmpty) return;
                      setD(() {
                        testing = true;
                        status = tr('পরীক্ষা করছি…');
                      });
                      final old = brain.services.ai.key;
                      brain.services.ai.key = key;
                      try {
                        final r = await brain.services.ai.route(tr('হ্যালো, তুমি কেমন আছো?'), brain.aiContext());
                        final reply = r?['reply'];
                        status = trf('✓ কাজ করছে! AI বলল: {0}', [reply ?? 'ঠিক আছে']);
                        await brain.setAiKey(key);
                      } catch (e) {
                        brain.services.ai.key = old;
                        status = '$e';
                      }
                      if (ctx.mounted) setD(() => testing = false);
                    },
              child: Text(tr('পরীক্ষা করে রাখুন')),
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
    final sample = tr('আসসালামু আলাইকুম! আমি আপনার সহকারী। বলুন, কী করে দিতে পারি?');
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
                    tr('ফোনে কোনো বাংলা কণ্ঠ পাওয়া যায়নি। Play Store থেকে “Speech Services by Google” হালনাগাদ করে, ফোনের Settings › ভাষা › Text-to-speech থেকে বাংলা (বাংলাদেশ) কণ্ঠ ডাউনলোড করে নিন।'),
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
                    child: Text(tr('▶ চেপে শুনুন, পছন্দ হলে বেছে নিন। “ইন্টারনেট” লেখাগুলো সাধারণত বেশি স্বাভাবিক শোনায়।'),
                        style: body(14, color: C.muted, height: 1.5)),
                  ),
                  ListTile(
                    leading: Icon(current == null ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: C.green),
                    title: Text(tr('নিজে থেকে সেরাটা বেছে নাও')),
                    onTap: () async {
                      await brain.setVoice(null);
                      setSheet(() {});
                    },
                  ),
                  for (var i = 0; i < list.length; i++)
                    ListTile(
                      leading: Icon(current == list[i].name ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: C.green),
                      title: Text(trf('কণ্ঠ {0}{1}', [bnDigits(i + 1), list[i].locale.toLowerCase().contains('bd') ? ' · বাংলাদেশ' : ' · ভারত'])),
                      subtitle: Text(list[i].online ? tr('ইন্টারনেট লাগে, বেশি স্বাভাবিক') : tr('ইন্টারনেট ছাড়াও চলে')),
                      trailing: IconButton(
                        tooltip: tr('শুনুন'),
                        icon: Icon(Icons.play_circle_outline_rounded, color: C.green),
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
    if (!await verifyUser(context, reason: tr('PIN বদলাতে আগে যাচাই করুন'))) return;
    if (!mounted) return;
    final lock = BrainScope.read(context).services.lock;
    final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _NewPinSheet(lock: lock));
    if (done == true && mounted) toast(context, tr('নতুন PIN রাখা হয়েছে'));
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

    Widget linkRow(IconData icon, String title, {String? sub, Color? subColor, VoidCallback? onTap, Widget? trailing}) => ListRow(
          leading: Icon(icon, color: C.muted2, size: 22),
          title: title,
          subtitle: sub,
          subtitleColor: subColor,
          trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: C.muted),
          onTap: onTap,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TabTitle(tr('আরও')),
        const SizedBox(height: 14),
        ProfileCard(onName: _setName, onPlace: _setDistrict),
        const SizedBox(height: 12),
        // The things people come here for, as big tiles (two rows of two).
        for (final row in [
          [
            _Tile(key: const Key('more-requests'), icon: Icons.bloodtype_outlined, fg: C.rose, bg: C.roseTint, title: tr('অনুরোধ'), sub: tr('রক্ত চাই / দিতে পারি'), onTap: () => push(const RequestsScreen())),
            _Tile(
                key: const Key('more-pro'),
                icon: Icons.workspace_premium_outlined,
                fg: C.ochre,
                bg: C.ochreTint,
                title: tr('প্রো ভার্সন'),
                sub: brain.gated && brain.pro ? tr('চালু আছে') : tr('কী কী পাবেন'),
                onTap: () => push(const ProScreen())),
          ],
          [
            _Tile(
                key: const Key('more-feedback'),
                icon: Icons.forum_outlined,
                fg: C.blue,
                bg: C.blueTint,
                title: tr('মতামত'),
                sub: brain.feedbackUnread > 0 ? trf('{0}টা নতুন উত্তর', [bnDigits(brain.feedbackUnread)]) : tr('সমস্যা বা নতুন সুবিধা'),
                badge: brain.feedbackUnread > 0,
                onTap: () => push(const FeedbackScreen())),
            _Tile(icon: Icons.lightbulb_outline_rounded, fg: C.green, bg: C.greenTint, title: tr('কী কী করা যায়'), sub: tr('সব সুবিধা, মাইকে কী বলবেন'), onTap: () => push(const HelpScreen())),
          ],
        ]) ...[
          Row(children: [Expanded(child: SizedBox(height: 70, child: row[0])), const SizedBox(width: 10), Expanded(child: SizedBox(height: 70, child: row[1]))]),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Panel(
          child: Rows(children: [
            linkRow(Icons.delete_outline_rounded, tr('মুছে ফেলা'),
                sub: brain.data.trash.isEmpty ? tr('যা মুছবেন, ৩০ দিন এখানে থাকবে') : trf('{0}টা — ৩০ দিনের মধ্যে ফিরিয়ে আনা যায়', [bnDigits(brain.data.trash.length)]),
                onTap: () => push(const TrashScreen())),
            linkRow(Icons.notifications_active_outlined, tr('রিমাইন্ডার ঠিকমতো বাজবে তো?'), sub: tr('ফোনের সেটিং দেখে নিন, ১ মিনিটে পরীক্ষা করুন'), onTap: () => push(const ReminderCheckScreen())),
            linkRow(Icons.bug_report_outlined, tr('সমস্যা খোঁজার লগ'),
                sub: Trace.enabled ? tr('চালু — মাইক কী শুনল, কী বুঝল') : tr('বন্ধ — ভয়েসে সমস্যা হলে চালু করুন'), onTap: () => push(const TraceScreen())),
          ]),
        ),
        const SizedBox(height: 22),
        Text(tr('সেটিংস'), style: display(20, weight: 700)),
        const SizedBox(height: 16),
        SectionTitle(tr('চেহারা ও ভাষা')),
        const LookSection(),
        const SizedBox(height: 16),
        SectionTitle(tr('সহকারী')),
        const AssistantSection(),
        // The downloaded APK runs AI on the user's own key (the Play app's AI comes with Pro).
        if (!brain.gated) ...[
          const SizedBox(height: 10),
          Panel(
            child: Rows(children: [
              linkRow(Icons.auto_awesome_outlined, tr('AI সহকারী (Claude)'),
                  sub: brain.aiOn ? tr('চালু আছে') : tr('বন্ধ · নিজের API key দিয়ে চালু করা যায়'), subColor: brain.aiOn ? C.green : C.muted, onTap: _setAiKey),
              if (brain.aiOn)
                switchRow(Icons.psychology_outlined, tr('সবচেয়ে ভালো বোঝা (Sonnet)'), tr('বন্ধ করলে দ্রুত ও সস্তা Haiku — তবে কম বোঝে'), brain.aiBest,
                    (v) => brain.setAiBest(v)),
              if (brain.aiOn)
                switchRow(Icons.manage_search_rounded, tr('AI আমার তথ্য দেখে উত্তর দিক'), tr('রিমাইন্ডার, কাজ, নোট ও হিসাব দেখে ঠিক উত্তর — পাসওয়ার্ড কখনো না'),
                    brain.aiShareData, (v) => brain.setAiShareData(v)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        SectionTitle(tr('রক্তদান')),
        const DonorPanel(),
        const SizedBox(height: 6),
        Panel(child: linkRow(Icons.bloodtype_outlined, tr('রক্তের অনুরোধ'), sub: tr('কারো রক্ত লাগলে দেখুন, বা নিজে অনুরোধ দিন'), onTap: () => push(const RequestsScreen()))),
        const SizedBox(height: 16),
        SectionTitle(tr('তথ্য নিরাপদ রাখা')),
        Panel(
          child: Rows(children: [
            linkRow(Icons.cloud_download_outlined, tr('Google অ্যাকাউন্ট ও ব্যাকআপ'),
                sub: brain.driveOn
                    ? (brain.has(ProFeature.autoBackup)
                        ? trf('{0} · Drive-এ অটো ব্যাকআপ চালু', [brain.googleEmail])
                        : trf('{0} · শেষ Drive ব্যাকআপ {1}', [brain.googleEmail, brain.lastDrive == null ? tr('হয়নি') : daysLeftLabel(brain.lastDrive!, now)]))
                    : (last == null ? tr('এখনো নেওয়া হয়নি') : trf('শেষ ব্যাকআপ {0}', [daysLeftLabel(last, now)])),
                subColor: backupOld && !brain.driveOn ? C.orange : C.muted,
                onTap: () => push(const BackupScreen())),
            linkRow(Icons.lock_outline_rounded, tr('PIN বদলান'), onTap: _changePin),
            switchRow(
              Icons.fingerprint_rounded,
              tr('আঙুলের ছাপে খোলা'),
              _bioAvailable ? tr('না হলে PIN লাগবে') : tr('এই ফোনে আঙুলের ছাপ চালু নেই'),
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
                Text(tr('অ্যাপ বন্ধ করলে নিজে থেকে লক হবে'), style: body(15)),
                const SizedBox(height: 8),
                SegTabs<int>(
                  items: [(0, tr('তখনই')), (30, tr('৩০ সে.')), (60, tr('১ মি.')), (300, tr('৫ মি.'))],
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
        SectionTitle(tr('রিমাইন্ডার ও কণ্ঠ')),
        Panel(
          child: Rows(children: [
            switchRow(Icons.alarm_rounded, tr('অ্যালার্মের মতো বাজবে'), tr('বন্ধ না করা পর্যন্ত, ফোন পকেটে থাকলেও শোনা যায়'), brain.alarmInsistent,
                (v) => brain.setAlarmInsistent(v)),
            linkRow(Icons.music_note_outlined, tr('রিমাইন্ডারের রিংটোন'),
                sub: brain.alarmSoundTitle.isEmpty ? tr('ফোনের অ্যালার্ম টোন') : brain.alarmSoundTitle, onTap: _pickRingtone),
            switchRow(Icons.volume_up_outlined, tr('উত্তর কণ্ঠে শোনাও'), tr('পাসওয়ার্ড কখনো জোরে পড়া হয় না'), brain.speakOn, (v) => brain.setSpeakOn(v)),
            linkRow(Icons.record_voice_over_outlined, tr('কণ্ঠ বেছে নিন'), sub: tr('ফোনে থাকা বাংলা কণ্ঠগুলো শুনে দেখুন'), onTap: _pickVoice),
            switchRow(Icons.record_voice_over_rounded, tr('উত্তরের মাঝে কথা বলে থামানো'), tr('বন্ধ থাকলে অ্যাপ কথা শেষ করে তারপর শোনে — নিজের কথা ভুল করে ধরে না। চালু করলে লম্বা উত্তরের মাঝেই বলতে পারবেন (কিছু ফোনে ভুল ধরতে পারে)'),
                brain.bargeIn, (v) => brain.setBargeIn(v)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(tr('মুখে বললে কথাকে লেখায় রূপান্তর করে ফোনের নিজের ভয়েস সেবা (সাধারণত Google)। সেজন্য আপনার কণ্ঠ ইন্টারনেটে Google-এর কাছে যেতে পারে — AI বন্ধ থাকলেও। না চাইলে লিখে ব্যবহার করুন।'),
            style: body(12, color: C.muted, height: 1.5)),
        const SizedBox(height: 16),
        SectionTitle(tr('অন্যান্য')),
        Panel(
          child: Rows(children: [
            linkRow(Icons.picture_as_pdf_outlined, tr('সবকিছু PDF আকারে'), sub: tr('কাজ, হিসাব, নোট, স্বাস্থ্য… যা চান বেছে নিয়ে এক PDF-এ'), onTap: () => exportEverything(context),
                trailing: brain.has(ProFeature.pdf) ? Icon(Icons.download_rounded, color: C.muted) : const ProMark()),
            linkRow(Icons.table_view_outlined, tr('ধার-দেনার রিপোর্ট (CSV)'), sub: tr('Excel বা Google Sheets-এ খোলা যায়'), onTap: _csv,
                trailing: Icon(Icons.ios_share_rounded, color: C.muted)),
            if (previewEdition)
              switchRow(Icons.science_outlined, tr('পরীক্ষা: প্রো চালু'), tr('শুধু প্রিভিউতে — ফ্রি আর প্রো ইউজার কী দেখবে দুটোই দেখে নিন'), brain.pro, (v) => brain.setProForTest(v)),
            linkRow(Icons.info_outline_rounded, tr('লাইসেন্স ও সংস্করণ'),
                sub: 'My Assistant ${bnDigits(appVersion)}${previewEdition ? ' · ${tr('প্লে স্টোর প্রিভিউ')}' : ''}',
                onTap: () => showLicensePage(context: context, applicationName: 'My Assistant', applicationVersion: appVersion)),
          ]),
        ),
        if (brain.aiOn) ...[
          const SizedBox(height: 8),
          Text(brain.aiShareData
                  ? tr('AI চালু থাকলে Anthropic-এ যায়: আপনার বলা বা লেখা বাক্য, টাকার হিসাবের সারাংশ (নাম ও অঙ্ক), রিমাইন্ডার, কাজ, নোট, ওষুধ ও অভ্যাসের নাম, বিশেষ দিন, ডকুমেন্টের নাম আর “মনে রেখো” কথাগুলো — যাতে আপনার জিনিস নিয়ে ঠিক উত্তর দিতে পারে। কখনো যায় না: পাসওয়ার্ড ও ভল্ট, PIN/OTP/পাসওয়ার্ড থাকা নোট, ফোন-কার্ড-NID নম্বর, ইমেইল, স্বাস্থ্যের মাপ আর অন্য অ্যাপের মেসেজ।')
                  : tr('AI চালু থাকলে শুধু আপনার বলা বা লেখা বাক্য আর টাকার হিসাবের সারাংশ (নাম ও অঙ্ক) Anthropic-এ যায়। রিমাইন্ডার, কাজ, নোট, পাসওয়ার্ড, ভল্ট, ফোন-কার্ড-NID নম্বর বা অন্য অ্যাপের মেসেজ যায় না।'),
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
        title: Text(create ? tr('ব্যাকআপের পাসওয়ার্ড') : tr('ব্যাকআপের পাসওয়ার্ড দিন'), style: display(20)),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (create)
              Text(tr('এই পাসওয়ার্ড ছাড়া ব্যাকআপ খোলা যাবে না। ভুলে গেলে কেউ উদ্ধার করতে পারবে না — কোথাও লিখে রাখুন।'),
                  style: body(14, color: C.muted, height: 1.5)),
            const SizedBox(height: 10),
            TextFormField(
              controller: a,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('পাসওয়ার্ড')),
              validator: (v) => create && (v ?? '').length < 8 ? tr('অন্তত ৮ অক্ষর দিন') : ((v ?? '').isEmpty ? tr('পাসওয়ার্ড দিন') : null),
            ),
            if (create) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: b,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('আবার দিন')),
                validator: (v) => v != a.text ? tr('দুটো মেলেনি') : null,
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(
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

  Future<void> _backup({bool toPhone = true}) async {
    final brain = BrainScope.read(context);
    if (brain.loadError != null) {
      toast(context, tr('এই ফোনে তথ্য খোলা যায়নি, তাই এখন ব্যাকআপ নেওয়া যাবে না। আগের কোনো ব্যাকআপ ফিরিয়ে আনুন।'));
      return;
    }
    if (!await verifyUser(context, reason: tr('ব্যাকআপ নিতে যাচাই করুন'))) return;
    final pass = await _askPassword(create: true);
    if (pass == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await Backup.export(brain.data, pass, files: await brain.backupFiles());
      final now = brain.services.now();
      final name = 'my-assistant-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.dbrain';
      if (toPhone) {
        final saved = await brain.services.files.saveFile(bytes, name);
        if (!saved) {
          if (mounted) toast(context, tr('সেভ করা হয়নি'));
          return;
        }
        if (mounted) toast(context, trf('ব্যাকআপ ফোনে সেভ হয়েছে: {0}', [name]));
      } else {
        await brain.services.files.shareFile(bytes, name, 'application/octet-stream', tr('My Assistant এনক্রিপ্টেড ব্যাকআপ'));
      }
      await brain.setPref('last_backup', now.toIso8601String());
      _lastBackup = now.toIso8601String();
    } catch (e) {
      if (mounted) toast(context, trf('ব্যাকআপ নেওয়া যায়নি: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final brain = BrainScope.read(context);
    if (!await verifyUser(context, reason: tr('ব্যাকআপ ফিরিয়ে আনতে যাচাই করুন'))) return;
    final Uint8List? bytes = await brain.services.files.pickFile();
    if (bytes == null || !mounted) return;
    final pass = await _askPassword(create: false);
    if (pass == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final (restored, files) = await Backup.restore(bytes, pass);
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        title: tr('ব্যাকআপ ফিরিয়ে আনবেন?'),
        text: trf('ব্যাকআপে আছে: {0}টি পাসওয়ার্ড, {1} জন যোগাযোগ, {2}টি ধার-দেনা, {3}টি আয়-ব্যয়, {4}টি নোট, {5}টি রিমাইন্ডার, {6}টি কাজ, {7}টি ছবি/ফাইল।\n\nএখনকার সব তথ্য এর বদলে যাবে (মেশানো হবে না)। কিছু ব্যর্থ হলে এখনকার তথ্য যেমন আছে থাকবে।', [bnDigits(restored.vault.length), bnDigits(restored.contacts.length), bnDigits(restored.ledger.length), bnDigits(restored.cash.length), bnDigits(restored.notes.length), bnDigits(restored.reminders.length), bnDigits(restored.tasks.length), bnDigits(files.length)]),
        yes: tr('ফিরিয়ে আনুন'),
        danger: true,
      );
      if (!ok) return;
      await brain.replaceAll(restored, files: files);
      if (mounted) toast(context, tr('ব্যাকআপ ফিরিয়ে আনা হয়েছে'));
    } on NotABackup {
      if (mounted) toast(context, tr('এটা My Assistant-এর ব্যাকআপ ফাইল নয়, অথবা ফাইলটি নষ্ট। এখনকার তথ্যে কোনো পরিবর্তন হয়নি।'));
    } on UnsupportedBackup {
      if (mounted) toast(context, tr('এই ব্যাকআপ অ্যাপের নতুন সংস্করণে বানানো। আগে অ্যাপ হালনাগাদ করুন। এখনকার তথ্যে কোনো পরিবর্তন হয়নি।'));
    } on WrongKey {
      if (mounted) toast(context, tr('পাসওয়ার্ড মেলেনি, অথবা ফাইলটি নষ্ট। এখনকার তথ্যে কোনো পরিবর্তন হয়নি।'));
    } catch (e) {
      if (mounted) toast(context, trf('ফিরিয়ে আনা যায়নি: {0}', [e]));
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
              decoration: BoxDecoration(color: C.fill, shape: BoxShape.circle),
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
          TopBar(title: tr('ব্যাকআপ')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              InfoBanner(
                text: last == null
                    ? tr('এখনো কোনো ব্যাকআপ নেওয়া হয়নি। ফোন হারালে বা বদলালে সব তথ্য হারিয়ে যাবে।')
                    : trf('শেষ ব্যাকআপ {0} ({1})।{2}', [daysLeftLabel(last, now), fullDate(last), old ? ' এর পরের তথ্য ফোন হারালে হারিয়ে যাবে।' : '']),
                icon: old ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                fg: old ? C.orangeDark : C.greenDark,
                iconColor: old ? C.orange : C.green,
                bg: old ? C.orangeTint : C.greenTint,
              ),
              const SizedBox(height: 12),
              const GoogleBackupPanel(),
              const SizedBox(height: 16),
              Text(tr('অথবা নিজে ফাইল হিসেবে'), style: body(14, weight: FontWeight.w600, color: C.muted2)),
              const SizedBox(height: 8),
              _step(tr('১'), tr('ব্যাকআপ নিন'), tr('কাজ, হিসাব, যোগাযোগ, নোট, পাসওয়ার্ড — সব একটা ফাইলে, আপনার দেওয়া পাসওয়ার্ড দিয়ে তালাবদ্ধ।'), [
                Row(children: [
                  Expanded(child: PrimaryButton(label: tr('ফোনে সেভ'), icon: Icons.save_alt_rounded, height: 48, onPressed: _busy ? null : () => _backup())),
                  const SizedBox(width: 8),
                  Expanded(child: SecondaryButton(label: tr('শেয়ার'), icon: Icons.ios_share_rounded, onPressed: _busy ? null : () => _backup(toPhone: false))),
                ]),
              ]),
              const SizedBox(height: 10),
              _step(tr('২'), tr('নিরাপদ জায়গায় রাখুন'), tr('“শেয়ার” চেপে Google Drive বা নিজের WhatsApp-এ পাঠিয়ে রাখুন — ফোন হারালেও ফাইল থাকবে।'), const []),
              const SizedBox(height: 10),
              _step(tr('৩'), tr('নতুন ফোনে ফিরিয়ে আনুন'), tr('অ্যাপ খুলে এখানে এসে ফাইলটা বেছে দিন, আর একই পাসওয়ার্ড দিন।'), [
                SecondaryButton(label: tr('ফাইল থেকে ফিরিয়ে আনুন'), icon: Icons.restore_rounded, onPressed: _busy ? null : _restore),
              ]),
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
            Text(_first == null ? tr('নতুন PIN দিন') : tr('নতুন PIN আবার দিন'), style: display(20)),
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
                    _error = tr('মেলেনি, আবার শুরু করুন');
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

/// A big square-ish shortcut at the top of আরও.
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.fg, required this.bg, required this.title, required this.sub, required this.onTap, this.badge = false});
  final IconData icon;
  final Color fg;
  final Color bg;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: C.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(children: [
              Badge(
                isLabelVisible: badge,
                smallSize: 10,
                child: Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg, size: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w700)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: badge ? C.greenDark : C.muted)),
                ]),
              ),
            ]),
          ),
        ),
      );
}
