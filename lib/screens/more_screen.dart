import 'notice_screen.dart';
import 'family_screen.dart' show FamilyScreen;
import 'look_settings.dart' show LookSettings;
import 'place_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart' show Via;
import '../logic/csv.dart';
import '../services/data_store.dart';
import '../services/lock.dart';
import '../services/location_share.dart';
import '../state/brain.dart';
import '../logic/home_scene.dart' show sceneNames, defaultScene;
import 'home_picture_screen.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/kit.dart';
import 'alarm_screens.dart';
import 'help_screen.dart';
import 'home_page.dart' show appTools;
import 'assistant_settings.dart';
import 'settings_parts.dart';
import 'sound_screen.dart';
import 'feedback_screen.dart';
import 'trash_screen.dart';
import 'nlu_model_screen.dart';
import 'trace_screen.dart';
import '../services/trace.dart';
import '../services/ads.dart';
import 'google_backup.dart';
import 'pro_screen.dart';
import '../logic/pro.dart';
import '../ui/pro_gate.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import 'biz/biz_more.dart';

const appVersion = '1.0.15';

/// The app's version, shown and sent to our server (sign-in, feedback,
/// problem logs). The Play app has its own numbering from 1.0.0 (owner, 29
/// Oct; the Play build's --dart-define=PLAY_VERSION) and the server tells
/// the two apart by the edition sent with it.
const playVersion = String.fromEnvironment('PLAY_VERSION');
String get shownVersion => playVersion.isNotEmpty ? playVersion : appVersion;

