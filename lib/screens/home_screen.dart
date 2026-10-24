import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../services/notifications.dart';
import '../state/brain.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart' show toast;
import 'alarm_screens.dart';
import 'calls_screen.dart';
import 'help_screen.dart';
import 'plan_screens.dart';
import '../logic/lang.dart';

/// A titled part of the home: a heading, maybe a link on the right, then
/// its card.
class HomeSection extends StatelessWidget {
  const HomeSection({super.key, required this.title, this.action, this.onAction, this.trailing, this.note, required this.child});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  /// A small hand-written word beside the heading (24 Oct design).
  final Widget? note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          HomeSectionHeader(title: title, action: action, onAction: onAction, trailing: trailing, padTop: false),
          if (note != null) Padding(padding: const EdgeInsets.fromLTRB(2, 0, 0, 10), child: Align(alignment: Alignment.centerLeft, child: note!)),
          child,
        ]),
      );
}

/// The heading of a home part: bold title, a hand note maybe, and a muted
/// "সব দেখুন ›" on the right.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.action, this.onAction, this.trailing, this.note, this.padTop = true});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final Widget? note;
  final bool padTop;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: padTop ? 22 : 0, bottom: 10),
        child: SizedBox(
          height: 36,
          child: Row(children: [
            Text(title, maxLines: 1, style: heading(18)),
            if (note != null) ...[const SizedBox(width: 10), Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: note!))],
            const Spacer(),
            if (trailing != null) trailing!,
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8), visualDensity: VisualDensity.compact, foregroundColor: C.muted),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(action!, style: body(13.5, weight: FontWeight.w500, color: C.muted)),
                  Icon(Icons.chevron_right_rounded, size: 18, color: C.muted),
                ]),
              ),
          ]),
        ),
      );
}

/// The plain white card every part of the home sits on.
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: C.shadow),
        child: Material(
          color: C.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: C.dark ? BorderSide(color: C.line) : BorderSide.none),
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// আজকের কাজ on the home: how many are done, what is late, today's
/// to-dos and reminders, and tomorrow's.
class TodaySections extends StatelessWidget {
  const TodaySections({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final today = dayOnly(now);
    final plan = planOf(d, now);
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowItems = plan.ahead.where((i) => dayOnly(i.sort) == tomorrow).toList();
    final todoToday = [for (final i in plan.today) if (i.task != null) i].length;
    final doneToday = [for (final t in d.tasks) if (t.done && t.doneAt != null && dayOnly(t.doneAt!) == today) t].length;
    final all = todoToday + doneToday;
    final yesterday = today.subtract(const Duration(days: 1));
    final doneYesterday = [for (final t in d.tasks) if (t.done && t.doneAt != null && dayOnly(t.doneAt!) == yesterday) t].length;

    Widget label(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
          child: Text(text, style: body(12.5, weight: FontWeight.w600, color: color ?? C.muted)),
        );
    List<Widget> rows(List<PlanItem> items, {bool late = false}) => [
          for (final (n, i) in items.indexed) ...[
            if (n > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.line2),
            PlanRow(
              item: i,
              withDay: late,
              trailing: late
                  ? TextButton(
                      onPressed: () => brain.saveTask(i.task!.copyWith(due: tomorrow)),
                      child: Text(tr('কাল করব'), style: body(13, weight: FontWeight.w600, color: C.primary)),
                    )
                  : null,
            ),
          ],
        ];

    return HomeSection(
      title: tr('আজকের কাজ'),
      note: doneToday > 0 && doneToday >= doneYesterday ? HandNote(tr('গতকালের চেয়ে একটু ভালো'), size: 12.5, smile: true) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (all > 0)
          InkWell(
            key: const Key('home-stat-tasks'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllTasksScreen())),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(todoToday == 0 ? tr('সব শেষ') : trf('{0}/{1} শেষ', [bnDigits(doneToday), bnDigits(all)]), style: body(13, color: C.muted)),
            ),
          ),
        TextButton.icon(
          onPressed: () => showAddSheet(context, remind: true),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
          icon: Icon(Icons.add_rounded, size: 18, color: C.primary),
          label: Text(tr('যোগ করুন'), style: body(13.5, weight: FontWeight.w600, color: C.primary)),
        ),
      ]),
      child: HomeCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (all > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: doneToday / all, minHeight: 5, color: C.primary, backgroundColor: C.chip),
              ),
            ),
          if (plan.overdue.isNotEmpty) ...[
            label(trf('দেরি হয়ে গেছে · {0}', [bnDigits(plan.overdue.length)]), color: C.orange),
            ...rows(plan.overdue, late: true),
            if (plan.today.isNotEmpty) label(tr('আজ')),
          ],
          if (plan.today.isEmpty && plan.overdue.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(tr('আজ কিছু রাখা নেই। নিচে লিখুন বা বলুন — যেমন “বিকেল ৪টায় মিটিং মনে করিয়ে দিও”।'), style: body(14, color: C.muted, height: 1.5)),
            )
          else
            ...rows(plan.today),
          if (tomorrowItems.isNotEmpty) ...[
            Divider(height: 1, color: C.line),
            label(trf('কাল, {0}', [weekdayName(tomorrow)])),
            ...rows(tomorrowItems),
          ],
          Divider(height: 1, color: C.line),
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllTasksScreen())),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(child: Text(tr('সব কাজ ও রিমাইন্ডার দেখুন'), style: body(14, weight: FontWeight.w600, color: C.primary))),
                Icon(Icons.chevron_right_rounded, color: C.primary),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Shown on "আজ" while something on this phone may stop reminders.
