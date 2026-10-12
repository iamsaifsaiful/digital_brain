import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../logic/search.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import 'home_shell.dart';
import 'new_item_screen.dart';
import 'person_screen.dart';
import 'plan_screens.dart';
import 'vault_item_screen.dart';

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
    final ok = await verifyUser(context, reason: '${v.name} — তথ্য দেখতে যাচাই করুন');
    if (ok && mounted) _push(VaultItemScreen(id: v.id));
  }

  Widget _group(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text(title, style: body(13, weight: FontWeight.w600, color: C.muted))),
        Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (i, r) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
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
            Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600)),
                if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              ]),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: C.muted),
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
    final total = contacts.length + people.length + reminders.length + notes.length + vault.length + tasks.length;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
            child: Row(children: [
              IconButton(tooltip: 'ফিরে যান', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left_rounded, size: 30)),
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.green, width: 1.6)),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: C.muted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _q,
                        autofocus: widget.initial.isEmpty,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        style: body(16),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'নাম, নম্বর, নোট, কাজ…',
                          hintStyle: body(15, color: C.muted),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'বলে খুঁজুন',
                      onPressed: () => openVoice(context),
                      icon: const Icon(Icons.mic_none_rounded, color: C.green),
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
                    child: Text('যা খুঁজবেন লিখুন — যেমন “রহিম”, “গাড়ির কাগজ”, “বিদ্যুৎ বিল”। মুখে জিজ্ঞেস করতে মাইক চাপুন।',
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
                          const Icon(Icons.auto_awesome_rounded, color: C.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('সহকারীকে জিজ্ঞেস করুন: “$q”', style: body(14.5, weight: FontWeight.w500, color: C.greenDark))),
                          const Icon(Icons.chevron_right_rounded, color: C.greenDark),
                        ]),
                      ),
                    ),
                  ),
                  if (total == 0)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('“$q” নামে কিছু পাওয়া যায়নি।', textAlign: TextAlign.center, style: body(14, color: C.muted)),
                    ),
                  if (contacts.isNotEmpty)
                    _group('যোগাযোগ · ${bnDigits(contacts.length)}', [
                      for (final c in contacts.take(8))
                        _row(Icons.person_outline_rounded, C.purple, C.purpleTint, c.name, c.phone.isEmpty ? c.note : showPhone(c.phone), () {
                          if (c.phone.isNotEmpty) brain.services.launcher.open(Via.call, c.phone);
                        }, trailing: c.phone.isEmpty ? null : const Icon(Icons.call_outlined, color: C.green)),
                    ]),
                  if (people.isNotEmpty)
                    _group('হিসাব · ${bnDigits(people.length)}', [
                      for (final p in people.take(6))
                        _row(Icons.swap_horiz_rounded, const Color(0xFF0F766E), const Color(0xFFE6F6F4), p, owesText(p, balanceWith(d.ledger, p)),
                            () => _push(PersonScreen(person: p))),
                    ]),
                  if (reminders.isNotEmpty || tasks.isNotEmpty)
                    _group('রিমাইন্ডার ও কাজ', [
                      for (final r in reminders.take(6))
                        _row(Icons.notifications_none_rounded, C.orange, C.orangeTint, r.title,
                            '${weekdayName(r.nextDate(now))}, ${bnDigits(r.nextDate(now).day)} ${bnMonths[r.nextDate(now).month - 1]} · ${bnTime(r.hour, r.minute)}',
                            () => _push(NewItemScreen(reminder: r))),
                      for (final t in tasks.take(6))
                        _row(Icons.checklist_rounded, C.green, C.greenTint, t.title, t.done ? 'শেষ হয়েছে' : (t.due == null ? 'কাজ' : 'কাজ · ${bnDigits(t.due!.day)} ${bnMonths[t.due!.month - 1]}'),
                            () => editTask(context, t)),
                    ]),
                  if (notes.isNotEmpty)
                    _group('নোট · ${bnDigits(notes.length)}', [
                      for (final n in notes.take(8))
                        _row(Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, n.title, '${n.category} · ${n.body.replaceAll('\n', ' ')}', () => _push(NewItemScreen(note: n))),
                    ]),
                  if (vault.isNotEmpty)
                    _group('পাসওয়ার্ড · ${bnDigits(vault.length)}', [
                      for (final v in vault.take(6))
                        _row(Icons.lock_outline_rounded, C.ink, const Color(0xFFF1F2F4), v.name, 'তালাবদ্ধ — খুলতে আঙুলের ছাপ বা PIN', () => _openVault(v)),
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
