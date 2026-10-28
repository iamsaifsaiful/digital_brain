// যাকাত — its own menu (not inside আয়-ব্যয় any more). Most people here are not
// sure how zakat is counted, so the page does it from what the app already
// knows (accounts, savings, DPS, ধার-দেনা, loan instalments), shows every
// line with where it came from and when it last changed, and lets the user
// leave a line out or add one by hand.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart' show cashStartOf, cashSinceStart;
import '../logic/lang.dart';
import '../logic/ledger.dart';
import '../logic/money_more.dart' show MetalPrice;
import '../logic/zakat.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'zakat_principles.dart';

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});
  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  /// What the app cannot know: entered once, kept for next time.
  final _f = {for (final k in ['gold_vori', 'gold_price', 'silver_vori', 'silver_price', 'business', 'other']) k: TextEditingController()};
  bool _fetching = false;
  String _priceNote = '';
  bool _editPrice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final z = BrainScope.read(context).zakatSaved;
      String n(num v) => v == 0 ? '' : (v is double && v != v.roundToDouble() ? '$v' : '${v.round()}');
      _f['gold_vori']!.text = n(z.goldVori);
      _f['gold_price']!.text = n(z.goldPrice);
      _f['silver_vori']!.text = n(z.silverVori);
      _f['silver_price']!.text = n(z.silverPrice);
      _f['business']!.text = n(z.business);
      _f['other']!.text = n(z.other);
      setState(() {});
      // No price yet: today's is fetched at once (the boxes stay for when it fails).
      if (z.goldPrice <= 0 || z.silverPrice <= 0) _todayPrice(BrainScope.read(context));
    });
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _todayPrice(Brain brain) async {
    setState(() => _fetching = true);
    final MetalPrice? p = await brain.metalPriceToday();
    if (!mounted) return;
    if (p == null) {
      setState(() {
        _fetching = false;
        _priceNote = tr('এখন আনতে পারলাম না (ইন্টারনেট বা সার্ভার সাড়া দেয়নি)। bajus.org-এ আজকের দাম দেখে নিজে লিখুন।');
      });
      return;
    }
    await brain.useMetalPrice(p);
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _f['gold_price']!.text = '${brain.zakatSaved.goldPrice}';
      _f['silver_price']!.text = '${p.silver22}';
      _editPrice = false;
      _priceNote = trf('{0}, {1} থেকে কার্যকর — আপনার বেছে নেওয়া ক্যারেটের দাম বসানো হলো। দোকানে বিক্রির দাম কম হলে নিজে বদলে দিন।', [p.source.isEmpty ? tr('বাজুস') : p.source, shortDate(p.date)]);
    });
  }

  Future<void> _addItem(Brain brain) async {
    final r = await showDialog<(String, int, bool)>(context: context, builder: (_) => const _ItemDialog());
    if (r != null && r.$1.isNotEmpty && r.$2 > 0) await brain.addZakatItem(r.$1, r.$2, debt: r.$3);
  }

  /// Rows grouped by month, newest first: (month, its rows, their sum).
  static List<(DateTime, List<(DateTime, String, int)>, int)> _byMonth(List<(DateTime, String, int)> rows) {
    final m = <DateTime, List<(DateTime, String, int)>>{};
    for (final r in rows) {
      m.putIfAbsent(DateTime(r.$1.year, r.$1.month), () => []).add(r);
    }
    final keys = m.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (k, m[k]!..sort((a, b) => b.$1.compareTo(a.$1)), m[k]!.fold(0, (s, r) => s + r.$3))];
  }

  /// The entries behind a line: a person's ধার-দেনা or an account's transactions.
  void _details(Brain brain, ZakatLine l) {
    final d = brain.data;
    final rows = <(DateTime, String, int)>[];
    if (l.key.startsWith('person:') || l.key.startsWith('owe:')) {
      final key = l.key.substring(l.key.indexOf(':') + 1);
      final keys = accountKeys(d.ledger);
      for (final e in newestFirst(d.ledger.where((e) => keys[e.id] == key))) {
        rows.add((e.date, tr(e.kind.label), e.kind.signed(e.amount)));
      }
    } else if (l.key.startsWith('account:')) {
      final id = l.key.substring(8);
      for (final e in d.cash.where((e) => e.accountId == id && e.projectId == null)) {
        rows.add((e.date, e.category, e.kind == CashKind.income ? e.amount : -e.amount));
      }
      for (final t in d.transfers.where((t) => t.to == id || t.from == id)) {
        rows.add((t.date, tr('এক অ্যাকাউন্ট থেকে আরেকটায়'), t.to == id ? t.amount : -(t.amount + t.fee)));
      }
      rows.sort((a, b) => b.$1.compareTo(a.$1));
    } else if (l.key == 'cash:now') {
      final start = cashStartOf(d);
      if (start != null) rows.add((start.$2, tr('শুরুতে ছিল'), start.$1));
      for (final e in cashSinceStart(d)) {
        rows.add((e.date, e.note.isEmpty ? e.category : '${e.category} · ${e.note}', e.kind == CashKind.income ? e.amount : -e.amount));
      }
      rows.sort((a, b) => b.$1.compareTo(a.$1));
    } else if (l.key.startsWith('project:')) {
      final id = l.key.substring(8);
      for (final e in d.cash.where((e) => e.projectId == id)) {
        rows.add((e.date, e.note.isEmpty ? e.category : '${e.category} · ${e.note}', e.kind == CashKind.income ? e.amount : -e.amount));
      }
    } else if (l.key.startsWith('goal:')) {
      for (final g in d.goals.where((g) => 'goal:${g.id}' == l.key)) {
        for (final x in g.deposits.reversed) {
          rows.add((x.date, tr('জমা'), x.amount));
        }
      }
    }
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          Text(l.label, style: display(20, weight: 700)),
          const SizedBox(height: 4),
          Text(l.how, style: body(13.5, color: C.muted, height: 1.4)),
          const SizedBox(height: 10),
          if (rows.isEmpty) Text(tr('আলাদা লেনদেন নেই — আপনার লেখা পরিমাণ'), style: body(14, color: C.muted)),
          // Month by month (owner, 28 Oct): each month's total, opened to see its entries.
          for (final (i, m) in _byMonth(rows).indexed)
            Theme(
              data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: Key('zakat-month-${m.$1.year}-${m.$1.month}'),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: i == 0,
                title: Text('${monthName(m.$1.month)} ${bnDigits(m.$1.year)}', style: body(15, weight: FontWeight.w600)),
                subtitle: Text(trf('{0}টা লেনদেন', [bnDigits(m.$2.length)]), style: body(12.5, color: C.muted)),
                trailing: Text('${m.$3 < 0 ? '−' : '+'}${taka(m.$3.abs())}', style: body(14.5, weight: FontWeight.w700, color: m.$3 < 0 ? C.orange : C.green)),
                children: [
                  for (final r in m.$2)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        SizedBox(width: 74, child: Text(shortDate(r.$1), style: body(13, color: C.muted))),
                        Expanded(child: Text(r.$2, style: body(14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('${r.$3 < 0 ? '−' : '+'}${taka(r.$3.abs())}', style: body(14, weight: FontWeight.w600, color: r.$3 < 0 ? C.orange : C.green)),
                      ]),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final saved = brain.zakatSaved;
    final lines = zakatLines(brain.data, now, saved);
    final z = zakatCount(lines, saved);
    final due = zakatDueDay(brain.data.zakat.yearStart, now);
    Widget field(String k, String label, {String? hint, bool vori = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _f[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) async {
              await brain.setZakatValue(k, asciiDigits(v).replaceAll(',', '').trim());
              if (mounted) setState(() {});
            },
            decoration: InputDecoration(labelText: label, hintText: hint, prefixText: vori ? null : tr('৳ '), suffixText: vori ? tr('ভরি') : null),
          ),
        );
    // Two lines for where it came from (a one-line row would cut it off).
    Widget line(ZakatLine l) => InkWell(
          key: Key('zakat-line-${l.key}'),
          onTap: () => _details(brain, l),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(value: l.included, onChanged: (v) => brain.setZakatIncluded(l.key, v ?? true)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.label, style: body(15.5, weight: FontWeight.w600, color: l.included ? null : C.muted2), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(l.at == null ? l.how : '${l.how} · ${trf('শেষ বদল {0}', [shortDate(l.at!)])}', style: body(12.5, color: C.muted, height: 1.35), maxLines: 3),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${l.debt ? '−' : ''}${taka(l.amount)}',
                    style: body(15.5, weight: FontWeight.w600, color: !l.included ? C.muted2 : (l.debt ? C.orange : null)).copyWith(decoration: l.included ? null : TextDecoration.lineThrough)),
              ),
              if (l.manualId != null)
                IconButton(tooltip: tr('মুছুন'), icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => brain.deleteZakatItem(l.manualId!)),
            ]),
          ),
        );
    final groups = <ZakatGroup, List<ZakatLine>>{};
    for (final l in lines) {
      groups.putIfAbsent(l.group, () => []).add(l);
    }
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('যাকাত')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Panel(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(trf('যাকাতযোগ্য সম্পদ: {0}', [taka(math.max(0, z.net))]), style: body(15)),
                  Text(trf('মোট সম্পদ {0} − দেনা {1}', [taka(z.wealth), taka(z.debts)]), style: body(12.5, color: C.muted)),
                  const SizedBox(height: 6),
                  Text(
                    z.nisab <= 0 ? (z.byGold ? tr('নিসাব জানতে নিচে আজকের সোনার দাম দিন') : tr('নিসাব জানতে নিচে আজকের রুপার দাম দিন')) : (z.due ? trf('যাকাত: {0}', [taka(z.zakat)]) : tr('নিসাবের কম — যাকাত ফরজ নয়')),
                    key: const Key('zakat-total'),
                    style: display(z.nisab <= 0 ? 17 : 24, weight: 700, color: z.due ? C.green : C.muted2),
                  ),
                  if (z.nisab > 0)
                    Text(z.byGold ? trf('নিসাব (সাড়ে ৭ ভরি সোনা — শুধু সোনা আছে বলে): {0}', [taka(z.nisab)]) : trf('নিসাব (সাড়ে ৫২ ভরি রুপা): {0}', [taka(z.nisab)]),
                        key: const Key('zakat-nisab'), style: body(12.5, color: C.muted)),
                  const Divider(height: 22),
                  Row(children: [
                    Expanded(
                      child: Text(
                        due == null ? tr('যাকাতের বছর কবে শুরু, দিন দিলে পরের যাকাতের দিন মনে করিয়ে দেব') : trf('পরের যাকাতের দিন: {0} ({1})', [shortDate(due), daysLeftLabel(due, now)]),
                        style: body(13.5, height: 1.35),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: brain.data.zakat.yearStart ?? now, firstDate: DateTime(now.year - 3), lastDate: now);
                        if (d != null) await brain.setZakatYearStart(d);
                      },
                      child: Text(due == null ? tr('তারিখ দিন') : tr('বদলান')),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              Panel(
                child: InkWell(
                  key: const Key('zakat-principles'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ZakatPrinciplesScreen())),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(Icons.menu_book_outlined, color: C.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('যাকাতের মূলনীতি'), style: body(15, weight: FontWeight.w600)),
                          Text(tr('নিসাব, বছর, কী ধরা হয়, কী হয় না, দেনা, সুদ, কাদের দেওয়া যায় — আর এই হিসাব কীভাবে মানে'), style: body(12.5, color: C.muted, height: 1.35)),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: C.muted),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SectionTitle(tr('হিসাব কোথা থেকে এল')),
              Text(tr('আয়-ব্যয়, অ্যাকাউন্ট, সঞ্চয়, কিস্তি আর ধার-দেনা থেকে নিজে আসে; সেখানে বদলালে এখানেও বদলায়। টিক তুলে দিলে সেটা বাদ যাবে, চাপলে কোন লেনদেন থেকে এল দেখাবে।'),
                  style: body(12.5, color: C.muted, height: 1.4)),
              const SizedBox(height: 8),
              if (lines.isEmpty) Text(tr('এখনো কিছু নেই — অ্যাকাউন্ট, ধার-দেনা বা নিচে সোনা-রুপা লিখলে এখানে আসবে।'), style: body(14, color: C.muted)),
              for (final g in ZakatGroup.values)
                if (groups[g] != null) ...[
                  Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(g.title, style: body(13.5, weight: FontWeight.w600, color: C.muted2))),
                  Panel(child: Rows(children: [for (final l in groups[g]!) line(l)])),
                  if (g == ZakatGroup.savings && (groups[ZakatGroup.bank] != null || groups[ZakatGroup.cash] != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(tr('এই টাকা কোনো অ্যাকাউন্টের ব্যালেন্সেই থাকলে একটির টিক তুলে দিন — একই টাকা দুবার ধরা যায় না।'),
                          key: const Key('zakat-twice'), style: body(12, color: C.orangeDark, height: 1.4)),
                    ),
                ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(key: const Key('zakat-add'), onPressed: () => _addItem(brain), icon: const Icon(Icons.add_rounded), label: Text(tr('নিজে কিছু যোগ করুন'))),
              ),
              const SizedBox(height: 18),
              SectionTitle(tr('একবার লিখে দিন — মনে রাখবো')),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('zakat-today-price'),
                  onPressed: _fetching ? null : () => _todayPrice(brain),
                  icon: _fetching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(tr('আজকের দাম আনুন (বাজুস)')),
                ),
              ),
              if (_priceNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_priceNote, style: body(12.5, color: C.muted, height: 1.4))),
              const SizedBox(height: 10),
              // The price of 1 ভরি comes from বাজুস; the boxes are only for
              // when it could not be fetched (owner, 24 Oct).
              if (saved.goldPrice > 0 && saved.silverPrice > 0 && !_editPrice)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                      child: Text(trf('১ ভরি: সোনা {0} · রুপা {1}', [taka(saved.goldPrice), taka(saved.silverPrice)]),
                          key: const Key('zakat-price-line'), style: body(14, weight: FontWeight.w600)),
                    ),
                    TextButton(onPressed: () => setState(() => _editPrice = true), child: Text(tr('বদলান'))),
                  ]),
                )
              else
                Row(children: [
                  Expanded(child: field('gold_price', tr('১ ভরি সোনার দাম'))),
                  const SizedBox(width: 10),
                  Expanded(child: field('silver_price', tr('১ ভরি রুপার দাম'), hint: tr('বাজারদর'))),
                ]),
              // The gold's carat (owner, 28 Oct): the price of that carat, from বাজুস when known.
              Text(tr('আপনার সোনার গয়না কত ক্যারেটের?'), style: body(13, color: C.muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (k, label) in goldCarats)
                  ChoiceChip(
                    key: Key('zakat-carat-$k'),
                    label: Text(tr(label)),
                    selected: brain.zakatCarat == k,
                    onSelected: (_) async {
                      await brain.setZakatCarat(k);
                      if (!mounted) return;
                      setState(() => _f['gold_price']!.text = '${brain.zakatSaved.goldPrice}');
                    },
                  ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: field('gold_vori', tr('আপনার সোনা'), vori: true)),
                const SizedBox(width: 10),
                Expanded(child: field('silver_vori', tr('আপনার রুপা'), vori: true)),
              ]),
              field('business', tr('ব্যবসার মাল (বিক্রয়মূল্যে)')),
              field('other', tr('অন্যান্য (শেয়ার, বন্ড…)')),
              InfoBanner(text: tr('মুখেও জিজ্ঞেস করা যায়: “আমার যাকাত কত?” — এই পাতার একই হিসাব থেকে উত্তর আসে।'), icon: Icons.info_outline_rounded),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Something added by hand: what, how much, asset or debt.
class _ItemDialog extends StatefulWidget {
  const _ItemDialog();
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _label = TextEditingController(), _amount = TextEditingController();
  bool _debt = false;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('যাকাতের হিসাবে যোগ করুন')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('zakat-item-label'), controller: _label, decoration: InputDecoration(labelText: tr('কী (যেমন: জমির বায়নার টাকা, প্রাইজবন্ড)'))),
          const SizedBox(height: 8),
          TextField(key: const Key('zakat-item-amount'), controller: _amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('টাকা'), prefixText: tr('৳ '))),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [ButtonSegment(value: false, label: Text(tr('সম্পদ'))), ButtonSegment(value: true, label: Text(tr('দেনা (বাদ যাবে)')))],
            selected: {_debt},
            onSelectionChanged: (v) => setState(() => _debt = v.first),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('বাতিল'))),
          FilledButton(
            key: const Key('zakat-item-save'),
            onPressed: () => Navigator.pop(context, (_label.text.trim(), int.tryParse(asciiDigits(_amount.text).replaceAll(',', '').trim()) ?? 0, _debt)),
            child: Text(tr('যোগ করুন')),
          ),
        ],
      );
}
