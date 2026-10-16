/// Everything in the app as a PDF report: each part on its own (from its
/// page) or all of them together (সেটিংস › সবকিছু PDF আকারে).
///
/// This file only decides what goes in; the phone lays it out
/// (PdfMaker.kt), so Bengali letters come out right. Passwords and other
/// vault items never go in, nor notes or memories that mention a PIN,
/// OTP or password.
library;

import '../models/models.dart';
import 'bn.dart';
import 'cash.dart';
import 'health.dart';
import 'lang.dart';
import 'ledger.dart';
import 'money_more.dart';
import 'parser.dart' show mentionsSecret;
import 'phrases.dart' show possessive;
import 'proactive.dart' show specialTitle;

enum ReportPart {
  tasks('কাজের তালিকা', 'tasks'),
  reminders('তারিখ ও রিমাইন্ডার', 'reminders'),
  money('আয়-ব্যয়', 'income-expense'),
  ledger('ধার-দেনা', 'loans'),
  projects('অন্যান্য হিসাব', 'separate-accounts'),
  accounts('অ্যাকাউন্ট, সঞ্চয় ও কিস্তি', 'accounts'),
  shops('দোকান', 'shops'),
  notes('নোট ও অন্যান্য', 'notes'),
  contacts('যোগাযোগ', 'contacts'),
  docs('ডকুমেন্টস', 'documents'),
  specialDays('বিশেষ দিন', 'special-days'),
  health('স্বাস্থ্য', 'health'),
  memories('সহকারীর স্মৃতি', 'memories');

  const ReportPart(this.label, this.slug);
  final String label;
  final String slug;
}

/// Narrows a single part: one month of আয়-ব্যয়, one আলাদা হিসাব, one
/// person's ধার-দেনা.
class ReportScope {
  const ReportScope({this.month, this.projectId, this.personKey, this.shopId});
  final String? shopId;
  final DateTime? month;
  final String? projectId;
  final String? personKey;
}

/// A table cell with a colour ("g" green, "o" orange, "m" muted) or bold.
Map<String, Object?> cell(String s, {String? tone, bool bold = false}) => {'s': s, if (tone != null) 'c': tone, if (bold) 'b': true};

class _Doc {
  final blocks = <Map<String, Object?>>[];
  void h1(String t) => blocks.add({'t': 'h1', 'text': t});
  void h2(String t) => blocks.add({'t': 'h2', 'text': t});
  void p(String t, {bool muted = false}) => blocks.add({'t': 'p', 'text': t, if (muted) 'muted': true});
  void stats(List<List<String>> items) => blocks.add({'t': 'stats', 'items': items});
  void kv(List<List<String>> rows) => blocks.add({'t': 'kv', 'rows': [for (final r in rows) if (r[1].trim().isNotEmpty) r]});
  void table(List<String> cols, List<List<Object>> rows, {List<num>? w, List<String>? a}) =>
      blocks.add({'t': 'table', 'cols': cols, 'rows': rows, if (w != null) 'w': w, if (a != null) 'a': a});
  void none(String what) => p(trf('{0} — এখনো কিছু রাখা হয়নি।', [what]), muted: true);
  void pageBreak() => blocks.add({'t': 'break'});
}

String _d(DateTime d) => fullDate(d);
String _hm(DateTime d) => bnTime(d.hour, d.minute);

/// "পাবেন ৳৫০০" / "দেবেন ৳৫০০" / "শোধ" with its colour.
Map<String, Object?> _owe(int b) => b > 0
    ? cell(trf('পাবেন {0}', [taka(b)]), tone: 'g', bold: true)
    : b < 0
        ? cell(trf('দেবেন {0}', [taka(-b)]), tone: 'o', bold: true)
        : cell(tr('শোধ'), tone: 'm');

/// The file name, e.g. `my-assistant-loans-20261015.pdf`.
String reportFileName(Set<ReportPart> parts, DateTime now, {String? extra}) {
  final what = parts.length == 1 ? parts.first.slug : 'all';
  final day = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return 'my-assistant-$what${extra == null ? '' : '-$extra'}-$day.pdf';
}

