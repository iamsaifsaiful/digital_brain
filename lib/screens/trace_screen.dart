import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
