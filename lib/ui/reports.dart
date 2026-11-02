import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../services/pdf.dart';
import '../state/hisab.dart';
import 'kit.dart';
import 'more.dart' show topCustomers;

/// A span of days: [from] inclusive, [to] exclusive.
class Period {
  const Period(this.from, this.to, this.label, this.key);
  final DateTime from;
  final DateTime to;
  final String label;
  final String key;

  factory Period.all() => Period(DateTime(2000), DateTime(2200), 'সব সময়', 'all');

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  static Period of(String key, DateTime now) {
    final today = _day(now);
    return switch (key) {
      'today' => Period(today, today.add(const Duration(days: 1)), 'আজ', key),
      'yesterday' => Period(today.subtract(const Duration(days: 1)), today, 'গতকাল', key),
      'week' => Period(today.subtract(const Duration(days: 6)), today.add(const Duration(days: 1)), 'গত ৭ দিন', key),
      'month' => Period(DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'এই মাস (${monthShort(now.month)})', key),
      'lastMonth' => Period(DateTime(now.year, now.month - 1), DateTime(now.year, now.month), 'গত মাস (${monthShort(DateTime(now.year, now.month - 1).month)})', key),
      _ => Period.all(),
    };
  }

  factory Period.range(DateTime a, DateTime b) => Period(_day(a), _day(b).add(const Duration(days: 1)), sameDay(a, b) ? dateShort(a) : '${dateShort(a)} – ${dateShort(b)}', 'range');

  bool has(DateTime t) => !t.isBefore(from) && t.isBefore(to);
  bool get isAll => key == 'all';
}

/// সব সময় · আজ · গতকাল · ৭ দিন · এই মাস · গত মাস · তারিখ বাছুন
class PeriodChips extends StatelessWidget {
  const PeriodChips({super.key, required this.value, required this.now, required this.onChanged, this.withAll = true, this.wrap = false});
  final Period value;
  final DateTime now;
  final ValueChanged<Period> onChanged;
  final bool withAll;

  /// Wrapped in lines instead of scrolling sideways (inside swipeable tabs).
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final keys = [if (withAll) ('all', 'সব সময়'), ('today', 'আজ'), ('yesterday', 'গতকাল'), ('week', '৭ দিন'), ('month', 'এই মাস'), ('lastMonth', 'গত মাস')];
    final chips = <Widget>[
      for (final (k, l) in keys) ChoiceChipX(label: l, on: value.key == k, onTap: () => onChanged(k == 'all' ? Period.all() : Period.of(k, now))),
      ChoiceChipX(
        label: value.key == 'range' ? value.label : 'তারিখ বাছুন',
        on: value.key == 'range',
        onTap: () async {
          final r = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024),
            lastDate: DateTime(now.year + 1),
            initialDateRange: value.key == 'range' ? DateTimeRange(start: value.from, end: value.to.subtract(const Duration(days: 1))) : null,
            helpText: 'কোন তারিখ থেকে কোন তারিখ',
            saveText: 'ঠিক আছে',
            cancelText: 'বাতিল',
          );
          if (r != null) onChanged(Period.range(r.start, r.end));
        },
      ),
    ];
    if (wrap) return Wrap(spacing: 8, runSpacing: 8, children: chips);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [for (final c in chips) Padding(padding: const EdgeInsets.only(right: 8), child: c)]),
    );
  }
}

String _footer(Hisab h) => 'আমানত${h.d.settings.ownerName.isEmpty ? '' : ' · ${h.d.settings.ownerName}'} · তৈরি ${dateShort(h.now)} ${bn('${h.now.year}')}, ${timeText(h.now)}';

String _when(DateTime t) => '${dateShort(t)}\n${timeText(t)}';

String _status(Txn x) => switch (x.status) {
      TxnStatus.pending => 'পাঠানোর অপেক্ষায়',
      TxnStatus.sent => proofText(x).isEmpty ? 'পৌঁছেছে' : proofText(x),
      TxnStatus.cancelled => 'বাতিল',
    };