/// The report as sent to the phone's PDF maker.
Map<String, Object?> reportSpec(AppData d, Set<ReportPart> parts, DateTime now, {String userName = '', ReportScope scope = const ReportScope(), String? title}) {
  final doc = _Doc();
  final ordered = [for (final p in ReportPart.values) if (parts.contains(p)) p];
  final all = ordered.length > 1;
  for (final (i, part) in ordered.indexed) {
    if (all && i > 0) doc.pageBreak();
    if (all) doc.h1(tr(part.label));
    switch (part) {
      case ReportPart.tasks:
        _tasks(doc, d, now);
      case ReportPart.reminders:
        _reminders(doc, d, now);
      case ReportPart.money:
        _money(doc, d, now, scope.month);
      case ReportPart.ledger:
        _ledger(doc, d, scope.personKey);
      case ReportPart.projects:
        _projects(doc, d, scope.projectId);
      case ReportPart.accounts:
        _accounts(doc, d);
      case ReportPart.shops:
        _shops(doc, d, now, scope.shopId);
      case ReportPart.notes:
        _notes(doc, d);
      case ReportPart.contacts:
        _contacts(doc, d);
      case ReportPart.docs:
        _docs(doc, d);
      case ReportPart.specialDays:
        _special(doc, d, now);
      case ReportPart.health:
        _health(doc, d, now, userName);
      case ReportPart.memories:
        _memories(doc, d);
    }
  }
  if (all) {
    doc.p('');
    doc.p(tr('পাসওয়ার্ড, PIN ও অন্যান্য গোপন তথ্য নিরাপত্তার জন্য এই PDF-এ রাখা হয়নি।'), muted: true);
  }
  final who = userName.trim();
  return {
    'brand': 'My Assistant',
    'title': title ?? (all ? (who.isEmpty ? tr('সব তথ্য') : trf('{0} সব তথ্য', [_whose(who)])) : tr(ordered.isEmpty ? '' : ordered.first.label)),
    'subtitle': trf('তৈরি: {0}, {1}', [_d(now), _hm(now)]),
    'footer': trf('My Assistant · {0}', [_d(now)]),
    'pageWord': tr('পাতা'),
    'bnDigits': !isEn,
    'blocks': doc.blocks,
  };
}

String _whose(String name) => isEn ? "$name's" : possessive(name);

// ───────────────────────── Parts ─────────────────────────

void _tasks(_Doc doc, AppData d, DateTime now) {
  if (d.tasks.isEmpty) return doc.none(tr('কাজের তালিকা'));
  final open = d.tasks.where((t) => !t.done).length;
  doc.stats([
    [tr('বাকি কাজ'), bnNumber(open), open > 0 ? 'o' : 'g'],
    [tr('শেষ হয়েছে'), bnNumber(d.tasks.length - open), 'g'],
  ]);
  final lists = <String, List<Task>>{};
  for (final t in d.tasks) {
    lists.putIfAbsent(t.list, () => []).add(t);
  }
  final names = lists.keys.toList()..sort((a, b) => a.isEmpty ? -1 : (b.isEmpty ? 1 : a.compareTo(b)));
  for (final name in names) {
    final ts = lists[name]!
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        final ad = a.due ?? DateTime(9999), bd = b.due ?? DateTime(9999);
        return ad.compareTo(bd);
      });
    doc.h2(name.isEmpty ? tr('মূল তালিকা') : name);
    doc.table(
      [tr('কাজ'), tr('কবে'), tr('অবস্থা')],
      [
        for (final t in ts)
          [
            t.title,
            t.due == null ? '—' : _d(t.due!),
            t.done
                ? cell(t.doneAt == null ? tr('শেষ') : trf('শেষ ({0})', [shortDate(t.doneAt!)]), tone: 'g')
                : (t.due != null && dayOnly(t.due!).isBefore(dayOnly(now)) ? cell(tr('সময় পেরিয়েছে'), tone: 'o', bold: true) : cell(tr('বাকি'), tone: 'o')),
          ],
      ],
      w: [5, 2.2, 1.8],
    );
  }
}

