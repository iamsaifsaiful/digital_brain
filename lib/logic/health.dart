/// Health numbers: BMI by the Asian cut-offs, blood pressure and blood
/// sugar ranges, the child vaccine schedule, and a summary to show a doctor.
///
/// The app keeps readings and says when one is outside the usual range
/// ("ডাক্তারকে দেখান"); it never diagnoses. Very high or very low readings
/// say so plainly and point to 999.
library;

import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';

/// How a reading looks: fine, worth watching, see a doctor, or urgent.
enum Level { low, ok, watch, high, urgent }

// ───────────────────────── BMI ─────────────────────────

double bmiOf(double kg, double cm) => kg / ((cm / 100) * (cm / 100));

/// WHO's cut-offs for Asian people (overweight from 23, obesity from 27.5),
/// which suit Bangladeshis better than the general 25/30.
(Level, String) bmiLevel(double bmi) {
  if (bmi < 18.5) return (Level.low, tr('ওজন কম'));
  if (bmi < 23) return (Level.ok, tr('স্বাভাবিক'));
  if (bmi < 27.5) return (Level.watch, tr('ওজন একটু বেশি'));
  return (Level.high, tr('ওজন অনেক বেশি'));
}

/// The healthy weight for a height (BMI 18.5–22.9), in whole kg.
(int, int) healthyWeight(double cm) {
  final m2 = (cm / 100) * (cm / 100);
  return ((18.5 * m2).ceil(), (22.9 * m2).floor());
}

/// 5 ft 6 in → 167.6 cm.
double feetToCm(int feet, double inches) => (feet * 12 + inches) * 2.54;

/// 167.6 cm → "৫ ফুট ৬ ইঞ্চি".
String heightText(double cm) {
  final inches = (cm / 2.54).round();
  return trf('{0} ফুট {1} ইঞ্চি', [bnDigits(inches ~/ 12), bnDigits(inches % 12)]);
}

// ───────────────────────── Blood pressure ─────────────────────────

(Level, String) bpLevel(double sys, double dia) {
  if (sys >= 180 || dia >= 120) return (Level.urgent, tr('খুব বেশি — এখনই ডাক্তার দেখান'));
  if (sys < 90 || dia < 60) return (Level.low, tr('কম'));
  if (sys >= 140 || dia >= 90) return (Level.high, tr('বেশি — ডাক্তারকে দেখান'));
  if (sys >= 130 || dia >= 80) return (Level.watch, tr('একটু বেশি'));
  if (sys >= 120) return (Level.watch, tr('স্বাভাবিকের উপরের দিকে'));
  return (Level.ok, tr('স্বাভাবিক'));
}

// ───────────────────────── Blood sugar ─────────────────────────

/// mg/dL readings (above 35) are turned into mmol/L.
double toMmol(double v) => v > 35 ? v / 18 : v;

/// [fasting]: before breakfast; otherwise about 2 hours after a meal.
(Level, String) sugarLevel(double mmol, {required bool fasting}) {
  if (mmol < 3.0) return (Level.urgent, tr('খুব কম — এখনই কিছু মিষ্টি খান, ডাক্তার দেখান'));
  if (mmol >= 16.7) return (Level.urgent, tr('খুব বেশি — এখনই ডাক্তার দেখান'));
  if (mmol < 3.9) return (Level.low, tr('কম'));
  if (fasting) {
    if (mmol < 5.6) return (Level.ok, tr('স্বাভাবিক'));
    if (mmol < 7.0) return (Level.watch, tr('একটু বেশি'));
    return (Level.high, tr('বেশি — ডাক্তারকে দেখান'));
  }
  if (mmol < 7.8) return (Level.ok, tr('স্বাভাবিক'));
  if (mmol < 11.1) return (Level.watch, tr('একটু বেশি'));
  return (Level.high, tr('বেশি — ডাক্তারকে দেখান'));
}

String mmolText(double v) => bnDigits(v.toStringAsFixed(1));

// ───────────────────────── Readings ─────────────────────────

