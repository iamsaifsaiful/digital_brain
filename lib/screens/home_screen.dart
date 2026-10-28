import '../logic/repeat_text.dart';
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
import 'google_backup.dart' show restoreFromPhoneFile;
import 'more_screen.dart' show BackupScreen;
import 'help_screen.dart';
import 'plan_screens.dart';
import '../logic/lang.dart';

/// আজকের কাজ on the home: the next thing with its actions, then what is
/// late, today's list and a peek at tomorrow (approved design, 24 Oct).
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
    void allTasks() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllTasksScreen()));

    // The next thing: the first timed one still ahead today, else the first open one.
    bool open(PlanItem i) => i.task != null ? !i.task!.done : i.sort.isAfter(now);
    final next = plan.today.where((i) => i.reminder != null && i.sort.isAfter(now)).firstOrNull ?? plan.today.where(open).firstOrNull;
    final rest = [for (final i in plan.today) if (!identical(i, next)) i];

    Widget group(String text, {bool late = false, IconData? icon}) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 14, color: late ? C.warn : C.muted), const SizedBox(width: 5)],
            Text(text, style: body(11.5, weight: FontWeight.w600, color: late ? C.warn : C.muted)),
          ]),
        );
    List<Widget> rows(List<PlanItem> items, {bool late = false}) => [
          for (final (n, i) in items.indexed) ...[
            if (n > 0) const Hairline(),
            _TaskRow(item: i, late: late, onLater: late && i.task != null ? () => brain.saveTask(i.task!.copyWith(due: tomorrow)) : null),
          ],
        ];

    String peek() {
      final first = tomorrowItems.first;
      final firstTimed = tomorrowItems.where((i) => i.reminder != null).firstOrNull;
      final head = trf('কাল, {0} · {1}টা কাজ', [weekdayName(tomorrow), bnDigits(tomorrowItems.length)]);
      final at = firstTimed ?? (first.reminder != null ? first : null);
      return at == null ? head : '$head, ${trf('প্রথমটা {0}', [bnTime(at.sort.hour, at.sort.minute)])}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(
        tr('আজকের কাজ'),
        counter: all > 0 ? (todoToday == 0 ? tr('সব শেষ') : trf('{0}/{1} শেষ', [bnDigits(doneToday), bnDigits(all)])) : null,
        counterKey: const Key('home-stat-tasks'),
        onCounter: allTasks,
      ),
      if (next != null) ...[_NextCard(item: next), const SizedBox(height: 8)],
      AppCard(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (plan.overdue.isNotEmpty) ...[
            group(trf('দেরি হয়ে গেছে · {0}', [bnDigits(plan.overdue.length)]), late: true, icon: Icons.schedule_rounded),
            ...rows(plan.overdue, late: true),
          ],
          if (rest.isNotEmpty) ...[
            if (plan.overdue.isNotEmpty) group(tr('আজ')),
            ...rows(rest),
          ],
          if (plan.today.isEmpty && plan.overdue.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(tr('আজ কিছু রাখা নেই। নিচে লিখুন বা বলুন — যেমন “বিকেল ৪টায় মিটিং মনে করিয়ে দিও”।'), style: body(13, color: C.muted, height: 1.5)),
            ),
          if (tomorrowItems.isNotEmpty) ...[
            const Hairline(),
            InkWell(
              onTap: allTasks,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: C.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(peek(), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted))),
                ]),
              ),
            ),
          ],
          const Hairline(),
          SizedBox(
            height: 44,
            child: Row(children: [
              Expanded(
                child: InkWell(
                  // Owner (24 Oct): a to-do starts with its reminder off; switch it on if wanted.
                  onTap: () => showAddSheet(context),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_rounded, size: 17, color: C.green),
                    const SizedBox(width: 5),
                    Text(tr('যোগ করুন'), style: body(13, weight: FontWeight.w600, color: C.green)),
                  ]),
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: C.border),
              Expanded(
                child: InkWell(
                  onTap: allTasks,
                  child: Center(child: Text(tr('সব কাজ ও রিমাইন্ডার'), style: body(13, weight: FontWeight.w600, color: C.green))),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// "• এরপর · ২৬ মিনিট পর": the next thing, big, with ফোন করুন (when it is
/// about someone in যোগাযোগ), হয়ে গেছে and পরে.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.item});
  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final r = item.reminder;
    final t = item.task;
    final timed = r != null;
    final mins = item.sort.difference(now).inMinutes;
    final soon = !timed
        ? tr('আজ')
        : mins < 60
            ? trf('{0} মিনিট পর', [bnDigits(mins < 1 ? 1 : mins)])
            : (mins < 24 * 60 ? trf('{0} ঘণ্টা পর', [bnDigits((mins / 60).round())]) : '');
    final meta = [
      if (t != null && t.list.isNotEmpty) t.list,
      if (r != null && r.repeat != Repeat.none) repeatText(r),
      if (t?.note.isNotEmpty ?? false) t!.note,
    ].join(' · ');
    // Someone in যোগাযোগ named in it: ফোন করুন first.
    final title = item.title;
    final who = brain.data.contacts.where((c) => c.phone.trim().isNotEmpty && c.name.trim().length > 1 && title.contains(c.name.trim().split(' ').first)).firstOrNull;
    final time = bnTime(item.sort.hour, item.sort.minute);
    final part = time.split(' ').first;
    // "৭:০০", not "৭টা", on the big clock.
    final h12 = item.sort.hour % 12 == 0 ? 12 : item.sort.hour % 12;
    final clock = isEn ? time : '${bnDigits(h12)}:${bnDigits(item.sort.minute.toString().padLeft(2, '0'))}';

    Future<void> done() async {
      if (t != null) {
        await brain.setTaskDone(t, true);
      } else if (r != null && r.repeat == Repeat.none) {
        await brain.saveReminder(r.copyWith(enabled: false));
      }
      if (context.mounted) toast(context, trf('“{0}” — হয়ে গেছে', [title]));
    }

    Future<void> later() async {
      if (r != null) {
        final at = now.add(const Duration(minutes: 30));
        final again = r.repeat == Repeat.none
            ? r.copyWith(date: dayOnly(at), hour: at.hour, minute: at.minute, enabled: true)
            : Reminder(title: r.title, date: dayOnly(at), hour: at.hour, minute: at.minute, daysBefore: 0);
        await brain.saveReminder(again);
        if (context.mounted) toast(context, trf('৩০ মিনিট পরে ({0}) আবার মনে করাব', [bnTime(at.hour, at.minute)]));
      } else if (t != null) {
        await brain.saveTask(t.copyWith(due: dayOnly(now).add(const Duration(days: 1))));
        if (context.mounted) toast(context, tr('কালকের তালিকায় রাখলাম'));
      }
    }

    final canDone = t != null || (r != null && r.repeat == Repeat.none);
    return AppCard(
      key: const Key('home-next'),
      onTap: () => t != null ? editTask(context, t) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: C.green, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(soon.isEmpty ? tr('এরপর') : '${tr('এরপর')} · $soon', style: body(11.5, weight: FontWeight.w600, color: C.green)),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w600, height: 1.35)),
              if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted))),
            ]),
          ),
          if (timed)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(clock, style: body(22, weight: FontWeight.w600, color: C.green, height: 1.2)),
              if (part != clock) Text(part, style: body(11, color: C.muted)),
            ]),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (who != null)
            SmallButton(primary: true, icon: Icons.call_outlined, label: tr('ফোন করুন'), onTap: () => brain.services.launcher.open(Via.call, who.phone)),
          if (canDone) SmallButton(primary: who == null, icon: Icons.check_rounded, label: tr('হয়ে গেছে'), onTap: done),
          SmallButton(icon: Icons.snooze_rounded, label: tr('পরে'), onTap: later),
        ]),
      ]),
    );
  }
}