void _reminders(_Doc doc, AppData d, DateTime now) {
  if (d.reminders.isEmpty) return doc.none(tr('রিমাইন্ডার'));
  final rs = List.of(d.reminders)..sort((a, b) => a.notifyAt(now).compareTo(b.notifyAt(now)));
  final upcoming = [for (final r in rs) if (r.repeat != Repeat.none || !r.notifyAt(now).isBefore(now)) r];
  final past = [for (final r in rs) if (!upcoming.contains(r)) r];
  List<Object> row(Reminder r) {
    final at = r.notifyAt(now);
    return [
      r.alarm ? '⏰ ${r.title}' : r.title,
      _d(at),
      bnTime(r.hour, r.minute),
      tr(r.repeat.label),
      r.enabled ? cell(tr('চালু'), tone: 'g') : cell(tr('বন্ধ'), tone: 'm'),
    ];
  }

  final cols = [tr('বিষয়'), tr('তারিখ'), tr('সময়'), tr('কতবার'), tr('অবস্থা')];
  const w = [4.2, 2.4, 1.5, 1.8, 1.1];
  if (upcoming.isNotEmpty) {
    doc.h2(tr('সামনে যা আছে'));
    doc.table(cols, [for (final r in upcoming) row(r)], w: w);
  }
  if (past.isNotEmpty) {
    doc.h2(tr('পেরিয়ে গেছে'));
    doc.table(cols, [for (final r in past.reversed) row(r)], w: w);
  }
}

void _money(_Doc doc, AppData d, DateTime now, DateTime? only) {
  final personal = [for (final e in d.cash) if (e.projectId == null) e];
  if (personal.isEmpty) return doc.none(tr('আয়-ব্যয়'));
  final accounts = {for (final a in d.accounts) a.id: accountLabel(a)};
  final months = <String, List<CashEntry>>{};
  for (final e in personal) {
    months.putIfAbsent(monthKey(e.date), () => []).add(e);
  }
  var keys = months.keys.toList()..sort((a, b) => b.compareTo(a));
  if (only != null) keys = [monthKey(only)];

  if (only == null) {
    var inc = 0, exp = 0;
    for (final e in personal) {
      e.kind == CashKind.income ? inc += e.amount : exp += e.amount;
    }
    doc.stats([
      [tr('মোট আয়'), taka(inc), 'g'],
      [tr('মোট খরচ'), taka(exp), 'o'],
      [tr('ব্যালেন্স'), '${inc - exp < 0 ? '−' : ''}${taka(inc - exp)}', inc - exp < 0 ? 'o' : 'g'],
    ]);
    // A month-by-month summary first.
    doc.h2(tr('মাস অনুযায়ী'));
    doc.table(
      [tr('মাস'), tr('আয়'), tr('খরচ'), tr('ব্যালেন্স')],
      [
        for (final k in keys)
          () {
            final s = monthSums(personal, DateTime.parse('$k-01'));
            return <Object>[monthTitle(DateTime.parse('$k-01')), cell(taka(s.income), tone: 'g'), cell(taka(s.expense), tone: 'o'), cell('${s.balance < 0 ? '−' : ''}${taka(s.balance)}', tone: s.balance < 0 ? 'o' : 'g', bold: true)];
          }(),
      ],
      w: [3, 2, 2, 2],
      a: ['l', 'r', 'r', 'r'],
    );
  }

  for (final k in keys) {
    final month = DateTime.parse('$k-01');
    final list = (months[k] ?? [])..sort((a, b) => a.date.compareTo(b.date));
    final r = monthReport(d, month);
    doc.h2(monthTitle(month));
    if (only != null) {
      doc.stats([
        [tr('আয়'), taka(r.income), 'g'],
        [tr('খরচ'), taka(r.expense), 'o'],
        [tr('ব্যালেন্স'), '${r.balance < 0 ? '−' : ''}${taka(r.balance)}', r.balance < 0 ? 'o' : 'g'],
      ]);
    } else {
      doc.p(trf('আয় {0} · খরচ {1} · ব্যালেন্স {2}{3}', [taka(r.income), taka(r.expense), r.balance < 0 ? '−' : '', taka(r.balance)]), muted: true);
    }
    if (list.isEmpty) {
      doc.p(tr('এই মাসে কিছু লেখা নেই।'), muted: true);
      continue;
    }
    doc.table(
      [tr('তারিখ'), tr('ধরন'), tr('খাত'), tr('বিবরণ'), tr('টাকা')],
      [
        for (final e in list)
          [
            shortDate(e.date),
            tr(e.kind.label),
            tr(e.category),
            [e.note, if (e.accountId != null && accounts[e.accountId] != null) '(${accounts[e.accountId]})'].where((s) => s.isNotEmpty).join(' '),
            cell('${e.kind == CashKind.income ? '+' : '−'}${taka(e.amount)}', tone: e.kind == CashKind.income ? 'g' : 'o', bold: true),
          ],
      ],
      w: [1.6, 1.1, 2, 3.6, 1.9],
      a: ['l', 'l', 'l', 'l', 'r'],
    );
    if (r.byCategory.isNotEmpty) {
      doc.table(
        [tr('খাত অনুযায়ী খরচ'), tr('টাকা'), tr('অংশ')],
        [
          for (final c in r.byCategory)
            [tr(c.key), taka(c.value), r.expense == 0 ? '—' : '${bnDigits((c.value * 100 / r.expense).round())}%'],
        ],
        w: [5, 2, 1.4],
        a: ['l', 'r', 'r'],
      );
    }
  }
}

