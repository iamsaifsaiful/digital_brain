import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../services/trace.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// আরও › সমস্যা খোঁজার লগ: what the microphone heard (each recogniser
/// session, partial and final), the whole speech, what it was understood as,
/// and where the answer came from. Only on this phone, in memory; numbers
/// are hidden. Copy it to send to the developer when something goes wrong.
class TraceScreen extends StatefulWidget {
  const TraceScreen({super.key});

  @override
  State<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends State<TraceScreen> {
  bool _sending = false;

  Future<void> _send(Brain brain) async {
    setState(() => _sending = true);
    final r = await brain.sendTrace(all: true);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r == null) return toast(context, tr('পাঠানো গেল না — ইন্টারনেট দেখে আবার চেষ্টা করুন'));
    if (r.sent == 0) return toast(context, r.left > 0 ? tr('পাঠানোর মতো কিছু নেই — সব কথোপকথনই ব্যক্তিগত বিষয়ের, তাই ফোনেই থাকল') : tr('পাঠানোর মতো কিছু নেই'));
    toast(context, r.left > 0 ? trf('{0}টা লাইন পাঠানো হয়েছে; ব্যক্তিগত বিষয়ের {1}টা কথোপকথন বাদ রাখা হয়েছে', [bnDigits(r.sent), bnDigits(r.left)]) : trf('{0}টা লাইন পাঠানো হয়েছে — ধন্যবাদ', [bnDigits(r.sent)]));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final events = Trace.events.reversed.toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('সমস্যা খোঁজার লগ'), trailing: [
            IconButton(
              tooltip: tr('কপি করুন'),
              onPressed: events.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: Trace.dump()));
                      if (context.mounted) toast(context, tr('কপি হয়েছে — ডেভেলপারকে পাঠাতে পারেন'));
                    },
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(tooltip: tr('মুছুন'), onPressed: () => setState(Trace.clear), icon: const Icon(Icons.delete_outline_rounded)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                key: const Key('trace-on'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('লগ চালু'), style: body(16, weight: FontWeight.w600)),
                subtitle: Text(tr('মাইক কী শুনল, কী বুঝল আর উত্তর কোথা থেকে এলো — লিখে রাখে। শুধু এই ফোনে, অ্যাপ বন্ধ করলে মুছে যায়।'), style: body(13, color: C.muted)),
                value: Trace.enabled,
                onChanged: (v) async {
                  Trace.enabled = v;
                  await brain.setPref('trace_on', v);
                  if (mounted) setState(() {});
                },
              ),
              SwitchListTile(
                key: const Key('trace-share'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('লগ আমাদের সার্ভারে পাঠান'), style: body(16, weight: FontWeight.w600)),
                subtitle: Text(
                    tr('চালু থাকলে অ্যাপ থেকে বের হলে নতুন লগ আমাদের কাছে যায়, যাতে সমস্যা খুঁজে ঠিক করতে পারি। নম্বর লুকানো থাকে; পাসওয়ার্ড, ভল্ট, PIN/OTP, স্বাস্থ্য, ওষুধ বা মেসেজ নিয়ে যে কথোপকথন — সেটা পুরোটাই বাদ যায়, ফোনের বাইরে যায় না।'),
                    style: body(13, color: C.muted)),
                value: brain.traceShare,
                onChanged: (v) async {
                  await brain.setPref('trace_share', v);
                  if (v && !Trace.enabled) {
                    Trace.enabled = true;
                    await brain.setPref('trace_on', true);
                  }
                  if (mounted) setState(() {});
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('trace-send'),
                  onPressed: events.isEmpty || _sending ? null : () => _send(brain),
                  icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 18),
                  label: Text(tr('এখনই পাঠান')),
                ),
              ),
            ]),
          ),
          Expanded(
            child: events.isEmpty
                ? EmptyState(icon: Icons.receipt_long_outlined, title: tr('লগ খালি'), text: tr('লগ চালু রেখে সহকারীর সাথে কথা বলুন, তারপর এখানে দেখুন।'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: C.line2),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SelectableText(events[i].toString(), style: TextStyle(fontSize: 12, height: 1.4, color: C.ink, fontFamily: 'monospace')),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
