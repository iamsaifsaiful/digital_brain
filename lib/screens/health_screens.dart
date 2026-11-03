import 'package:flutter/material.dart';
import '../ui/secure.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import 'family_screen.dart' show sendMedicineToFamily;
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/medicine_times.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/pdf_export.dart';

/// Today's habits as tick chips (for দিনলিপি).
class HabitStrip extends StatelessWidget {
  const HabitStrip({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final h in brain.data.habits)
        FilterChip(
          selected: h.doneOn(day),
          onSelected: (_) => brain.toggleHabit(h, day),
          avatar: Icon(h.doneOn(day) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: h.doneOn(day) ? C.green : C.muted),
          label: Text(h.streak(now) > 1 ? '${h.name} · ${trf('{0} দিন', [bnDigits(h.streak(now))])}' : h.name),
          labelStyle: body(14, weight: FontWeight.w500, color: h.doneOn(day) ? C.greenDark : C.ink),
          showCheckmark: false,
        ),
    ]);
  }
}

/// Today's doses as tick chips (for দিনলিপি).
class DoseStrip extends StatelessWidget {
  const DoseStrip({super.key, required this.day, this.member});
  final DateTime day;

  /// Only this person's ([FamilyMember.id]); null: everyone's, with the name on others'.
  final String? member;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final m in brain.data.medicines)
        if ((member == null || m.member == member) && (m.until == null || !dayOnly(day).isAfter(dayOnly(m.until!))))
          for (final t in m.times)
            FilterChip(
              selected: m.takenAt(day, t),
              onSelected: (_) => brain.toggleDose(m, day, t),
              avatar: Icon(m.takenAt(day, t) ? Icons.check_circle_rounded : Icons.medication_outlined, size: 18, color: m.takenAt(day, t) ? C.green : C.muted2),
              label: Text(member == null && m.member != FamilyMember.meId ? '${brain.personById(m.member).name}: ${m.name} · ${minutesText(t)}' : '${m.name} · ${minutesText(t)}'),
              labelStyle: body(14, weight: FontWeight.w500, color: m.takenAt(day, t) ? C.greenDark : C.ink),
              showCheckmark: false,
            ),
    ]);
  }
}