/// "আমি": Pro, reminder check, backup and security, voice, and the rest.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  /// Bumped on every change here, so an open settings page redraws too.
  final _changed = ValueNotifier<int>(0);
  Map<String, List<Widget> Function()> _parts = const {};

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _changed.value++;
  }

  @override
  void dispose() {
    _changed.dispose();
    super.dispose();
  }

  // Static (owner, 13 Nov: "ব্যবসায়ী মোড চালু করলে এখনো কিছুটা গ্লিজ মারে"):
  // switching the mode builds this page anew; it starts with what was read
  // last time instead of the defaults, so nothing jumps when they load.
  static bool? _bioOn;
  static bool _bioAvailable = false;
  static int _autoLock = 30;
  static String? _lastBackup;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
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
        title: Text(tr('আপনাকে কী নামে ডাকব?'), style: body(18, weight: FontWeight.w600)),
        content: TextField(textCapitalization: TextCapitalization.sentences, controller: c, autofocus: true, style: body(16), decoration: InputDecoration(hintText: tr('যেমন: সাইফুল ভাই'))),
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
    final v = await pickPlace(context);
    if (v == null) return;
    if (v is PickedPlace) {
      await brain.setDistrict(v.place.key);
      return;
    }
    // Following the phone: location permission first (asked once by Android).
    var st = await LocationShareChannel.status();
    if (st['fine'] != true) {
      await LocationShareChannel.ask();
      for (var i = 0; i < 20 && st['fine'] != true; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        st = await LocationShareChannel.status();
      }
    }
    await brain.setAutoPlace(true);
    if (!mounted) return;
    if (st['fine'] != true) {
      toast(context, tr('লোকেশনের অনুমতি দিলে জেলা নিজে বদলাবে'));
    } else if (st['service'] != true) {
      toast(context, tr('ফোনের লোকেশন (GPS) চালু করলে জেলা নিজে বদলাবে'));
    } else {
      toast(context, trf('এখন: {0} — অন্য জেলায় গেলে নিজে বদলাবে', [brain.placeLabel]));
    }
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
                        status = trf('✓ কাজ করছে। AI বলল: {0}', [reply ?? 'ঠিক আছে']);
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
    await showAppSheet<void>(
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
                    tr('ফোনে কোনো বাংলা কণ্ঠ পাওয়া যায়নি। Play Store থেকে “Speech Services by Google” আপডেট করে, ফোনের Settings › ভাষা › Text-to-speech থেকে বাংলা (বাংলাদেশ) কণ্ঠ ডাউনলোড করে নিন।'),
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
                    title: Text(tr('স্বয়ংক্রিয়ভাবে সেরাটি বেছে নিন')),
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
    final done = await showAppSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _NewPinSheet(lock: lock));
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

    Widget linkRow(IconData icon, String title, {Key? key, String? sub, Color? subColor, VoidCallback? onTap, Widget? trailing}) => ListRow(
          key: key,
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: C.muted2, size: 20)),
          title: title,
          subtitle: sub,
          subtitleColor: subColor,
          trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: C.muted),
          onTap: onTap,
        );

    // Each settings page's insides; built afresh whenever the page redraws.
    _parts = {
      'look': () => [
      const LookSettings(),
      const SizedBox(height: 12),
      Panel(
        child: Rows(children: [
          linkRow(Icons.landscape_outlined, tr('হোমের ছবি'), sub: trf('{0} · আবহাওয়া, নড়াচড়া, বিশেষ দিন', [tr(sceneNames[brain.text('home_scene', defaultScene)] ?? sceneNames['auto']!)]), onTap: () => push(const HomePictureScreen())),
        ]),
      ),
      ],
      'remind': () => [
      Panel(
        child: Rows(children: [
          linkRow(Icons.notifications_none_rounded, tr('নোটিফিকেশন প্যানেল'),
              sub: tr('কোনটি কখন আসবে, আগে কী এসেছে'), onTap: () => push(const NoticeScreen())),
          linkRow(Icons.notifications_active_outlined, tr('রিমাইন্ডার ঠিকমতো বাজবে তো?'), sub: tr('ফোনের সেটিং দেখে নিন, ১ মিনিটে পরীক্ষা করুন'), onTap: () => push(const ReminderCheckScreen())),
          switchRow(Icons.alarm_rounded, tr('অ্যালার্মের মতো বাজবে'), tr('বন্ধ না করা পর্যন্ত, ফোন পকেটে থাকলেও শোনা যায়'), brain.alarmInsistent,
              (v) => brain.setAlarmInsistent(v)),
          linkRow(Icons.music_note_outlined, tr('রিমাইন্ডারের রিংটোন'),
              sub: brain.alarmSoundTitle.isEmpty ? tr('ফোনের অ্যালার্ম টোন') : brain.alarmSoundTitle, onTap: _pickRingtone),
        ]),
      ),
      ],
      'assistant': () => [
      const AssistantSection(),
      // The downloaded APK runs AI on the user's own key (the Play app's AI comes with Pro).
      if (!brain.gated) ...[
        const SizedBox(height: 10),
        Panel(
          child: Rows(children: [
            linkRow(Icons.auto_awesome_outlined, tr('AI সহকারী (Claude)'),
                sub: brain.aiOn ? tr('চালু আছে') : tr('বন্ধ · নিজের API key দিয়ে চালু করা যায়'), subColor: brain.aiOn ? C.green : C.muted, onTap: _setAiKey),
            if (brain.aiOn)
              switchRow(Icons.manage_search_rounded, tr('AI আমার তথ্য দেখে উত্তর দিক'), tr('রিমাইন্ডার, কাজ, নোট ও হিসাব দেখে ঠিক উত্তর — পাসওয়ার্ড কখনো না'),
                  brain.aiShareData, (v) => brain.setAiShareData(v)),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      // Owner, 6 Nov: members who speak English were heard as Bangla.
      Panel(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.translate_rounded, color: C.muted2, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('কোন ভাষায় বলবেন'), style: body(15)),
                  Text(tr('মাইক এই ভাষায় শোনে। লিখে দিলে দুই ভাষাই চলে।'), style: body(12, color: C.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            SegTabs<String>(
              key: const Key('voice-lang'),
              items: [('', tr('অ্যাপের ভাষা')), ('bn', 'বাংলা'), ('en', 'English')],
              value: brain.voiceLang,
              onChanged: (v) => brain.setPref('voice_lang', v),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Panel(
        child: Rows(children: [
          switchRow(Icons.volume_up_outlined, tr('উত্তর পড়ে শোনান'), tr('পাসওয়ার্ড কখনো জোরে পড়া হয় না'), brain.speakOn, (v) => brain.setSpeakOn(v)),
          linkRow(Icons.record_voice_over_outlined, tr('কণ্ঠ বেছে নিন'), sub: tr('ফোনে থাকা বাংলা কণ্ঠগুলো শুনে দেখুন'), onTap: _pickVoice),
          switchRow(Icons.record_voice_over_rounded, tr('উত্তরের মাঝে কথা বলে থামানো'), tr('বন্ধ থাকলে অ্যাপ কথা শেষ করে তারপর শোনে — নিজের কথা ভুল করে ধরে না। চালু করলে লম্বা উত্তরের মাঝেই বলতে পারবেন (কিছু ফোনে ভুল ধরতে পারে)'),
              brain.bargeIn, (v) => brain.setBargeIn(v)),
        ]),
      ),
      ],
      'model': () => [
      Panel(
        child: Rows(children: [
          linkRow(Icons.psychology_outlined, tr('কথা বোঝার মডেল'),
                sub: switch (brain.nluModelState) {
                  'ready' => trf('নামানো আছে · {0}', [brain.nluModelVersion]),
                  'wait-wifi' => tr('Wi-Fi পেলে নিজে নামবে (প্রায় ১৪ MB) — মোবাইল ডেটায় নয়'),
                  'builtin' => tr('এখনো চালু হয়নি — অ্যাপ নিজের নিয়মে বুঝছে'),
                  '' => tr('কেন, কীভাবে শিখছে, কী উন্নতি হলো'),
                  _ => tr('নামানো যায়নি — পরে আবার চেষ্টা হবে'),
                },
                onTap: () => push(const NluModelScreen())),
          switchRow(Icons.school_outlined, tr('কথা বোঝা আরও ভালো করতে সাহায্য করুন'),
              tr('কিছু বার্তা নাম সরিয়ে সার্ভারে যায় — পাসওয়ার্ড, মোবাইল নম্বর, কোড বা স্বাস্থ্যের কথা কখনো না; ১৮০ দিন পর নিজে মুছে যায়'),
              brain.nluSamplesOn, (v) => brain.setNluSamplesOn(v)),
          linkRow(Icons.delete_sweep_outlined, tr('আমার পাঠানো বার্তা সার্ভার থেকে মুছে দিন'), sub: tr('কী নিই, কেন নিই — আর মুছে দেওয়া'), onTap: () => push(const NluSamplesScreen())),
        ]),
      ),
      const SizedBox(height: 8),
      Text(improvingNote, key: const Key('nlu-improving'), style: body(12, color: C.muted, height: 1.5)),
      ],
      'safety': () => [
      Panel(
        child: Rows(children: [
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
      ],
    };
    Widget setRow(Key key, IconData icon, Color fg, Color bg, String title, String sub, String part, {Color? subColor}) => ListRow(
          key: key,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: fg, size: 20),
          ),
          title: title,
          subtitle: sub,
          subtitleColor: subColor,
          trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => _SettingsPage(key: Key('settings-$part'), title: title, changed: _changed, parts: () => _parts[part]!())))
              .then((_) => _load()),
        );

    // ব্যবসায়ী মোড (owner, 23 Nov): only what the shop needs.
    if (brain.businessMode) {
      return BizMore(
        settings: [
          ListRow(
            key: const Key('more-set-backup'),
            leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.cloud_upload_outlined, color: C.blue, size: 20)),
            title: tr('ব্যাকআপ'),
            subtitle: brain.driveOn
                ? (brain.lastDrive == null ? tr('Drive-এ এখনো হয়নি') : trf('শেষ ব্যাকআপ {0}', [daysLeftLabel(brain.lastDrive!, now)]))
                : (last == null ? tr('এখনো নেওয়া হয়নি — ফোন হারালে সব হারাবে') : trf('শেষ ব্যাকআপ {0}', [daysLeftLabel(last, now)])),
            subtitleColor: (last == null || backupOld) && !brain.driveOn ? C.orange : null,
            trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
            onTap: () => push(const BackupScreen()),
          ),
          setRow(const Key('more-set-safety'), Icons.lock_outline_rounded, C.teal, C.tealTint, tr('তালা ও নিরাপত্তা'), tr('PIN, আঙুলের ছাপ, নিজে থেকে লক'), 'safety'),
          setRow(const Key('more-set-look'), Icons.palette_outlined, C.green, C.greenTint, tr('চেহারা ও ভাষা'), tr('আলো-আঁধার, রং, বাংলা/English'), 'look'),
        ],
        others: [
          const _PremiumCard(),
          const SizedBox(height: 10),
          Panel(
            child: Rows(children: [
              if (brain.supportWhatsapp.isNotEmpty) SupportWhatsapp(number: brain.supportWhatsapp),
              linkRow(Icons.forum_outlined, tr('সমস্যা বা পরামর্শ দিন'), key: const Key('more-feedback'), sub: brain.feedbackUnread > 0 ? trf('{0}টি নতুন উত্তর', [bnDigits(brain.feedbackUnread)]) : tr('লিখুন, উত্তর এখানেই'), onTap: () => push(const FeedbackScreen())),
              linkRow(Icons.delete_outline_rounded, tr('রিসাইকেল বিন'), key: const Key('more-trash'), sub: trf('{0}টি', [bnDigits(brain.data.trash.length)]), onTap: () => push(const TrashScreen())),
            ]),
          ),
          const SizedBox(height: 18),
          Center(child: Text('My Assistant ${bnDigits(shownVersion)}', style: body(12.5, weight: FontWeight.w600, color: C.muted))),
        ],
      );
    }

    return ListView(
      // Keeps its place when the mode switches (the page is built again).
      key: const PageStorageKey('more-list'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Owner, 17 Nov (third look): who you are and what needs doing on
        // top, Premium as one bright card, the features grouped by what they
        // are for, then settings, your data, help and the app itself.
        TabTitle(tr('আরও')),
        const SizedBox(height: 12),
        // Owner, 18 Nov (after trying it): the profile first again, as before.
        _MeCard(
          onProfile: () => push(_ProfilePage(onName: _setName, onPlace: _setDistrict)),
          backup: brain.driveOn
              ? (brain.has(ProFeature.autoBackup) ? tr('অটো ব্যাকআপ চালু') : trf('ব্যাকআপ {0}', [brain.lastDrive == null ? tr('হয়নি') : daysLeftLabel(brain.lastDrive!, now)]))
              : (last == null ? tr('ব্যাকআপ নেই') : trf('ব্যাকআপ {0}', [daysLeftLabel(last, now)])),
          backupWarn: (last == null || backupOld) && !brain.driveOn,
          onBackup: () => push(const BackupScreen()),
        ),
        const SizedBox(height: 12),
        const _PremiumCard(),
        const _GroupedTools(),
        SectionTitle(tr('সেটিংস')),
        Panel(
          child: Rows(children: [
            setRow(const Key('more-set-look'), Icons.palette_outlined, C.green, C.greenTint, tr('থিম ও ভাষা'), tr('আলো-আঁধার, রং, ভাষা, লেখার মাপ'), 'look'),
            setRow(const Key('more-set-remind'), Icons.notifications_none_rounded, C.ochre, C.ochreTint, tr('রিমাইন্ডার ও নোটিফিকেশন'), tr('ঠিকমতো বাজবে কিনা, রিংটোন'), 'remind'),
            setRow(const Key('more-set-assistant'), Icons.mic_none_rounded, C.blue, C.blueTint, tr('সহকারী ও কণ্ঠ'),
                brain.speakOn ? tr('কণ্ঠে উত্তর চালু · কণ্ঠ বেছে নিন') : tr('কণ্ঠে উত্তর বন্ধ · কণ্ঠ বেছে নিন'), 'assistant'),
            // Owner, 17 Nov: the backup on its own row (inside "তথ্য নিরাপদ রাখা" it was missed).
            ListRow(
              key: const Key('more-set-backup'),
              leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.cloud_upload_outlined, color: C.blue, size: 20)),
              title: tr('ব্যাকআপ'),
              subtitle: brain.driveOn
                  ? (brain.has(ProFeature.autoBackup)
                      ? trf('{0} · Drive-এ অটো ব্যাকআপ চালু', [brain.googleEmail])
                      : trf('{0} · শেষ Drive ব্যাকআপ {1}', [brain.googleEmail, brain.lastDrive == null ? tr('হয়নি') : daysLeftLabel(brain.lastDrive!, now)]))
                  : (last == null ? tr('এখনো নেওয়া হয়নি — ফোন হারালে সব হারাবে') : trf('শেষ ব্যাকআপ {0}', [daysLeftLabel(last, now)])),
              subtitleColor: (last == null || backupOld) && !brain.driveOn ? C.orange : null,
              trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
              onTap: () => push(const BackupScreen()),
            ),
            setRow(const Key('more-set-safety'), Icons.shield_outlined, C.teal, C.tealTint, tr('তালা ও নিরাপত্তা'), tr('PIN, আঙুলের ছাপ, নিজে থেকে লক'), 'safety'),
          ]),
        ),
        // Owner, 18 Nov: these take the data out (and back from the bin) — not "your data".
        SectionTitle(tr('তথ্য এক্সপোর্ট ও রিসাইকেল বিন')),
        Row(children: [
          Expanded(child: _MiniTile(key: const Key('more-pdf'), icon: Icons.picture_as_pdf_outlined, label: tr('সব PDF-এ'), badge: brain.has(ProFeature.pdf) ? null : const ProMark(), onTap: () => exportEverything(context))),
          const SizedBox(width: 10),
          Expanded(child: _MiniTile(key: const Key('more-csv'), icon: Icons.table_view_outlined, label: tr('ধার-দেনা CSV'), onTap: _csv)),
          const SizedBox(width: 10),
          Expanded(
              child: _MiniTile(
                  key: const Key('more-trash'),
                  icon: Icons.delete_outline_rounded,
                  label: tr('রিসাইকেল বিন'),
                  count: brain.data.trash.length,
                  onTap: () => push(const TrashScreen()))),
        ]),
        SectionTitle(tr('সাহায্য ও যোগাযোগ')),
        Panel(
          child: Rows(children: [
            // Owner, 17 Nov: WhatsApp support; the number is set on the website (none in the app).
            if (brain.supportWhatsapp.isNotEmpty) SupportWhatsapp(number: brain.supportWhatsapp),
            ListRow(
              key: const Key('more-feedback'),
              leading: Badge(
                  isLabelVisible: brain.feedbackUnread > 0,
                  smallSize: 10,
                  child: Container(width: 38, height: 38, decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.forum_outlined, color: C.muted2, size: 20))),
              title: tr('সমস্যা বা পরামর্শ দিন'),
              subtitle: brain.feedbackUnread > 0 ? trf('{0}টি নতুন উত্তর', [bnDigits(brain.feedbackUnread)]) : tr('লিখুন, উত্তর এখানেই'),
              subtitleColor: brain.feedbackUnread > 0 ? C.greenDark : null,
              trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
              onTap: () => push(const FeedbackScreen()),
            ),
          ]),
        ),
        SectionTitle(tr('অ্যাপ সম্পর্কে')),
        Panel(
          child: Rows(children: [
            // Owner, 18 Nov: what the app has belongs with the app, not with help.
            linkRow(Icons.lightbulb_outline_rounded, tr('কী কী করা যায়'), key: const Key('more-help'), sub: tr('সব সুবিধা, মাইকে কী বলবেন'), onTap: () => push(const HelpScreen())),
            // Owner, 17 Nov: how the app understands speech is not a setting.
            linkRow(Icons.psychology_outlined, tr('কথা বোঝা'),
                key: const Key('more-set-model'),
                sub: switch (brain.nluModelState) {
                  'ready' => trf('নামানো আছে · {0}', [brain.nluModelVersion]),
                  'wait-wifi' => tr('Wi-Fi পেলে নিজে নামবে (প্রায় ১৪ MB)'),
                  'builtin' => tr('এখনো চালু হয়নি — অ্যাপ নিজের নিয়মে বুঝছে'),
                  '' => tr('কীভাবে শিখছে, কী উন্নতি হলো'),
                  _ => tr('নামানো যায়নি — পরে আবার চেষ্টা হবে'),
                },
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => _SettingsPage(key: const Key('settings-model'), title: tr('কথা বোঝা'), changed: _changed, parts: () => _parts['model']!())))
                    .then((_) => _load())),
            linkRow(Icons.bug_report_outlined, tr('সমস্যা খোঁজার লগ'),
                sub: Trace.enabled ? tr('চালু — মাইক কী শুনল, কী বুঝল') : tr('বন্ধ — ভয়েসে সমস্যা হলে চালু করুন'), onTap: () => push(const TraceScreen())),
            // কোম্পানির পরিসংখ্যান (owner, 24 Nov): on unless turned off here.
            Semantics(
              container: true,
              child: KeyedSubtree(
                key: const Key('more-stats'),
                child: switchRow(Icons.insights_outlined, tr('ব্যবহারের হিসাব পাঠান'),
                    tr('কোন অংশ খোলা হয়, অ্যাপ খুলতে কত সময় — আপনার লেখা, টাকার অঙ্ক, স্বাস্থ্য বা লোকেশন যায় না'), brain.statsOn, (v) => brain.setStatsOn(v)),
              ),
            ),
            if (proTestSwitch)
              switchRow(Icons.science_outlined, tr('পরীক্ষা: প্রিমিয়াম চালু'), tr('শুধু প্রিভিউতে — ফ্রি আর প্রিমিয়াম ইউজার কী দেখবে দুটোই দেখে নিন'), brain.pro, (v) => brain.setProForTest(v)),
            linkRow(Icons.privacy_tip_outlined, tr('প্রাইভেসি পলিসি'), sub: tr('কোন তথ্য ফোনেই থাকে, কোনটা কেন সার্ভারে যায়'),
                onTap: () => brain.services.launcher.openUrl(Uri.parse(privacyPage)), trailing: Icon(Icons.open_in_new_rounded, color: C.muted)),
            if (realAds && brain.showAds)
              FutureBuilder<bool>(
                future: Ads.privacyChoiceNeeded(),
                builder: (_, s) => s.data == true
                    ? linkRow(Icons.ads_click_outlined, tr('বিজ্ঞাপনের গোপনীয়তা'), sub: tr('Google বিজ্ঞাপনের জন্য আপনার সম্মতি বদলান'), onTap: Ads.changePrivacyChoice)
                    : const SizedBox.shrink(),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        // The app's name and version, small, at the very end (tap: licences).
        Center(
          child: InkWell(
            key: const Key('more-version'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => showLicensePage(context: context, applicationName: 'My Assistant', applicationVersion: shownVersion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(children: [
                Text('My Assistant ${bnDigits(shownVersion)}${previewEdition ? ' · ${tr('প্লে স্টোর প্রিভিউ')}' : ''}', style: body(12.5, weight: FontWeight.w600, color: C.muted)),
                Text(tr('আপনার তথ্য আপনার ফোনেই · লাইসেন্স'), style: body(11.5, color: C.muted)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// One settings page opened from আরও (owner, 3 Nov): its rows come from
/// আরও itself, so they work exactly as they did there.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({super.key, required this.title, required this.changed, required this.parts});
  final String title;
  final ValueNotifier<int> changed;
  final List<Widget> Function() parts;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: title),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([changed, BrainScope.read(context)]),
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [const SizedBox(height: 4), ...parts()],
                ),
              ),
            ),
          ]),
        ),
      );
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
      final bytes = await Backup.export(brain.data, pass, files: await brain.backupFiles(), settings: await brain.backupSettings(), iterations: Backup.passwordIterations);
      final now = brain.services.now();
      final name = 'my-assistant-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.dbrain';
      if (toPhone) {
        final saved = await brain.services.files.saveFile(bytes, name);
        if (!saved) {
          if (mounted) toast(context, tr('রাখা হয়নি'));
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

  Future<void> _restore() => restoreFromPhoneFile(context, busy: (v) {
        if (mounted) setState(() => _busy = v);
      });

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
    final file = _lastBackup == null ? null : DateTime.tryParse(_lastBackup!);
    // The newer of the file backup and the Google Drive one (13 Nov: with
    // Drive backing up, the page still said "no backup taken").
    final drive = brain.lastDrive;
    final last = file == null ? drive : (drive != null && drive.isAfter(file) ? drive : file);
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
              _step(tr('২'), tr('নিরাপদ জায়গায় রাখুন'), tr('“শেয়ার” চেপে Google Drive বা নিজের হোয়াটসঅ্যাপে পাঠিয়ে রাখুন — ফোন হারালেও ফাইল থাকবে।'), const []),
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


/// "হোয়াটসঅ্যাপে কথা বলুন": opens a chat with our support number, with a
/// short greeting the member can change before sending. Nothing about the
/// member goes with it — only the app's version.
class SupportWhatsapp extends StatelessWidget {
  const SupportWhatsapp({super.key, required this.number});
  final String number;

  static const _waGreen = Color(0xFF1DA851);

  /// 01712345678 → ০১৭১২-৩৪৫৬৭৮
  static String shown(String n) {
    final d = n.replaceAll(RegExp(r'[^0-9]'), '');
    final local = d.startsWith('880') && d.length == 13 ? '0${d.substring(3)}' : d;
    final s = local.length == 11 ? '${local.substring(0, 5)}-${local.substring(5)}' : local;
    return bnDigits(s);
  }

  Future<void> _open(BuildContext context) async {
    final brain = BrainScope.read(context);
    final text = trf('আসসালামু আলাইকুম, My Assistant অ্যাপ নিয়ে জানতে চাই। (অ্যাপ {0})', [bnDigits(shownVersion)]);
    final ok = await brain.services.launcher.open(Via.whatsapp, number, text: text);
    if (!ok && context.mounted) toast(context, tr('হোয়াটসঅ্যাপ খোলা গেল না'));
  }

  @override
  Widget build(BuildContext context) => ListRow(
        key: const Key('more-whatsapp'),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: _waGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.chat_rounded, color: _waGreen, size: 21),
        ),
        title: tr('হোয়াটসঅ্যাপে কথা বলুন'),
        subtitle: shown(number),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _waGreen, borderRadius: BorderRadius.circular(20)),
          child: Text(tr('মেসেজ'), style: body(13, weight: FontWeight.w700, color: Colors.white)),
        ),
        onTap: () => _open(context),
      );
}

/// "কেন প্রিমিয়াম নেবেন": every reason from [proInfo] in the owner's order;
/// a tap shows what Premium gives and what the free app has instead.
class WhyPremium extends StatefulWidget {
  const WhyPremium({super.key, this.showTitle = true});
  final bool showTitle;
  @override
  State<WhyPremium> createState() => _WhyPremiumState();
}

class _WhyPremiumState extends State<WhyPremium> {
  ProFeature? _open;

  static const _icons = <ProFeature, IconData>{
    ProFeature.business: Icons.storefront_outlined,
    ProFeature.reminders: Icons.notifications_active_outlined,
    ProFeature.docs: Icons.folder_outlined,
    ProFeature.projects: Icons.account_balance_wallet_outlined,
    ProFeature.will: Icons.history_edu_outlined,
    ProFeature.familyHealth: Icons.monitor_heart_outlined,
    ProFeature.vault: Icons.lock_outline_rounded,
    ProFeature.family: Icons.family_restroom_rounded,
    ProFeature.autoBackup: Icons.cloud_sync_outlined,
    ProFeature.pdf: Icons.picture_as_pdf_outlined,
    ProFeature.ai: Icons.auto_awesome_outlined,
    ProFeature.noAds: Icons.block_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final has = brain.gated && brain.pro;
    final items = [for (final e in proInfo.entries) if (!e.value.later) e];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.showTitle) SectionTitle(has ? tr('প্রিমিয়ামে যা পাচ্ছেন') : tr('কেন প্রিমিয়াম নেবেন')),
      Panel(
        key: const Key('more-why-pro'),
        child: Column(children: [
          for (final (i, e) in items.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 62, color: C.border),
            InkWell(
              key: Key('why-${e.key.name}'),
              onTap: () => setState(() => _open = _open == e.key ? null : e.key),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: C.ochreTint, borderRadius: BorderRadius.circular(11)),
                      child: Icon(_icons[e.key] ?? Icons.star_outline_rounded, color: C.ochre, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tr(e.value.title), style: body(14.5, weight: FontWeight.w600))),
                    AnimatedRotation(
                      turns: _open == e.key ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.expand_more_rounded, color: C.muted),
                    ),
                  ]),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.topCenter,
                    child: _open != e.key
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(48, 8, 6, 2),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr(e.value.what), style: body(13.5, height: 1.45)),
                              if (e.value.free.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(trf('ফ্রি সংস্করণে: {0}', [tr(e.value.free)]), style: body(12.5, color: C.muted, height: 1.4)),
                              ],
                            ]),
                          ),
                  ),
                ]),
              ),
            ),
          ],
          if (!has) ...[
            Divider(height: 1, color: C.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr('আপনার রাখা কোনো তথ্য কখনো তালাবদ্ধ হবে না — প্রিমিয়াম শেষ হলেও সব দেখা যাবে।'), style: body(12.5, color: C.muted, height: 1.4)),
                const SizedBox(height: 10),
                PrimaryButton(key: const Key('why-pro-open'), label: tr('প্রিমিয়াম দেখুন'), icon: Icons.workspace_premium_outlined, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen()))),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}