class AlarmBanner extends StatefulWidget {
  const AlarmBanner({super.key});

  @override
  State<AlarmBanner> createState() => _AlarmBannerState();
}

class _AlarmBannerState extends State<AlarmBanner> with WidgetsBindingObserver {
  AlarmHealth? _h;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final h = await BrainScope.read(context).services.notifier.health();
    if (mounted) setState(() => _h = h);
  }

  @override
  Widget build(BuildContext context) {
    final h = _h;
    if (h == null || h.allGood) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: C.orangeTint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderCheckScreen()));
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Icon(Icons.notifications_off_outlined, color: C.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('রিমাইন্ডার নাও বাজতে পারে'), style: body(15, weight: FontWeight.w600, color: C.orangeDark)),
                  Text(tr('ফোনের একটা সেটিং বন্ধ আছে — চেপে ঠিক করুন'), style: body(13, color: C.orangeDark)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: C.orangeDark),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Reminders from today on, soonest first.
List<Reminder> upcomingReminders(AppData d, DateTime now) =>
    ([...d.reminders]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)))).where((r) => !r.nextDate(now).isBefore(dayOnly(now))).toList();

/// First steps for a new user, until they hide it.
class StartTips extends StatefulWidget {
  const StartTips({super.key});

  @override
  State<StartTips> createState() => _StartTipsState();
}

class _StartTipsState extends State<StartTips> {
  bool? _hidden;
  Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Built while scrolling past, it may be gone by the next frame.
      if (!mounted) return;
      final keys = BrainScope.read(context).services.lock.keys;
      final v = await keys.read('tips_done');
      final seen = (await keys.read('tips_seen')) ?? '';
      if (mounted) {
        setState(() {
          _hidden = v == 'true';
          _seen = {for (final x in seen.split(',')) if (x.isNotEmpty) x};
        });
      }
    });
  }

  Future<void> _hide() async {
    await BrainScope.read(context).services.lock.keys.write('tips_done', 'true');
    if (mounted) setState(() => _hidden = true);
  }

  Future<void> _mark(String k) async {
    if (_seen.contains(k)) return;
    setState(() => _seen = {..._seen, k});
    await BrainScope.read(context).services.lock.keys.write('tips_seen', _seen.join(','));
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden != false) return const SizedBox.shrink();
    final brain = BrainScope.of(context);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final steps = <(String, String, String, IconData, bool, VoidCallback)>[
      ('contacts', tr('ফোনবুকের সব নম্বর এক ক্লিকে আনুন'), tr('নাম বললেই ফোন, মেসেজ আর হিসাবে নম্বর নিজে থেকে বসে যাবে'), Icons.contacts_outlined,
          brain.data.contacts.isNotEmpty, () => importFromPhone(context)),
      ('alarm', tr('রিমাইন্ডার যেন ঠিক সময়ে বাজে'), tr('ফোনের দুই-একটা সেটিং এক চাপে ঠিক করে নিন'), Icons.notifications_active_outlined, _seen.contains('alarm'),
          () => push(const ReminderCheckScreen())),
      ('say', tr('নিচে বলুন বা লিখুন'), tr('“রবিনকে ৫০০০ টাকা দিলাম”, “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”, “আজকের কাজের তালিকা”'), Icons.mic_none_rounded,
          _seen.contains('say'), () => toast(context, tr('যেমন: “রবিনকে ৫০০০ টাকা দিলাম”, “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”'))),
      ('help', tr('কী কী করা যায়, দেখে নিন'), tr('সব সুবিধা আর কী বললে কী হয়'), Icons.lightbulb_outline_rounded, _seen.contains('help'), () => push(const HelpScreen())),
    ];
    final done = steps.where((x) => x.$5).length;

    return HomeSection(
      title: tr('শুরু করার ৪টা ধাপ'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(trf('{0}/৪ হয়েছে', [bnDigits(done)]), style: body(13, color: C.muted)),
        IconButton(
          tooltip: tr('বুঝেছি, লুকিয়ে রাখো'),
          visualDensity: VisualDensity.compact,
          onPressed: _hide,
          icon: Icon(Icons.close_rounded, size: 20, color: C.muted),
        ),
      ]),
      child: HomeCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (n, (k, title, sub, icon, ok, onTap)) in steps.indexed) ...[
            if (n > 0) Divider(height: 1, indent: 62, color: C.line2),
            InkWell(
              key: Key('tip-$k'),
              onTap: () {
                _mark(k);
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: ok ? C.green : C.greenTint, shape: BoxShape.circle),
                    child: Icon(ok ? Icons.check_rounded : icon, color: ok ? Colors.white : C.green, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: body(14.5, weight: FontWeight.w600, color: ok ? C.muted : C.ink)),
                      Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted, height: 1.4)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
