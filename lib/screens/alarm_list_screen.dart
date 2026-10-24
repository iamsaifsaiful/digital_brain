import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'alarm_screens.dart';
import '../logic/lang.dart';

/// Short names, Saturday first (the Bangladesh week).
const _dayOrder = [DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday];
final _dayShort = {
  DateTime.saturday: tr('শ'),
  DateTime.sunday: tr('র'),
  DateTime.monday: tr('সো'),
  DateTime.tuesday: tr('ম'),
  DateTime.wednesday: tr('বু'),
  DateTime.thursday: tr('বৃ'),
  DateTime.friday: tr('শু'),
};

/// "প্রতিদিন", "শুক্রবার বাদে প্রতিদিন", "শুক্র, শনি", "একবার — কাল".
String alarmDaysText(Reminder r, DateTime now) {
  if (r.repeat == Repeat.daily) return tr('প্রতিদিন');
  if (r.repeat == Repeat.weekly) {
    final days = r.ringDays;
    if (days.length == 7) return tr('প্রতিদিন');
    if (days.length == 6) return trf('{0} বাদে প্রতিদিন', [dayName(_dayOrder.firstWhere((d) => !days.contains(d)))]);
    return [for (final d in _dayOrder) if (days.contains(d)) weekdayShort(DateTime(2026, 10, 12 + (d - 1)))].join(', ');
  }
  if (r.repeat == Repeat.none) {
    final day = DateTime(r.date.year, r.date.month, r.date.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    return trf('একবার — {0}', [diff == 0 ? 'আজ' : diff == 1 ? 'কাল' : '${bnDigits(day.day)} ${monthShort(day.month)}']);
  }
  return r.repeat.label;
}

/// অ্যালার্ম: big times with an on/off switch, like a clock app.
class AlarmsScreen extends StatelessWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final alarms = brain.data.reminders.where((r) => r.alarm).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    final on = alarms.where((r) => r.enabled && (r.repeat != Repeat.none || r.notifyAt(now).isAfter(now))).toList()
      ..sort((a, b) => a.notifyAt(now).compareTo(b.notifyAt(now)));
    final next = on.isEmpty ? null : on.first;
    String inText(DateTime at) {
      final m = at.difference(now).inMinutes;
      final h = m ~/ 60;
      return h == 0 ? trf('{0} মিনিট পর', [bnDigits(m)]) : trf('{0} ঘণ্টা {1} মিনিট পর', [bnDigits(h), bnDigits(m % 60)]);
    }

    void open([Reminder? r]) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: r)));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: tr('নতুন অ্যালার্ম'),
        backgroundColor: C.fill,
        foregroundColor: Colors.white,
        onPressed: open,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('অ্যালার্ম'), sub: tr('ফোন লক থাকলেও ঠিক সময়ে বাজবে'), note: HandNote(tr('ঘুম ভালো হোক'), size: 12.5, rotate: -5)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                if (next == null)
                  InfoBanner(icon: Icons.alarm_rounded, text: '${tr('কোনো অ্যালার্ম চালু নেই')}\n${tr('নিচের + চাপুন, বা সহকারীকে বলুন — “প্রতিদিন সকাল ৭টায় অ্যালার্ম দাও”')}')
                else
                  Builder(builder: (context) {
                    final at = next.notifyAt(now);
                    final diff = DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
                    final dayWord = diff == 0 ? tr('আজ') : diff == 1 ? '${tr('কাল')} ${weekdayName(at)}' : '${bnDigits(at.day)} ${monthShort(at.month)}';
                    final h12 = next.hour % 12 == 0 ? 12 : next.hour % 12;
                    final night = next.hour < 6 || next.hour >= 18;
                    return HeroCard(
                      key: const Key('alarm-next'),
                      landscape: false,
                      label: '${tr('পরের অ্যালার্ম')} · $dayWord',
                      onTap: () => open(next),
                      side: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                        child: Icon(night ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: C.sun, size: 30),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text(bnDigits('$h12:${next.minute.toString().padLeft(2, '0')}'), style: display(40, weight: 700, color: Colors.white, height: 1.2)),
                          const SizedBox(width: 8),
                          Text(bnTime(next.hour, next.minute).split(' ').first, style: body(16, color: Colors.white)),
                        ]),
                        Row(children: [
                          Expanded(child: Text(inText(at), style: body(13, color: Colors.white.withValues(alpha: 0.8)))),
                          Flexible(child: StatusPill(next.title, bg: Colors.white.withValues(alpha: 0.12), fg: Colors.white)),
                        ]),
                      ]),
                    );
                  }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: Row(children: [
                    Expanded(child: Text(tr('সব অ্যালার্ম'), style: heading(18))),
                    Text(trf('{0}টা', [bnDigits(alarms.length)]), style: body(13, color: C.muted)),
                  ]),
                ),
                for (final r in alarms) _AlarmCard(alarm: r, onTap: () => open(r)),
                if (alarms.isNotEmpty) const SizedBox(height: 4),
                Material(
                  color: C.greenTint,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReminderCheckScreen())),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      child: Row(children: [
                        Icon(Icons.verified_outlined, color: C.green),
                        const SizedBox(width: 12),
                        Expanded(child: Text(tr('অ্যালার্ম ঠিকমতো বাজবে তো? দেখে নিন'), style: body(14, weight: FontWeight.w600, color: C.greenDark))),
                        Icon(Icons.chevron_right_rounded, color: C.greenDark),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.alarm, required this.onTap});
  final Reminder alarm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final r = alarm;
    final h12 = r.hour % 12 == 0 ? 12 : r.hour % 12;
    final part = bnTime(r.hour, r.minute).split(' ').first;
    final days = r.repeat == Repeat.weekly ? r.ringDays : (r.repeat == Repeat.daily ? _dayOrder.toSet() : <int>{});
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: r.enabled ? 1 : 0.5,
        child: Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: C.dark ? BorderSide(color: C.line) : BorderSide.none),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text(bnDigits('$h12:${r.minute.toString().padLeft(2, '0')}'), style: display(34, weight: 600, height: 1.2)),
                  const SizedBox(width: 6),
                  Text(part, style: body(15, color: C.muted)),
                  const Spacer(),
                  Switch(
                    value: r.enabled,
                    onChanged: (v) => brain.saveReminder(r.copyWith(enabled: v)),
                  ),
                ]),
                Text('${r.title} · ${alarmDaysText(r, now)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, color: C.muted2)),
                if (days.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    for (final d in _dayOrder)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: days.contains(d) ? C.chip : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: days.contains(d) ? C.chip : C.line)),
                        child: Text(weekdayShort(DateTime(2026, 10, 12 + (d - 1))),
                            style: body(11.5, weight: days.contains(d) ? FontWeight.w600 : FontWeight.w400, color: days.contains(d) ? C.ink : C.muted)),
                      ),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Set or change an alarm: time wheels, days, name.
