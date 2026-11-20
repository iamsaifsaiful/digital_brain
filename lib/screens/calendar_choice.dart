import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/world_calendars.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Which calendars sit beside the English date (owner, 19 Nov): English is
/// always on; one or two more may be added. The first chosen is the main
/// one (large on the calendar page), the second shows beside it.
Future<void> showCalendarChoice(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const CalendarChoice(),
    );

class CalendarChoice extends StatefulWidget {
  const CalendarChoice({super.key});

  @override
  State<CalendarChoice> createState() => _CalendarChoiceState();
}

class _CalendarChoiceState extends State<CalendarChoice> {
  /// Shown for a moment when a third one is tapped.
  bool _full = false;

  Future<void> _tap(Brain brain, String id) async {
    final now = [...brain.calendars];
    if (now.contains(id)) {
      now.remove(id);
    } else if (now.length >= maxCalendars) {
      setState(() => _full = true);
      return;
    } else {
      now.add(id);
    }
    setState(() => _full = false);
    await brain.setPref('calendars', calendarsPref(now));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final today = brain.services.now();
    final chosen = brain.calendars;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          Text(tr('ক্যালেন্ডার বাছাই'), style: display(20, weight: 700)),
          const SizedBox(height: 4),
          Text(tr('ইংরেজি তারিখ সবসময় থাকে। এর সাথে আরও একটি বা দুটি ক্যালেন্ডার বেছে নিন।'), style: body(13.5, color: C.muted, height: 1.45)),
          const SizedBox(height: 14),
          Panel(
            child: ListTile(
              key: const Key('cal-choice-english'),
              contentPadding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
              title: Text(tr('ইংরেজি (গ্রেগরিয়ান)'), style: body(15, weight: FontWeight.w600)),
              subtitle: Text(fullDate(today), style: body(12.5, color: C.muted)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: C.muted),
                const SizedBox(width: 4),
                Text(tr('সবসময়'), style: body(12.5, color: C.muted)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text(tr('আরও যোগ করুন'), style: body(13, weight: FontWeight.w600, color: C.muted2))),
            Text(trf('{0}/{1} বাছাই', [bnDigits(chosen.length), bnDigits(maxCalendars)]), key: const Key('cal-choice-count'), style: body(12.5, color: _full ? C.rose : C.muted)),
          ]),
          if (_full)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr('দুটির বেশি নয়। নতুনটি নিতে আগে একটি বাদ দিন।'), style: body(12.5, color: C.rose)),
            ),
          const SizedBox(height: 8),
          Panel(
            child: Rows(children: [
              for (final k in calKinds) _row(brain, k, today, chosen),
            ]),
          ),
          const SizedBox(height: 10),
          Text(tr('প্রথমটি ক্যালেন্ডার পাতায় বড় করে দেখাবে। হিজরি তারিখ চাঁদ দেখার ওপর এক দিন আগে-পরে হতে পারে।'), style: body(12, color: C.muted, height: 1.45)),
          const SizedBox(height: 14),
          PrimaryButton(key: const Key('cal-choice-done'), label: tr('ঠিক আছে'), height: 48, onPressed: () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }

  Widget _row(Brain brain, CalKind k, DateTime today, List<String> chosen) {
    final at = chosen.indexOf(k.id);
    final on = at >= 0;
    final d = calDate(k.id, today, hijriShift: brain.hijriShift);
    return InkWell(
      key: Key('cal-choice-${k.id}'),
      onTap: () => _tap(brain, k.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.name, style: body(15, weight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(d == null ? k.where : '${d.text} · ${k.where}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
            ]),
          ),
          const SizedBox(width: 10),
          // Thin ring; filled with its place (১, ২) when chosen.
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? C.green : Colors.transparent,
              border: Border.all(color: on ? C.green : C.inputBorder, width: 1.4),
            ),
            child: on ? Text(bnDigits(at + 1), style: body(12, weight: FontWeight.w700, color: C.onAccent, height: 1)) : null,
          ),
        ]),
      ),
    );
  }
}
