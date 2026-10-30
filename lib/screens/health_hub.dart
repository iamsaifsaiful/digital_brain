import 'health_connect_screen.dart';
import '../logic/health_connect.dart' show hcTag;
import 'package:flutter/material.dart';

import '../logic/steps.dart';
import '../services/steps_channel.dart';

import '../logic/bn.dart';
import '../logic/health.dart';
import '../logic/lang.dart';
import '../logic/me.dart' show bloodGroups;
import '../logic/pro.dart';
import '../ui/pro_gate.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'blood_details.dart';
import 'docs_screen.dart';
import 'health_screens.dart';
import '../ui/pdf_export.dart';

/// স্বাস্থ্য: the user's (and family's) profile and BMI, weight, blood
/// pressure, blood sugar, water, walking and sleep, check-ups, reports, a
/// child's vaccine card, and a page to show the doctor.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, this.member = FamilyMember.meId});
  final String member;

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

Color levelColor(Level l) => switch (l) {
      Level.ok => C.green,
      Level.watch => C.ochre,
      Level.low => C.blue,
      Level.high => C.orange,
      Level.urgent => C.red,
    };

class _HealthScreenState extends State<HealthScreen> {
  late String _member = widget.member;

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final people = brain.healthPeople;
    final m = people.firstWhere((x) => x.id == _member, orElse: () => people.first);
    final w = latest(d, m.id, HealthKind.weight);
    final bp = latest(d, m.id, HealthKind.bp);
    final sugar = latest(d, m.id, HealthKind.sugar);
    final age = m.ageOn(now);

