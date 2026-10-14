import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/parser.dart' show findAmount, normalize, CashAdd;
import '../logic/when.dart' show parseWhen;
import '../logic/inbox.dart';
import '../logic/lang.dart';
import '../logic/when.dart' show sayWhen;
import '../models/models.dart';
import '../services/inbox.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';
import 'money_screens.dart' show CashFormScreen;
import 'new_item_screen.dart';

/// মেসেজ থেকে কাজ: new messages from WhatsApp, Telegram, imo, Gmail, SMS…
/// (read from their notifications, on the phone), with what needs doing
/// pulled out — keep it as a reminder or to-do, note the money, or reply.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  bool? _access;
  Timer? _poll;
  String _app = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final brain = BrainScope.read(context);
    final a = await brain.services.inbox.hasAccess();
    if (a) await brain.syncInbox();
    if (mounted && a != _access) setState(() => _access = a);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final todo = inboxTodo(brain.data, now);
    final all = [for (final m in brain.data.inbox.reversed) if (m.state != 'dismissed') if (_app.isEmpty || m.appName.startsWith(_app)) m];
    final apps = {for (final m in brain.data.inbox) m.appName.replaceAll(RegExp(r' (HD|Lite|X|Business)$'), '')}.toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('মেসেজ থেকে কাজ'), trailing: [
            IconButton(tooltip: tr('কোন অ্যাপ পড়বে'), onPressed: () => _settings(context), icon: const Icon(Icons.tune_rounded)),
          ]),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
                if (!brain.inboxSupported)
                  InfoBanner(
                    icon: Icons.info_outline_rounded,
                    text: tr('অন্য অ্যাপের মেসেজ পড়ার সুবিধা এই সংস্করণে নেই: Play Store-এর বাইরে থেকে নামানো অ্যাপ নোটিফিকেশন পড়তে চাইলে Google Play Protect সেটা ইনস্টলই করতে দেয় না। Play Store-এর সংস্করণে এটা থাকবে।'),
                  )
                else if (_access == false)
                  _Setup(onDone: _refresh),
                if (_access == true && !brain.inboxOn)
                  InfoBanner(icon: Icons.pause_circle_outline_rounded, text: tr('মেসেজ পড়া বন্ধ রাখা আছে। উপরের ডান কোণের বোতাম থেকে চালু করুন।')),
                if (_access == true && brain.data.inbox.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.mark_chat_unread_outlined,
                      title: tr('এখনো কোনো মেসেজ নেই'),
                      text: tr('অনুমতি দেওয়া আছে। WhatsApp, imo, Gmail-এ নতুন মেসেজ এলে এখানে দেখাবে, আর কাজের কথা আলাদা করে দেবো।'),
                    ),
                  ),
                if (todo.isNotEmpty) ...[
                  SectionTitle(trf('কাজের কথা · {0}', [bnDigits(todo.length)])),
                  for (final (m, i) in todo.take(30)) ...[_TodoCard(message: m, insight: i), const SizedBox(height: 10)],
                  const SizedBox(height: 8),
                ],
                if (all.isNotEmpty) ...[
                  SectionTitle(tr('সব মেসেজ')),
                  if (apps.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        ChoiceChip(label: Text(tr('সব')), selected: _app.isEmpty, onSelected: (_) => setState(() => _app = '')),
                        for (final a in apps) ChoiceChip(label: Text(a), selected: _app == a, onSelected: (_) => setState(() => _app = a)),
                      ]),
                    ),
                  Panel(
                    child: Rows(children: [
                      for (final m in all.take(150))
                        ListRow(
                          leading: _AppBadge(m.appName),
                          title: m.group && m.from.isNotEmpty && m.from != m.chat ? '${m.from} · ${m.chat}' : (m.from.isNotEmpty ? m.from : m.chat),
                          subtitle: '${sayWhen(m.at, now)} · ${m.text.replaceAll('\n', ' ')}',
                          onTap: () => showMessage(context, m),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                Text(tr('মেসেজগুলো শুধু এই ফোনে, তালাবদ্ধ অবস্থায় থাকে; কোনো সার্ভার বা AI-তে যায় না। OTP, পিন বা পাসওয়ার্ডের মেসেজ রাখা হয় না। ৩০ দিন পর নিজে থেকে মুছে যায়।'),
                    style: body(12.5, color: C.muted, height: 1.5)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _settings(BuildContext context) async {
    final brain = BrainScope.read(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final on = brain.inboxAppsOn;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('কোন অ্যাপের মেসেজ পড়বে'), style: display(20, weight: 700)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('মেসেজ পড়া চালু'), style: body(16)),
                value: brain.inboxOn,
                onChanged: (v) async {
                  await brain.setInboxApps(on, on: v);
                  setS(() {});
                },
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in inboxAppNames)
                  FilterChip(
                    label: Text(a),
                    selected: on.contains(a),
                    onSelected: (v) async {
                      await brain.setInboxApps(v ? [...on, a] : [for (final x in on) if (x != a) x]);
                      setS(() {});
                    },
                  ),
              ]),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await confirmDialog(ctx, title: tr('সব মেসেজ মুছবেন?'), text: tr('এখানে রাখা মেসেজগুলো মুছে যাবে। মূল অ্যাপে কিছু বদলাবে না।'), yes: tr('মুছুন'), danger: true);
                  if (ok) {
                    await brain.clearInbox();
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(tr('সব মেসেজ মুছুন')),
              ),
              TextButton(onPressed: () => brain.services.inbox.openAccess(), child: Text(tr('ফোনের অনুমতির পাতা'))),
            ]),
          ),
        );
      }),
    );
  }
}