List<HealthLog> readings(AppData d, String member, HealthKind kind) =>
    [for (final h in d.health) if (h.member == member && h.kind == kind) h]..sort((a, b) => a.at.compareTo(b.at));

HealthLog? latest(AppData d, String member, HealthKind kind) {
  final r = readings(d, member, kind);
  return r.isEmpty ? null : r.last;
}

/// Glasses of water (or minutes, hours) on [day].
double totalOn(AppData d, String member, HealthKind kind, DateTime day) =>
    d.health.where((h) => h.member == member && h.kind == kind && dayOnly(h.at) == dayOnly(day)).fold(0.0, (a, h) => a + h.a);

/// Weight change over the last [days] days (null without two readings).
double? weightChange(AppData d, String member, DateTime now, {int days = 30}) {
  final r = readings(d, member, HealthKind.weight);
  if (r.length < 2) return null;
  final since = now.subtract(Duration(days: days));
  final before = r.lastWhere((h) => !h.at.isAfter(since), orElse: () => r.first);
  if (identical(before, r.last)) return null;
  return r.last.a - before.a;
}

String kg(double v) => trf('{0} কেজি', [bnDigits(v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1))]);

/// One line about a reading, for lists and answers.
String readingText(HealthLog h) => switch (h.kind) {
      HealthKind.weight => kg(h.a),
      HealthKind.bp => '${bnDigits(h.a.round())}/${bnDigits(h.b?.round() ?? 0)}${h.c == null ? '' : trf(' · পালস {0}', [bnDigits(h.c!.round())])}',
      HealthKind.sugar => trf('{0} mmol/L ({1})', [mmolText(h.a), h.tag == 'fasting' ? tr('খালি পেটে') : tr('খাওয়ার পরে')]),
      HealthKind.water => trf('{0} গ্লাস', [bnDigits(h.a.round())]),
      HealthKind.exercise => trf('{0} মিনিট', [bnDigits(h.a.round())]),
      HealthKind.sleep => trf('{0} ঘণ্টা', [bnDigits(h.a == h.a.roundToDouble() ? h.a.toStringAsFixed(0) : h.a.toStringAsFixed(1))]),
    };

(Level, String)? levelOf(HealthLog h) => switch (h.kind) {
      HealthKind.bp => bpLevel(h.a, h.b ?? 0),
      HealthKind.sugar => sugarLevel(h.a, fasting: h.tag == 'fasting'),
      _ => null,
    };

FamilyMember memberOf(AppData d, String id, {String myName = ''}) =>
    d.members.where((m) => m.id == id).firstOrNull ?? FamilyMember(id: FamilyMember.meId, name: myName.isEmpty ? tr('আমি') : myName);

// ───────────────────────── Child vaccines (EPI, Bangladesh) ─────────────────────────

class VaccineDose {
  const VaccineDose(this.key, this.name, this.days, this.protects);
  final String key;
  final String name;

  /// Days after birth.
  final int days;
  final String protects;
}

/// Bangladesh's routine schedule (EPI): birth, 6/10/14 weeks, 9 and 15 months.
const epiSchedule = [
  VaccineDose('bcg', 'বিসিজি', 0, 'যক্ষ্মা'),
  VaccineDose('penta1', 'পেন্টাভ্যালেন্ট-১', 42, 'ডিপথেরিয়া, ধনুষ্টংকার, হুপিং কাশি, হেপাটাইটিস-বি, হিব'),
  VaccineDose('opv1', 'ওপিভি-১ (মুখে পোলিও)', 42, 'পোলিও'),
  VaccineDose('pcv1', 'পিসিভি-১', 42, 'নিউমোনিয়া'),
  VaccineDose('ipv1', 'আইপিভি-১ (পোলিও ইনজেকশন)', 42, 'পোলিও'),
  VaccineDose('penta2', 'পেন্টাভ্যালেন্ট-২', 70, 'ডিপথেরিয়া, ধনুষ্টংকার, হুপিং কাশি, হেপাটাইটিস-বি, হিব'),
  VaccineDose('opv2', 'ওপিভি-২', 70, 'পোলিও'),
  VaccineDose('pcv2', 'পিসিভি-২', 70, 'নিউমোনিয়া'),
  VaccineDose('penta3', 'পেন্টাভ্যালেন্ট-৩', 98, 'ডিপথেরিয়া, ধনুষ্টংকার, হুপিং কাশি, হেপাটাইটিস-বি, হিব'),
  VaccineDose('opv3', 'ওপিভি-৩', 98, 'পোলিও'),
  VaccineDose('pcv3', 'পিসিভি-৩', 98, 'নিউমোনিয়া'),
  VaccineDose('ipv2', 'আইপিভি-২', 98, 'পোলিও'),
  VaccineDose('mr1', 'এমআর-১', 274, 'হাম ও রুবেলা'),
  VaccineDose('tcv', 'টিসিভি (টাইফয়েড)', 274, 'টাইফয়েড'),
  VaccineDose('mr2', 'এমআর-২', 456, 'হাম ও রুবেলা'),
];