    Widget tile(HealthKind kind, IconData icon, Color color, String value, String sub, {Level? level, VoidCallback? quick, String? quickLabel}) => Expanded(
          child: Material(
            color: C.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _push(HealthKindScreen(member: m.id, kind: kind)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 6),
                    Expanded(child: Text(isEn ? kind.en : kind.bn, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: C.muted2))),
                  ]),
                  const SizedBox(height: 6),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(19, weight: 700, color: level == null ? C.ink : levelColor(level))),
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted, height: 1.3)),
                  if (quick != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: quick,
                        child: Text(quickLabel ?? tr('যোগ'), style: body(13, weight: FontWeight.w600, color: C.green)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        );

    final bpLevelNow = bp == null ? null : bpLevel(bp.a, bp.b ?? 0);
    final sugarLevelNow = sugar == null ? null : sugarLevel(sugar.a, fasting: sugar.tag == 'fasting');
    final water = totalOn(d, m.id, HealthKind.water, now);
    final walk = totalOn(d, m.id, HealthKind.exercise, now);
    final sleep = latest(d, m.id, HealthKind.sleep);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('স্বাস্থ্য'), trailing: [
            const PdfButton({ReportPart.health}),
            if (!medicalOff) IconButton(tooltip: tr('ডাক্তারকে দেখান'), onPressed: () => _push(DoctorSummaryScreen(member: m.id)), icon: const Icon(Icons.assignment_ind_outlined)),
          ]),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              for (final p in people)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.isMe ? tr('আমি') : (p.relation.isEmpty ? p.name : '${p.name} (${p.relation})')),
                    selected: p.id == m.id,
                    onSelected: (_) => setState(() => _member = p.id),
                  ),
                ),
              ActionChip(
                avatar: Icon(Icons.person_add_alt_outlined, size: 18, color: C.green),
                label: Text(tr('পরিবারের সদস্য')),
                onPressed: () async {
                  final added = await editMember(context, null);
                  if (added != null) setState(() => _member = added.id);
                },
              ),
            ]),
          ),
          Expanded(
            child: SwipeTabs<String>(
              items: [for (final p in people) p.id],
              value: m.id,
              onChanged: (id) => setState(() => _member = id),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
                // Profile and BMI.
                Panel(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.isMe ? (brain.userName.isEmpty ? tr('আমি') : brain.userName) : m.name, style: display(20, weight: 700)),
                          Text(
                              [
                                if (age != null) trf('বয়স {0}', [bnDigits(age)]),
                                if (m.heightCm != null) heightText(m.heightCm!),
                                if (m.sex.isNotEmpty) m.sex == 'm' ? tr('পুরুষ') : tr('নারী'),
                                if ((m.isMe ? brain.data.emergency.blood : m.blood).isNotEmpty) trf('রক্ত {0}', [m.isMe ? brain.data.emergency.blood : m.blood]),
                              ].join(' · ').ifEmpty(tr('বয়স, উচ্চতা, রক্তের গ্রুপ দিন')),
                              style: body(13.5, color: C.muted)),
                        ]),
                      ),
                      TextButton.icon(
                        onPressed: () => editMember(context, m),
                        icon: Icon(Icons.edit_outlined, size: 18, color: C.green),
                        label: Text(tr('বদলান'), style: body(14, weight: FontWeight.w600, color: C.green)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (w != null && m.heightCm != null) ...[
                      BmiGauge(bmi: bmiOf(w.a, m.heightCm!)),
                      const SizedBox(height: 8),
                      Text(trf('আপনার উচ্চতায় সুস্থ ওজন {0}–{1} কেজি; এখন {2}।', [bnDigits(healthyWeight(m.heightCm!).$1), bnDigits(healthyWeight(m.heightCm!).$2), kg(w.a)]),
                          style: body(13.5, color: C.muted2, height: 1.5)),
                    ] else
                      Text(m.heightCm == null ? tr('উচ্চতা আর ওজন দিলে BMI দেখাবে (এশীয়দের মাপে)।') : tr('ওজন লিখলে BMI দেখাবে।'), style: body(13.5, color: C.muted)),
                  ]),
                ),
                const SizedBox(height: 12),
                // The Play app: weight and water side by side, no blood
                // pressure or sugar (pro.dart medicalOff).
                if (medicalOff)
                  Row(children: [
                    tile(HealthKind.weight, Icons.monitor_weight_outlined, C.teal, w == null ? '—' : kg(w.a), w == null ? tr('লেখা হয়নি') : _changeText(d, m.id, now),
                        quick: () => addReading(context, m.id, HealthKind.weight)),
                    const SizedBox(width: 10),
                    tile(HealthKind.water, Icons.water_drop_outlined, C.blue, trf('{0}/৮ গ্লাস', [bnDigits(water.round())]), tr('আজ পানি'),
                        quick: () => brain.addHealth(HealthLog(member: m.id, kind: HealthKind.water, at: brain.services.now(), a: 1)), quickLabel: tr('+১ গ্লাস')),
                  ])
                else ...[
                Row(children: [
                  tile(HealthKind.weight, Icons.monitor_weight_outlined, C.teal, w == null ? '—' : kg(w.a), w == null ? tr('লেখা হয়নি') : _changeText(d, m.id, now),
                      quick: () => addReading(context, m.id, HealthKind.weight)),
                  const SizedBox(width: 10),
                  tile(HealthKind.bp, Icons.favorite_border_rounded, C.rose, bp == null ? '—' : readingText(bp).split(' · ').first,
                      bp == null ? tr('লেখা হয়নি') : '${bpLevelNow!.$2} · ${shortDate(bp.at)}',
                      level: bpLevelNow?.$1, quick: () => addReading(context, m.id, HealthKind.bp)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  tile(HealthKind.sugar, Icons.bloodtype_outlined, C.purple, sugar == null ? '—' : mmolText(sugar.a),
                      sugar == null ? tr('লেখা হয়নি') : '${sugarLevelNow!.$2} · ${sugar.tag == 'fasting' ? tr('খালি পেটে') : tr('খাওয়ার পরে')}',
                      level: sugarLevelNow?.$1, quick: () => addReading(context, m.id, HealthKind.sugar)),
                  const SizedBox(width: 10),
                  tile(HealthKind.water, Icons.water_drop_outlined, C.blue, trf('{0}/৮ গ্লাস', [bnDigits(water.round())]), tr('আজ পানি'),
                      quick: () => brain.addHealth(HealthLog(member: m.id, kind: HealthKind.water, at: brain.services.now(), a: 1)), quickLabel: tr('+১ গ্লাস')),
                ]),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  tile(HealthKind.exercise, Icons.directions_walk_rounded, C.green, trf('{0} মিনিট', [bnDigits(walk.round())]), tr('আজ হাঁটা/ব্যায়াম'),
                      quick: () => addReading(context, m.id, HealthKind.exercise)),
                  const SizedBox(width: 10),
                  tile(HealthKind.sleep, Icons.bedtime_outlined, C.ochre, sleep == null ? '—' : readingText(sleep), sleep == null ? tr('লেখা হয়নি') : shortDate(sleep.at),
                      quick: () => addReading(context, m.id, HealthKind.sleep)),
                ]),
                // The phone's own step count (the user's, not a family member's).
                if (m.isMe) const HealthConnectCard(),
                if (m.isMe && !(brain.hcOn && brain.hcGranted)) const StepsCard(),
                if (!medicalOff && (needsVaccineCard(m, now) || (!m.isMe && m.birth != null && now.difference(m.birth!).inDays < 6 * 366))) ...[
                  const SizedBox(height: 12),
                  Panel(
                    child: ListRow(
                      leading: Icon(Icons.vaccines_outlined, color: C.green),
                      title: tr('টিকার কার্ড'),
                      subtitle: _nextDoseText(d, m, now),
                      trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                      onTap: () => _push(VaccineScreen(member: m.id)),
                    ),
                  ),
                ],
                if (!medicalOff) ...[
                const SizedBox(height: 16),
                SectionTitle(tr('চেকআপ ও রিপোর্ট')),
                Panel(
                  child: Rows(children: [
                    ListRow(
                      leading: Icon(Icons.event_available_outlined, color: C.green),
                      title: m.nextCheckup == null ? tr('পরের চেকআপের তারিখ') : trf('পরের চেকআপ: {0}', [fullDate(m.nextCheckup!)]),
                      subtitle: m.nextCheckup == null ? tr('দিলে আগের দিন আর সেদিন সকালে মনে করাবো') : daysLeftLabel(m.nextCheckup!, now),
                      trailing: m.nextCheckup == null ? null : IconButton(tooltip: tr('তারিখ মুছুন'), onPressed: () => brain.setCheckup(m, null), icon: Icon(Icons.close_rounded, color: C.muted)),
                      onTap: () async {
                        final p = await showDatePicker(context: context, initialDate: m.nextCheckup ?? now.add(const Duration(days: 30)), firstDate: dayOnly(now), lastDate: DateTime(now.year + 3));
                        if (p != null) await brain.setCheckup(m, p);
                      },
                    ),
                    ListRow(
                      leading: Icon(Icons.description_outlined, color: C.blue),
                      title: tr('পরীক্ষার রিপোর্ট'),
                      subtitle: tr('ছবি তুলে রাখুন — তারিখসহ খুঁজে পাবেন'),
                      trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                      onTap: () => _push(const DocsScreen(folder: 'চিকিৎসা')),
                    ),
                    ListRow(
                      leading: Icon(Icons.receipt_long_outlined, color: C.blue),
                      title: tr('প্রেসক্রিপশন'),
                      trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                      onTap: () => _push(const DocsScreen(folder: 'প্রেসক্রিপশন')),
                    ),
                    // Everyone's, family members' too (owner, 24 Oct night).
                    Builder(builder: (context) {
                      final meds = [for (final x in d.medicines) if (x.member == m.id) x];
                      return ListRow(
                        key: const Key('health-medicines'),
                        leading: Icon(Icons.medication_outlined, color: C.orange),
                        title: m.isMe ? tr('ওষুধের সময়সূচি') : trf('{0}-এর ওষুধ', [m.name]),
                        subtitle: meds.isEmpty ? tr('কোনো ওষুধ রাখা নেই') : meds.map((x) => x.name).join(', '),
                        trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                        onTap: () => _push(MedicinesScreen(member: m.id)),
                      );
                    }),
                  ]),
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: tr('ডাক্তারকে দেখানোর সারাংশ'), icon: Icons.assignment_ind_outlined, onPressed: () => _push(DoctorSummaryScreen(member: m.id))),
                ],
                const SizedBox(height: 12),
                Text(tr('এখানে শুধু মাপ রাখা হয়; রোগ নির্ণয় করা হয় না। মাপ স্বাভাবিকের বাইরে গেলে ডাক্তার দেখান। সব তথ্য এই ফোনে তালাবদ্ধ থাকে।'), style: body(12.5, color: C.muted, height: 1.5)),
                if (!m.isMe) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final ok = await confirmDialog(context, title: trf('{0}-কে সরাবেন?', [m.name]), text: tr('তার সব মাপ আর টিকার তথ্য মুছে যাবে।'), yes: tr('সরান'), danger: true);
                        if (!ok) return;
                        await brain.deleteMember(m);
                        setState(() => _member = FamilyMember.meId);
                      },
                      icon: Icon(Icons.person_remove_outlined, size: 18, color: C.red),
                      label: Text(tr('এই সদস্যকে সরান'), style: body(13, color: C.red)),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  String _changeText(AppData d, String member, DateTime now) {
    final ch = weightChange(d, member, now);
    if (ch == null || ch.abs() < 0.1) return shortDate(latest(d, member, HealthKind.weight)!.at);
    return ch < 0 ? trf('মাসে {0} কমেছে', [kg(-ch)]) : trf('মাসে {0} বেড়েছে', [kg(ch)]);
  }

  String _nextDoseText(AppData d, FamilyMember m, DateTime now) {
    final due = [
      for (final v in epiSchedule)
        if (givenOn(d, m, v) == null) v
    ];
    if (due.isEmpty) return tr('সব টিকা দেওয়া হয়েছে');
    final next = doseDay(m, due.first);
    return trf('পরের টিকা {0} — {1} ({2})', [tr(due.first.name), fullDate(next), daysLeftLabel(next, now)]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// The BMI on a coloured scale: thin, normal, a little over, well over.
class BmiGauge extends StatelessWidget {
  const BmiGauge({super.key, required this.bmi});
  final double bmi;

  @override
  Widget build(BuildContext context) {
    final (level, label) = bmiLevel(bmi);
    const lo = 15.0, hi = 35.0;
    final pos = ((bmi - lo) / (hi - lo)).clamp(0.0, 1.0);
    final bands = [(18.5, C.blue), (23.0, C.green), (27.5, C.ochre), (hi, C.orange)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('BMI ', style: body(14, color: C.muted)),
        Text(bnDigits(bmi.toStringAsFixed(1)), style: display(30, weight: 700, color: levelColor(level), height: 1.1)),
        const SizedBox(width: 8),
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(label, style: body(15, weight: FontWeight.w600, color: levelColor(level)))),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (_, c) => Stack(clipBehavior: Clip.none, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(children: [
              for (var i = 0; i < bands.length; i++)
                Expanded(
                  flex: (((bands[i].$1 - (i == 0 ? lo : bands[i - 1].$1)) * 10)).round(),
                  child: Container(height: 10, color: bands[i].$2.withValues(alpha: 0.75)),
                ),
            ]),
          ),
          Positioned(
            left: (c.maxWidth * pos - 7).clamp(0, c.maxWidth - 14),
            top: -3,
            child: Container(width: 14, height: 16, decoration: BoxDecoration(color: C.surface, border: Border.all(color: C.ink, width: 2), borderRadius: BorderRadius.circular(4))),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      Text(tr('এশীয়দের মাপ: ১৮.৫-এর নিচে কম ওজন · ২৩ পর্যন্ত স্বাভাবিক · ২৭.৫ পর্যন্ত একটু বেশি'), style: body(11.5, color: C.muted)),
    ]);
  }
}

/// Add or change a family member (or the user's own height, age, sex).
Future<FamilyMember?> editMember(BuildContext context, FamilyMember? m) async {
  final brain = BrainScope.read(context);
  // Family in স্বাস্থ্য is premium (owner, 24 Oct); one's own is free.
  if (m == null && !await needPro(context, ProFeature.familyHealth)) return null;
  if (!context.mounted) return null;
  final name = TextEditingController(text: m == null ? '' : (m.isMe ? (brain.userName.isEmpty ? tr('আমি') : brain.userName) : m.name));
  final relation = TextEditingController(text: m?.relation ?? '');
  final cm = m?.heightCm;
  final inchesAll = cm == null ? null : (cm / 2.54).round();
  final ft = TextEditingController(text: inchesAll == null ? '' : '${inchesAll ~/ 12}');
  final inch = TextEditingController(text: inchesAll == null ? '' : '${inchesAll % 12}');
  var birth = m?.birth;
  var sex = m?.sex ?? '';
  var blood = m == null ? '' : (m.isMe ? brain.data.emergency.blood : m.blood);
  final now = brain.services.now();
  final saved = await showDialog<FamilyMember>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(m == null ? tr('পরিবারের সদস্য') : tr('প্রোফাইল'), style: display(20)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (m == null || !m.isMe) ...[
              TextField(controller: name, decoration: InputDecoration(labelText: tr('নাম'))),
              const SizedBox(height: 10),
              TextField(controller: relation, decoration: InputDecoration(labelText: tr('সম্পর্ক'), hintText: tr('যেমন: আব্বা, আম্মা, মেয়ে'))),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                final p = await showDatePicker(context: ctx, initialDate: birth ?? DateTime(now.year - 30), firstDate: DateTime(1920), lastDate: now);
                if (p != null) setD(() => birth = p);
              },
              icon: const Icon(Icons.cake_outlined, size: 18),
              label: Text(birth == null ? tr('জন্মতারিখ') : fullDate(birth!)),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: Text(tr('পুরুষ')), selected: sex == 'm', onSelected: (_) => setD(() => sex = 'm')),
              ChoiceChip(label: Text(tr('নারী')), selected: sex == 'f', onSelected: (_) => setD(() => sex = 'f')),
            ]),
            const SizedBox(height: 10),
            Text(tr('উচ্চতা'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
            Row(children: [
              Expanded(child: TextField(controller: ft, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('ফুট')))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: inch, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('ইঞ্চি')))),
            ]),
            const SizedBox(height: 14),
            Text(tr('রক্তের গ্রুপ'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final g in [...bloodGroups, ''])
                ChoiceChip(
                  label: Text(g.isEmpty ? tr('জানি না') : g),
                  selected: blood == g,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setD(() => blood = g),
                ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(
            onPressed: () {
              final f = int.tryParse(asciiDigits(ft.text.trim()));
              final i = double.tryParse(asciiDigits(inch.text.trim())) ?? 0;
              final h = f == null || f <= 0 ? null : feetToCm(f, i);
              final n = name.text.trim();
              if ((m == null || !m.isMe) && n.isEmpty) return;
              final base = m ?? FamilyMember(name: n);
              Navigator.pop(
                  ctx,
                  base.copyWith(
                    name: base.isMe ? (brain.userName.isEmpty ? tr('আমি') : brain.userName) : n,
                    relation: relation.text.trim(),
                    birth: birth,
                    sex: sex,
                    heightCm: h,
                    blood: blood,
                  ));
            },
            child: Text(tr('রাখুন'), style: body(15, weight: FontWeight.w600, color: C.green)),
          ),
        ],
      ),
    ),
  );
  for (final c in [name, relation, ft, inch]) {
    c.dispose();
  }
  if (saved != null) {
    var keep = saved;
    // The user's own group needs its number and last donation (owner, 28 Oct).
    if (saved.isMe && blood != brain.data.emergency.blood && blood.isNotEmpty && context.mounted && !await askBloodDetails(context, blood)) {
      keep = saved.copyWith(blood: brain.data.emergency.blood);
    }
    await brain.saveMember(keep);
    if (keep.isMe && keep.blood != brain.data.emergency.blood) await brain.saveEmergency(brain.data.emergency.copyWith(blood: keep.blood));
  }
  return saved;
}

