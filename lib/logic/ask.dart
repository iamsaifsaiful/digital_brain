/// Everyday questions answered straight from the phone, to the point:
/// prayer, sehri and iftar times, "কাল কী আছে?", how much money is where,
/// savings, medicines, habits, how many notes or numbers are kept, and
/// when a paper expires. Each answer says what was asked — and when there
/// is nothing, says so plainly and how to add it.
library;

import '../models/models.dart';
import 'bn.dart';
import 'calendar_bd.dart';
import 'lang.dart';
import 'money_more.dart' show accountBalance, ZakatSaved, zakatAuto;
import 'cash.dart';
import 'inbox.dart' show inboxAnswer;
import 'parser.dart';
import 'proactive.dart' show remindsOn, specialTitle;
import 'when.dart';
import 'answers.dart' show taskLine;

/// The user's place (for prayer times) and name, set by the app.
String askPlace = 'ঢাকা';
String askUserName = '';

/// What the user entered on the যাকাত page (set by the app).
ZakatSaved askZakat = const ZakatSaved();

bool _has(String text, List<String> ws) => ws.any((w) {
      final n = normalize(w);
      return n.isNotEmpty && text.contains(n);
    });

const _prayers = [
  ('fajr', ['ফজর', 'ফজরের']),
  ('dhuhr', ['জোহর', 'যোহর', 'জোহরের', 'যোহরের', 'জুমা', 'জুম্মা']),
  ('asr', ['আসর', 'আসরের']),
  ('maghrib', ['মাগরিব', 'মাগরিবের']),
  ('isha', ['এশা', 'ইশা', 'এশার', 'ইশার']),
];
const _prayerNames = {'fajr': 'ফজর', 'dhuhr': 'জোহর', 'asr': 'আসর', 'maghrib': 'মাগরিব', 'isha': 'এশা'};

DateTime _prayerAt(SunTimes s, String k) => switch (k) { 'fajr' => s.fajr, 'dhuhr' => s.dhuhr, 'asr' => s.asr, 'maghrib' => s.maghrib, _ => s.isha };

/// Times as said for prayers and the sun: "ভোর ৪:৪০", "সন্ধ্যা ৫:৩৬".
String _t(DateTime d) {
  final t = bnTime(d.hour, d.minute);
  if (isEn) return t;
  if (d.hour >= 4 && d.hour < 6) return t.replaceFirst('সকাল', 'ভোর');
  if (d.hour >= 17 && d.hour < 18) return t.replaceFirst('বিকেল', 'সন্ধ্যা');
  return t;
}