void _ledger(_Doc doc, AppData d, String? onlyKey) {
  if (d.ledger.isEmpty) return doc.none(tr('ধার-দেনা'));
  final people = balances(d.ledger);
  if (onlyKey == null) {
    final t = totals(d.ledger);
    doc.stats([
      [tr('মোট পাবেন'), taka(t.receivable), 'g'],
      [tr('মোট দেবেন'), taka(t.payable), 'o'],
      [tr('নিট'), '${t.net < 0 ? '−' : ''}${taka(t.net)}', t.net < 0 ? 'o' : 'g'],
    ]);
    doc.h2(tr('কার সাথে কত'));
    doc.table(
      [tr('নাম'), tr('মোবাইল'), tr('লেনদেন'), tr('এখন')],
      [
        for (final p in people) [p.name, p.phone.isEmpty ? '—' : showPhone(p.phone), bnNumber(p.count), _owe(p.balance)],
      ],
      w: [3, 2.4, 1.2, 2.4],
      a: ['l', 'l', 'r', 'r'],
    );
  }
  for (final p in people) {
    if (onlyKey != null && p.key != onlyKey) continue;
    final rows = runningForKey(d.ledger, p.key);
    doc.h2(p.phone.isEmpty ? p.name : '${p.name} · ${showPhone(p.phone)}');
    if (onlyKey != null) {
      doc.stats([
        [tr('দিয়েছি'), taka(p.lentTotal + p.repaidTotal), 'o'],
        [tr('পেয়েছি'), taka(p.borrowedTotal + p.receivedTotal), 'g'],
        [tr('এখন'), p.balance == 0 ? tr('শোধ') : (p.balance > 0 ? trf('পাবেন {0}', [taka(p.balance)]) : trf('দেবেন {0}', [taka(-p.balance)])), p.balance < 0 ? 'o' : 'g'],
      ]);
    }
    doc.table(
      [tr('তারিখ'), tr('কী হলো'), tr('টাকা'), tr('এরপর'), tr('নোট')],
      [
        for (final (e, after) in rows)
          [
            _d(e.date),
            tr(e.kind.label),
            cell(taka(e.amount), tone: e.kind.outflow ? 'o' : 'g', bold: true),
            _owe(after),
            [e.note, if (e.due != null) trf('ফেরতের দিন {0}', [shortDate(e.due!)])].where((s) => s.isNotEmpty).join(' · '),
          ],
      ],
      w: [2.2, 1.8, 1.7, 2, 2.6],
      a: ['l', 'l', 'r', 'r', 'l'],
    );
  }
}