/// A reading typed in: weight, blood pressure (and pulse), blood sugar
/// (before or after food, mmol/L or mg/dL), minutes walked, hours slept.
Future<void> addReading(BuildContext context, String member, HealthKind kind, {HealthLog? old}) async {
  final brain = BrainScope.read(context);
  String num(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : '$v');
  final a = TextEditingController(text: num(old?.a));
  final b = TextEditingController(text: num(old?.b));
  final c = TextEditingController(text: num(old?.c));
  var fasting = old == null || old.tag != 'after';
  double? n(TextEditingController t) => double.tryParse(asciiDigits(t.text.trim()));
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(isEn ? kind.en : kind.bn, style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          switch (kind) {
            HealthKind.bp => Row(children: [
                Expanded(child: TextField(controller: a, autofocus: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('উপরের (সিস্টোলিক)')))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: b, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('নিচের (ডায়াস্টোলিক)')))),
              ]),
            HealthKind.weight =>
              TextField(controller: a, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('ওজন (কেজি)'))),
            HealthKind.sugar =>
              TextField(controller: a, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('সুগার (mmol/L বা mg/dL)'))),
            HealthKind.water => TextField(controller: a, autofocus: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('কত গ্লাস'))),
            HealthKind.exercise => TextField(controller: a, autofocus: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('কত মিনিট'))),
            HealthKind.sleep =>
              TextField(controller: a, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: tr('কত ঘণ্টা ঘুম'))),
          },
          if (kind == HealthKind.bp) ...[
            const SizedBox(height: 8),
            TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('পালস (ঐচ্ছিক)'))),
          ],
          if (kind == HealthKind.sugar) ...[
            const SizedBox(height: 10),
            SegTabs<bool>(items: [(true, tr('খালি পেটে')), (false, tr('খাওয়ার পরে'))], value: fasting, onChanged: (v) => setD(() => fasting = v)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('রাখুন'), style: body(15, weight: FontWeight.w600, color: C.green))),
        ],
      ),
    ),
  );
  final va = n(a), vb = n(b), vc = n(c);
  if (ok != true || va == null || va <= 0) return;
  if (kind == HealthKind.bp && (vb == null || vb <= 0)) return;
  final log = HealthLog(
    id: old?.id,
    member: member,
    kind: kind,
    at: old?.at ?? brain.services.now(),
    a: kind == HealthKind.sugar ? double.parse(toMmol(va).toStringAsFixed(1)) : va,
    b: kind == HealthKind.bp ? vb : null,
    c: kind == HealthKind.bp ? vc : null,
    tag: kind == HealthKind.sugar ? (fasting ? 'fasting' : 'after') : '',
  );
  await (old == null ? brain.addHealth(log) : brain.saveHealth(log));
  final level = levelOf(log);
  if (context.mounted) {
    toast(context, level == null ? tr('রাখা হলো') : trf('রাখা হলো — {0}', [level.$2]));
  }
}

