import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/proactive.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/pdf_export.dart';

/// বিশেষ দিন: birthdays, wedding anniversaries, death anniversaries —
/// each reminded every year, the day before and on the day.
class SpecialDaysScreen extends StatelessWidget {
  const SpecialDaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final days = [...brain.data.specialDays]..sort((a, b) => a.next(now).compareTo(b.next(now)));
    final thisMonth = days.where((s) => s.next(now).difference(today).inDays < 31).toList();
    final later = days.where((s) => s.next(now).difference(today).inDays >= 31).toList();

    return Scaffold(
      floatingActionButton: AddButton(label: tr('বিশেষ দিন যোগ'), onPressed: () => editSpecialDay(context, null)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('বিশেষ দিন'), trailing: const [PdfButton({ReportPart.specialDays})]),
          Expanded(
            child: days.isEmpty
                ? ListView(padding: const EdgeInsets.all(20), children: [
                    EmptyState(
                      icon: Icons.cake_outlined,
                      title: tr('কোনো বিশেষ দিন রাখা নেই'),
                      text: tr('জন্মদিন, বিবাহবার্ষিকী, মৃত্যুবার্ষিকী — রেখে দিন, প্রতি বছর আগের দিন আর সেদিন সকালে মনে করিয়ে দেবো। মুখেও বলা যায়: “রহিমের জন্মদিন ১২ মার্চ”।'),
                      action: tr('প্রথমটা যোগ করুন'),
                      onAction: () => editSpecialDay(context, null),
                    ),
                  ])
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
                    if (thisMonth.isNotEmpty) ...[
                      SectionTitle(tr('সামনের ৩০ দিনে')),
                      Panel(child: Rows(children: [for (final s in thisMonth) _row(context, s, now)])),
                      const SizedBox(height: 16),
                    ],
                    if (later.isNotEmpty) ...[
                      SectionTitle(tr('পরে')),
                      Panel(child: Rows(children: [for (final s in later) _row(context, s, now)])),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, SpecialDay s, DateTime now) {
    final next = s.next(now);
    final left = dayOnly(next).difference(dayOnly(now)).inDays;
    final when = left == 0 ? tr('আজ') : (left == 1 ? tr('কাল') : trf('{0} দিন পর', [bnDigits(left)]));
    final brain = BrainScope.read(context);
    return ListRow(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: left <= 1 ? C.roseTint : C.greenTint, borderRadius: BorderRadius.circular(12)),
        child: Text(s.kind.mark, style: const TextStyle(fontSize: 20)),
      ),
      title: specialTitle(s, on: next),
      subtitle: '${bnDigits(next.day)} ${monthName(next.month)} · $when',
      subtitleColor: left <= 1 ? C.rose : null,
      trailing: s.phone.isEmpty || s.kind == SpecialKind.deathday
          ? Icon(Icons.chevron_right_rounded, color: C.muted)
          : IconButton(
              tooltip: tr('শুভেচ্ছা পাঠান'),
              icon: Icon(Icons.celebration_outlined, color: C.green),
              onPressed: () => brain.services.launcher.open(Via.whatsapp, s.phone, text: wishText(s)),
            ),
      onTap: () => editSpecialDay(context, s),
    );
  }
}

/// A ready greeting to send on the day.
String wishText(SpecialDay s) => switch (s.kind) {
      SpecialKind.birthday => tr('শুভ জন্মদিন! আপনার জীবন আনন্দ, সুস্থতা আর সাফল্যে ভরে উঠুক। অনেক অনেক শুভকামনা।'),
      SpecialKind.anniversary => tr('শুভ বিবাহবার্ষিকী! আপনাদের দুজনের পথচলা ভালোবাসা আর আনন্দে ভরে থাকুক।'),
      _ => tr('আজকের বিশেষ দিনে আপনাকে আন্তরিক শুভেচ্ছা।'),
    };

/// Adds or edits a special day in a sheet.
Future<void> editSpecialDay(BuildContext context, SpecialDay? old) async {
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SpecialSheet(old: old),
  );
}

class _SpecialSheet extends StatefulWidget {
  const _SpecialSheet({this.old});
  final SpecialDay? old;
  @override
  State<_SpecialSheet> createState() => _SpecialSheetState();
}