void _projects(_Doc doc, AppData d, String? onlyId) {
  final ps = [for (final p in d.projects) if (onlyId == null || p.id == onlyId) p];
  if (ps.isEmpty) return doc.none(tr('অন্যান্য হিসাব'));
  if (onlyId == null && ps.length > 1) {
    doc.table(
      [tr('হিসাব'), tr('আয়'), tr('খরচ'), tr('বাকি')],
      [
        for (final p in ps)
          () {
            final s = projectSums(d.cash, p.id);
            return <Object>[p.closed ? trf('{0} (বন্ধ)', [p.name]) : p.name, cell(taka(s.income), tone: 'g'), cell(taka(s.expense), tone: 'o'), cell('${s.balance < 0 ? '−' : ''}${taka(s.balance)}', tone: s.balance < 0 ? 'o' : 'g', bold: true)];
          }(),
      ],
      w: [3.5, 2, 2, 2],
      a: ['l', 'r', 'r', 'r'],
    );
  }
  for (final p in ps) {
    final s = projectSums(d.cash, p.id);
    final list = [for (final e in d.cash) if (e.projectId == p.id) e]..sort((a, b) => a.date.compareTo(b.date));
    doc.h2(p.closed ? trf('{0} (বন্ধ)', [p.name]) : p.name);
    doc.stats([
      [tr('আয়'), taka(s.income), 'g'],
      [tr('খরচ'), taka(s.expense), 'o'],
      [tr('বাকি'), '${s.balance < 0 ? '−' : ''}${taka(s.balance)}', s.balance < 0 ? 'o' : 'g'],
      if (p.budget > 0) [tr('বাজেট'), taka(p.budget), s.expense > p.budget ? 'o' : ''],
    ]);
    if (list.isEmpty) {
      doc.p(tr('এই হিসাবে এখনো কিছু লেখা নেই।'), muted: true);
      continue;
    }
    doc.table(
      [tr('তারিখ'), tr('ধরন'), tr('খাত'), tr('বিবরণ'), tr('টাকা')],
      [
        for (final e in list)
          [_d(e.date), tr(e.kind.label), tr(e.category), e.note, cell('${e.kind == CashKind.income ? '+' : '−'}${taka(e.amount)}', tone: e.kind == CashKind.income ? 'g' : 'o', bold: true)],
      ],
      w: [2.1, 1.1, 2, 3.2, 1.9],
      a: ['l', 'l', 'l', 'l', 'r'],
    );
  }
}

void _accounts(_Doc doc, AppData d) {
  if (d.accounts.isEmpty && d.transfers.isEmpty && d.goals.isEmpty && d.installments.isEmpty) return doc.none(tr('অ্যাকাউন্ট, সঞ্চয় ও কিস্তি'));
  final names = {for (final a in d.accounts) a.id: accountLabel(a)};
  if (d.accounts.isNotEmpty) {
    doc.h2(tr('অ্যাকাউন্ট'));
    final total = totalBalance(d);
    doc.table(
      [tr('অ্যাকাউন্ট'), tr('ধরন'), tr('ব্যালেন্স')],
      [
        for (final a in d.accounts)
          () {
            final b = accountBalance(d, a);
            return <Object>[accountLabel(a), isEn ? a.kind.en : a.kind.bn, cell('${b < 0 ? '−' : ''}${taka(b)}', tone: b < 0 ? 'o' : 'g', bold: true)];
          }(),
        [cell(tr('মোট'), bold: true), '', cell('${total < 0 ? '−' : ''}${taka(total)}', bold: true)],
      ],
      w: [3.5, 2.5, 2.2],
      a: ['l', 'l', 'r'],
    );
  }
  if (d.transfers.isNotEmpty) {
    doc.h2(tr('এক অ্যাকাউন্ট থেকে আরেকটায়'));
    final ts = List.of(d.transfers)..sort((a, b) => b.date.compareTo(a.date));
    doc.table(
      [tr('তারিখ'), tr('থেকে'), tr('যেখানে'), tr('টাকা'), tr('খরচ')],
      [
        for (final t in ts) [_d(t.date), names[t.from] ?? '—', names[t.to] ?? '—', taka(t.amount), t.fee > 0 ? taka(t.fee) : '—'],
      ],
      w: [2.2, 2.2, 2.2, 1.8, 1.4],
      a: ['l', 'l', 'l', 'r', 'r'],
    );
  }
  if (d.goals.isNotEmpty) {
    doc.h2(tr('সঞ্চয়ের লক্ষ্য'));
    doc.table(
      [tr('লক্ষ্য'), tr('দরকার'), tr('জমেছে'), tr('বাকি'), tr('শেষ তারিখ')],
      [
        for (final g in d.goals)
          () {
            final saved = g.deposits.fold<int>(0, (s, x) => s + x.amount);
            final left = (g.target - saved).clamp(0, g.target);
            return <Object>[g.name, taka(g.target), cell(taka(saved), tone: 'g'), left == 0 ? cell(tr('পূর্ণ'), tone: 'g', bold: true) : taka(left), g.deadline == null ? '—' : _d(g.deadline!)];
          }(),
      ],
      w: [3, 1.8, 1.8, 1.8, 2.2],
      a: ['l', 'r', 'r', 'r', 'l'],
    );
  }
  if (d.installments.isNotEmpty) {
    doc.h2(tr('কিস্তি'));
    doc.table(
      [tr('নাম'), tr('ধরন'), tr('মাসে'), tr('দেওয়া'), tr('বাকি'), tr('শেষ মাস')],
      [
        for (final i in d.installments)
          [i.name, isEn ? i.kind.en : i.kind.bn, taka(i.amount), trf('{0}/{1}', [bnDigits(i.paidCount), bnDigits(i.months)]), cell(taka(i.left * i.amount), tone: i.left > 0 ? 'o' : 'g'), monthTitle(i.end)],
      ],
      w: [2.6, 2, 1.6, 1.3, 1.8, 2],
      a: ['l', 'l', 'r', 'c', 'r', 'l'],
    );
  }
}