/// Which everyday question [text] (normalized) is, or null.
String? infoTopic(String text) {
  // "রহিম কী লিখেছে?", "করিম কী মেসেজ দিয়েছে?"
  if (_has(text, ['কী লিখেছে', 'কি লিখেছে', 'কী লিখছে', 'কি লিখছে', 'কী মেসেজ দিয়েছে', 'কি মেসেজ দিয়েছে', 'কী পাঠিয়েছে', 'কি পাঠিয়েছে', 'কী বলেছে মেসেজে'])) return 'inbox';
  if (_has(text, ['মেসেজ', 'মেসেজে', 'বার্তা', 'ম্যাসেজ', 'ইমেইল', 'মেইল', 'জিমেইল', 'message', 'mail', 'এসএমএস', 'sms']) ||
      (_has(text, ['হোয়াটসঅ্যাপ', 'হোয়াটসআপ', 'টেলিগ্রাম', 'ইমো', 'মেসেঞ্জার', 'whatsapp', 'telegram', 'imo']) && _has(text, ['এসেছে', 'আসছে', 'লিখেছে', 'লিখছে', 'কী', 'কি', 'কে']))) {
    final sending = _has(text, ['মেসেজ দাও', 'মেসেজ দিন', 'মেসেজ দেন', 'মেসেজ পাঠাও', 'মেসেজ পাঠান', 'লিখে দাও', 'লিখে পাঠাও', 'মেইল করো', 'মেইল পাঠাও', 'send']);
    if (!sending && _has(text, ['এসেছে', 'আসছে', 'এলো', 'আসলো', 'লিখেছে', 'লিখছে', 'পাঠিয়েছে', 'নতুন', 'জরুরি', 'কী আছে', 'কি আছে', 'কোন', 'কয়টা', 'দেখাও', 'পড়ো', 'পড়ে শোনাও', 'শোনাও'])) return 'inbox';
  }
  if (_has(text, ['সেহরি', 'সাহরি', 'সেহেরি'])) return 'sehri';
  if (_has(text, ['ইফতার'])) return 'iftar';
  if (_has(text, ['সূর্যোদয়', 'সূর্য ওঠে', 'সূর্য উঠবে', 'sunrise'])) return 'sunrise';
  if (_has(text, ['সূর্যাস্ত', 'সূর্য ডুববে', 'সূর্য ডোবে', 'sunset'])) return 'sunset';
  if (_has(text, ['নামাজ', 'নামায', 'ওয়াক্ত', 'আজান', 'আযান']) || _prayers.any((p) => _has(text, p.$2))) return 'prayer';
  if (_has(text, ['সঞ্চয়', 'সেভিংস', 'savings', 'জমানো টাকা', 'কত জমেছে', 'কত জমল'])) return 'savings';
  if (_has(text, ['ব্যালেন্স', 'balance', 'হাতে কত', 'কত টাকা আছে', 'টাকা কত আছে', 'কোথায় কত টাকা']) &&
      !_has(text, ['প্রজেক্ট', 'প্রকল্প', 'project', 'কাছে', 'পাওনা', 'দেনা', 'পাবো', 'পাব', 'বাকি', 'এই মাসে', 'মাসের'])) {
    return 'money';
  }
  if (_has(text, ['যাকাত', 'জাকাত', 'zakat'])) return 'zakat';
  if (_has(text, ['ওষুধ', 'ঔষধ', 'অষুধ', 'মেডিসিন'])) return 'medicines';
  if (_has(text, ['অভ্যাস', 'habit'])) return 'habits';
  if (_has(text, ['মেয়াদ', 'expiry', 'এক্সপায়ার'])) return 'expiry';
  if (_has(text, ['কয়টা নোট', 'কয়টি নোট', 'কতগুলো নোট', 'কত নোট', 'নোট কয়টা', 'নোট কতগুলো', 'কী কী নোট', 'কি কি নোট'])) return 'notes';
  if (_has(text, ['জন্মদিন', 'বিবাহবার্ষিকী', 'মৃত্যুবার্ষিকী', 'বিশেষ দিন']) && _has(text, ['সামনে', 'কার কার', 'কবে কবে', 'কী কী', 'কি কি', 'এই মাসে', 'আসছে'])) return 'special';
  final w = words(text);
  // A day by name, or a date ("৩১ ডিসেম্বর কী আছে?", "২৩ তারিখে কী আছে?").
  final dayWord = w.any((x) => const ['কাল', 'কালকে', 'আগামীকাল', 'পরশু', 'পরশুদিন'].map(normalize).contains(x)) ||
      RegExp('[০-৯0-9]{1,2}\\s+(?:${bnMonths.map(normalize).join('|')}|${normalize('তারিখ')})').hasMatch(text);
  if (dayWord && _has(text, ['কী আছে', 'কি আছে', 'কী কী', 'কি কি', 'কী কাজ', 'কি কাজ', 'কোনো কাজ', 'প্ল্যান', 'প্রোগ্রাম', 'শিডিউল', 'কী করতে হবে', 'কি করতে হবে'])) return 'day';
  return null;
}

