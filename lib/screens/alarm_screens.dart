import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../services/notifications.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// The big page a ringing reminder opens (also over the lock screen).
/// Shows only the title and time — nothing private.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.info});
  final NoticeInfo info;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  bool _closing = false;

  Reminder? get _reminder => BrainScope.read(context).reminderById(widget.info.reminderId);

  String get _title {
    final t = widget.info.title.replaceFirst('আগাম মনে করানো: ', '').trim();
    return t.isNotEmpty ? t : (_reminder?.title ?? 'রিমাইন্ডার');
  }

  Future<void> _close({Duration? snooze, bool stop = false}) async {
    if (_closing) return;
    _closing = true;
    final brain = BrainScope.read(context);
    final n = brain.services.notifier;
    await n.stopRinging(widget.info.reminderId);
    if (snooze != null) {
      await n.ringOnce(widget.info.reminderId, _title, widget.info.body, snooze);
    }
    if (stop) await brain.deleteReminder(widget.info.reminderId);
    await n.showOverLock(false);
    if (!mounted) return;
    final msg = stop
        ? 'আর বাজবে না'
        : snooze != null
            ? '${bnDigits(snooze.inMinutes >= 60 ? snooze.inHours : snooze.inMinutes)} ${snooze.inMinutes >= 60 ? 'ঘণ্টা' : 'মিনিট'} পরে আবার মনে করাব'
            : null;
    Navigator.of(context).pop();
    if (msg != null) toast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reminder;
    final now = BrainScope.of(context).services.now();
    final repeating = widget.info.repeating || (r?.repeat.isInterval ?? false);
    final when = r == null ? bnTime(now.hour, now.minute) : (repeating ? r.repeat.label : bnTime(r.hour, r.minute));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: C.alarm,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: Column(children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: Color(0xFF145A49), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_outlined, size: 42, color: C.mint),
              ),
              const SizedBox(height: 24),
              Text('রিমাইন্ডার · $when', style: body(16, color: C.mint)),
              const SizedBox(height: 6),
              Text(_title, textAlign: TextAlign.center, style: display(32, weight: 700, color: Colors.white)),
              if ((r?.note ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r!.note.trim(), textAlign: TextAlign.center, style: body(16, color: const Color(0xFFCDE7DE))),
              ],
              const Spacer(),
              if (repeating) ...[
                _AlarmButton(label: 'ঠিক আছে', onTap: () => _close()),
                const SizedBox(height: 12),
                _AlarmButton(label: 'আর বাজাবে না', primary: true, onTap: () => _close(stop: true)),
              ] else ...[
                Text('পরে মনে করাও', style: body(14, color: const Color(0xFFCDE7DE))),
                const SizedBox(height: 10),
                Row(children: [
                  for (final (d, label) in const [
                    (Duration(minutes: 5), '৫ মিনিট'),
                    (Duration(minutes: 10), '১০ মিনিট'),
                    (Duration(hours: 1), '১ ঘণ্টা'),
                  ]) ...[
                    if (d != const Duration(minutes: 5)) const SizedBox(width: 10),
                    Expanded(child: _AlarmButton(label: label, onTap: () => _close(snooze: d))),
                  ],
                ]),
                const SizedBox(height: 12),
                _AlarmButton(label: 'হয়ে গেছে, বন্ধ করো', primary: true, onTap: () => _close()),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _AlarmButton extends StatelessWidget {
  const _AlarmButton({required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: primary ? 58 : 50,
        width: double.infinity,
        child: Material(
          color: primary ? Colors.white : const Color(0xFF10493C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: primary ? BorderSide.none : const BorderSide(color: Color(0xFF2E6F5E)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: Text(label, style: body(primary ? 18 : 15, weight: primary ? FontWeight.w700 : FontWeight.w500, color: primary ? C.alarm : Colors.white)),
            ),
          ),
        ),
      );
}

/// "রিমাইন্ডার ঠিকমতো বাজবে তো?" — checks each thing that can stop a
/// reminder on this phone, with a button to fix it, and a 1-minute test.
class ReminderCheckScreen extends StatefulWidget {
  const ReminderCheckScreen({super.key});

  @override
  State<ReminderCheckScreen> createState() => _ReminderCheckScreenState();
}

class _ReminderCheckScreenState extends State<ReminderCheckScreen> with WidgetsBindingObserver {
  AlarmHealth? _h;
  bool _autostartDone = false;

  /// The battery page was opened; when back, check it took.
  bool _batteryTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the phone's settings: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final brain = BrainScope.read(context);
    final h = await brain.services.notifier.health();
    final done = (await brain.services.lock.keys.read('autostart_done')) == 'true';
    await brain.refreshNotices();
    if (!mounted) return;
    setState(() {
      _h = h;
      _autostartDone = done;
    });
    if (_batteryTried && !h.batteryFree) {
      _batteryTried = false;
      await _batteryHelp();
    }
  }

  /// Some phones (Xiaomi, Oppo, Vivo, Realme…) keep their own battery switch
  /// that Android never reports, so the tick can't turn green by itself.
  Future<void> _batteryHelp() async {
    final brain = BrainScope.read(context);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ব্যাটারি সেটিং', style: display(20)),
        content: Text(
          'ফোন এখনো জানাচ্ছে না যে অনুমতি দেওয়া হয়েছে। অনেক ফোনে অ্যাপের নিজের পাতায় যেতে হয়:\n\n'
          'App info › Battery (বা Battery saver) › “No restrictions / Unrestricted / সীমাবদ্ধতা নেই” বেছে নিন।\n\n'
          'করে থাকলে “করেছি” চাপুন।',
          style: body(15, height: 1.55),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'open'), child: const Text('পাতাটা খুলুন')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'done'), child: const Text('করেছি')),
        ],
      ),
    );
    if (r == 'open') {
      _batteryTried = true;
      await brain.services.notifier.openAppSettings();
    } else if (r == 'done') {
      await brain.confirmBattery();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final n = brain.services.notifier;
    final h = _h;
    final brandName = switch (h?.brand ?? '') {
      'xiaomi' || 'redmi' || 'poco' => 'Xiaomi / Redmi',
      'oppo' => 'Oppo',
      'realme' => 'Realme',
      'vivo' || 'iqoo' => 'Vivo',
      'samsung' => 'Samsung',
      'huawei' || 'honor' => 'Huawei / Honor',
      'infinix' || 'tecno' || 'itel' => 'Infinix / Tecno',
      'oneplus' => 'OnePlus',
      final b => b.isEmpty ? 'এই ফোন' : b,
    };
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'রিমাইন্ডার ঠিকমতো বাজবে তো?'),
          Expanded(
            child: h == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                    Text(
                      'কিছু ফোন ব্যাটারি বাঁচাতে অ্যাপের অ্যালার্ম থামিয়ে দেয়। নিচের সব কটিতে সবুজ টিক থাকলে রিমাইন্ডার ঠিক সময়ে বাজবে — ফোন লক থাকলেও।',
                      style: body(14, color: C.muted, height: 1.55),
                    ),
                    const SizedBox(height: 14),
                    Panel(
                      child: Rows(children: [
                        _CheckRow(
                          ok: h.notificationsOn,
                          title: 'নোটিফিকেশন চালু',
                          sub: h.notificationsOn ? 'চালু আছে' : 'বন্ধ — রিমাইন্ডার দেখাতে পারবে না',
                          fix: 'চালু করুন',
                          onFix: () async {
                            await n.requestPermission();
                            final again = await n.health();
                            if (!again.notificationsOn) await n.openNotificationSettings();
                            await _load();
                          },
                        ),
                        _CheckRow(
                          ok: h.exactOn,
                          title: 'ঠিক মিনিটে বাজানোর অনুমতি',
                          sub: h.exactOn ? 'চালু আছে' : 'বন্ধ — রিমাইন্ডার দেরিতে আসতে পারে',
                          fix: 'চালু করুন',
                          onFix: () async {
                            await n.requestExact();
                            await _load();
                          },
                        ),
                        _CheckRow(
                          ok: h.batteryFree,
                          title: 'ব্যাটারি সেভিং থেকে বাদ',
                          sub: h.batteryFree ? 'বাদ দেওয়া আছে' : 'ফোন অ্যাপটিকে ঘুম পাড়িয়ে রিমাইন্ডার থামাতে পারে',
                          fix: 'বাদ দিন',
                          onFix: () async {
                            _batteryTried = true;
                            await n.fixBattery();
                            // Some phones answer in place, with no return to the app.
                            await Future<void>.delayed(const Duration(seconds: 2));
                            if (mounted) await _load();
                          },
                        ),
                        if (!h.fullScreenOn)
                          _CheckRow(
                            ok: false,
                            title: 'লক স্ক্রিনে বড় করে দেখানো',
                            sub: 'চালু করলে ফোন লক থাকলেও পুরো পর্দায় রিমাইন্ডার আসবে',
                            fix: 'চালু করুন',
                            onFix: n.requestFullScreen,
                          ),
                        if (h.hasAutostart)
                          _CheckRow(
                            ok: _autostartDone,
                            title: '$brandName: অটো-স্টার্ট চালু',
                            sub: _autostartDone
                                ? 'চালু করেছেন'
                                : 'এই ফোনে “Autostart / Auto-launch / Background” থেকে My Assistant চালু করতে হয়, নইলে ফোন বন্ধ-চালুর পর রিমাইন্ডার আসে না',
                            fix: 'খুলুন',
                            onFix: () async {
                              await n.openAutostart();
                              if (!context.mounted) return;
                              final yes = await confirmDialog(context,
                                  title: 'চালু করেছেন?', text: 'খোলা পাতায় My Assistant-এর পাশের সুইচটা চালু করেছেন?', yes: 'হ্যাঁ, করেছি');
                              if (yes) {
                                await brain.services.lock.keys.write('autostart_done', 'true');
                                await _load();
                              }
                            },
                          ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: '১ মিনিট পরে পরীক্ষা করুন',
                      icon: Icons.alarm_rounded,
                      color: C.ink,
                      onPressed: () async {
                        await n.requestPermission();
                        await n.ringOnce('test', 'পরীক্ষা: রিমাইন্ডার কাজ করছে ✓', 'এভাবেই সময়মতো বাজবে', const Duration(minutes: 1));
                        if (context.mounted) {
                          toast(context, '১ মিনিট পরে বাজবে। এখন ফোন লক করে রেখে দিন।');
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('ফোন লক করে রাখুন। ১ মিনিট পরে বাজলে সব ঠিক আছে।', textAlign: TextAlign.center, style: body(13, color: C.muted)),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.ok, required this.title, required this.sub, required this.fix, required this.onFix});
  final bool ok;
  final String title;
  final String sub;
  final String fix;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? C.green : C.orange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: body(15, weight: FontWeight.w600)),
              Text(sub, style: body(13, color: ok ? C.muted : C.orangeDark, height: 1.45)),
            ]),
          ),
          if (!ok) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onFix,
              style: FilledButton.styleFrom(backgroundColor: C.green, minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
              child: Text(fix, style: body(14, weight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ]),
      );
}

/// After a reminder is saved: if this phone may block it, offer the check.
Future<void> checkAlarmsAfterSave(BuildContext context) async {
  final brain = BrainScope.read(context);
  final h = await brain.services.notifier.health();
  final done = (await brain.services.lock.keys.read('autostart_done')) == 'true';
  if (h.allGood && (!h.hasAutostart || done)) return;
  if (!context.mounted) return;
  final go = await confirmDialog(
    context,
    title: 'রিমাইন্ডার যেন বাজে',
    text: 'এই ফোনের কিছু সেটিং রিমাইন্ডার থামিয়ে দিতে পারে। এক মিনিটে ঠিক করে নেবেন?',
    yes: 'ঠিক করি',
  );
  if (go && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderCheckScreen()));
  }
}