void _notes(_Doc doc, AppData d) {
  final hidden = d.notes.where((n) => mentionsSecret('${n.title} ${n.body}')).length;
  final notes = [for (final n in d.notes) if (!mentionsSecret('${n.title} ${n.body}')) n];
  if (notes.isEmpty && hidden == 0) return doc.none(tr('নোট'));
  final cats = <String, List<Note>>{};
  for (final n in notes) {
    cats.putIfAbsent(n.category, () => []).add(n);
  }
  final names = cats.keys.toList()..sort();
  for (final c in names) {
    doc.h2(tr(c));
    for (final n in cats[c]!..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))) {
      final head = [
        if (n.title.trim().isNotEmpty) n.title.trim(),
      ].join();
      doc.blocks.add({'t': 'p', 'text': head.isEmpty ? '•' : '• $head'});
      if (n.body.trim().isNotEmpty && n.body.trim() != n.title.trim()) doc.p(n.body.trim());
      doc.p(
          [
            trf('হালনাগাদ: {0}', [_d(n.updatedAt)]),
            if (n.files.isNotEmpty) trf('সাথে {0}টি ফাইল (অ্যাপে আছে)', [bnDigits(n.files.length)]),
          ].join(' · '),
          muted: true);
    }
  }
  if (hidden > 0) doc.p(trf('গোপন তথ্য (পাসওয়ার্ড/PIN) থাকা {0}টি নোট এই PDF-এ রাখা হয়নি।', [bnDigits(hidden)]), muted: true);
}

void _contacts(_Doc doc, AppData d) {
  if (d.contacts.isEmpty) return doc.none(tr('যোগাযোগ'));
  final cs = List.of(d.contacts)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  doc.table(
    [tr('নাম'), tr('মোবাইল'), tr('ইমেইল'), tr('ঠিকানা'), tr('নোট')],
    [
      for (final c in cs) [cell(c.name, bold: true), c.phone.isEmpty ? '—' : showPhone(c.phone), c.email, c.address, c.note],
    ],
    w: [2.4, 2.2, 2.6, 2.4, 2.4],
  );
}

void _docs(_Doc doc, AppData d) {
  if (d.docs.isEmpty) return doc.none(tr('ডকুমেন্টস'));
  final folders = <String, List<Doc>>{};
  for (final x in d.docs) {
    folders.putIfAbsent(x.folder, () => []).add(x);
  }
  final names = folders.keys.toList()..sort();
  for (final f in names) {
    doc.h2(tr(f));
    for (final x in folders[f]!..sort((a, b) => a.title.compareTo(b.title))) {
      doc.blocks.add({'t': 'p', 'text': '• ${x.title}'});
      doc.kv([
        for (final fl in x.fields) [fl.label, fl.value],
        [tr('মেয়াদ শেষ'), x.expiry == null ? '' : _d(x.expiry!)],
        [tr('কী নিয়ে'), x.about],
        [tr('কারা'), x.people],
        [tr('কোথায়'), x.place],
        [tr('কবে তোলা'), x.taken == null ? '' : _d(x.taken!)],
        [tr('ফাইল'), x.files.isEmpty ? '' : x.files.map((f) => f.name).join(', ')],
      ]);
    }
  }
  doc.p(tr('ছবি ও ফাইলগুলো অ্যাপের ভেতরে নিরাপদে রাখা আছে; দরকার হলে ডকুমেন্টস থেকে আলাদা করে ডাউনলোড করুন।'), muted: true);
}