/// How to turn it on, and what it does with the messages (shown before access is given).
class _Setup extends StatelessWidget {
  const _Setup({required this.onDone});
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.greenTint, shape: BoxShape.circle),
              child: Text(n, style: body(13, weight: FontWeight.w700, color: C.green)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: body(14, color: C.muted2, height: 1.45))),
          ]),
        );
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.mark_chat_read_outlined, color: C.green, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('অন্য অ্যাপের মেসেজ থেকে কাজ'), style: display(18, weight: 700))),
        ]),
        const SizedBox(height: 8),
        Text(
            tr('WhatsApp, Telegram, imo, Messenger, Gmail, SMS-এ নতুন মেসেজ এলে সহকারী নোটিফিকেশন থেকে তা পড়বে, আর মিটিং, টাকা চাওয়া, বিল, উত্তর দেওয়ার মতো কাজগুলো আলাদা করে দেখাবে। এক চাপে রিমাইন্ডার বা কাজ বানাতে, এখান থেকেই উত্তর দিতে পারবেন।'),
            style: body(14.5, height: 1.5)),
        const SizedBox(height: 10),
        InfoBanner(
          icon: Icons.lock_outline_rounded,
          text: tr('মেসেজ শুধু এই ফোনে থাকে — কোনো সার্ভার বা AI-তে যায় না। OTP, পিন, পাসওয়ার্ডের মেসেজ রাখা হয় না। কোন অ্যাপ পড়বে আপনি বেছে দেবেন, যেকোনো সময় বন্ধ করা যায়। আগের পুরনো চ্যাট পড়া যায় না, শুধু নতুন আসা মেসেজ।'),
        ),
        const SizedBox(height: 6),
        step('১', tr('নিচের বোতাম চাপুন — ফোনের “Notification access” পাতা খুলবে।')),
        step('২', tr('“My Assistant” চালু করে “Allow” দিন, তারপর ফিরে আসুন।')),
        step('৩', tr('চালু করা না গেলে (“Restricted setting” লেখা এলে): অ্যাপের তথ্য পাতায় ডান-উপরের তিন-ফোঁটা মেনু চেপে “Allow restricted settings” দিন, তারপর আবার ১ নম্বর।')),
        const SizedBox(height: 14),
        PrimaryButton(
          label: tr('অনুমতি দিন'),
          icon: Icons.notifications_active_outlined,
          onPressed: () async {
            await brain.setInboxApps(brain.inboxAppsOn, on: true);
            await brain.services.inbox.openAccess();
            await onDone();
          },
        ),
        TextButton(onPressed: () => brain.services.inbox.openAppInfo(), child: Text(tr('অ্যাপের তথ্য পাতা (Restricted settings)'))),
      ]),
    );
  }
}