List<List<String>> _txnRows(Hisab h, Iterable<Txn> list) => [
      for (final x in list)
        [
          '#${bn('${x.no}')}\n${_when(x.at)}${x.byName.isEmpty ? '' : '\n${x.byName}'}',
          '${customerById(h.d, x.customerId)?.name ?? ''}${x.recipientLabel.isEmpty ? '' : '\nপ্রাপক: ${x.recipientLabel}'}',
          '${serviceName(x)}${x.kind == Kind.mb && x.pack.isNotEmpty ? ' (${x.pack})' : ''}\n${bdShow(x.number)}',
          '${bnNum(x.sarAmount, decimals: 2)}\n× ${rateText(x.rate)}',
          '${bnNum(x.taka)}${x.fee > 0 ? '\n+${bnNum(x.fee)}' : ''}',
          x.cancelled ? '—' : (x.sarDueAtSend > 0 ? 'বাকি ${bnNum(x.sarDueAtSend, decimals: 2)}' : 'পরিশোধ'),
          '${_status(x)}${x.fault != null ? '\nভুল নম্বর (${x.fault!.short})' : ''}',
        ],
    ];

const _txnHead = ['নং / সময় / এডমিন', 'গ্রাহক', 'কী / নম্বর', 'রিয়াল', 'টাকা', 'রিয়াল পরিশোধ', 'অবস্থা'];
const _txnFlex = [1.2, 1.7, 1.9, 1.2, 1.1, 1.2, 1.6];

/// A list of sends (as filtered on screen).
PdfDoc txnsPdf(Hisab h, List<Txn> list, String title, Period p) {
  final live = list.where((x) => !x.cancelled);
  final doc = PdfDoc(title, subtitle: p.label, footer: _footer(h));
  doc.tiles([
    ('লেনদেন', '${bn('${list.length}')}টা'),
    ('মোট রিয়াল', sar(live.fold<double>(0, (s, x) => s + x.sarAmount))),
    ('মোট টাকা', taka(live.fold<double>(0, (s, x) => s + x.taka))),
    ('এজেন্টের খরচসহ টাকা', taka(live.fold<double>(0, (s, x) => s + x.agentTaka))),
  ]);
  doc.table(_txnHead, _txnRows(h, [...list]..sort((a, b) => a.at.compareTo(b.at))), flex: _txnFlex, right: {3, 4});
  return doc;
}