void _special(_Doc doc, AppData d, DateTime now) {
  if (d.specialDays.isEmpty) return doc.none(tr('বিশেষ দিন'));
  final ss = List.of(d.specialDays)..sort((a, b) => a.next(now).compareTo(b.next(now)));
  doc.table(
    [tr('কী'), tr('তারিখ'), tr('পরের বার'), tr('নোট')],
    [
      for (final s in ss)
        [
          specialTitle(s, on: s.next(now)),
          '${bnDigits(s.day)} ${monthName(s.month)}${s.year == null ? '' : ' ${bnDigits(s.year!)}'}',
          trf('{0} ({1})', [_d(s.next(now)), daysLeftLabel(s.next(now), now)]),
          [s.note, if (s.phone.isNotEmpty) showPhone(s.phone)].where((x) => x.isNotEmpty).join(' · '),
        ],
    ],
    w: [3.4, 2, 3, 2.4],
  );
}

void _health(_Doc doc, AppData d, DateTime now, String userName) {
  final me = d.members.where((m) => m.isMe).firstOrNull ?? memberOf(d, FamilyMember.meId, myName: userName);
  final people = [me, for (final m in d.members) if (!m.isMe) m];
  final e = d.emergency;
  final any = d.health.isNotEmpty || d.medicines.isNotEmpty || d.habits.isNotEmpty || d.members.isNotEmpty || e.blood.isNotEmpty;
  if (!any) return doc.none(tr('স্বাস্থ্য'));
  for (final m in people) {
    final logs = [for (final h in d.health) if (h.member == m.id) h]..sort((a, b) => b.at.compareTo(a.at));
    final blood = m.blood.isNotEmpty ? m.blood : (m.isMe ? e.blood : '');
    if (!m.isMe && logs.isEmpty && blood.isEmpty && m.heightCm == null && m.birth == null) continue;
    doc.h2(m.isMe ? (userName.isEmpty ? tr('আমি') : trf('{0} (আমি)', [userName])) : (m.relation.isNotEmpty && m.relation != m.name ? '${m.name} (${m.relation})' : m.name));
    doc.kv([
      [tr('রক্তের গ্রুপ'), blood],
      [tr('উচ্চতা'), m.heightCm == null ? '' : heightText(m.heightCm!)],
      [tr('জন্ম'), m.birth == null ? '' : _d(m.birth!)],
      [tr('পরের চেকআপ'), m.nextCheckup == null ? '' : _d(m.nextCheckup!)],
      if (m.isMe) ...[
        [tr('অ্যালার্জি'), e.allergies],
        [tr('অসুখ'), e.conditions],
        [tr('নিয়মিত ওষুধ'), e.medicines],
      ],
    ]);
    if (logs.isNotEmpty) {
      doc.table(
        [tr('তারিখ'), tr('কী মাপা হলো'), tr('মাপ'), tr('নোট')],
        [
          for (final h in logs.take(300))
            () {
              final lv = levelOf(h);
              return <Object>[
                '${shortDate(h.at)} ${bnDigits(h.at.year)}, ${_hm(h.at)}',
                isEn ? h.kind.en : h.kind.bn,
                lv == null ? readingText(h) : cell('${readingText(h)} · ${lv.$2}', tone: lv.$1 == Level.ok ? 'g' : 'o'),
                h.note,
              ];
            }(),
        ],
        w: [2.6, 2, 3.4, 2.2],
      );
    }
  }
  if (d.medicines.isNotEmpty) {
    doc.h2(tr('ওষুধ'));
    doc.table(
      [tr('ওষুধ'), tr('প্রতিবার'), tr('সময়'), tr('আছে'), tr('শেষ দিন')],
      [
        for (final x in d.medicines)
          [
            [x.name, if (x.note.isNotEmpty) '(${x.note})'].join(' '),
            bnDigits(x.dose),
            x.times.map((t) => bnTime(t ~/ 60, t % 60)).join(', '),
            x.stock <= 0 ? '—' : (x.daysLeft == null ? bnDigits(x.stock) : trf('{0}টি (~{1} দিন)', [bnDigits(x.stock), bnDigits(x.daysLeft!)])),
            x.until == null ? '—' : _d(x.until!),
          ],
      ],
      w: [3, 1.2, 3, 2, 2],
    );
  }
  if (d.habits.isNotEmpty) {
    doc.h2(tr('অভ্যাস'));
    doc.table(
      [tr('অভ্যাস'), tr('টানা'), tr('সেরা'), tr('মোট দিন')],
      [
        for (final h in d.habits) [h.name, trf('{0} দিন', [bnDigits(h.streak(now))]), trf('{0} দিন', [bnDigits(h.best())]), bnDigits(h.done.length)],
      ],
      w: [4, 1.6, 1.6, 1.6],
      a: ['l', 'r', 'r', 'r'],
    );
  }
  doc.p(tr('এটা শুধু আপনার রাখা তথ্য, ডাক্তারি পরামর্শ নয়।'), muted: true);
}

