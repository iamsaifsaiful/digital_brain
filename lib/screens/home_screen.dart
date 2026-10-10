import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../models/models.dart';
import '../services/notifications.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'alarm_screens.dart';
import 'home_shell.dart';
import 'plan_screens.dart';

/// "আজ": what needs doing today, in time order — the first thing a busy
/// person wants to see. Money is one tap away in the strip at the top.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final t = totals(d.ledger);
    final month = monthSums(d.cash, now);
    final plan = planOf(d, now);
    final tomorrow = dayOnly(now).add(const Duration(days: 1));
    final tomorrowItems = plan.ahead.where((i) => dayOnly(i.sort) == tomorrow).toList();
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TabTitle(
          'আজ',
          sub: '${weekdayName(now)}, ${bnDigits(now.day)} ${bnMonths[now.month - 1]}',
          trailing: Semantics(
            button: true,
            label: 'আমি',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => ShellTabs.goTo(context, ShellTab.me),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: C.greenTint, shape: BoxShape.circle),
                child: const Icon(Icons.person_outline_rounded, color: C.green),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => ShellTabs.goTo(context, ShellTab.money),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                Expanded(child: Figure(label: 'পাওনা', amount: taka(t.receivable), color: C.green, size: 17)),
                Expanded(child: Figure(label: 'দেনা', amount: taka(t.payable), color: C.orange, size: 17)),
                Expanded(child: Figure(label: 'এ মাসে খরচ', amount: taka(month.expense), size: 17)),
                const Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
          ),
        ),
        if (d.reminders.isNotEmpty) const _AlarmBanner(),
        if (plan.overdue.isNotEmpty) ...[
          _Heading('দেরি হয়ে গেছে · ${bnDigits(plan.overdue.length)}', color: C.orange),
          Panel(
            borderColor: const Color(0xFFF3D9C2),
            child: Rows(children: [
              for (final i in plan.overdue)
                PlanRow(
                  item: i,
                  withDay: true,
                  trailing: TextButton(
                    onPressed: () => brain.saveTask(i.task!.copyWith(due: tomorrow)),
                    child: Text('কাল করব', style: body(13, weight: FontWeight.w600, color: C.green)),
                  ),
                ),
            ]),
          ),
        ],
        _Heading('আজ · ${bnDigits(plan.today.length)}',
            action: TextButton.icon(
              onPressed: () => showAddSheet(context),
              icon: const Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text('যোগ করুন', style: body(14, weight: FontWeight.w600, color: C.green)),
            )),
        if (plan.today.isEmpty)
          Panel(
            padding: const EdgeInsets.all(16),
            child: Text('আজ কিছু রাখা নেই। নিচের মাইক চেপে বলুন — যেমন “বিকেল ৪টায় মিটিং মনে করিয়ে দিও”।', style: body(14, color: C.muted, height: 1.5)),
          )
        else
          Panel(child: Rows(children: [for (final i in plan.today) PlanRow(item: i)])),
        if (tomorrowItems.isNotEmpty) ...[
          _Heading('কাল, ${weekdayName(tomorrow)}'),
          Panel(child: Rows(children: [for (final i in tomorrowItems) PlanRow(item: i)])),
        ],
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => push(const AllTasksScreen()),
            child: Text('সব কাজ ও রিমাইন্ডার দেখুন', style: body(14, weight: FontWeight.w600, color: C.green)),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.color = C.muted2, this.action});
  final String text;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(2, 18, 0, action == null ? 8 : 0),
        child: Row(children: [
          Expanded(child: Text(text, style: body(15, weight: FontWeight.w600, color: color))),
          if (action != null) action!,
        ]),
      );
}

/// Shown on "আজ" while something on this phone may stop reminders.
class _AlarmBanner extends StatefulWidget {
  const _AlarmBanner();

  @override
  State<_AlarmBanner> createState() => _AlarmBannerState();
}

class _AlarmBannerState extends State<_AlarmBanner> with WidgetsBindingObserver {
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
              const Icon(Icons.notifications_off_outlined, color: C.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('রিমাইন্ডার নাও বাজতে পারে', style: body(15, weight: FontWeight.w600, color: C.orangeDark)),
                  Text('ফোনের একটা সেটিং বন্ধ আছে — চেপে ঠিক করুন', style: body(13, color: C.orangeDark)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.orangeDark),
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