/// One line of the list: a tick box (a to-do) or a bell (a reminder).
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.item, this.late = false, this.onLater});
  final PlanItem item;
  final bool late;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final t = item.task;
    final r = item.reminder;
    final passed = r != null && r.repeat == Repeat.none && !r.notifyAt(now).isAfter(now);
    final done = (t?.done ?? false) || passed;
    final label = whenLabel(item, now, withDay: late);
    final sub = late && t != null && r == null ? trf('{0} ছিল', [label]) : (passed ? trf('{0} · বেজেছে', [label]) : label);
    return InkWell(
      onTap: () => t != null ? editTask(context, t) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          if (t != null)
            InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () => brain.setTaskDone(t, !t.done),
              child: SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: t.done ? C.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: t.done ? C.green : C.border, width: 1.6),
                    ),
                    child: t.done ? Icon(Icons.check_rounded, size: 15, color: C.onAccent) : null,
                  ),
                ),
              ),
            )
          else
            SizedBox(width: 34, height: 34, child: Icon(passed ? Icons.notifications_off_outlined : Icons.notifications_none_rounded, size: 20, color: passed ? C.muted : C.green)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(14, color: done ? C.muted : C.ink).copyWith(decoration: t?.done ?? false ? TextDecoration.lineThrough : null, decorationColor: C.muted)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: late ? C.warn : C.muted)),
            ]),
          ),
          if (onLater != null) ...[const SizedBox(width: 8), SoftChip(tr('কাল করব'), onTap: onLater)] else if (t != null && !t.done) TaskAlarmButton(t),
        ]),
      ),
    );
  }
}