void _memories(_Doc doc, AppData d) {
  final ms = [for (final m in d.memories) if (!mentionsSecret(m.text)) m]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (ms.isEmpty) return doc.none(tr('সহকারীর স্মৃতি'));
  doc.table(
    [tr('তারিখ'), tr('যা মনে রেখেছে')],
    [
      for (final m in ms) [_d(m.createdAt), m.text],
    ],
    w: [2.2, 7],
  );
}


void _shops(_Doc doc, AppData d, DateTime now, String? onlyId) {
  final shops = [for (final x in d.shops) if (onlyId == null || x.id == onlyId) x];
  if (shops.isEmpty) return doc.none(tr('দোকান'));
  for (final shop in shops) {
    final m = shopMonth(d, shop, now);
    doc.h2(shop.name);
    if (shop.phone.isNotEmpty || shop.address.isNotEmpty) doc.p([if (shop.phone.isNotEmpty) shop.phone, if (shop.address.isNotEmpty) shop.address].join(' · '), muted: true);
    doc.stats([
      [trf('{0}-এর বিক্রি', [monthName(now.month)]), taka(m.sales), 'g'],
      [tr('এ মাসের খরচ'), taka(m.costs), 'o'],
      [tr('এ মাসে থাকল'), '${m.sales - m.costs < 0 ? '−' : ''}${taka(m.sales - m.costs)}', m.sales - m.costs < 0 ? 'o' : 'g'],
    ]);
    final entries = [for (final e in d.cash) if (e.projectId == null && ((e.kind == CashKind.income && e.category == salesCategory && ofShop(d, e.shopId, shop)) || (e.kind == CashKind.expense && e.shopId == shop.id))) e]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (entries.isNotEmpty) {
      doc.table(
        [tr('তারিখ'), tr('ধরন'), tr('বিবরণ'), tr('টাকা')],
        [
          for (final e in entries.take(400))
            [_d(e.date), e.kind == CashKind.income ? tr('বিক্রি') : tr(e.category), e.note, cell('${e.kind == CashKind.income ? '+' : '−'}${taka(e.amount)}', tone: e.kind == CashKind.income ? 'g' : 'o', bold: true)],
        ],
        w: [2.2, 2, 4, 2],
        a: ['l', 'l', 'l', 'r'],
      );
    }
    final rs = d.receipts.where((r) => r.shopId == shop.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    if (rs.isNotEmpty) {
      doc.table(
        [tr('রসিদ'), tr('তারিখ'), tr('গ্রাহক'), tr('মোট'), tr('বাকি')],
        [
          for (final r in rs) ['#${bnDigits(r.no)}', _d(r.date), r.customer.isEmpty ? '—' : r.customer, taka(r.total), r.due > 0 ? cell(taka(r.due), tone: 'o') : '—'],
        ],
        w: [1.2, 2.2, 3, 2, 1.8],
        a: ['l', 'l', 'l', 'r', 'r'],
      );
    }
    final owing = shopCustomersOwing(d, shop);
    if (owing.isNotEmpty) {
      doc.table([tr('কাস্টমার'), tr('বাকি')], [for (final p in owing) [p.name, cell(taka(p.balance), tone: 'o', bold: true)]], w: [5, 2], a: ['l', 'r']);
    }
  }
}
