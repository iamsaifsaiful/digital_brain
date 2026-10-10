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
import 'calls_screen.dart';
import 'help_screen.dart';
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
        const AskBar(),
        const _StartTips(),
        const SizedBox(height: 12),
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

/// Type or speak, right on আজ: whatever is typed is understood exactly like
/// speech ("রবিনকে ৫০০০ টাকা দিলাম", "রবিনের কাছে কত পাব?").
class AskBar extends StatefulWidget {
  const AskBar({super.key});

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _send() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    _c.clear();
    FocusScope.of(context).unfocus();
    openChatWith(context, t);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: C.inputBorder)),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _c,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              minLines: 1,
              maxLines: 3,
              style: body(16),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'লিখুন বা বলুন — যেমন “রবিনকে ৫০০০ টাকা দিলাম”',
                hintStyle: body(14, color: C.muted),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _c,
            builder: (context, v, _) => v.text.trim().isEmpty
                ? CircleAction(icon: Icons.mic_none_rounded, tooltip: 'বলুন', fg: Colors.white, bg: C.green, size: 44, onPressed: () => openVoice(context))
                : CircleAction(icon: Icons.arrow_upward_rounded, tooltip: 'পাঠান', fg: Colors.white, bg: C.ink, size: 44, onPressed: _send),
          ),
        ]),
      );
}

/// First steps for a new user, until they hide it.
class _StartTips extends StatefulWidget {
  const _StartTips();

  @override
  State<_StartTips> createState() => _StartTipsState();
}

class _StartTipsState extends State<_StartTips> {
  bool? _hidden;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final v = await BrainScope.read(context).services.lock.keys.read('tips_done');
      if (mounted) setState(() => _hidden = v == 'true');
    });
  }

  Future<void> _hide() async {
    await BrainScope.read(context).services.lock.keys.write('tips_done', 'true');
    if (mounted) setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden != false) return const SizedBox.shrink();
    final brain = BrainScope.of(context);
    final hasContacts = brain.data.contacts.isNotEmpty;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    Widget step(String n, String title, String sub, {bool done = false, String? action, VoidCallback? onTap}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: done ? C.green : C.surface, shape: BoxShape.circle, border: Border.all(color: C.green)),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text(n, style: body(13, weight: FontWeight.w700, color: C.green, height: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15, weight: FontWeight.w600)),
                Text(sub, style: body(13, color: C.muted, height: 1.4)),
              ]),
            ),
            if (action != null && !done)
              TextButton(onPressed: onTap, child: Text(action, style: body(14, weight: FontWeight.w600, color: C.green))),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Panel(
        color: C.greenSoft,
        borderColor: C.greenTint,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('শুরু করার ৪টা ধাপ', style: body(16, weight: FontWeight.w700, color: C.greenDark)),
          const SizedBox(height: 4),
          step('১', 'ফোনবুকের সব নম্বর এক ক্লিকে আনুন', 'নাম বললেই ফোন, মেসেজ আর হিসাবে নম্বর নিজে থেকে বসে যাবে',
              done: hasContacts, action: 'আনুন', onTap: () => importFromPhone(context)),
          step('২', 'রিমাইন্ডার যেন ঠিক সময়ে বাজে', 'ফোনের দুই-একটা সেটিং এক চাপে ঠিক করে নিন',
              action: 'দেখুন', onTap: () => push(const ReminderCheckScreen())),
          step('৩', 'মুখে বলুন বা উপরে লিখুন', '“রবিনকে ৫০০০ টাকা দিলাম”, “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”, “আজকের কাজের তালিকা”'),
          step('৪', 'কী কী করা যায়, দেখে নিন', 'সব সুবিধা আর কী বললে কী হয়', action: 'দেখুন', onTap: () => push(const HelpScreen())),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _hide, child: Text('বুঝেছি, লুকিয়ে রাখো', style: body(13, color: C.muted))),
          ),
        ]),
      ),
    );
  }
}
