import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'google_backup.dart' show GoogleBackupPanel;
import 'more_screen.dart' show appVersion;

/// সেটিংস › মতামত বা সমস্যা জানান: a new feature wish or a problem, sent to
/// our server where the admins read it. Only what the user writes here goes
/// (with the app's version) — nothing from their data.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _text = TextEditingController();
  String _kind = 'idea';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final brain = BrainScope.read(context);
    final t = _text.text.trim();
    if (t.length < 5) {
      setState(() => _error = tr('আরেকটু খুলে লিখুন'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await brain.sendFeedback(_kind, t, appVersion);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = e;
    });
    if (e == null) {
      _text.clear();
      toast(context, tr('পাঠানো হয়েছে। ধন্যবাদ — আমরা পড়ে দেখব।'));
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('মতামত বা সমস্যা জানান')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(tr('নতুন কোনো সুবিধা চাইলে, বা কিছু ঠিকমতো কাজ না করলে লিখে পাঠান। আমাদের দল প্রতিটা লেখা পড়ে।'), style: body(14.5, color: C.muted2, height: 1.55)),
              const SizedBox(height: 16),
              SegTabs<String>(
                items: [('idea', tr('নতুন সুবিধা')), ('problem', tr('সমস্যা')), ('other', tr('অন্য কিছু'))],
                value: _kind,
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('feedback-text'),
                controller: _text,
                minLines: 5,
                maxLines: 10,
                maxLength: 2000,
                style: body(16),
                decoration: InputDecoration(
                  hintText: _kind == 'problem' ? tr('কী করতে গিয়ে কী হলো? যেমন: রিমাইন্ডার সময়মতো বাজেনি') : tr('কী হলে আপনার সুবিধা হয়?'),
                ),
              ),
              Text(tr('পাসওয়ার্ড, PIN বা ব্যক্তিগত নম্বর লিখবেন না। শুধু এখানে যা লিখবেন সেটুকু আর অ্যাপের সংস্করণ যাবে — আপনার অন্য কোনো তথ্য না।'),
                  style: body(12.5, color: C.muted, height: 1.5)),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: body(14, color: C.red)),
              ],
              const SizedBox(height: 16),
              if (!brain.signedIn) ...[
                Text(tr('পাঠাতে আগে Google দিয়ে লগইন করুন, যাতে উত্তর দিতে পারি।'), style: body(14, color: C.orange)),
                const SizedBox(height: 10),
                const GoogleBackupPanel(),
              ] else
                PrimaryButton(key: const Key('feedback-send'), label: _busy ? tr('পাঠাচ্ছি…') : tr('পাঠান'), icon: Icons.send_rounded, onPressed: _busy ? null : _send),
            ]),
          ),
        ]),
      ),
    );
  }
}