// ───────────────────────── Habits ─────────────────────────

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  /// The habit's "করেছেন কি?" is on (or its older plain daily reminder).
  static bool _asks(Habit h) => h.askAt != null || h.reminderId != null;

  /// Turn on (or move) the daily "করেছেন কি?" — the user's own choice.
  static Future<void> _ask(BuildContext context, Habit h) async {
    final brain = BrainScope.read(context);
    final r = h.reminderId == null ? null : brain.reminderById(h.reminderId!);
    final m = await askTime(context, h.askAt ?? (r == null ? 21 * 60 : r.hour * 60 + r.minute));
    if (m == null) return;
    await brain.setHabitAsk(h, m);
    if (context.mounted) toast(context, trf('প্রতিদিন {0}-এ জিজ্ঞেস করবো — টিক দেওয়া থাকলে করবো না', [bnTime(m ~/ 60, m % 60)]));
  }

  Future<void> _add(BuildContext context) async {
    final brain = BrainScope.read(context);
    final name = await askText(context, tr('নতুন অভ্যাস'), hint: tr('যেমন: সকালে হাঁটা, ৮ গ্লাস পানি, কুরআন পড়া'));
    if (name == null || name.isEmpty) return;
    await brain.saveHabit(Habit(name: name, createdAt: brain.services.now()));
  }

  Future<void> _menu(BuildContext context, Habit h) async {
    final brain = BrainScope.read(context);
    final pick = await showAppSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.alarm_rounded), title: Text(!_asks(h) ? tr('প্রতিদিন জিজ্ঞেস করুক “করেছেন কি?”') : tr('জিজ্ঞেস করার সময় বদলান')), onTap: () => Navigator.pop(ctx, 0)),
          if (_asks(h)) ListTile(leading: const Icon(Icons.alarm_off_rounded), title: Text(tr('জিজ্ঞেস করা বন্ধ')), onTap: () => Navigator.pop(ctx, 1)),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('নাম বদলান')), onTap: () => Navigator.pop(ctx, 2)),
          ListTile(leading: Icon(Icons.delete_outline_rounded, color: C.red), title: Text(tr('মুছে ফেলুন'), style: TextStyle(color: C.red)), onTap: () => Navigator.pop(ctx, 3)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    switch (pick) {
      case 0:
        await _ask(context, h);
      case 1:
        await brain.setHabitAsk(h, null);
      case 2:
        final n = await askText(context, tr('নাম বদলান'), initial: h.name);
        if (n != null && n.isNotEmpty) await brain.saveHabit(h.copyWith(name: n));
      case 3:
        if (await confirmDialog(context, title: tr('মুছবেন?'), text: trf('“{0}” আর এর সব দিনের হিসাব মুছে যাবে।', [h.name]), yes: tr('মুছুন'), danger: true)) {
          await brain.deleteHabit(h);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final week = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    return Scaffold(
      floatingActionButton: AddButton(label: tr('অভ্যাস যোগ'), onPressed: () => _add(context)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('অভ্যাস'), trailing: const [PdfButton({ReportPart.health})]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              if (brain.data.habits.isEmpty)
                EmptyState(icon: Icons.local_fire_department_outlined, title: tr('ভালো অভ্যাস গড়ুন'), text: tr('প্রতিদিন টিক দিন — টানা কত দিন হলো দেখাবে, চাইলে রোজ নির্দিষ্ট সময়ে মনে করাবো।'))
              else
                for (final h in brain.data.habits) ...[
                  Panel(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(h.name, style: body(16, weight: FontWeight.w600))),
                        // Off unless the user turns it on (owner, 28 Oct).
                        IconButton(
                          key: Key('habit-ask-${h.id}'),
                          tooltip: _asks(h) && h.askAt != null ? trf('প্রতিদিন {0}-এ জিজ্ঞেস করবে', [bnTime(h.askAt! ~/ 60, h.askAt! % 60)]) : tr('“করেছেন কি?” নোটিফিকেশন'),
                          onPressed: () => _asks(h) ? _menu(context, h) : _ask(context, h),
                          icon: Icon(_asks(h) ? Icons.alarm_on_rounded : Icons.alarm_add_outlined, color: _asks(h) ? C.green : C.muted, size: 21),
                        ),
                        IconButton(tooltip: tr('আরও'), onPressed: () => _menu(context, h), icon: Icon(Icons.more_horiz_rounded, color: C.muted)),
                      ]),
                      Text(
                        [
                          h.streak(now) > 0 ? trf('টানা {0} দিন · সেরা {1} দিন', [bnDigits(h.streak(now)), bnDigits(h.best())]) : tr('আজ থেকে শুরু করুন'),
                          if (h.askAt != null) trf('রোজ {0}-এ জিজ্ঞেস', [bnTime(h.askAt! ~/ 60, h.askAt! % 60)]),
                        ].join(' · '),
                        style: body(13.5, color: h.streak(now) > 0 ? C.orange : C.muted, weight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        for (final d in week)
                          Expanded(
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => brain.toggleHabit(h, d),
                              child: Column(children: [
                                Text(weekdayShort(d), style: body(11, color: C.muted)),
                                const SizedBox(height: 4),
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: h.doneOn(d) ? C.green : Colors.transparent,
                                    border: Border.all(color: h.doneOn(d) ? C.green : (d == today ? C.green : C.line), width: 1.5),
                                  ),
                                  child: h.doneOn(d) ? Icon(Icons.check_rounded, size: 18, color: C.onAccent) : null,
                                ),
                              ]),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Medicines ─────────────────────────

/// ওষুধের সময়সূচি of one person in স্বাস্থ্য: the user's own, or a family
/// member's (owner, 24 Oct night) — their list, today's doses, adding one
/// (it rings on this phone), and, when that person is in ফ্যামিলি and
/// allows it, sending the reminder to their own phone (sealed).
class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key, this.member = FamilyMember.meId});
  final String member;

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final me = member == FamilyMember.meId;
    final who = brain.personById(member);
    final meds = [for (final m in brain.data.medicines) if (m.member == member) m];
    final senders = [for (final l in brain.family.links) if (l.active && l.theyAllow.contains('medicine')) l];
    return Scaffold(
      floatingActionButton: AddButton(label: tr('ওষুধ যোগ'), onPressed: () => editMedicine(context, null, member: member)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: me ? tr('ওষুধের সময়সূচি') : trf('{0}-এর ওষুধ', [who.name]), trailing: const [PdfButton({ReportPart.health})]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              if (!me && senders.isNotEmpty) ...[
                Panel(
                  child: ListRow(
                    key: const Key('med-send-family'),
                    leading: Icon(Icons.send_to_mobile_outlined, color: C.green),
                    title: tr('ওঁর নিজের ফোনেও রিমাইন্ডার দিন'),
                    subtitle: tr('ফ্যামিলিতে যুক্ত থাকলে ওঁর ফোনে বাজবে — তালাবদ্ধ হয়ে যায়'),
                    trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                    onTap: () => sendMedicineToFamily(context, senders),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (meds.isEmpty)
                EmptyState(
                  icon: Icons.medication_outlined,
                  title: tr('কোনো ওষুধ রাখা নেই'),
                  text: me
                      ? tr('ওষুধের নাম, দিনে কয়বার আর কয়টা আছে লিখুন — সময়মতো বাজবে, খেলে টিক দিন, ফুরানোর আগে মনে করাবো।')
                      : trf('{0}-এর ওষুধের নাম আর সময় লিখুন — সময়মতো আপনার ফোনে বাজবে, যেন খাইয়ে দিতে বা মনে করিয়ে দিতে পারেন।', [who.name]),
                )
              else ...[
                SectionTitle(tr('আজ')),
                Panel(padding: const EdgeInsets.all(12), child: DoseStrip(day: now, member: member)),
                const SizedBox(height: 14),
                for (final m in meds) ...[
                  Panel(
                    child: ListRow(
                      leading: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.roseTint, borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.medication_outlined, color: C.green, size: 22),
                      ),
                      title: m.name,
                      subtitle: [
                        m.times.map(minutesText).join(', '),
                        if (m.dose > 1) trf('{0}টা করে', [bnDigits(m.dose)]),
                        if (m.meal.isNotEmpty) mealText(m.meal),
                        if (m.daysLeft != null) m.daysLeft == 0 ? tr('আজই ফুরাবে') : trf('আর {0} দিনের', [bnDigits(m.daysLeft!)]),
                        if (m.until != null) trf('{0} পর্যন্ত', [shortDate(m.until!)]),
                      ].join(' · '),
                      subtitleColor: (m.daysLeft ?? 99) <= 5 ? C.orange : null,
                      trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                      onTap: () => editMedicine(context, m),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> editMedicine(BuildContext context, Medicine? old, {String member = FamilyMember.meId}) =>
    showAppSheet<void>(context: context, isScrollControlled: true, builder: (_) => _MedicineSheet(old: old, member: old?.member ?? member));

class _MedicineSheet extends StatefulWidget {
  const _MedicineSheet({this.old, this.member = FamilyMember.meId});
  final Medicine? old;
  final String member;
  @override
  State<_MedicineSheet> createState() => _MedicineSheetState();
}

class _MedicineSheetState extends State<_MedicineSheet> {
  late final _name = TextEditingController(text: widget.old?.name ?? '');
  late final _stock = TextEditingController(text: (widget.old?.stock ?? 0) > 0 ? '${widget.old!.stock}' : '');
  late final _note = TextEditingController(text: widget.old?.note ?? '');
  late List<int> _times = [...?widget.old?.times];
  late int _dose = widget.old?.dose ?? 1;
  late DateTime? _until = widget.old?.until;
  late String _member = widget.member;
  late String _meal = widget.old?.meal ?? '';

  @override
  void initState() {
    super.initState();
    if (_times.isEmpty) _times = [9 * 60, 21 * 60];
  }

  @override
  void dispose() {
    _name.dispose();
    _stock.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty || _times.isEmpty) {
      toast(context, tr('নাম আর অন্তত একটা সময় দিন'));
      return;
    }
    final base = widget.old ?? Medicine(name: name, member: _member);
    await brain.saveMedicine(base.copyWith(
      member: _member,
      name: name,
      dose: _dose,
      times: [..._times]..sort(),
      stock: readInt(_stock.text) ?? 0,
      note: _note.text.trim(),
      until: _until,
      clearUntil: _until == null,
      meal: _meal,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.old == null ? tr('নতুন ওষুধ') : tr('ওষুধ বদলান'), style: display(20, weight: 700)),
          // Owner, 29 Oct: whose first, then the name, then before or after
          // food, then how many times a day, then the times.
          FieldLabel(tr('কার জন্য')),
          MedicinePersonPicker(
            people: [for (final m in BrainScope.of(context).healthPeople) (m.id, m.isMe ? tr('আমি') : m.name)],
            selected: _member,
            onChanged: (id) => setState(() => _member = id),
          ),
          FieldLabel(tr('ওষুধের নাম')),
          TextField(key: const Key('med-name'), controller: _name, autofocus: widget.old == null, decoration: InputDecoration(hintText: tr('যেমন: নাপা, সেকলো'))),
          FieldLabel(tr('খাবারের আগে না পরে')),
          MealPicker(meal: _meal, onChanged: (v) => setState(() => _meal = v)),
          const SizedBox(height: 14),
          MedicineTimesPicker(times: _times, onChanged: (t) => setState(() => _times = t)),
          FieldLabel(trf('প্রতিবার কয়টা: {0}', [bnDigits(_dose)])),
          Row(children: [
            IconButton(onPressed: _dose > 1 ? () => setState(() => _dose--) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
            Text(bnDigits(_dose), style: display(20)),
            IconButton(onPressed: () => setState(() => _dose++), icon: const Icon(Icons.add_circle_outline_rounded)),
          ]),
          FieldLabel(tr('এখন কয়টা আছে (ঐচ্ছিক)')),
          TextField(controller: _stock, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: tr('দিলে ফুরানোর আগে মনে করাবো'))),
          FieldLabel(tr('কোর্স কবে শেষ (ঐচ্ছিক)')),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(context: context, initialDate: _until ?? now.add(const Duration(days: 7)), firstDate: now, lastDate: DateTime(now.year + 5));
              setState(() => _until = d);
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(_until == null ? tr('চলতেই থাকবে') : fullDate(_until!)),
          ),
          FieldLabel(tr('নোট (ঐচ্ছিক)')),
          TextField(controller: _note, decoration: InputDecoration(hintText: tr('যেমন: পানির সাথে'))),
          const SizedBox(height: 16),
          PrimaryButton(label: tr('রাখুন'), onPressed: _save),
          if (widget.old != null)
            TextButton(
              onPressed: () async {
                await BrainScope.read(context).deleteMedicine(widget.old!);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(tr('মুছে ফেলুন'), style: body(15, weight: FontWeight.w600, color: C.red)),
            ),
        ]),
      ),
    );
  }
}