class _AppBadge extends StatelessWidget {
  const _AppBadge(this.app);
  final String app;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color fg, Color bg) = switch (app) {
      final a when a.startsWith('WhatsApp') => (Icons.chat_rounded, C.green, C.greenTint),
      final a when a.startsWith('Telegram') => (Icons.send_rounded, C.blue, C.blueTint),
      final a when a.startsWith('imo') => (Icons.videocam_outlined, C.teal, C.tealTint),
      final a when a.startsWith('Messenger') => (Icons.forum_outlined, C.purple, C.purpleTint),
      'Gmail' || 'Outlook' || 'Yahoo Mail' || 'Email' => (Icons.mail_outline_rounded, C.rose, C.roseTint),
      'SMS' => (Icons.sms_outlined, C.orange, C.orangeTint),
      _ => (Icons.chat_bubble_outline_rounded, C.ink, C.soft),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 21),
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({required this.message, required this.insight});
  final InboxMessage message;
  final InboxInsight insight;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.read(context);
    final c = insight.command;
    final keep = switch (insight.kind) {
      InboxKind.meeting => tr('রিমাইন্ডার রাখুন'),
      InboxKind.moneyIn => tr('আয়ে লিখুন'),
      InboxKind.moneyOut => tr('খরচে লিখুন'),
      _ => tr('কাজে রাখুন'),
    };
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _AppBadge(message.appName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(insight.kind.label, style: body(12.5, weight: FontWeight.w700, color: C.green)),
              Text(insight.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600, height: 1.35)),
            ]),
          ),
          IconButton(
            tooltip: tr('বাদ দিন'),
            visualDensity: VisualDensity.compact,
            onPressed: () => brain.setInboxState(message, 'dismissed'),
            icon: Icon(Icons.close_rounded, size: 20, color: C.muted),
          ),
        ]),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => showMessage(context, message),
          child: Text(message.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: body(13.5, color: C.muted2, height: 1.4)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (c != null)
            FilledButton.tonalIcon(
              onPressed: () async {
                final said = await brain.acceptInsight(message, c);
                if (context.mounted && said.isNotEmpty) toast(context, said);
              },
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: Text(keep),
            ),
          OutlinedButton.icon(
            onPressed: () => addFromMessage(context, message),
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: Text(tr('অন্যভাবে রাখুন')),
          ),
          // Bank and bKash notices cannot be answered.
          if (insight.kind != InboxKind.moneyIn && insight.kind != InboxKind.moneyOut)
            OutlinedButton.icon(
              onPressed: () => replyTo(context, message),
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: Text(tr('উত্তর দিন')),
            ),
        ]),
      ]),
    );
  }
}

/// The whole message, with reply and "open in the app".
Future<void> showMessage(BuildContext context, InboxMessage m) async {
  final brain = BrainScope.read(context);
  final now = brain.services.now();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _AppBadge(m.appName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.from.isNotEmpty ? m.from : m.chat, style: display(18, weight: 700)),
                Text('${m.appName}${m.group ? ' · ${m.chat}' : ''} · ${sayWhen(m.at, now)}', style: body(13, color: C.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
            child: SingleChildScrollView(child: SelectableText(m.text, style: body(16, height: 1.5))),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(ctx);
                addFromMessage(context, m);
              },
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: Text(tr('যুক্ত করুন')),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                replyTo(context, m);
              },
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: Text(tr('উত্তর দিন')),
            ),
            OutlinedButton.icon(
              onPressed: () => brain.services.inbox.openApp(m.app),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(trf('{0}-এ খুলুন', [m.appName])),
            ),
            TextButton.icon(
              onPressed: () {
                brain.deleteInboxMessage(m);
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: C.red),
              label: Text(tr('মুছুন'), style: body(14, color: C.red)),
            ),
          ]),
        ]),
      ),
    ),
  );
}

/// Replies with the message's own reply button (WhatsApp, Telegram…), or
/// opens the app when the message is no longer on the phone.
Future<void> replyTo(BuildContext context, InboxMessage m) async {
  final brain = BrainScope.read(context);
  final can = await brain.services.inbox.canReply(m);
  if (!context.mounted) return;
  if (!can) {
    toast(context, trf('এই মেসেজের উত্তর এখান থেকে দেওয়া যাচ্ছে না — {0} খুলছি।', [m.appName]));
    await brain.services.inbox.openApp(m.app);
    return;
  }
  final c = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(trf('{0}-কে উত্তর', [m.from.isNotEmpty ? m.from : m.chat]), style: display(18)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: body(13, color: C.muted)),
        const SizedBox(height: 10),
        TextField(controller: c, autofocus: true, minLines: 1, maxLines: 5, decoration: InputDecoration(hintText: tr('উত্তর লিখুন…'))),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in [tr('জি, ঠিক আছে।'), tr('একটু পরে জানাচ্ছি।'), tr('আসছি।'), tr('পরে ফোন দিচ্ছি।')])
            ActionChip(label: Text(q), onPressed: () => c.text = q),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(tr('পাঠান'), style: body(15, weight: FontWeight.w600, color: C.green))),
      ],
    ),
  );
  // (The controller is left to the garbage collector: the dialog is still
  // animating away and uses it for a few frames.)
  if (text == null || text.isEmpty || !context.mounted) return;
  final ok = await brain.services.inbox.reply(m, text);
  if (ok) await brain.setInboxState(m, 'replied');
  if (context.mounted) toast(context, ok ? trf('{0}-এ উত্তর পাঠালাম।', [m.appName]) : tr('পাঠানো গেল না — মূল অ্যাপ থেকে দিন।'));
}