/// The whole report for a period: totals, sends, deposits, losses, costs,
/// agent payments, day-end counts.
PdfDoc periodPdf(Hisab h, Period p) {
  final d = h.d;
  final txns = d.txns.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final live = txns.where((x) => !x.cancelled);
  final deps = d.deposits.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final losses = d.losses.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final exps = d.expenses.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final pays = d.agentPayments.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final closes = d.closes.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
  final sarSum = live.fold<double>(0, (s, x) => s + x.sarAmount);
  final takaSum = live.fold<double>(0, (s, x) => s + x.taka);
  final got = live.fold<double>(0, (s, x) => s + x.sarPaid) + deps.fold<double>(0, (s, x) => s + x.sarAmount);
  final doc = PdfDoc('রিপোর্ট', subtitle: p.label, footer: _footer(h));
  doc.tiles([
    ('মোট পাঠানো (রিয়াল)', sar(sarSum)),
    ('মোট পাঠানো (টাকা)', taka(takaSum)),
    ('লেনদেন', '${bn('${live.length}')}টা${sarSum == 0 ? '' : ' · গড় রেট ${rateText(takaSum / sarSum)}'}'),
    ('রিয়াল হাতে পেলাম', sar(got)),
    ('খরচ / রিয়াল বের', sar(exps.fold<double>(0, (s, x) => s + x.sarAmount))),
    ('লস (আদায় হবে না)', sar(losses.fold<double>(0, (s, x) => s + x.sarAmount))),
    ('এজেন্টকে দিলাম', taka(pays.fold<double>(0, (s, x) => s + x.taka))),
    ('ভুল নম্বরে গেছে', '${bn('${live.where((x) => x.fault != null).length}')}টা'),
    ('এখন মোট বাকি', sar(totalCustomerDue(d))),
    ('এখন হাতে থাকা উচিত', sar(cashInHand(d))),
  ]);
  for (final (which, title) in const [(0, 'যে গ্রাহকরা বেশি পাঠান'), (1, 'যে গ্রাহকরা বেশি নগদ দেন'), (2, 'যাদের বাকি বেশি (এখন)')]) {
    final top = topCustomers(d, which, p.has, h.now).take(10).toList();
    if (top.isEmpty) continue;
    doc.heading(title);
    doc.table(['#', 'গ্রাহক', 'বিস্তারিত', 'রিয়াল'], [
      for (final (i, r) in top.indexed) [bn('${i + 1}'), r.$1.name, r.$3, bnNum(r.$2, decimals: 2)],
    ], flex: [0.4, 2, 3, 1.2], right: {3});
  }
  doc.heading('লেনদেন');
  doc.table(_txnHead, _txnRows(h, txns), flex: _txnFlex, right: {3, 4});
  doc.heading('রিয়াল জমা');
  doc.table([
    'সময়',
    'গ্রাহক',
    'কীভাবে',
    'রিয়াল'
  ], [
    for (final x in deps)
      [_when(x.at), customerById(d, x.customerId)?.name ?? '', '${x.way == 'cash' ? 'নগদ হাতে' : 'ব্যাংক/ট্রান্সফার'}${x.note.isEmpty ? '' : '\n${x.note}'}', bnNum(x.sarAmount, decimals: 2)],
  ], flex: [
    1.2,
    2,
    2,
    1.2
  ], right: {
    3
  });
  if (losses.isNotEmpty) {
    doc.heading('লস (আদায় হবে না)');
    doc.table([
      'সময়',
      'গ্রাহক',
      'কারণ',
      'রিয়াল'
    ], [
      for (final x in losses) [_when(x.at), customerById(d, x.customerId)?.name ?? '', x.note, bnNum(x.sarAmount, decimals: 2)],
    ], flex: [
      1.2,
      2,
      2.4,
      1.2
    ], right: {
      3
    });
  }
  doc.heading('খরচ / রিয়াল বের');
  doc.table([
    'সময়',
    'কী',
    'নোট',
    'রিয়াল'
  ], [
    for (final x in exps) [_when(x.at), x.category, x.note, bnNum(x.sarAmount, decimals: 2)],
  ], flex: [
    1.2,
    2,
    2.4,
    1.2
  ], right: {
    3
  });
  doc.heading('এজেন্টকে দেওয়া টাকা');
  doc.table(['সময় / এডমিন', 'এজেন্ট', 'কীভাবে', 'টাকা', 'রিয়াল'], [
    for (final x in pays) ['${_when(x.at)}${x.byName.isEmpty ? '' : '\n${x.byName}'}', agentById(d, x.agentId)?.name ?? '', payDetail(x), bnNum(x.taka), x.sarAmount > 0 ? bnNum(x.sarAmount, decimals: 2) : '—'],
  ], flex: [1.3, 1.8, 2.4, 1.1, 1.1], right: {3, 4});
  // Each admin's hand in this period; handovers move riyal between hands.
  final admins = adminsIn(d);
  if (admins.length > 1 || h.session != null) {
    doc.heading('এডমিনদের হাতের হিসাব');
    doc.table(['এডমিন', 'এসেছে', 'গেছে', 'এখন হাতে'], [
      for (final e in admins.entries)
        () {
          final lines = cashLines(d, me: e.key, owner: e.key == 0).where((l) => p.has(l.at));
          return [
            e.value,
            bnNum(lines.fold<double>(0, (s, l) => s + l.inSar), decimals: 2),
            bnNum(lines.fold<double>(0, (s, l) => s + l.outSar), decimals: 2),
            bnNum(cashInHand(d, me: e.key, owner: e.key == 0), decimals: 2),
          ];
        }(),
    ], flex: [2, 1.3, 1.3, 1.3], right: {1, 2, 3});
    final hs = d.handovers.where((x) => p.has(x.at)).toList()..sort((a, b) => a.at.compareTo(b.at));
    if (hs.isNotEmpty) {
      doc.heading('কালেকশন হাতবদল');
      doc.table(['সময়', 'কার কাছ থেকে', 'কে বুঝে নিলেন', 'নোট', 'রিয়াল'], [
        for (final x in hs) [_when(x.at), x.fromName, x.toName, x.note, bnNum(x.sarAmount, decimals: 2)],
      ], flex: [1.2, 1.6, 1.6, 2, 1.1], right: {4});
    }
  }
  if (closes.isNotEmpty) {
    doc.heading('দিন শেষের হিসাব');
    doc.table([
      'সময়',
      'হিসাবে',
      'গুনে',
      'পার্থক্য'
    ], [
      for (final x in closes) [_when(x.at), bnNum(x.expected, decimals: 2), bnNum(x.counted, decimals: 2), x.difference.abs() < 0.01 ? 'মিলেছে' : bnNum(x.difference, decimals: 2)],
    ], right: {
      1,
      2,
      3
    });
  }
  return doc;
}

String payDetail(AgentPayment p) => [
      payWayName(p.way),
      if (p.fromAccount.isNotEmpty) 'থেকে ${p.fromAccount}',
      if (p.ref.isNotEmpty) 'রেফ ${p.ref}',
      if (p.txnIds.isNotEmpty) '${bn('${p.txnIds.length}')}টা লেনদেনের',
      if (p.receipt != null) 'রসিদের ছবি আছে',
      if (p.note.isNotEmpty) p.note,
    ].join(' · ');