/// One kind of reading over time: a line chart and the list.
class HealthKindScreen extends StatelessWidget {
  const HealthKindScreen({super.key, required this.member, required this.kind});
  final String member;
  final HealthKind kind;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final all = readings(brain.data, member, kind);
    final now = brain.services.now();
    // Water, walking: one point a day (the day's total).
    final daily = kind == HealthKind.water || kind == HealthKind.exercise;
    final points = daily
        ? [
            for (var i = 13; i >= 0; i--) (now.subtract(Duration(days: i)), totalOn(brain.data, member, kind, now.subtract(Duration(days: i))), null as double?),
          ]
        : [for (final h in all.where((h) => h.at.isAfter(now.subtract(const Duration(days: 92))))) (h.at, h.a, h.b)];
    return Scaffold(
      floatingActionButton: AddButton(label: tr('যোগ করুন'), onPressed: () => addReading(context, member, kind)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: isEn ? kind.en : kind.bn),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              if (points.length >= 2)
                Panel(
                  padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
                  child: SizedBox(height: 180, child: CustomPaint(painter: _LineChart(points: points, color: C.green, second: C.rose, grid: C.line, label: C.muted))),
                )
              else
                Text(tr('দুই বা তার বেশি মাপ হলে গ্রাফ দেখাবে।'), style: body(13, color: C.muted)),
              const SizedBox(height: 12),
              if (all.isEmpty)
                EmptyState(icon: Icons.monitor_heart_outlined, title: tr('এখনো কিছু লেখা নেই'), text: tr('নিচের বোতাম চেপে লিখুন, অথবা সহকারীকে বলুন।'))
              else
                Panel(
                  child: Rows(children: [
                    for (final h in all.reversed.take(60))
                      ListRow(
                        leading: Icon(Icons.circle, size: 12, color: levelOf(h) == null ? C.muted : levelColor(levelOf(h)!.$1)),
                        title: readingText(h),
                        subtitle: '${shortDate(h.at)} · ${bnTime(h.at.hour, h.at.minute)}${levelOf(h) == null ? '' : ' · ${levelOf(h)!.$2}'}${h.tag == hcTag ? ' · Health Connect' : ''}',
                        trailing: IconButton(tooltip: tr('মুছুন'), onPressed: () => brain.deleteHealth(h.id), icon: Icon(Icons.delete_outline_rounded, color: C.muted, size: 20)),
                        // Health Connect's own readings are changed there; here they can only be deleted.
                        onTap: h.tag == hcTag ? null : () => addReading(context, member, kind, old: h),
                      ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LineChart extends CustomPainter {
  _LineChart({required this.points, required this.color, required this.second, required this.grid, required this.label});
  final List<(DateTime, double, double?)> points;
  final Color color;
  final Color second;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final p in points) p.$2,
      for (final p in points)
        if (p.$3 != null) p.$3!
    ];
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.15;
    lo -= pad;
    hi += pad;
    const left = 36.0, bottom = 18.0;
    final w = size.width - left, h = size.height - bottom;
    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    double x(DateTime t) => left + (t1 == t0 ? w / 2 : (t.millisecondsSinceEpoch - t0) / (t1 - t0) * w);
    double y(double v) => h - (v - lo) / (hi - lo) * h;
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 3; i++) {
      final v = lo + (hi - lo) * i / 3;
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), gp);
      tp.text = TextSpan(text: bnDigits(v.round()), style: TextStyle(color: label, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset(0, y(v) - 6));
    }
    void line(double Function((DateTime, double, double?)) pick, Color c) {
      final path = Path();
      final dot = Paint()..color = c;
      for (var i = 0; i < points.length; i++) {
        final o = Offset(x(points[i].$1), y(pick(points[i])));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
        canvas.drawCircle(o, 3, dot);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = c
            ..strokeWidth = 2.2
            ..style = PaintingStyle.stroke);
    }

    line((p) => p.$2, color);
    if (points.every((p) => p.$3 != null)) line((p) => p.$3!, second);
    for (final p in [points.first, points.last]) {
      tp.text = TextSpan(text: shortDate(p.$1), style: TextStyle(color: label, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset((x(p.$1) - tp.width / 2).clamp(left, size.width - tp.width), size.height - 14));
    }
  }

  @override
  bool shouldRepaint(_LineChart old) => old.points != points;
}

/// The child's vaccine card: every dose by Bangladesh's EPI schedule, the
/// day it is due, ticked when given.
class VaccineScreen extends StatelessWidget {
  const VaccineScreen({super.key, required this.member});
  final String member;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final m = brain.personById(member);
    final now = brain.services.now();
    final today = dayOnly(now);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: trf('{0}-এর টিকা', [m.name])),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              InfoBanner(
                icon: Icons.vaccines_outlined,
                text: tr('বাংলাদেশের ইপিআই সময়সূচি অনুযায়ী। প্রতিটা টিকার আগের দিন আর সেদিন সকালে মনে করাবো। টিকা কার্ডের তারিখের সাথে মিলিয়ে নিন — কেন্দ্রের দেওয়া তারিখই মানবেন।'),
              ),
              const SizedBox(height: 12),
              if (m.birth == null)
                Text(tr('জন্মতারিখ দিলে সময়সূচি দেখাবে।'), style: body(14, color: C.muted))
              else
                Panel(
                  child: Rows(children: [
                    for (final v in epiSchedule)
                      Builder(builder: (context) {
                        final due = doseDay(m, v);
                        final given = givenOn(brain.data, m, v);
                        final late = given == null && due.isBefore(today);
                        return CheckboxListTile(
                          value: given != null,
                          onChanged: (on) => brain.setDoseGiven(m, v, on == true ? now : null),
                          title: Text(tr(v.name), style: body(15, weight: FontWeight.w600)),
                          subtitle: Text(
                              given != null ? trf('দেওয়া হয়েছে {0} · {1}', [shortDate(given), tr(v.protects)]) : trf('{0} ({1}) · {2}', [fullDate(due), daysLeftLabel(due, now), tr(v.protects)]),
                              style: body(12.5, color: late ? C.orange : C.muted)),
                        );
                      }),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One page for the doctor: profile, BMI, the last three months of blood
/// pressure and sugar, medicines and allergies — to show or send.
class DoctorSummaryScreen extends StatelessWidget {
  const DoctorSummaryScreen({super.key, required this.member});
  final String member;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final m = brain.personById(member);
    final text = doctorSummary(brain.data, m.isMe ? m.copyWith(name: brain.userName.isEmpty ? m.name : brain.userName) : m, brain.services.now());
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('ডাক্তারকে দেখান'), trailing: [
            IconButton(tooltip: tr('পাঠান'), onPressed: () => brain.services.files.shareText(text), icon: const Icon(Icons.share_outlined)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Panel(padding: const EdgeInsets.all(16), child: SelectableText(text, style: body(15, height: 1.6))),
              const SizedBox(height: 12),
              PrimaryButton(label: tr('পাঠান (WhatsApp ইত্যাদি)'), icon: Icons.share_outlined, onPressed: () => brain.services.files.shareText(text)),
            ]),
          ),
        ]),
      ),
    );
  }
}