/// Keep anything from a message: a to-do, a reminder, income, spending,
/// a loan or a customer's due, or a note — each opens its own form, filled
/// in from the message, to check and save.
Future<void> addFromMessage(BuildContext context, InboxMessage m) async {
  final brain = BrainScope.read(context);
  final now = brain.services.now();
  final insight = insightOf(m, now);
  final amount = findAmount(normalize(m.text));
  final when = parseWhen(m.text, m.at);
  final who = m.from.isNotEmpty ? m.from : m.chat;
  final short = m.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final title = short.length <= 60 ? '$who: $short' : '$who: ${short.substring(0, 60)}…';
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(tr('এই মেসেজ থেকে কী রাখবেন?'), style: display(18, weight: 700)),
        ),
        for (final (k, icon, label) in [
          ('task', Icons.checklist_rounded, tr('কাজের তালিকায়')),
          ('reminder', Icons.notifications_active_outlined, tr('রিমাইন্ডার')),
          ('income', Icons.south_west_rounded, tr('আয়')),
          ('expense', Icons.north_east_rounded, tr('খরচ')),
          ('ledger', Icons.payments_outlined, tr('লেনদেন (ধার / বাকি / পাওনা)')),
          ('note', Icons.sticky_note_2_outlined, tr('নোট')),
        ])
          ListTile(leading: Icon(icon, color: C.green), title: Text(label, style: body(16)), onTap: () => Navigator.pop(ctx, k)),
      ]),
    ),
  );
  if (pick == null || !context.mounted) return;
  final before = _count(brain.data);
  Future<void> push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
  switch (pick) {
    case 'task':
      final t = await _askTask(context, title, when != null && when.hasDay ? dayOnly(when.at) : null);
      if (t != null) await brain.saveTask(t);
    case 'reminder':
      await push(NewItemScreen(category: ItemCategory.reminder, presetTitle: title, presetAt: when != null && when.hasTime ? when.at : null));
    case 'income' || 'expense':
      await push(CashFormScreen(
        kind: pick == 'income' ? CashKind.income : CashKind.expense,
        amount: amount,
        note: short,
        date: m.at,
        category: insight?.command is CashAdd ? (insight!.command as CashAdd).category : null,
      ));
    case 'ledger':
      await push(LedgerFormScreen(person: who, amount: amount, note: short));
    case 'note':
      await push(NewItemScreen(category: ItemCategory.note, presetTitle: trf('{0} — {1}', [who, m.appName]), presetBody: m.text));
  }
  if (_count(brain.data) != before) {
    await brain.setInboxState(m, 'saved');
    if (context.mounted) toast(context, tr('রেখে দিলাম।'));
  }
}

int _count(AppData d) => d.tasks.length + d.reminders.length + d.cash.length + d.ledger.length + d.notes.length;

/// A to-do from a message: its words and a day, to check before saving.
Future<Task?> _askTask(BuildContext context, String title, DateTime? due) async {
  final c = TextEditingController(text: title);
  var day = due;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(tr('কাজের তালিকায় রাখুন'), style: display(18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, minLines: 1, maxLines: 4, decoration: InputDecoration(labelText: tr('কাজ'))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final p = await showDatePicker(context: ctx, initialDate: day ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
              if (p != null) setD(() => day = p);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(day == null ? tr('তারিখ (ঐচ্ছিক)') : fullDate(day!)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('বাতিল'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('রাখুন'), style: body(15, weight: FontWeight.w600, color: C.green))),
        ],
      ),
    ),
  );
  final text = c.text.trim();
  if (ok != true || text.isEmpty) return null;
  return Task(title: text, due: day);
}