/// A customer's account, riyal only.
PdfDoc customerPdf(Hisab h, Customer c) {
  final d = h.d;
  final rows = <(DateTime, List<String>)>[
    for (final x in d.txns.where((x) => x.customerId == c.id && !x.cancelled))
      (
        x.at,
        [
          _when(x.at),
          '#${bn('${x.no}')} ${serviceName(x)} ${bdShow(x.number)}${x.recipientLabel.isEmpty ? '' : ' (${x.recipientLabel})'}\n${taka(x.taka)}',
          bnNum(x.sarAmount, decimals: 2),
          x.sarPaid > 0 ? bnNum(x.sarPaid, decimals: 2) : '',
        ]
      ),
    for (final p in d.deposits.where((p) => p.customerId == c.id)) (p.at, [_when(p.at), 'রিয়াল জমা${p.note.isEmpty ? '' : ' · ${p.note}'}', '', bnNum(p.sarAmount, decimals: 2)]),
    for (final l in d.losses.where((l) => l.customerId == c.id)) (l.at, [_when(l.at), 'লস — আদায় হবে না${l.note.isEmpty ? '' : ' · ${l.note}'}', '', bnNum(l.sarAmount, decimals: 2)]),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  // Running due after each line.
  var run = 0.0;
  final table = <List<String>>[];
  for (final (_, r) in rows) {
    run += (parseNum(r[2]) ?? 0) - (parseNum(r[3]) ?? 0);
    table.add([...r, run > 0.004 ? bnNum(run, decimals: 2) : (run < -0.004 ? 'অগ্রিম ${bnNum(-run, decimals: 2)}' : '—')]);
  }
  final due = customerDue(d, c.id);
  final doc = PdfDoc('${c.name} — হিসাব', subtitle: '${c.phone.isEmpty ? '' : '${bn(c.phone)} · '}সব হিসাব রিয়ালে', footer: _footer(h));
  doc.tiles([
    ('এখন বাকি', due > 0 ? sar(due) : (due < 0 ? 'অগ্রিম ${sar(-due)}' : 'বাকি নেই')),
    ('মোট পাঠানো', sar(d.txns.where((x) => x.customerId == c.id && !x.cancelled).fold<double>(0, (s, x) => s + x.sarAmount))),
    if (lossOf(d, c.id) > 0) ('লস ধরা হয়েছে', sar(lossOf(d, c.id))),
    if (c.promiseAt != null) ('বাকি দেওয়ার কথা', '${dateShort(c.promiseAt!)}, ${timeText(c.promiseAt!)}'),
  ]);
  doc.table(['সময়', 'বিবরণ', 'পাঠানো (রিয়াল)', 'দিলেন (রিয়াল)', 'বাকি'], table, flex: [1.1, 3, 1.3, 1.3, 1.3], right: {2, 3, 4});
  return doc;
}

/// An agent's account, taka only.
PdfDoc agentPdf(Hisab h, Agent a, Period p) {
  final d = h.d;
  final txns = d.txns.where((x) => x.agentId == a.id && !x.cancelled && p.has(x.at)).toList()..sort((x, y) => x.at.compareTo(y.at));
  final pays = d.agentPayments.where((x) => x.agentId == a.id && p.has(x.at)).toList()..sort((x, y) => x.at.compareTo(y.at));
  final owed = agentOwed(d, a.id);
  final doc = PdfDoc('${a.name} — হিসাব', subtitle: '${p.label} · সব হিসাব টাকায়', footer: _footer(h));
  doc.tiles([
    (owed >= 0 ? 'এখন এজেন্টকে দিতে হবে' : 'এখন এজেন্টের কাছে অগ্রিম', taka(owed.abs())),
    ('এই সময়ে পাঠালেন', taka(txns.fold<double>(0, (s, x) => s + x.agentTaka))),
    ('এই সময়ে কমিশন', taka(txns.fold<double>(0, (s, x) => s + commissionOf(x, a)))),
    ('এই সময়ে দিলাম', taka(pays.fold<double>(0, (s, x) => s + x.taka))),
  ]);
  doc.heading('এজেন্ট যা পাঠালেন');
  doc.table([
    'নং / সময়',
    'কী / নম্বর',
    'টাকা',
    'উত্তর / TrxID',
    'টাকা দেওয়া'
  ], [
    for (final x in txns)
      [
        '#${bn('${x.no}')}\n${_when(x.at)}',
        '${serviceName(x)}\n${bdShow(x.number)}',
        bnNum(x.agentTaka),
        '${_status(x)}${x.fault != null ? '\nভুল নম্বর (${x.fault!.short})' : ''}',
        x.agentPaymentId == null ? 'বাকি' : 'দেওয়া',
      ],
  ], flex: [
    1.3,
    2,
    1.2,
    2,
    1.1
  ], right: {
    2
  });
  doc.heading('এজেন্টকে দেওয়া টাকা');
  doc.table([
    'সময়',
    'কীভাবে',
    'টাকা'
  ], [
    for (final x in pays) [_when(x.at), payDetail(x), bnNum(x.taka)],
  ], flex: [
    1.2,
    4,
    1.3
  ], right: {
    2
  });
  return doc;
}

PdfDoc logPdf(Hisab h, List<LogEntry> list, String subtitle) {
  final doc = PdfDoc('কাজের লগ', subtitle: subtitle, footer: _footer(h));
  doc.table([
    'সময়',
    'কী হলো',
    'বিস্তারিত',
    'কে'
  ], [
    for (final e in list) [_when(e.at), e.title, e.detail, e.who == 'app' ? 'অ্যাপ' : 'আপনি'],
  ], flex: [
    1.1,
    1.8,
    4,
    0.8
  ]);
  return doc;
}

PdfDoc lossPdf(Hisab h) {
  final d = h.d;
  final list = [...d.losses]..sort((a, b) => a.at.compareTo(b.at));
  final doc = PdfDoc('লস — আদায় হবে না', subtitle: 'মোট ${sar(lossOf(d))}', footer: _footer(h));
  doc.table([
    'সময়',
    'গ্রাহক',
    'কারণ',
    'রিয়াল'
  ], [
    for (final x in list) [_when(x.at), customerById(d, x.customerId)?.name ?? '', x.note, bnNum(x.sarAmount, decimals: 2)],
  ], flex: [
    1.2,
    2,
    2.6,
    1.2
  ], right: {
    3
  });
  return doc;
}

/// Builds the PDF and opens its preview; from there it can be saved to
/// Downloads, printed, shared, or just looked at.
Future<void> sharePdf(BuildContext context, Hisab h, PdfDoc doc, String name) async {
  if (!h.can('reports')) {
    snack(context, 'PDF বানানোর অনুমতি আপনার নেই');
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator()))),
  );
  try {
    final bytes = await doc.build();
    if (context.mounted) Navigator.of(context).pop();
    final n = h.now;
    final safe = name.replaceAll(RegExp(r'[^\wঀ-৿-]+'), '-');
    final file = '$safe-${n.year}-${n.month}-${n.day}.pdf';
    await h.note('sys', 'PDF বানানো', doc.title);
    if (context.mounted) await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => PdfPreview(h: h, doc: doc, bytes: bytes, file: file)));
    doc.disposePages();
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      snack(context, 'PDF বানানো যায়নি');
    }
  }
}

