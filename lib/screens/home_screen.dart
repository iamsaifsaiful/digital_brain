import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../services/notifications.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart' show toast;
import 'alarm_screens.dart';
import 'calls_screen.dart';
import 'help_screen.dart';
import 'plan_screens.dart';
import '../logic/lang.dart';

/// What needs doing — late, today, tomorrow — shown on the home under the
/// greeting, in the same light style as the chat.
class TodaySections extends StatelessWidget {
  const TodaySections({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final plan = planOf(d, now);
    final tomorrow = dayOnly(now).add(const Duration(days: 1));
    final tomorrowItems = plan.ahead.where((i) => dayOnly(i.sort) == tomorrow).toList();

    Widget box(List<Widget> rows, {Color? color}) => Container(
          decoration: BoxDecoration(color: color ?? C.surface, borderRadius: BorderRadius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (i, r) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
              r,
            ],
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (plan.overdue.isNotEmpty) ...[
        _Heading(trf('দেরি হয়ে গেছে · {0}', [bnDigits(plan.overdue.length)]), color: C.orange),
        box(color: C.orangeTint, [
          for (final i in plan.overdue)
            PlanRow(
              item: i,
              withDay: true,
              trailing: TextButton(
                onPressed: () => brain.saveTask(i.task!.copyWith(due: tomorrow)),
                child: Text(tr('কাল করব'), style: body(13, weight: FontWeight.w600, color: C.green)),
              ),
            ),
        ]),
      ],
      _Heading(tr('আজকের তালিকা'), big: true,
          action: TextButton.icon(
            onPressed: () => showAddSheet(context, remind: true),
            icon: Icon(Icons.add_rounded, size: 18, color: C.green),
            label: Text(tr('যোগ করুন'), style: body(14, weight: FontWeight.w600, color: C.green)),
          )),
      if (plan.today.isEmpty)
        box([
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(tr('আজ কিছু রাখা নেই। নিচে লিখুন বা বলুন — যেমন “বিকেল ৪টায় মিটিং মনে করিয়ে দিও”।'), style: body(14, color: C.muted, height: 1.5)),
          ),
        ])
      else
        box([for (final i in plan.today) PlanRow(item: i)]),
      if (tomorrowItems.isNotEmpty) ...[
        _Heading(trf('কাল, {0}', [weekdayName(tomorrow)])),
        box([for (final i in tomorrowItems) PlanRow(item: i)]),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllTasksScreen())),
          iconAlignment: IconAlignment.end,
          icon: Icon(Icons.arrow_forward_rounded, size: 18, color: C.green),
          label: Text(tr('সব কাজ ও রিমাইন্ডার দেখুন'), style: body(14, weight: FontWeight.w600, color: C.green)),
        ),
      ),
    ]);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {Color? color, this.action, this.big = false}) : _color = color;
  final String text;
  final bool big;
  final Color? _color;
  Color get color => _color ?? C.muted;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, big ? 22 : 18, 0, action == null ? 8 : 2),
        child: Row(children: [
          Expanded(child: Text(text, style: big ? display(18, weight: 700) : body(13, weight: FontWeight.w600, color: color))),
          if (action != null) action!,
        ]),
      );
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
    final steps = <(String, String, IconData, Color, bool, VoidCallback)>[
      ('contacts', tr('ফোনবুকের নম্বর আনুন'), Icons.contacts_outlined, const Color(0xFF7C3AED), brain.data.contacts.isNotEmpty, () => importFromPhone(context)),
      ('alarm', tr('রিমাইন্ডার ঠিক সময়ে বাজুক'), Icons.notifications_active_outlined, const Color(0xFFEA580C), _seen.contains('alarm'), () => push(const ReminderCheckScreen())),
      ('say', tr('নিচে বলুন বা লিখুন'), Icons.mic_none_rounded, const Color(0xFF059669), _seen.contains('say'),
          () => toast(context, tr('যেমন: “রবিনকে ৫০০০ টাকা দিলাম”, “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”'))),
      ('help', tr('কী কী করা যায়, দেখুন'), Icons.lightbulb_outline_rounded, const Color(0xFF2563EB), _seen.contains('help'), () => push(const HelpScreen())),
    ];
    final done = steps.where((x) => x.$5).length;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tr('শুরু করার ৪টা ধাপ'), style: display(16, weight: 700))),
            Text(trf('{0}/৪ হয়েছে', [bnDigits(done)]), style: body(12.5, weight: FontWeight.w600, color: C.green)),
            IconButton(
              tooltip: tr('বুঝেছি, লুকিয়ে রাখো'),
              visualDensity: VisualDensity.compact,
              onPressed: _hide,
              icon: Icon(Icons.close_rounded, size: 20, color: C.muted),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: done / 4, minHeight: 5, color: C.green, backgroundColor: C.greenTint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (k, title, icon, color, ok, onTap) in steps)
                SizedBox(
                      width: (MediaQuery.of(context).size.width - 32 - 28 - 10) / 2,
                      child: Material(
                        color: color.withValues(alpha: C.dark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          key: Key('tip-$k'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _mark(k);
                            onTap();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(color: ok ? C.green : color, shape: BoxShape.circle),
                                child: Icon(ok ? Icons.check_rounded : icon, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(title, maxLines: 2, style: body(13, weight: FontWeight.w600, height: 1.25, color: ok ? C.muted : C.ink)),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
            ]),
          ),
        ]),
      ),
    );
  }
}