class _SpecialSheetState extends State<_SpecialSheet> {
  late final _person = TextEditingController(text: widget.old?.person ?? '');
  late final _phone = TextEditingController(text: widget.old?.phone ?? '');
  late final _note = TextEditingController(text: widget.old?.note ?? '');
  late SpecialKind _kind = widget.old?.kind ?? SpecialKind.birthday;
  late int? _month = widget.old?.month;
  late int? _day = widget.old?.day;
  late int? _year = widget.old?.year;
  late int _before = widget.old?.daysBefore ?? 1;

  @override
  void dispose() {
    _person.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final init = _month == null ? now : DateTime(_year ?? now.year, _month!, _day!.clamp(1, DateTime(_year ?? now.year, _month! + 1, 0).day));
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: tr('দিনটা বেছে নিন (বছর জানা না থাকলে যেকোনো বছর)'),
    );
    if (d == null) return;
    setState(() {
      _month = d.month;
      _day = d.day;
      _year = d.year < now.year ? d.year : null;
    });
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final person = _person.text.trim();
    if (person.isEmpty || _month == null) {
      toast(context, tr('নাম আর তারিখ দিন'));
      return;
    }
    final base = widget.old ?? SpecialDay(person: person, month: _month!, day: _day!);
    await brain.saveSpecialDay(base.copyWith(
      person: person,
      kind: _kind,
      month: _month,
      day: _day,
      year: _year,
      clearYear: _year == null,
      daysBefore: _before,
      phone: _phone.text.trim(),
      note: _note.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, inset + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.old == null ? tr('নতুন বিশেষ দিন') : tr('বিশেষ দিন বদলান'), style: display(20, weight: 700)),
          FieldLabel(tr('কী দিন')),
          ChoiceChips<SpecialKind>(
            items: [for (final k in SpecialKind.values) (k, '${k.mark} ${isEn ? k.en : k.bn}')],
            value: _kind,
            onChanged: (v) => setState(() => _kind = v),
          ),
          FieldLabel(_kind == SpecialKind.other ? tr('দিনটার নাম') : tr('কার')),
          TextField(
            controller: _person,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: _kind == SpecialKind.anniversary ? tr('যেমন: আমাদের, বা রহিম ও রুমা') : tr('যেমন: রহিম, আম্মা')),
          ),
          FieldLabel(tr('তারিখ')),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(_month == null ? tr('তারিখ বেছে নিন') : '${bnDigits(_day!)} ${monthName(_month!)}${_year == null ? '' : ' ${bnDigits(_year!)}'}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: C.ink),
          ),
          if (_month != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _year != null,
              onChanged: (v) => setState(() => _year = v == true ? (_year ?? DateTime.now().year - 1) : null),
              title: Text(tr('বছরও রাখুন (কত বছর হলো দেখাবে)'), style: body(14)),
            ),
          FieldLabel(tr('কবে মনে করাবো')),
          ChoiceChips<int>(
            items: [(0, tr('শুধু সেদিন')), (1, tr('আগের দিনও')), (3, tr('৩ দিন আগেও')), (7, tr('৭ দিন আগেও'))],
            value: _before,
            onChanged: (v) => setState(() => _before = v),
          ),
          if (_kind != SpecialKind.deathday) ...[
            FieldLabel(tr('মোবাইল নম্বর (শুভেচ্ছা পাঠাতে, ঐচ্ছিক)')),
            TextField(controller: _phone, keyboardType: TextInputType.phone),
          ],
          FieldLabel(tr('নোট (ঐচ্ছিক)')),
          TextField(controller: _note, decoration: InputDecoration(hintText: tr('যেমন: উপহার কিনতে হবে'))),
          const SizedBox(height: 18),
          PrimaryButton(label: tr('রাখুন'), onPressed: _save),
          if (widget.old != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final brain = BrainScope.read(context);
                await brain.deleteSpecialDay(widget.old!);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(tr('মুছে ফেলুন'), style: body(15, weight: FontWeight.w600, color: C.red)),
            ),
          ],
        ]),
      ),
    );
  }
}