/// The answer to an everyday question, or null when it is not one.
String? infoAnswer(AppData d, String said, DateTime now) {
  final text = normalize(said);
  final topic = infoTopic(text);
  if (topic == null) return null;
  final place = placeNamed(askPlace);
  final today = sunTimes(now, place);
  final tomorrow = sunTimes(now.add(const Duration(days: 1)), place);
  final where = _at(place.label);
  switch (topic) {
    case 'inbox':
      return inboxAnswer(d, said, now);
    case 'sehri':
      // The last time for sehri is the start of Fajr.
      final s = now.isBefore(today.fajr) ? today : tomorrow;
      return trf('{0} {1} সেহরির শেষ সময় {2} (আনুমানিক; স্থানীয় মসজিদের সময় মিলিয়ে নিন)।', [where, s == today ? tr('আজ') : tr('কাল'), _t(s.fajr)]);
    case 'iftar':
      final s = now.isBefore(today.maghrib) ? today : tomorrow;
      final left = s.maghrib.difference(now);
      final soon = s == today && left.inMinutes < 180 ? trf(' — আর {0}', [_left(left)]) : '';
      return trf('{0} {1} ইফতার {2}{3} (আনুমানিক)।', [where, s == today ? tr('আজ') : tr('কাল'), _t(s.maghrib), soon]);
    case 'sunrise':
      final s = now.isBefore(today.sunrise) ? today : tomorrow;
      return trf('{0} {1} সূর্যোদয় {2}।', [where, s == today ? tr('আজ') : tr('কাল'), _t(s.sunrise)]);
    case 'sunset':
      final s = now.isBefore(today.sunset) ? today : tomorrow;
      return trf('{0} {1} সূর্যাস্ত {2}।', [where, s == today ? tr('আজ') : tr('কাল'), _t(s.sunset)]);
    case 'prayer':
      final named = [for (final p in _prayers) if (_has(text, p.$2)) p.$1];
      if (named.isNotEmpty) {
        final k = named.first;
        final s = now.isBefore(_prayerAt(today, k)) ? today : tomorrow;
        final jumuah = k == 'dhuhr' && _has(text, ['জুমা', 'জুম্মা']) ? tr(' (জুমার আজান স্থানীয় মসজিদে একটু আগে-পরে হতে পারে)') : '';
        return trf('{0} {1} {2} শুরু {3}।{4}', [where, s == today ? tr('আজ') : tr('কাল'), tr(_prayerNames[k]!), _t(_prayerAt(s, k)), jumuah]);
      }
      final next = [for (final p in _prayers) (p.$1, _prayerAt(today, p.$1))].where((x) => x.$2.isAfter(now)).firstOrNull;
      final list = [for (final p in _prayers) '${tr(_prayerNames[p.$1]!)} ${_t(_prayerAt(today, p.$1))}'].join(', ');
      final nextText = next == null ? '' : trf(' পরের ওয়াক্ত {0} — {1}।', [tr(_prayerNames[next.$1]!), _t(next.$2)]);
      return trf('{0} আজকের নামাজের সময়: {1}।{2}', [where, list, nextText]);
    case 'money':
      if (d.accounts.isNotEmpty) {
        final named = [for (final a in d.accounts) if (_has(text, [a.name, a.kind.bn])) a];
        if (named.length == 1) {
          return trf('{0} অ্যাকাউন্টে এখন {1} টাকা আছে।', [named.first.name, bnNumber(accountBalance(d, named.first))]);
        }
        final parts = [for (final a in d.accounts) '${a.name} ${bnNumber(accountBalance(d, a))}'];
        final total = d.accounts.fold<int>(0, (s, a) => s + accountBalance(d, a));
        return trf('সব অ্যাকাউন্ট মিলিয়ে {0} টাকা — {1}।', [bnNumber(total), parts.join(', ')]);
      }
      final m = monthSums(d.cash, now);
      if (m.income == 0 && m.expense == 0) {
        return tr('টাকার হিসাবের কোনো তথ্য নেই। অ্যাকাউন্ট পাতায় হাতের টাকা, বিকাশ, ব্যাংকের জমা যুক্ত করতে পারেন — পরে জিজ্ঞেস করলেই কোথায় কত আছে বলে দেবো।');
      }
      return trf('এই মাসে আয় {0}, খরচ {1} টাকা — ব্যালেন্স {2} টাকা। কোন অ্যাকাউন্টে কত আছে জানতে অ্যাকাউন্ট পাতায় হিসাব যুক্ত করুন।',
          [bnNumber(m.income), bnNumber(m.expense), m.balance >= 0 ? bnNumber(m.balance) : trf('মাইনাস {0}', [bnNumber(-m.balance)])]);
    case 'zakat':
      final z = zakatAuto(d, now, askZakat);
      if (z.nisab <= 0) {
        return trf('আপনার হিসাব থেকে যাকাতযোগ্য সম্পদ এখন প্রায় {0} টাকা (নগদ, ব্যাংক-সঞ্চয়, পাওনা থেকে দেনা বাদে)। নিসাব জানতে আজকের রুপার দাম লাগবে — যাকাত পাতায় রুপার দাম আর সোনা-রুপার পরিমাণ দিন, তারপর জিজ্ঞেস করলেই যাকাত বলে দেবো।', [bnNumber(z.net < 0 ? 0 : z.net)]);
      }
      if (!z.due) return trf('আপনার যাকাতযোগ্য সম্পদ {0} টাকা — নিসাব {1} টাকার কম, তাই যাকাত ফরজ নয় (আনুমানিক হিসাব)।', [bnNumber(z.net < 0 ? 0 : z.net), bnNumber(z.nisab)]);
      return trf('আপনার যাকাতযোগ্য সম্পদ {0} টাকা, যাকাত প্রায় {1} টাকা (২.৫%)। এটা আনুমানিক — নিশ্চিত হতে আলেমের পরামর্শ নিন।', [bnNumber(z.net), bnNumber(z.zakat)]);
    case 'savings':
      if (d.goals.isEmpty) {
        return tr('সঞ্চয়ের কোনো তথ্য নেই। “সঞ্চয় ও কিস্তি” পাতায় লক্ষ্য যুক্ত করতে পারেন — পরে জিজ্ঞেস করলেই কত জমল বলে দেবো।');
      }
      final saved = d.goals.fold<int>(0, (s, g) => s + g.saved);
      final parts = [for (final g in d.goals) trf('{0} {1} টাকা ({2}%)', [g.name, bnNumber(g.saved), bnDigits((g.progress * 100).round())])];
      return trf('সঞ্চয়ে মোট জমেছে {0} টাকা — {1}।', [bnNumber(saved), parts.join(', ')]);
    case 'medicines':
      if (d.medicines.isEmpty) {
        return tr('ওষুধের কোনো তথ্য নেই। ওষুধ পাতায় নাম আর খাওয়ার সময় যুক্ত করতে পারেন — সময়মতো মনে করিয়ে দেবো।');
      }
      final lines = [for (final m in d.medicines) '• ${m.name} — ${m.times.map((t) => bnTime(t ~/ 60, t % 60)).join(', ')}'];
      return trf('{0}টা ওষুধ চলছে:\n{1}', [bnDigits(d.medicines.length), lines.join('\n')]);
    case 'habits':
      if (d.habits.isEmpty) return tr('অভ্যাসের কোনো তথ্য নেই। অভ্যাস পাতায় যুক্ত করতে পারেন — প্রতিদিন টিক দিলে কত দিন টানা হলো বলে দেবো।');
      final parts = [
        for (final h in d.habits)
          '${h.name} — ${h.doneOn(now) ? tr('আজ হয়েছে') : tr('আজ বাকি')}${h.streak(now) > 1 ? trf(', টানা {0} দিন', [bnDigits(h.streak(now))]) : ''}',
      ];
      return parts.join('; ');
    case 'notes':
      if (d.notes.isEmpty) return tr('কোনো নোট নেই। বলুন “মনে রাখো: …” — রেখে দেবো, পরে জিজ্ঞেস করলেই বলবো।');
      final cats = <String, int>{};
      for (final n in d.notes) {
        cats[n.category] = (cats[n.category] ?? 0) + 1;
      }
      return trf('{0}টা নোট আছে — {1}।', [bnDigits(d.notes.length), cats.entries.map((e) => '${e.key} ${bnDigits(e.value)}টা').join(', ')]);
    case 'special':
      final upcoming = [...d.specialDays]..sort((a, b) => a.next(now).compareTo(b.next(now)));
      final soon = upcoming.where((s) => s.next(now).difference(dayOnly(now)).inDays <= 60).take(5).toList();
      if (d.specialDays.isEmpty) return tr('বিশেষ দিনের কোনো তথ্য নেই। বলুন, যেমন “রহিমের জন্মদিন ১২ মার্চ” — প্রতি বছর মনে করিয়ে দেবো।');
      if (soon.isEmpty) return tr('সামনের দুই মাসে কোনো বিশেষ দিন নেই।');
      return trf('সামনে: {0}।', [soon.map((s) => '${specialTitle(s, on: s.next(now))} ${sayWhen(s.next(now), now, withTime: false)}').join('; ')]);
    case 'day':
      final w = parseWhen(said, now);
      final day = w != null && w.hasDay ? dayOnly(w.day) : dayOnly(now.add(const Duration(days: 1)));
      final rems = [for (final r in d.reminders) if (remindsOn(r, day)) r]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
      final tasks = [for (final t in d.tasks) if (!t.done && t.onDay(day)) t];
      final specials = [for (final s in d.specialDays) if (dayOnly(s.next(day)) == day) s];
      final label = sayWhen(day, now, withTime: false);
      if (rems.isEmpty && tasks.isEmpty && specials.isEmpty) return trf('{0} কিছু রাখা নেই — কোনো রিমাইন্ডার বা কাজ নেই।', [label]);
      final lines = [
        for (final r in rems) '• ${bnTime(r.hour, r.minute)} — ${r.title}',
        for (final t in tasks) '• ${tr('কাজ')}: ${t.span == TaskSpan.day ? t.title : taskLine(t, now)}',
        for (final s in specials) '• ${specialTitle(s, on: day)}',
      ];
      return trf('{0}:\n{1}', [label, lines.join('\n')]);
    case 'expiry':
      // Only words that name a paper narrow it ("পাসপোর্টের মেয়াদ কবে?");
      // the rest ("কোনটা", "দিকে", "আমার") ask about all of them.
      final terms = [
        for (final t in searchTerms(text))
          if (!_has(t, ['মেয়াদ', 'কবে', 'শেষ']) && d.docs.any((x) => normalize('${x.title} ${x.folder}').contains(t))) t
      ];
      final docs = [
        for (final x in d.docs)
          if (x.expiry != null && (terms.isEmpty || terms.any((t) => normalize('${x.title} ${x.folder}').contains(t)))) x,
      ]..sort((a, b) => a.expiry!.compareTo(b.expiry!));
      if (docs.isEmpty) {
        return tr('মেয়াদের কোনো তথ্য নেই। ডকুমেন্টসে কাগজটি রেখে মেয়াদের তারিখ দিলে শেষ হওয়ার আগে মনে করিয়ে দেবো।');
      }
      return docs.take(4).map((x) {
        final left = dayOnly(x.expiry!).difference(dayOnly(now)).inDays;
        final how = left < 0 ? trf('{0} দিন আগে শেষ হয়ে গেছে', [bnDigits(-left)]) : trf('আর {0} দিন বাকি', [bnDigits(left)]);
        return trf('{0}: মেয়াদ শেষ {1}, {2}।', [x.title, fullDate(x.expiry!), how]);
      }).join(' ');
  }
  return null;
}

/// "ঢাকায়", "সিলেটে", "রাজশাহীতে" / "In Dhaka".
String _at(String place) {
  if (isEn) return 'In $place';
  if (place.endsWith('া')) return '$placeয়';
  if (RegExp('[িীুূেো]\$').hasMatch(place)) return '$placeতে';
  return '$placeে';
}

String _left(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return trf('{0} মিনিট', [bnDigits(m)]);
  return m == 0 ? trf('{0} ঘণ্টা', [bnDigits(h)]) : trf('{0} ঘণ্টা {1} মিনিট', [bnDigits(h), bnDigits(m)]);
}
