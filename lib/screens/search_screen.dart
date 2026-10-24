import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../logic/search.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'docs_screen.dart';
import 'special_days_screen.dart';
import '../logic/proactive.dart';
import 'home_shell.dart';
import 'new_item_screen.dart';
import 'person_screen.dart';
import 'plan_screens.dart';
import 'vault_item_screen.dart';
import '../logic/lang.dart';
import '../logic/answers.dart' show taskWhen;

/// One box that finds anything: people and numbers, money, reminders,
/// to-dos, notes and logins — typed or (through the assistant) spoken.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initial = ''});
  final String initial;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _q = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _openVault(VaultItem v) async {
    final ok = await verifyUser(context, reason: trf('{0} — তথ্য দেখতে যাচাই করুন', [v.name]));
    if (ok && mounted) _push(VaultItemScreen(id: v.id));
  }

  Widget _group(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text(title, style: body(13, weight: FontWeight.w600, color: C.muted))),
        Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (i, r) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
              r,
            ],
          ]),
        ),
      ]);

  Widget _row(IconData icon, Color fg, Color bg, String title, String sub, VoidCallback onTap, {Widget? trailing}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            IconSquare(icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600)),
                if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              ]),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final q = _q.text.trim();
    final terms = q.isEmpty ? const <String>[] : searchTerms(normalize(q));
    final useTerms = terms.isEmpty && q.isNotEmpty ? [normalize(q)] : terms;
    final hits = useTerms.isEmpty ? const <Hit>[] : searchAll(d, useTerms);
    final tasks = useTerms.isEmpty ? const <Task>[] : matchTasks(d.tasks, useTerms);

    final contacts = [for (final h in hits) if (h is ContactHit) h.contact];
    final people = [for (final h in hits) if (h is PersonHit) h.person];
    final reminders = [for (final h in hits) if (h is ReminderHit) h.reminder];
    final notes = [for (final h in hits) if (h is NoteHit) h.note];
    final vault = [for (final h in hits) if (h is VaultHit) h.item];
    List<String> tagsOf(String k) => d.tags[k] ?? const [];
    final docs = useTerms.isEmpty
        ? const <Doc>[]
        : [for (final h in hits) if (h is DocHit) h.doc];
    // Notes found by a tag ("#গাড়ি" or just "গাড়ি").
    final tagged = useTerms.isEmpty
        ? const <Note>[]
        : d.notes.where((n) => !notes.contains(n) && score(useTerms.map((t) => t.replaceAll('#', '')).toList(), tagsOf('note:${n.id}')) > 0).toList();
    notes.addAll(tagged);
    final specials = useTerms.isEmpty ? const <SpecialDay>[] : d.specialDays.where((x) => score(useTerms, [x.person, x.kind.bn, x.kind.en, x.note]) > 0).toList();
    final total = contacts.length + people.length + reminders.length + notes.length + vault.length + tasks.length + docs.length + specials.length;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
            child: Row(children: [
              IconButton(tooltip: tr('ফিরে যান'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left_rounded, size: 30)),
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.ink, width: 1.6)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: C.muted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _q,
                        autofocus: widget.initial.isEmpty,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (t) {
                          if (t.trim().isNotEmpty) openChatWith(context, t.trim());
                        },
                        style: body(16),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: tr('খুঁজুন, রাখুন বা জিজ্ঞেস করুন…'),
                          hintStyle: body(15, color: C.muted),
                        ),
                      ),
                    ),
                    if (q.isNotEmpty)
                      IconButton(
                        tooltip: tr('সহকারীকে পাঠান'),
                        onPressed: () => openChatWith(context, q),
                        icon: Icon(Icons.send_rounded, color: C.ink),
                      )
                    else
                      IconButton(
                        tooltip: tr('বলে খুঁজুন'),
                        onPressed: () => openVoice(context),
                        icon: Icon(Icons.mic_none_rounded, color: C.ink),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (q.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tr('যা খুঁজবেন লিখুন — যেমন “রহিম”, “গাড়ির কাগজ”। নিচে সাথে সাথে মিলে যাওয়া জিনিস দেখাবে। কিছু রাখতে বা জিজ্ঞেস করতে লিখে পাঠান (➤) — যেমন “রহিমকে ৫০০ টাকা দিলাম”।'),
                        textAlign: TextAlign.center, style: body(14, color: C.muted, height: 1.5)),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Material(
                    color: C.greenTint,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => openChatWith(context, q),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Row(children: [
                          Icon(Icons.auto_awesome_rounded, color: C.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(trf('সহকারীকে জিজ্ঞেস করুন: “{0}”', [q]), style: body(14.5, weight: FontWeight.w500, color: C.greenDark))),
                          Icon(Icons.chevron_right_rounded, color: C.greenDark),
                        ]),
                      ),
                    ),
                  ),
                  if (total == 0)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(trf('“{0}” নামে কিছু পাওয়া যায়নি।', [q]), textAlign: TextAlign.center, style: body(14, color: C.muted)),
                    ),
                  if (contacts.isNotEmpty)
                    _group(trf('যোগাযোগ · {0}', [bnDigits(contacts.length)]), [
                      for (final c in contacts.take(8))
                        _row(Icons.person_outline_rounded, C.purple, C.purpleTint, c.name, c.phone.isEmpty ? c.note : showPhone(c.phone), () {
                          if (c.phone.isNotEmpty) brain.services.launcher.open(Via.call, c.phone);
                        }, trailing: c.phone.isEmpty ? null : Icon(Icons.call_outlined, color: C.ink)),
                    ]),
                  if (people.isNotEmpty)
                    _group(trf('হিসাব · {0}', [bnDigits(people.length)]), [
                      for (final p in people.take(6))
                        _row(Icons.payments_outlined, C.teal, C.tealTint, p, owesText(p, balanceWith(d.ledger, p)),
                            () => _push(PersonScreen(person: p))),
                    ]),
                  if (reminders.isNotEmpty || tasks.isNotEmpty)
                    _group(tr('রিমাইন্ডার ও কাজ'), [
                      for (final r in reminders.take(6))
                        _row(Icons.notifications_none_rounded, C.orange, C.orangeTint, r.title,
                            '${weekdayName(r.nextDate(now))}, ${bnDigits(r.nextDate(now).day)} ${monthName(r.nextDate(now).month)} · ${bnTime(r.hour, r.minute)}',
                            () => _push(NewItemScreen(reminder: r))),
                      for (final t in tasks.take(6))
                        _row(Icons.checklist_rounded, C.green, C.greenTint, t.title, t.done ? tr('শেষ হয়েছে') : (t.due == null ? tr('কাজ') : trf('কাজ · {0}', [taskWhen(t, now) ?? ''])),
                            () => editTask(context, t)),
                    ]),
                  if (notes.isNotEmpty)
                    _group(trf('নোট · {0}', [bnDigits(notes.length)]), [
                      for (final n in notes.take(8))
                        _row(Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, n.title, '${n.category} · ${n.body.replaceAll('\n', ' ')}', () => _push(NewItemScreen(note: n))),
                    ]),
                  if (docs.isNotEmpty)
                    _group(trf('ডকুমেন্টস · {0}', [bnDigits(docs.length)]), [
                      for (final x in docs.take(6))
                        _row(Icons.folder_copy_outlined, C.blue, C.blueTint, x.title, trf('{0} · {1} পাতা', [x.folder, bnDigits(x.files.length)]), () async {
                          final ok = await verifyUser(context, reason: trf('{0} — দেখতে যাচাই করুন', [x.title]));
                          if (ok && context.mounted) _push(DocScreen(id: x.id, unlocked: true));
                        }),
                    ]),
                  if (specials.isNotEmpty)
                    _group(tr('বিশেষ দিন'), [
                      for (final x in specials.take(6))
                        _row(Icons.cake_outlined, C.purple, C.purpleTint, specialTitle(x, on: x.next(now)),
                            '${bnDigits(x.next(now).day)} ${monthName(x.next(now).month)}', () => editSpecialDay(context, x)),
                    ]),
                  if (vault.isNotEmpty)
                    _group(trf('পাসওয়ার্ড · {0}', [bnDigits(vault.length)]), [
                      for (final v in vault.take(6))
                        _row(Icons.lock_outline_rounded, C.ink, C.soft, v.name, tr('তালাবদ্ধ — খুলতে আঙুলের ছাপ বা PIN'), () => _openVault(v)),
                    ]),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