class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.onName, required this.onPlace});
  final VoidCallback onName;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: tr('প্রোফাইল')),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [ProfileCard(onName: onName, onPlace: onPlace)])),
          ]),
        ),
      );
}


class _WhyPremiumPage extends StatelessWidget {
  const _WhyPremiumPage();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: brain.gated && brain.pro ? tr('প্রিমিয়ামে যা পাচ্ছেন') : tr('কেন প্রিমিয়াম নেবেন')),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: const [WhyPremium(showTitle: false)])),
        ]),
      ),
    );
  }
}


/// You and what needs doing: photo, name, place and blood group (a tap
/// opens the profile), then the backup and the shop switch side by side.
class _MeCard extends StatelessWidget {
  const _MeCard({required this.onProfile, required this.backup, required this.backupWarn, required this.onBackup});
  final VoidCallback onProfile;
  final String backup;
  final bool backupWarn;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final blood = brain.data.emergency.blood;
    Widget chip({required Key key, required IconData icon, required String text, required Color fg, required Color bg, VoidCallback? onTap, Widget? end, int flex = 5}) => Expanded(
          flex: flex,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, end == null ? 10 : 0, 0),
                  child: Row(children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600, color: fg))),
                    if (end != null) end,
                  ]),
                ),
              ),
            ),
          ),
        );
    return Panel(
      child: Column(children: [
        InkWell(
          key: const Key('more-profile'),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          onTap: onProfile,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 10, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Owner, 18 Nov: Premium or free under the photo. Owner, 19 Nov: how
              // long it lasts only on the Premium page, not here.
              Column(mainAxisSize: MainAxisSize.min, children: [
                const UserPhoto(size: 60),
                if (brain.gated) ...[const SizedBox(height: 6), const _PlanTag()],
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(brain.userName.isEmpty ? tr('আপনার নাম দিন') : brain.userName, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(19, weight: 700, color: brain.userName.isEmpty ? C.muted : C.ink)),
                  // Owner, 19 Nov: how full the profile is, in place of the plan's days.
                  const SizedBox(height: 6),
                  _Fullness(onProfile: onProfile),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            _Fact(key: const Key('more-place'), icon: Icons.location_on_outlined, fg: C.blue, bg: C.blueTint, label: tr('লোকেশন'), value: brain.placeLabel.isEmpty ? tr('জেলা দিন') : brain.placeLabel, empty: brain.placeLabel.isEmpty, onTap: onProfile),
            const SizedBox(width: 8),
            _Fact(key: const Key('more-blood'), icon: Icons.water_drop_outlined, fg: C.red, bg: C.roseTint, label: tr('রক্তের গ্রুপ'), value: blood.isEmpty ? tr('দিন') : blood, empty: blood.isEmpty, onTap: onProfile),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            chip(
                key: const Key('more-backup-chip'),
                icon: backupWarn ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                text: backup,
                fg: backupWarn ? C.orange : C.greenDark,
                bg: backupWarn ? C.orangeTint : C.greenTint,
                onTap: onBackup),
            const SizedBox(width: 8),
            chip(
              key: const Key('more-business-chip'),
              icon: Icons.storefront_outlined,
              text: tr('ব্যবসায়ী মোড'),
              flex: 6,
              fg: brain.businessMode ? C.greenDark : C.muted2,
              bg: C.surface2,
              onTap: () => brain.setPref('business_mode', !brain.businessMode),
              end: Transform.scale(
                scale: 0.72,
                child: Switch(key: const Key('more-business'), value: brain.businessMode, onChanged: (v) => brain.setPref('business_mode', v)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// "প্রিমিয়াম", "ট্রায়াল" or "ফ্রি" under the photo; a tap opens Premium.
class _PlanTag extends StatelessWidget {
  const _PlanTag();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final pro = brain.pro;
    final label = !pro ? tr('ফ্রি') : (brain.proKind == 'trial' ? tr('ট্রায়াল') : tr('প্রিমিয়াম'));
    final fg = pro ? C.ochre : C.muted2;
    return Material(
      color: pro ? C.ochreTint : C.chip,
      shape: StadiumBorder(side: BorderSide(color: fg.withValues(alpha: 0.35))),
      child: InkWell(
        key: const Key('plan-badge'),
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (pro) ...[Icon(Icons.workspace_premium_rounded, size: 13, color: fg), const SizedBox(width: 3)],
            Text(label, style: body(11.5, weight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// One part of the profile: its name, whether it is given, and what to tap
/// to give it (the hint under the name says "এরপর: …").
typedef _Part = ({String label, String todo, bool done, Future<void> Function(BuildContext) give});

/// The parts counted for "প্রোফাইল ৮০%": photo, name, mobile, place, blood
/// group, an heir (family), and in the website edition an emergency contact.
List<_Part> _profileParts(Brain brain, VoidCallback onProfile) {
  Future<void> profile(BuildContext _) async => onProfile();
  return [
    (label: tr('ছবি'), todo: tr('ছবি দিন'), done: brain.photo != null, give: changePhoto),
    (label: tr('নাম'), todo: tr('নাম দিন'), done: brain.userName.isNotEmpty, give: profile),
    (label: tr('মোবাইল নম্বর'), todo: tr('মোবাইল নম্বর দিন'), done: brain.userPhone.isNotEmpty, give: editUserPhone),
    (label: tr('লোকেশন'), todo: tr('জেলা দিন'), done: brain.placeLabel.isNotEmpty, give: profile),
    (label: tr('রক্তের গ্রুপ'), todo: tr('রক্তের গ্রুপ দিন'), done: brain.data.emergency.blood.isNotEmpty, give: pickBloodGroup),
    if (!medicalOff) (label: tr('জরুরি যোগাযোগ'), todo: tr('জরুরি যোগাযোগ দিন'), done: brain.data.emergency.contacts.any((c) => c.trim().isNotEmpty), give: profile),
    (
      label: tr('উত্তরাধিকারী'),
      todo: tr('উত্তরাধিকারী বাছুন'),
      done: brain.family.links.any((l) => l.active && l.theyAreMyHeir),
      give: (c) => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const FamilyScreen())),
    ),
  ];
}

/// Under the name: a thin bar, "প্রোফাইল ৮০%" and the next part to give
/// (a tap gives it); "প্রোফাইল সম্পূর্ণ" when all are there.
class _Fullness extends StatelessWidget {
  const _Fullness({required this.onProfile});
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final parts = _profileParts(brain, onProfile);
    final done = parts.where((p) => p.done).length;
    final pct = (done * 100 / parts.length).round();
    final next = parts.where((p) => !p.done).firstOrNull;
    return Column(key: const Key('more-fullness'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(next == null ? tr('প্রোফাইল সম্পূর্ণ') : trf('প্রোফাইল {0}%', [bnDigits(pct)]), style: body(12.5, weight: FontWeight.w600, color: next == null ? C.green : C.muted2)),
        if (next == null) ...[const SizedBox(width: 4), Icon(Icons.check_circle_outline_rounded, size: 15, color: C.green)],
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: done / parts.length, minHeight: 5, backgroundColor: C.line2, valueColor: AlwaysStoppedAnimation(C.green)),
          ),
        ),
      ]),
      if (next != null)
        InkWell(
          key: const Key('more-fullness-next'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => next.give(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(tr('এরপর: '), style: body(12.5, color: C.muted)),
              Flexible(child: Text(next.todo, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600, color: C.green))),
              Icon(Icons.chevron_right_rounded, size: 16, color: C.green),
            ]),
          ),
        ),
    ]);
  }
}

/// One fact about the user in the profile card: the place or the blood group.
class _Fact extends StatelessWidget {
  const _Fact({super.key, required this.icon, required this.fg, required this.bg, required this.label, required this.value, required this.empty, required this.onTap});
  final IconData icon;
  final Color fg;
  final Color bg;
  final String label;
  final String value;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: C.surface2,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 20, color: fg)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w700, color: empty ? C.muted2 : C.ink)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Premium as one card that stands out (flat colour, no gradient): three
/// reasons at a glance, a tap opens all of them.
class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final has = brain.gated && brain.pro;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _WhyPremiumPage()));
    if (has) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Panel(
          child: ListRow(
            key: const Key('more-why-pro'),
            leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: C.ochreTint, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.workspace_premium_rounded, color: C.ochre, size: 21)),
            title: tr('প্রিমিয়াম চালু আছে'),
            subtitle: tr('যা যা পাচ্ছেন দেখুন'),
            trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
            onTap: open,
          ),
        ),
      );
    }
    final n = [for (final e in proInfo.values) if (!e.later) e].length;
    Widget reason(IconData i, String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 15, color: C.ochre),
            const SizedBox(width: 4),
            Text(t, style: body(12.5, weight: FontWeight.w600, color: C.ink)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: C.ochreTint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('more-why-pro'),
          borderRadius: BorderRadius.circular(18),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.workspace_premium_rounded, color: C.ochre, size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('কেন প্রিমিয়াম নেবেন'), style: display(17, weight: 700))),
                Text(trf('{0}টি কারণ', [bnDigits(n)]), style: body(13, weight: FontWeight.w600, color: C.ochre)),
                Icon(Icons.chevron_right_rounded, color: C.ochre),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                reason(Icons.block_outlined, tr('বিজ্ঞাপন নেই')),
                reason(Icons.cloud_sync_outlined, tr('অটো ব্যাকআপ')),
                reason(Icons.notifications_active_outlined, tr('যত খুশি রিমাইন্ডার')),
                reason(Icons.auto_awesome_outlined, tr('AI উত্তর')),
                reason(Icons.picture_as_pdf_outlined, tr('PDF ডাউনলোড')),
                reason(Icons.folder_outlined, tr('যত খুশি ডকুমেন্ট')),
                reason(Icons.lock_outline_rounded, tr('যত খুশি পাসওয়ার্ড')),
                reason(Icons.family_restroom_rounded, tr('উত্তরাধিকারী')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// সব সুবিধা in groups, by what they are for (the bottom bar's own left out).
class _GroupedTools extends StatelessWidget {
  const _GroupedTools();

  static const _groups = <(String, List<String>)>[
    ('প্রতিদিন', ['reminders', 'alarms', 'calendar', 'notes']),
    ('নিরাপদে রাখা', ['docs', 'vault', 'contacts']),
    ('পরিবার ও স্বাস্থ্য', ['family', 'health', 'medicines', 'med_reminder', 'blood']),
    ('মুসলিম টাইম ও যাকাত', ['compass', 'zakat']),
  ];

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final x in appTools(context)) x.$1: x};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr('সব সুবিধা')),
      AppCard(
        key: const Key('more-tools'),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Column(children: [
          for (final (i, (title, keys)) in _groups.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 6, endIndent: 6, color: C.line2),
            // The group's name on the left, its tools on the right: one row each.
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(width: 62, child: Padding(padding: const EdgeInsets.only(left: 6), child: Text(tr(title), style: body(12, weight: FontWeight.w600, color: C.muted, height: 1.25)))),
              for (final k in [...keys.where(byKey.containsKey).take(4)]) Expanded(child: SizedBox(height: 82, child: ToolTile(key: Key('tool-$k'), icon: byKey[k]!.$3, label: byKey[k]!.$2, onTap: byKey[k]!.$4))),
              for (var j = keys.where(byKey.containsKey).take(4).length; j < 4; j++) const Expanded(child: SizedBox()),
            ]),
          ],
        ]),
      ),
    ]);
  }
}

/// A small square: icon over a short name (your data).
class _MiniTile extends StatelessWidget {
  const _MiniTile({super.key, required this.icon, required this.label, required this.onTap, this.badge, this.count = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? badge;
  final int count;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: C.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 78,
            child: Stack(children: [
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Badge(isLabelVisible: count > 0, label: Text(bnDigits(count)), child: Icon(icon, color: C.muted2, size: 24)),
                  const SizedBox(height: 6),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w600)),
                ]),
              ),
              if (badge != null) Positioned(top: 6, right: 6, child: badge!),
            ]),
          ),
        ),
      );
}