class AlarmEditScreen extends StatefulWidget {
  const AlarmEditScreen({super.key, this.alarm});
  final Reminder? alarm;

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late int _hour = widget.alarm?.hour ?? 7;
  late int _minute = widget.alarm?.minute ?? 0;
  late Set<int> _days = {
    if (widget.alarm?.repeat == Repeat.daily) ..._dayOrder,
    if (widget.alarm?.repeat == Repeat.weekly) ...widget.alarm!.ringDays,
  };
  late final _name = TextEditingController(text: widget.alarm?.title ?? '');
  late final _h = FixedExtentScrollController(initialItem: (_hour % 12 == 0 ? 12 : _hour % 12) - 1);
  late final _m = FixedExtentScrollController(initialItem: _minute);
  late final _p = FixedExtentScrollController(initialItem: _hour >= 12 ? 1 : 0);

  @override
  void dispose() {
    _name.dispose();
    _h.dispose();
    _m.dispose();
    _p.dispose();
    super.dispose();
  }

  void _setHour({int? h12, bool? pm}) {
    final cur12 = _hour % 12 == 0 ? 12 : _hour % 12;
    final curPm = _hour >= 12;
    final nh = h12 ?? cur12;
    final np = pm ?? curPm;
    setState(() => _hour = (nh % 12) + (np ? 12 : 0));
  }

