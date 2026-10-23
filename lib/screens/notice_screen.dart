/// নোটিফিকেশন: what is coming in the next days and what already came —
/// reminders, the assistant's summaries and nudges, and messages from us.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/notice_log.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'notification_settings.dart';

/// A short Bangla name for a notification's kind.
String noticeKindLabel(String kind) {
  if (kind == 'reminder') return tr('রিমাইন্ডার');
  if (kind == 'reminder_early') return tr('আগাম রিমাইন্ডার');
  if (kind == 'server' || kind == 'push') return tr('My Assistant থেকে');
  if (kind.startsWith('brief:morning')) return tr('সকালের সারাংশ');
  if (kind.startsWith('brief:night') || kind.startsWith('brief:')) return tr('দিনের সারাংশ');
  return switch (kind) {
    'pro' => tr('প্রো'),
    'blood' => tr('রক্তদান'),
    'family' || 'family_item' => tr('ফ্যামিলি'),
    'feedback' => tr('মতামতের উত্তর'),
    'heir_claim' => tr('উত্তরাধিকার'),
    _ => tr('সহকারী'),
  };
}

IconData _icon(String kind) {
  if (kind == 'reminder') return Icons.alarm_rounded;
  if (kind == 'reminder_early') return Icons.schedule_rounded;
  if (kind.startsWith('brief:morning')) return Icons.wb_sunny_outlined;
  if (kind.startsWith('brief:')) return Icons.nights_stay_outlined;
  return switch (kind) {
    'server' || 'push' || 'pro' => Icons.campaign_outlined,
    'blood' => Icons.bloodtype_outlined,
    'family' || 'family_item' || 'heir_claim' => Icons.family_restroom_rounded,
    'feedback' => Icons.forum_outlined,
    _ => Icons.lightbulb_outline_rounded,
  };
}

class _Row {
  const _Row(this.at, this.title, this.body, this.kind);
  final DateTime at;
  final String title;
  final String body;
  final String kind;
}

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  int _tab = 0;
  List<PushRecord> _pushes = const [];

  @override
  void initState() {
    super.initState();
    BrainScope.read(context).pushLog().then((p) {
      if (mounted) setState(() => _pushes = p);
    }).catchError((_) {});
  }

  /// A notification opened: the whole message in a box.
  Future<void> _open(_Row r, DateTime now) async {
    final reminder = r.kind.startsWith('reminder');
    final fg = reminder ? C.orange : C.blue;
    final bg = reminder ? C.orangeTint : C.blueTint;
    await showAppSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              key: const Key('notice-box'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: fg.withValues(alpha: 0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
                    child: Icon(_icon(r.kind), color: fg, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(noticeKindLabel(r.kind), style: body(13, weight: FontWeight.w600, color: fg)),
                      Text('${relativeDay(r.at, now)} · ${bnTime(r.at.hour, r.at.minute)}', style: body(13, color: C.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(r.title.isEmpty ? noticeKindLabel(r.kind) : r.title, style: display(20, weight: 700, height: 1.3)),
                if (r.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r.body.trim(), style: body(16, height: 1.55)),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            PrimaryButton(label: tr('ঠিক আছে'), height: 48, onPressed: () => Navigator.pop(ctx)),
          ]),
        ),
      ),
    );
  }

  List<Widget> _list(List<_Row> rows, DateTime now, bool coming, Brain brain) {
    final children = <Widget>[];
    var day = DateTime(0);
    var group = <Widget>[];
    void flush() {
      if (group.isEmpty) return;
      final rel = relativeDay(day, now);
      children
        ..add(SectionTitle(rel == shortDate(day) ? '${weekdayName(day)}, ${shortDate(day)}' : rel))
        ..add(Panel(child: Rows(children: group)))
        ..add(const SizedBox(height: 12));
      group = <Widget>[];
    }

    for (final r in rows.take(200)) {
      final d = dayOnly(r.at);
      if (day != d) {
        flush();
        day = d;
      }
      group.add(ListRow(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: r.kind.startsWith('reminder') ? C.orangeTint : C.blueTint, borderRadius: BorderRadius.circular(12)),
          child: Icon(_icon(r.kind), color: r.kind.startsWith('reminder') ? C.orange : C.blue, size: 20),
        ),
        title: r.title.isEmpty ? noticeKindLabel(r.kind) : r.title,
        subtitle: [noticeKindLabel(r.kind), if (r.body.trim().isNotEmpty) r.body.trim()].join(' · '),
        trailing: Text(bnTime(r.at.hour, r.at.minute), style: body(13, color: C.muted)),
        onTap: () => _open(r, now),
      ));
    }
    flush();
    return [
      if (coming && brain.scheduleFailed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            padding: const EdgeInsets.all(14),
            child: Text(tr('ফোন রিমাইন্ডার রাখতে দিচ্ছে না — নোটিফিকেশনের অনুমতি দেখুন।'), style: body(14, color: C.orange)),
          ),
        ),
      if (rows.isEmpty)
        EmptyState(
          icon: Icons.notifications_none_rounded,
          title: coming ? tr('সামনের ৭ দিনে কোনো নোটিফিকেশন নেই') : tr('এখনো কোনো নোটিফিকেশন আসেনি'),
          text: coming ? tr('রিমাইন্ডার রাখলে বা সারাংশ চালু করলে এখানে দেখাবে — কখন কোনটা আসবে।') : tr('যেগুলোর সময় হয়ে গেছে, সেগুলো এখানে থাকবে ৩০ দিন।'),
        )
      else
        ...children,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final coming = [for (final e in brain.noticePlan) if (e.at.isAfter(now)) _Row(e.at, e.title, e.body, e.kind)];
    final came = <_Row>[
      for (final e in brain.noticeHistory) if (!e.at.isAfter(now)) _Row(e.at, e.title, e.body, e.kind),
      // Plan items whose time came since the last look.
      for (final e in brain.noticePlan) if (!e.at.isAfter(now)) _Row(e.at, e.title, e.body, e.kind),
      for (final p in _pushes)
        if (p.status == 'sent') _Row(p.at, p.title, '', p.kind),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('নোটিফিকেশন'), trailing: [
            IconButton(
              tooltip: tr('নোটিফিকেশন সেটিংস'),
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
            ),
          ]),
          // Swiped like the other pages' tabs.
          Expanded(
            child: TabPages<int>(
              items: [(0, trf('আসছে ({0})', [bnDigits(coming.length)])), (1, tr('আগে এসেছে'))],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              page: (t) => _list(t == 0 ? coming : came, now, t == 0, brain),
            ),
          ),
        ]),
      ),
    );
  }
}