DateTime doseDay(FamilyMember m, VaccineDose v) => dayOnly(m.birth!).add(Duration(days: v.days));

DateTime? givenOn(AppData d, FamilyMember m, VaccineDose v) => DateTime.tryParse(d.vaccines['${m.id}:${v.key}'] ?? '');

/// A child under 2 with a birth date: the vaccine card applies.
bool needsVaccineCard(FamilyMember m, DateTime now) => m.birth != null && now.difference(m.birth!).inDays < 2 * 366;

// ───────────────────────── For the doctor ─────────────────────────

/// The last three months on one page: profile, BMI, blood pressure and
/// sugar readings, medicines and allergies — to show or send a doctor.
String doctorSummary(AppData d, FamilyMember m, DateTime now) {
  final lines = <String>[];
  final age = m.ageOn(now);
  lines.add('${m.name}${age == null ? '' : trf(' · বয়স {0}', [bnDigits(age)])}${m.sex.isEmpty ? '' : ' · ${m.sex == 'm' ? tr('পুরুষ') : tr('নারী')}'}');
  if (m.isMe && d.emergency.blood.isNotEmpty) lines.add(trf('রক্তের গ্রুপ: {0}', [d.emergency.blood]));
  final w = latest(d, m.id, HealthKind.weight);
  if (m.heightCm != null) lines.add(trf('উচ্চতা: {0}', [heightText(m.heightCm!)]));
  if (w != null) {
    lines.add(trf('ওজন: {0} ({1})', [kg(w.a), shortDate(w.at)]));
    if (m.heightCm != null) {
      final b = bmiOf(w.a, m.heightCm!);
      lines.add(trf('BMI: {0} — {1}', [bnDigits(b.toStringAsFixed(1)), bmiLevel(b).$2]));
    }
  }
  final since = now.subtract(const Duration(days: 92));
  for (final kind in [HealthKind.bp, HealthKind.sugar]) {
    final r = readings(d, m.id, kind).where((h) => h.at.isAfter(since)).toList();
    if (r.isEmpty) continue;
    lines.add('');
    lines.add(trf('{0} (গত ৩ মাস, {1}টা মাপ):', [isEn ? kind.en : kind.bn, bnDigits(r.length)]));
    for (final h in r.reversed.take(12)) {
      lines.add('• ${shortDate(h.at)} ${bnTime(h.at.hour, h.at.minute)} — ${readingText(h)}');
    }
  }
  if (m.isMe) {
    final meds = d.medicines.map((x) => '${x.name}${x.times.isEmpty ? '' : ' (${trf('দিনে {0} বার', [bnDigits(x.times.length)])})'}').toList();
    if (meds.isNotEmpty) lines.addAll(['', trf('চলমান ওষুধ: {0}', [meds.join(', ')])]);
    if (d.emergency.medicines.isNotEmpty && meds.isEmpty) lines.addAll(['', trf('ওষুধ: {0}', [d.emergency.medicines])]);
    if (d.emergency.allergies.isNotEmpty) lines.add(trf('অ্যালার্জি: {0}', [d.emergency.allergies]));
    if (d.emergency.conditions.isNotEmpty) lines.add(trf('রোগ/সমস্যা: {0}', [d.emergency.conditions]));
  }
  lines.addAll(['', trf('My Assistant থেকে · {0}', [fullDate(now)])]);
  return lines.join('\n');
}