  Widget _wheel(FixedExtentScrollController c, int count, String Function(int) label, void Function(int) onChanged, {double width = 70}) => SizedBox(
        width: width,
        height: 170,
        child: ListWheelScrollView.useDelegate(
          controller: c,
          itemExtent: 50,
          physics: const FixedExtentScrollPhysics(),
          perspective: 0.004,
          diameterRatio: 1.6,
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (_, i) => Center(child: Text(label(i), style: display(30, weight: 600))),
          ),
        ),
      );

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final now = brain.services.now();
    final today = DateTime(now.year, now.month, now.day);
    final title = _name.text.trim().isEmpty ? tr('অ্যালার্ম') : _name.text.trim();
    final Repeat repeat;
    var date = today;
    if (_days.length == 7) {
      repeat = Repeat.daily;
    } else if (_days.isNotEmpty) {
      repeat = Repeat.weekly;
    } else {
      repeat = Repeat.none;
      if (!DateTime(today.year, today.month, today.day, _hour, _minute).isAfter(now)) date = today.add(const Duration(days: 1));
    }
    final old = widget.alarm;
    final r = old == null
        ? Reminder(title: title, date: date, hour: _hour, minute: _minute, repeat: repeat, alarm: true, weekdays: repeat == Repeat.weekly ? (_days.toList()..sort()) : const [])
        : old.copyWith(
            title: title,
            date: date,
            hour: _hour,
            minute: _minute,
            repeat: repeat,
            alarm: true,
            enabled: true,
            weekdays: repeat == Repeat.weekly ? (_days.toList()..sort()) : const []);
    await brain.saveReminder(r);
    if (!mounted) return;
    final at = r.notifyAt(now);
    final mins = at.difference(now).inMinutes;
    toast(context, trf('অ্যালার্ম রাখা হলো — {0} পর বাজবে', [mins < 60 ? '${bnDigits(mins)} মিনিট' : '${bnDigits(mins ~/ 60)} ঘণ্টা ${bnDigits(mins % 60)} মিনিট']));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: tr('অ্যালার্মটা মুছবেন?'), text: _name.text, yes: tr('মুছুন'), danger: true);
    if (!ok || !mounted) return;
    await BrainScope.read(context).deleteReminder(widget.alarm!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final presets = <(String, Set<int>)>[
      (tr('একবার'), <int>{}),
      (tr('প্রতিদিন'), _dayOrder.toSet()),
      (tr('অফিসের দিন'), _dayOrder.where((d) => d != DateTime.friday).toSet()),
      (tr('ছুটির দিন'), {DateTime.friday, DateTime.saturday}),
    ];
    bool same(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(
            title: widget.alarm == null ? tr('নতুন অ্যালার্ম') : tr('অ্যালার্ম বদলান'),
            trailing: [
              if (widget.alarm != null) IconButton(tooltip: tr('মুছুন'), onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Container(
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(18)),
                  child: Stack(alignment: Alignment.center, children: [
                    Container(height: 52, margin: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(14))),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _wheel(_h, 12, (i) => bnDigits(i + 1), (i) => _setHour(h12: i + 1)),
                      Text(':', style: display(30, weight: 600)),
                      _wheel(_m, 60, (i) => bnDigits(i.toString().padLeft(2, '0')), (i) => setState(() => _minute = i)),
                      _wheel(_p, 2, (i) => i == 0 ? 'AM' : 'PM', (i) => _setHour(pm: i == 1), width: 80),
                    ]),
                  ]),
                ),
                const SizedBox(height: 6),
                Center(child: Text(bnTime(_hour, _minute), style: body(15, weight: FontWeight.w600, color: C.green))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Text(tr('কোন কোন দিন'), style: body(13, weight: FontWeight.w600, color: C.muted)),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (final d in _dayOrder)
                    Semantics(
                      button: true,
                      selected: _days.contains(d),
                      label: dayName(d),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _days.contains(d) ? C.green : C.soft),
                          child: Text(_dayShort[d]!, style: body(14, weight: FontWeight.w600, color: _days.contains(d) ? Colors.white : C.muted)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (label, set) in presets)
                    ChoiceChip(
                      label: Text(label, style: body(14, color: same(_days, set) ? C.onInk : C.muted2)),
                      selected: same(_days, set),
                      selectedColor: C.ink,
                      backgroundColor: C.surface,
                      side: BorderSide(color: same(_days, set) ? C.ink : C.line),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _days = {...set}),
                    ),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  style: body(16),
                  decoration: InputDecoration(labelText: tr('নাম (বাজলে এটা দেখাবে)'), hintText: tr('যেমন: ঘুম থেকে ওঠা')),
                ),
                const SizedBox(height: 10),
                Text(tr('বাজলে পুরো স্ক্রিনে অ্যালার্ম আসবে, ফোন লক থাকলেও। ৫/১০ মিনিট বা ১ ঘণ্টা পরে আবার বাজানো যায়। রিংটোন সেটিংস থেকে বদলানো যায়।'),
                    style: body(13, color: C.muted, height: 1.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: PrimaryButton(label: tr('অ্যালার্ম রাখুন'), icon: Icons.alarm_add_rounded, onPressed: _save),
          ),
        ]),
      ),
    );
  }
}