/// At most one thing that needs a look, the most important first:
/// reminders may not ring; the Google sign-in offer on a new phone; the
/// four first steps for a new user.
class HomeAttention extends StatefulWidget {
  const HomeAttention({super.key});

  @override
  State<HomeAttention> createState() => _HomeAttentionState();
}

class _HomeAttentionState extends State<HomeAttention> with WidgetsBindingObserver {
  AlarmHealth? _h;
  bool? _tipsHidden;
  Set<String> _seen = {};
  bool _tipsOpen = false;

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
    if (!mounted) return;
    final brain = BrainScope.read(context);
    final h = await brain.services.notifier.health();
    final keys = brain.services.lock.keys;
    final v = await keys.read('tips_done');
    final seen = (await keys.read('tips_seen')) ?? '';
    if (mounted) {
      setState(() {
        _h = h;
        _tipsHidden = v == 'true';
        _seen = {for (final x in seen.split(',')) if (x.isNotEmpty) x};
      });
    }
  }

  Future<void> _hideTips() async {
    await BrainScope.read(context).services.lock.keys.write('tips_done', 'true');
    if (mounted) setState(() => _tipsHidden = true);
  }

  Future<void> _mark(String k) async {
    if (_seen.contains(k)) return;
    setState(() => _seen = {..._seen, k});
    await BrainScope.read(context).services.lock.keys.write('tips_seen', _seen.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    Widget wrap(Widget w) => Padding(padding: const EdgeInsets.only(top: 12), child: w);

    // 1. Reminders may not ring.
    final h = _h;
    if (d.reminders.isNotEmpty && h != null && !h.allGood) {
      return wrap(AttentionCard(
        key: const Key('home-alarm-health'),
        icon: Icons.warning_amber_rounded,
        title: tr('রিমাইন্ডার নাও বাজতে পারে'),
        text: tr('ফোনের একটা সেটিং বন্ধ আছে'),
        action: tr('ঠিক করুন'),
        onAction: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderCheckScreen()));
          _load();
        },
      ));
    }
    // 2. A new phone: bring back the Google backup, or one saved on the phone (owner, 28 Oct).
    final fresh = d.ledger.isEmpty && d.cash.isEmpty && d.notes.isEmpty && d.reminders.isEmpty && d.tasks.isEmpty && d.vault.isEmpty;
    if (brain.signedIn && fresh && !brain.flag('p_card_off')) {
      return wrap(AttentionCard(
        key: const Key('home-phone-backup'),
        icon: Icons.restore_rounded,
        title: tr('ফোনে আগের ব্যাকআপ আছে?'),
        text: tr('আগে “ফোনে সেভ” করা ব্যাকআপ ফাইল বেছে নিলে সব তথ্য ফিরে আসবে'),
        action: tr('ফাইল বেছে নিন'),
        onAction: () => restoreFromPhoneFile(context, fresh: true),
        onClose: () => brain.setPref('p_card_off', true),
      ));
    }
    if (!brain.signedIn && fresh && !brain.flag('g_card_off')) {
      return wrap(AttentionCard(
        key: const Key('home-google'),
        icon: Icons.cloud_download_outlined,
        title: tr('আগে ব্যবহার করেছেন?'),
        text: tr('Google দিয়ে লগইন করলে, বা ফোনে রাখা ব্যাকআপ ফাইল বেছে নিলে, আগের সব তথ্য ফিরে আসবে'),
        action: tr('লগইন'),
        onAction: () => push(const BackupScreen()),
        onClose: () => brain.setPref('g_card_off', true),
      ));
    }
    // 3. The four first steps, until done or hidden.
    if (_tipsHidden != false) return const SizedBox.shrink();
    final steps = <(String, String, String, IconData, bool, VoidCallback)>[
      ('contacts', tr('ফোনবুকের সব নম্বর এক ক্লিকে আনুন'), tr('নাম বললেই ফোন, মেসেজ আর হিসাবে নম্বর নিজে থেকে বসে যাবে'), Icons.contacts_outlined,
          d.contacts.isNotEmpty, () => importFromPhone(context)),
      ('alarm', tr('রিমাইন্ডার যেন ঠিক সময়ে বাজে'), tr('ফোনের দুই-একটা সেটিং এক চাপে ঠিক করে নিন'), Icons.notifications_active_outlined, _seen.contains('alarm'),
          () => push(const ReminderCheckScreen())),
      ('say', tr('নিচে বলুন বা লিখুন'), tr('“রবিনকে ৫০০০ টাকা দিলাম”, “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”, “আজকের কাজের তালিকা”'), Icons.mic_none_rounded,
          _seen.contains('say'), () => toast(context, tr('যেমন: “রবিনকে ৫০০০ টাকা দিলাম”, “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”'))),
      ('help', tr('কী কী করা যায়, দেখে নিন'), tr('সব সুবিধা আর কী বললে কী হয়'), Icons.lightbulb_outline_rounded, _seen.contains('help'), () => push(const HelpScreen())),
    ];
    final done = steps.where((x) => x.$5).length;
    if (done == steps.length) return const SizedBox.shrink();
    return wrap(AppCard(
      key: const Key('home-tips'),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _tipsOpen = !_tipsOpen),
          child: SizedBox(
            height: 50,
            child: Row(children: [
              const IconTile(Icons.flag_outlined, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text(trf('শুরু করার ৪টা ধাপ ({0}/৪)', [bnDigits(done)]), style: body(13.5, weight: FontWeight.w600))),
              Icon(_tipsOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: C.muted, size: 20),
              IconButton(tooltip: tr('বুঝেছি, লুকিয়ে রাখো'), visualDensity: VisualDensity.compact, onPressed: _hideTips, icon: Icon(Icons.close_rounded, size: 18, color: C.muted)),
            ]),
          ),
        ),
        if (_tipsOpen)
          for (final (k, title, sub, icon, ok, onTap) in steps) ...[
            const Hairline(),
            InkWell(
              key: Key('tip-$k'),
              onTap: () {
                _mark(k);
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: ok ? C.green : C.greenTint, borderRadius: BorderRadius.circular(9)),
                    child: Icon(ok ? Icons.check_rounded : icon, color: ok ? C.onAccent : C.green, size: 17),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: body(13.5, weight: FontWeight.w600, color: ok ? C.muted : C.ink)),
                      Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted, height: 1.4)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted, size: 18),
                ]),
              ),
            ),
          ],
      ]),
    ));
  }
}

/// Reminders from today on, soonest first.
List<Reminder> upcomingReminders(AppData d, DateTime now) =>
    ([...d.reminders]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)))).where((r) => !r.nextDate(now).isBefore(dayOnly(now))).toList();