/// "আমার বিএমআই কত?", "ওজন কত কমল?", "প্রেশার কেমন?"
String healthAnswer(AppData d, String what, DateTime now, {String member = FamilyMember.meId}) {
  final m = memberOf(d, member);
  final w = latest(d, member, HealthKind.weight);
  switch (what) {
    case 'bmi':
      if (m.heightCm == null || w == null) {
        return tr('BMI বের করতে উচ্চতা আর ওজন লাগবে। স্বাস্থ্য পাতায় উচ্চতা দিন, আর বলুন যেমন “আজ ওজন ৬৮ কেজি”।');
      }
      final b = bmiOf(w.a, m.heightCm!);
      final (lo, hi) = healthyWeight(m.heightCm!);
      return trf('আপনার BMI {0} — {1}। আপনার উচ্চতায় ({2}) সুস্থ ওজন {3}–{4} কেজি; এখন {5}।',
          [bnDigits(b.toStringAsFixed(1)), bmiLevel(b).$2, heightText(m.heightCm!), bnDigits(lo), bnDigits(hi), kg(w.a)]);
    case 'weight':
      if (w == null) return tr('ওজনের কোনো তথ্য নেই। বলুন, যেমন “আজ ওজন ৬৮ কেজি” — পরে যেকোনো সময় জিজ্ঞেস করলে হিসাব দেবো।');
      final ch = weightChange(d, member, now);
      final trend = ch == null || ch.abs() < 0.1 ? '' : (ch < 0 ? trf(' গত এক মাসে {0} কমেছে।', [kg(-ch)]) : trf(' গত এক মাসে {0} বেড়েছে।', [kg(ch)]));
      return trf('শেষ ওজন {0} ({1})।{2}', [kg(w.a), shortDate(w.at), trend]);
    case 'bp':
      final r = latest(d, member, HealthKind.bp);
      if (r == null) return tr('প্রেশারের কোনো তথ্য নেই। মেপে বলুন, যেমন “প্রেশার ১৩০ বাই ৮৫” — পরে যেকোনো সময় জিজ্ঞেস করলে হিসাব দেবো।');
      final week = readings(d, member, HealthKind.bp).where((h) => h.at.isAfter(now.subtract(const Duration(days: 7)))).toList();
      final avg = week.length < 2
          ? ''
          : trf(' এই সপ্তাহের গড় {0}/{1}।', [bnDigits((week.fold(0.0, (a, h) => a + h.a) / week.length).round()), bnDigits((week.fold(0.0, (a, h) => a + (h.b ?? 0)) / week.length).round())]);
      return trf('শেষ মাপ {0} ({1}) — {2}।{3}', [readingText(r), shortDate(r.at), bpLevel(r.a, r.b ?? 0).$2, avg]);
    case 'sugar':
      final r = readings(d, member, HealthKind.sugar);
      if (r.isEmpty) return tr('সুগারের কোনো তথ্য নেই। মেপে বলুন, যেমন “খালি পেটে সুগার ৬.৮” — পরে যেকোনো সময় জিজ্ঞেস করলে হিসাব দেবো।');
      final f = r.lastWhere((h) => h.tag == 'fasting', orElse: () => r.last);
      final last = r.last;
      final parts = [
        trf('শেষ মাপ {0} ({1}) — {2}', [readingText(last), shortDate(last.at), sugarLevel(last.a, fasting: last.tag == 'fasting').$2]),
        if (!identical(f, last) && f.tag == 'fasting') trf('খালি পেটে শেষবার {0}', [mmolText(f.a)]),
      ];
      return '${parts.join('। ')}।';
  }
  return tr('স্বাস্থ্য পাতায় সব মাপ দেখা যাবে।');
}
