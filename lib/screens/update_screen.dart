/// A newer version on Google Play (owner, 31 Oct): when the app is opened and
/// Play has a newer version, this page says so and, with one tap, Google
/// Play's own update runs inside the app (MainActivity › PlayUpdate.kt). "পরে"
/// hides it for a day for that version. The downloaded APK never sees it (Play
/// answers "none" for an app it did not install).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';

class AppUpdate {
  static const channel = MethodChannel('my_assistant/update');

  /// What Play says, or null (no Play, no network, a test).
  static Future<Map<String, Object?>?> check() async {
    try {
      return await channel.invokeMapMethod<String, Object?>('check');
    } catch (_) {
      return null;
    }
  }

  /// "ok", "cancelled", "failed" or "none".
  static Future<String> start() async {
    try {
      return await channel.invokeMethod<String>('start') ?? 'failed';
    } catch (_) {
      return 'failed';
    }
  }
}

const _laterKey = 'update_later';

/// Asked once per opening of the app (from the home shell).
bool _askedThisRun = false;

/// For tests: ask again as if the app were opened anew.
void resetUpdateOffer() => _askedThisRun = false;

/// Shows the update page when Play has a newer version (not more than once
/// per opening, and not for a day after "পরে" for the same version). An
/// update Play had started and the app left resumes at once.
Future<void> offerUpdate(BuildContext context) async {
  if (_askedThisRun) return;
  _askedThisRun = true;
  final brain = BrainScope.read(context);
  final info = await AppUpdate.check();
  if (info == null || !context.mounted) return;
  if (info['inProgress'] == true) {
    await AppUpdate.start();
    return;
  }
  if (info['available'] != true) return;
  final code = '${info['versionCode'] ?? ''}';
  final keys = brain.services.lock.keys;
  try {
    final later = (await keys.read(_laterKey) ?? '').split('|');
    final at = later.length == 2 ? DateTime.tryParse(later[1]) : null;
    if (later.first == code && at != null && brain.services.now().difference(at) < const Duration(hours: 24)) return;
  } catch (_) {}
  if (!context.mounted) return;
  final later = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const UpdateScreen(), fullscreenDialog: true));
  if (later == true) {
    try {
      await keys.write(_laterKey, '$code|${brain.services.now().toIso8601String()}');
    } catch (_) {}
  }
}

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _busy = false;
  String _note = '';

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _note = '';
    });
    final r = await AppUpdate.start();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = switch (r) {
        'ok' => tr('আপডেট হচ্ছে… শেষ হলে অ্যাপ নিজেই আবার খুলবে।'),
        'cancelled' => tr('আপডেট বাতিল হয়েছে। চাইলে আবার চাপুন।'),
        'none' => tr('এখন আর কোনো আপডেট নেই।'),
        _ => tr('আপডেট শুরু করা গেল না। Play Store থেকে My Assistant খুলে আপডেট করুন।'),
      };
    });
    if (r == 'none') Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.ground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(26)),
                    child: Icon(Icons.system_update_rounded, size: 44, color: C.green),
                  ),
                ),
                const SizedBox(height: 22),
                Text(tr('নতুন সংস্করণ এসেছে'), textAlign: TextAlign.center, style: display(26, weight: 700, height: 1.25)),
                const SizedBox(height: 10),
                Text(
                  tr('My Assistant-এর নতুন সংস্করণ Google Play-তে এসেছে। আপডেট করলে নতুন সুবিধা আর ঠিক করা ভুলগুলো পাবেন। আপনার সব তথ্য ফোনে আগের মতোই থাকবে।'),
                  textAlign: TextAlign.center,
                  style: body(15.5, color: C.muted, height: 1.55),
                ),
                if (_note.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_note, key: const Key('update-note'), textAlign: TextAlign.center, style: body(14, color: C.green, height: 1.5)),
                ],
                const Spacer(),
                FilledButton(
                  key: const Key('update-now'),
                  onPressed: _busy ? null : _update,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
                  child: _busy
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: C.onAccent))
                      : Text(tr('এখন আপডেট করুন'), style: body(16.5, weight: FontWeight.w600, color: C.onAccent)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('update-later'),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(tr('পরে'), style: body(15.5, color: C.muted)),
                ),
              ],
            ),
          ),
        ),
      );
}