class PdfPreview extends StatelessWidget {
  const PdfPreview({super.key, required this.h, required this.doc, required this.bytes, required this.file});
  final Hisab h;
  final PdfDoc doc;
  final Uint8List bytes;
  final String file;

  @override
  Widget build(BuildContext context) {
    return Screen(
      title: doc.title,
      body: Column(children: [
        Expanded(
          child: Container(
            color: K.chip,
            child: InteractiveViewer(
              maxScale: 4,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: doc.pages.length,
                separatorBuilder: (_, i) => const SizedBox(height: 10),
                itemBuilder: (_, i) => AspectRatio(
                  aspectRatio: PdfDoc.w / PdfDoc.h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6)]),
                    child: RawImage(image: doc.pages[i], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              Expanded(
                child: _Act(Icons.download_outlined, 'ডাউনলোড', () async {
                  final at = await h.s.device.saveDownload(bytes, file, 'application/pdf');
                  if (context.mounted) snack(context, at == null ? 'সেভ করা যায়নি' : 'সেভ হয়েছে: $at');
                }),
              ),
              Expanded(
                child: _Act(Icons.print_outlined, 'প্রিন্ট', () async {
                  final ok = await h.s.device.printPdf(bytes, file);
                  if (!ok && context.mounted) snack(context, 'প্রিন্ট খোলা যায়নি');
                }),
              ),
              Expanded(child: _Act(Icons.share_outlined, 'শেয়ার', () => h.s.device.shareFile(bytes, file, 'application/pdf'))),
              Expanded(child: _Act(Icons.visibility_outlined, 'শুধু দেখা', () => Navigator.of(context).pop())),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: K.navy),
            const SizedBox(height: 4),
            Tx(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