/// আজকের হাঁটা from the phone's step counter (owner, 24 Oct night): asks
/// for the permission once, then shows today's steps (and about how far),
/// with yesterday's beside. Read and kept on this phone only.
class StepsCard extends StatefulWidget {
  const StepsCard({super.key});

  @override
  State<StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<StepsCard> with WidgetsBindingObserver {
  bool _sensor = false, _allowed = false, _read = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the permission question (or another app): read again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final (sensor, allowed) = await StepsChannel.status();
    if (!mounted) return;
    setState(() {
      _sensor = sensor;
      _allowed = allowed;
    });
    if (!sensor || !allowed) return;
    final n = await StepsChannel.read();
    if (n == null || !mounted) return;
    final brain = BrainScope.read(context);
    final book = stepsRead(StepBook.fromJson(brain.text('steps_book')), brain.services.now(), n);
    await brain.setPref('steps_book', book.toJson());
    if (mounted) setState(() => _read = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_sensor) return const SizedBox.shrink();
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final book = StepBook.fromJson(brain.text('steps_book'));
    final today = book != null && book.day == stepDay(now) ? book.today : 0;
    final y = book?.days[stepDay(now.subtract(const Duration(days: 1)))];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Panel(
        key: const Key('health-steps'),
        child: ListRow(
          leading: Icon(Icons.directions_walk_rounded, color: C.green),
          title: !_allowed ? tr('হাঁটার ধাপ নিজে থেকে গুনুক') : trf('আজ {0} ধাপ', [bnDigits(today)]),
          subtitle: !_allowed
              ? tr('ফোন সারাদিন ধাপ গোনে — অনুমতি দিলে এখানে দেখাবে; শুধু এই ফোনেই থাকে')
              : [
                  if (today > 0) trf('প্রায় {0} কিমি', [bnDigits(double.parse(stepsKm(today).toStringAsFixed(1)))]),
                  if (y != null) trf('গতকাল {0} ধাপ', [bnDigits(y)]),
                  if (!_read && today == 0) tr('গোনা শুরু হলো — হাঁটলে বাড়বে'),
                ].join(' · '),
          trailing: _allowed ? null : TextButton(key: const Key('steps-allow'), onPressed: StepsChannel.ask, child: Text(tr('চালু করুন'))),
        ),
      ),
    );
  }
}
