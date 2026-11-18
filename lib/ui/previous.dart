import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/lang.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'home.dart' show push;
import 'kit.dart';
import 'send.dart' show QuickProfile;
import 'txn.dart' show Live, TxnScreen;

// "পূর্বের হিসাব": what was owed and held before the app was used. Nothing
// here is sent to a customer or an agent.

/// The four kinds of old account, and everything entered so far.
class PreviousHub extends StatelessWidget {
  const PreviousHub({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) {
    Widget kind(IconData i, Color bg, Color fg, String title, String sub, Widget page, {bool last = false}) => Row2(
          lead: dotIcon(i, bg, fg),
          title: title,
          sub: sub,
          trailing: const Icon(Icons.chevron_right_rounded, color: K.muted),
          last: last,
          onTap: () => push(context, page),
        );
    return Live(
      h: h,
      builder: (context) {
        final rows = _entered(h);
        return Screen(
          title: 'পূর্বের হিসাব',
          subtitle: 'অ্যাপ চালুর আগের হিসাব তুলুন',
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
            const Note(
              'খাতায় বা মনে রাখা আগের হিসাব এখানে তুলুন। এগুলো "পূর্বের হিসাব" চিহ্ন নিয়ে থাকবে — গ্রাহক বা এজেন্টের কাছে কোনো মেসেজ বা নোটিফিকেশন যাবে না।',
              icon: Icons.history_edu_outlined,
            ),
            const SizedBox(height: 14),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                kind(Icons.person_outline_rounded, K.amberTint, K.amberText, 'গ্রাহকের আগের বকেয়া', 'কার কাছে কত রিয়াল বকেয়া বা অগ্রিম — একজন করে বা অনেকজন একসাথে', PrevCustomerScreen(h: h)),
                kind(Icons.storefront_outlined, K.blueTint, K.blue, 'এজেন্টের আগের হিসাব', 'এজেন্ট কত টাকা পাবেন, বা আগাম কত দেওয়া আছে', PrevAgentScreen(h: h)),
                kind(Icons.account_balance_wallet_outlined, K.greenTint, K.green, 'হাতে আগের রিয়াল', 'কোন এডমিনের হাতে কত রিয়াল ছিল', PrevCashScreen(h: h)),
                kind(Icons.receipt_long_outlined, K.navySoft, K.navy, 'আগের লেনদেন', 'পুরনো তারিখের পাঠানো — এজেন্টকে কিছু যাবে না', PrevSendScreen(h: h), last: true),
              ]),
            ),
            const SizedBox(height: 6),
            SectionHead('যা তোলা হয়েছে'),
            if (rows.isEmpty)
              const Note('এখনো কিছু তোলা হয়নি।')
            else
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, r) in rows.indexed)
                    Row2(
                      lead: dotIcon(r.icon, r.cancelled ? K.chip : K.amberTint, r.cancelled ? K.muted : K.amberText, size: 38),
                      title: r.title,
                      sub: r.sub,
                      value: r.value,
                      valueColor: r.cancelled ? K.muted : K.ink,
                      valueSub: r.cancelled ? 'বাতিল' : 'পূর্বের হিসাব',
                      valueSubColor: r.cancelled ? K.red : K.amberText,
                      last: i == rows.length - 1,
                      onTap: () => r.open(context),
                    ),
                ]),
              ),
            const SizedBox(height: 8),
            Tx('ভুল তুললে লাইনে চেপে বাতিল করা যাবে (বাতিলের রেকর্ড থাকবে)।', style: t(12.5, c: K.muted)),
          ]),
        );
      },
    );
  }

  static List<_Entered> _entered(Hisab h) {
    final d = h.d;
    String title(Opening o) => switch (o.kind) {
          'customer' => '${customerById(d, o.customerId)?.name ?? ''} · ${o.sar >= 0 ? 'বকেয়া' : 'অগ্রিম জমা'}',
          'agent' => '${agentById(d, o.agentId)?.name ?? ''} · ${o.taka >= 0 ? 'এজেন্ট পাবেন' : 'অগ্রিম নিয়েছেন'}',
          _ => '${o.handByName.isEmpty ? 'মূল হিসাব' : o.handByName}-এর হাতে',
        };
    final out = <_Entered>[
      for (final o in d.openings)
        _Entered(
          at: o.created ?? o.at,
          icon: switch (o.kind) { 'customer' => Icons.person_outline_rounded, 'agent' => Icons.storefront_outlined, _ => Icons.account_balance_wallet_outlined },
          title: title(o),
          sub: '${dateShort(o.at)} ${bn('${o.at.year}')} পর্যন্ত · ${o.byName}${o.note.isEmpty ? '' : ' · ${o.note}'}',
          value: o.kind == 'agent' ? taka(o.taka.abs()) : sar(o.sar.abs()),
          cancelled: o.cancelled,
          open: (context) => _openingSheet(context, h, o),
        ),
      for (final x in d.txns.where((x) => x.old))
        _Entered(
          at: x.at,
          icon: Icons.receipt_long_outlined,
          title: '${txnNo(x.no)} · ${customerNameOf(d, x)}',
          sub: '${dateShort(x.at)} ${bn('${x.at.year}')} · ${bdShow(x.number)}${x.oldPaid ? ' · এজেন্টকে আগেই দেওয়া' : ''}',
          value: sar(x.sarAmount),
          cancelled: x.cancelled,
          open: (context) => push(context, TxnScreen(h: h, id: x.id)),
        ),
    ];
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }
}

class _Entered {
  _Entered({required this.at, required this.icon, required this.title, required this.sub, required this.value, required this.cancelled, required this.open});
  final DateTime at;
  final IconData icon;
  final String title;
  final String sub;
  final String value;
  final bool cancelled;
  final void Function(BuildContext) open;
}

/// One old-account line: what it is, and "বাতিল" while it counts.
Future<void> _openingSheet(BuildContext context, Hisab h, Opening o) => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Tx('পূর্বের হিসাব', style: t(18, w: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Tx(openingText(h.d, o), style: t(16, w: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Tx('${dateShort(o.at)} ${bn('${o.at.year}')} পর্যন্ত · তুলেছেন ${o.byName}${o.created == null ? '' : ', ${dateShort(o.created!)}'}${o.note.isEmpty ? '' : '\n${o.note}'}', style: t(13.5, c: K.muted, h: 1.5), textAlign: TextAlign.center),
          if (o.cancelled) ...[
            const SizedBox(height: 10),
            Tx('বাতিল করা হয়েছে${o.cancelledByName.isEmpty ? '' : ' (${o.cancelledByName})'} — হিসাবে ধরা হয় না।', style: t(13.5, c: K.red), textAlign: TextAlign.center),
          ] else if (h.can('edit')) ...[
            const SizedBox(height: 16),
            SoftPill(
              label: 'ভুল হয়েছে — বাতিল করুন',
              icon: Icons.block_rounded,
              color: K.red,
              onTap: () async {
                if (await confirm(ctx, 'এই পূর্বের হিসাব বাতিল করবেন?', '${openingText(h.d, o)} — এটা আর হিসাবে ধরা হবে না। রেকর্ড থেকে যাবে। ঠিকটা আবার নতুন করে তুলুন।', yes: 'বাতিল করুন', danger: true)) {
                  await h.cancelOpening(o);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
          ],
        ]),
      ),
    );

/// A date line that opens the calendar (and the clock with [time]).
class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.at, required this.onPick, this.time = false});
  final String label;
  final DateTime at;
  final bool time;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tx(label, style: t(14, c: K.muted)),
        const SizedBox(height: 6),
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: at, firstDate: DateTime(2015), lastDate: DateTime.now());
            if (d == null || !context.mounted) return;
            var picked = DateTime(d.year, d.month, d.day, at.hour, at.minute);
            if (time) {
              final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(at));
              if (tm != null) picked = DateTime(d.year, d.month, d.day, tm.hour, tm.minute);
            }
            onPick(picked);
          },
          border: K.border,
          child: Row(children: [
            const Icon(Icons.calendar_month_outlined, color: K.blue),
            const SizedBox(width: 10),
            Expanded(child: Tx('${dateShort(at)} ${bn('${at.year}')}${time ? ', ${timeText(at)}' : ''}', style: t(16, w: FontWeight.w500))),
            Tx('বদলান', style: t(13.5, c: K.blue, w: FontWeight.w600)),
          ]),
        ),
      ]);
}

/// What will happen, shown before saving.
Widget _effect(String text) => CardBox(
      color: K.amberTint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tx('যা হবে', style: t(13, c: K.amberText, w: FontWeight.w600)),
        const SizedBox(height: 4),
        Tx(text, style: t(14.5, w: FontWeight.w600, h: 1.45)),
      ]),
    );

/// The end of yesterday: the usual "as it stood" date for an old account.
DateTime _yesterday(Hisab h) {
  final n = h.now.subtract(const Duration(days: 1));
  return DateTime(n.year, n.month, n.day, 23, 59);
}

/// Pick a customer from a searchable list.
Future<Customer?> pickCustomer(BuildContext context, Hisab h) => showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final q = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, set) {
            final list = h.searchCustomers(q.text);
            return Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(children: [
                  Field(label: 'গ্রাহক খুঁজুন', controller: q, hint: 'নাম বা নম্বর', autofocus: true, onChanged: (_) => set(() {})),
                  const SizedBox(height: 8),
                  Expanded(
                    child: list.isEmpty
                        ? const Note('কেউ নেই — নতুন গ্রাহক বানিয়ে নিন।')
                        : ListView(children: [
                            for (final (i, c) in list.indexed)
                              Row2(
                                lead: CircleAvatar(radius: 18, backgroundColor: K.amberTint, child: Tx(c.name.characters.first, style: t(14, w: FontWeight.w700, c: K.amberText))),
                                title: c.name,
                                sub: bdShow(c.phone),
                                value: sar(customerDue(h.d, c.id)),
                                last: i == list.length - 1,
                                onTap: () => Navigator.pop(ctx, c),
                              ),
                          ]),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );

/// The chosen customer, with "বদলান".
Widget _customerBox(BuildContext context, Hisab h, Customer? c, VoidCallback onTap) => CardBox(
      border: K.border,
      onTap: onTap,
      child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: K.amberTint, child: c == null ? const Icon(Icons.person_search_rounded, color: K.amberText) : Tx(c.name.characters.first, style: t(16, w: FontWeight.w700, c: K.amberText))),
        const SizedBox(width: 12),
        Expanded(
          child: c == null
              ? Tx('গ্রাহক বাছুন', style: t(16, w: FontWeight.w600, c: K.blue))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx(c.name, style: t(16, w: FontWeight.w600)),
                  Tx('${bdShow(c.phone)} · এখন বকেয়া ${sar(customerDue(h.d, c.id))}', style: t(12.5, c: K.muted)),
                ]),
        ),
        if (c != null) Tx('বদলান', style: t(13.5, c: K.blue, w: FontWeight.w600)),
      ]),
    );

/// A customer's old due (or advance): one at a time, or many in a table.
class PrevCustomerScreen extends StatefulWidget {
  const PrevCustomerScreen({super.key, required this.h, this.many = false, this.customer});
  final Hisab h;
  final bool many;
  final Customer? customer;
  @override
  State<PrevCustomerScreen> createState() => _PrevCustomerScreenState();
}

class _PrevCustomerScreenState extends State<PrevCustomerScreen> {
  Hisab get h => widget.h;
  late bool _many = widget.many;
  late Customer? _c = widget.customer;
  bool _due = true;
  final _amount = TextEditingController(), _note = TextEditingController();
  late DateTime _at = _yesterday(h);
  final _rows = [for (var i = 0; i < 3; i++) (TextEditingController(), TextEditingController(), TextEditingController())];

  Future<void> _save() async {
    if (_many) {
      final rows = [
        for (final r in _rows)
          if (r.$1.text.trim().isNotEmpty && (parseNum(r.$3.text) ?? 0) > 0) (r.$1.text, r.$2.text, parseNum(r.$3.text)!),
      ];
      if (rows.isEmpty) return snack(context, 'অন্তত একজনের নাম আর বকেয়া লিখুন');
      final made = await h.addOpeningsMany(rows, _at);
      if (!mounted) return;
      snack(context, '${bn('${rows.length}')} জনের বকেয়া উঠেছে${made > 0 ? ' · ${bn('$made')} জন নতুন গ্রাহক' : ''}');
      Navigator.pop(context);
      return;
    }
    final v = parseNum(_amount.text) ?? 0;
    if (_c == null) return snack(context, 'গ্রাহক বাছুন');
    if (v <= 0) return snack(context, 'রিয়াল লিখুন');
    await h.addOpening(kind: 'customer', at: _at, customerId: _c!.id, sar: _due ? v : -v, note: _note.text);
    if (!mounted) return;
    snack(context, 'পূর্বের হিসাবে উঠেছে');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final count = _rows.where((r) => r.$1.text.trim().isNotEmpty && (parseNum(r.$3.text) ?? 0) > 0).length;
    final total = _rows.where((r) => r.$1.text.trim().isNotEmpty).fold<double>(0, (s, r) => s + (parseNum(r.$3.text) ?? 0));
    final v = parseNum(_amount.text) ?? 0;
    return Screen(
      title: 'গ্রাহকের আগের বকেয়া',
      bottom: Pill(label: _many ? '${bn('$count')} জনের বকেয়া তুলুন' : 'পূর্বের হিসাবে তুলুন', onTap: _save),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        Seg<bool>(items: const [(false, 'একজন করে'), (true, 'অনেকজন একসাথে')], value: _many, onChanged: (v) => setState(() => _many = v)),
        const SizedBox(height: 14),
        if (!_many) ...[
          Tx('গ্রাহক', style: t(14, c: K.muted)),
          const SizedBox(height: 6),
          _customerBox(context, h, _c, () async {
            final c = await pickCustomer(context, h);
            if (c != null) setState(() => _c = c);
          }),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final c = await push<Customer>(context, QuickProfile(h: h));
                if (c != null) setState(() => _c = c);
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Tx('নতুন গ্রাহক বানিয়ে তুলুন', style: t(14, c: K.blue)),
            ),
          ),
          const SizedBox(height: 4),
          Seg<bool>(items: const [(true, 'গ্রাহক দেবেন (বকেয়া)'), (false, 'গ্রাহকের অগ্রিম জমা')], value: _due, onChanged: (v) => setState(() => _due = v)),
          const SizedBox(height: 12),
          Field(label: 'রিয়াল', controller: _amount, number: true, big: true, suffix: 'SAR', hint: '0', onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _DateRow(label: 'কোন তারিখ পর্যন্ত হিসাব', at: _at, onPick: (d) => setState(() => _at = d)),
          const SizedBox(height: 12),
          Field(label: 'নোট (ইচ্ছা হলে)', controller: _note, hint: 'যেমন পুরনো খাতার ১২ নং পাতা', maxLines: 2),
          if (_c != null && v > 0) ...[
            const SizedBox(height: 14),
            _effect(_due
                ? '${_c!.name}-এর বকেয়া ${sar(v)} বাড়বে (এখন ${sar(customerDue(h.d, _c!.id))} → ${sar(customerDue(h.d, _c!.id) + v)}), ${dateShort(_at)} তারিখের "পূর্বের হিসাব" হিসেবে। তাগাদা আর রিপোর্টে ধরা হবে।'
                : '${_c!.name}-এর ${sar(v)} অগ্রিম জমা থাকবে — বকেয়া থেকে কাটা যাবে (এখন ${sar(customerDue(h.d, _c!.id))} → ${sar(customerDue(h.d, _c!.id) - v)})।'),
          ],
        ] else ...[
          const Note('খাতা দেখে একটার পর একটা লিখে যান। নাম বা নম্বর মিলে গেলে আগের গ্রাহকেই যোগ হবে, না মিললে নতুন গ্রাহক তৈরি হবে।', icon: Icons.table_rows_outlined),
          const SizedBox(height: 12),
          _DateRow(label: 'সবার হিসাব কোন তারিখ পর্যন্ত', at: _at, onPick: (d) => setState(() => _at = d)),
          const SizedBox(height: 14),
          CardBox(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Column(children: [
              Row(children: [
                Expanded(flex: 9, child: Tx('নাম / ফোন', style: t(13, c: K.muted, w: FontWeight.w600))),
                Expanded(flex: 4, child: Tx('বকেয়া SAR', style: t(13, c: K.muted, w: FontWeight.w600), textAlign: TextAlign.right)),
                const SizedBox(width: 30),
              ]),
              const Divider(height: 14),
              for (final (i, r) in _rows.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 9,
                      child: Column(children: [
                        _cell(r.$1, 'নাম'),
                        const SizedBox(height: 4),
                        _cell(r.$2, 'ফোন (ইচ্ছা হলে)', number: true),
                      ]),
                    ),
                    const SizedBox(width: 6),
                    Expanded(flex: 4, child: _cell(r.$3, '০', number: true, right: true)),
                    SizedBox(
                      width: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close_rounded, size: 18, color: K.muted),
                        onPressed: () => setState(() => _rows.removeAt(i)),
                      ),
                    ),
                  ]),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _rows.add((TextEditingController(), TextEditingController(), TextEditingController()))),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Tx('আরও এক সারি', style: t(14, c: K.blue)),
                ),
              ),
            ]),
          ),
          if (count > 0) ...[
            const SizedBox(height: 12),
            _effect('${bn('$count')} জন গ্রাহকের মোট ${sar(total)} বকেয়া উঠবে, ${dateShort(_at)} তারিখে। নতুন নামগুলো গ্রাহক তালিকায় আসবে।'),
          ],
        ],
      ]),
    );
  }

  Widget _cell(TextEditingController c, String hint, {bool number = false, bool right = false}) => TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        onChanged: (_) => setState(() {}),
        style: t(14.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: tr(hint),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: K.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: K.border)),
        ),
      );
}

/// What the agent was owed (or had in advance) before the app.
class PrevAgentScreen extends StatefulWidget {
  const PrevAgentScreen({super.key, required this.h});
  final Hisab h;
  @override
  State<PrevAgentScreen> createState() => _PrevAgentScreenState();
}

class _PrevAgentScreenState extends State<PrevAgentScreen> {
  Hisab get h => widget.h;
  int _i = 0;
  bool _owed = true;
  final _amount = TextEditingController(), _note = TextEditingController();
  late DateTime _at = _yesterday(h);

  @override
  Widget build(BuildContext context) {
    final agents = h.d.liveAgents;
    final a = agents.isEmpty ? null : agents[_i.clamp(0, agents.length - 1)];
    final v = parseNum(_amount.text) ?? 0;
    return Screen(
      title: 'এজেন্টের আগের হিসাব',
      bottom: Pill(
        label: 'পূর্বের হিসাবে তুলুন',
        onTap: () async {
          if (a == null) return snack(context, 'আগে এজেন্ট যোগ করুন');
          if (v <= 0) return snack(context, 'টাকা লিখুন');
          await h.addOpening(kind: 'agent', at: _at, agentId: a.id, taka: _owed ? v : -v, note: _note.text);
          if (!context.mounted) return;
          snack(context, 'পূর্বের হিসাবে উঠেছে');
          Navigator.pop(context);
        },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        Tx('এজেন্ট', style: t(14, c: K.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, x) in agents.indexed) ChoiceChipX(label: x.name, on: _i == i, onTap: () => setState(() => _i = i)),
        ]),
        const SizedBox(height: 14),
        Seg<bool>(items: const [(true, 'এজেন্ট পাবেন'), (false, 'এজেন্টের কাছে অগ্রিম')], value: _owed, onChanged: (v) => setState(() => _owed = v)),
        const SizedBox(height: 12),
        Field(label: 'টাকা', controller: _amount, number: true, big: true, prefix: '৳ ', hint: '0', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _DateRow(label: 'কোন তারিখ পর্যন্ত হিসাব', at: _at, onPick: (d) => setState(() => _at = d)),
        const SizedBox(height: 12),
        Field(label: 'নোট (ইচ্ছা হলে)', controller: _note, hint: 'যেমন অক্টোবরের শেষ হিসাব', maxLines: 2),
        if (a != null && v > 0) ...[
          const SizedBox(height: 14),
          _effect(_owed
              ? '${a.name}-এর পাওনায় ${taka(v)} যোগ হবে (এখন ${taka(agentOwed(h.d, a.id))} → ${taka(agentOwed(h.d, a.id) + v)})। এজেন্টের অ্যাপে "পূর্বের হিসাব" লেখা দেখাবে।'
              : '${a.name}-এর কাছে ${taka(v)} আগাম আছে — পাওনা থেকে কাটা যাবে (এখন ${taka(agentOwed(h.d, a.id))} → ${taka(agentOwed(h.d, a.id) - v)})।'),
        ],
      ]),
    );
  }
}

/// Riyal an admin held before the app.
class PrevCashScreen extends StatefulWidget {
  const PrevCashScreen({super.key, required this.h});
  final Hisab h;
  @override
  State<PrevCashScreen> createState() => _PrevCashScreenState();
}

class _PrevCashScreenState extends State<PrevCashScreen> {
  Hisab get h => widget.h;
  int _i = 0;
  final _amount = TextEditingController(), _note = TextEditingController();
  late DateTime _at = _yesterday(h);

  /// The admins to choose from: this one first, then the others seen.
  List<(int, String)> _admins() {
    final out = <(int, String)>[(h.session == null ? 0 : h.meId, h.meName.isEmpty ? h.ownerLabel : h.meName)];
    for (final e in adminsIn(h.d).entries) {
      if (e.key == 0 || out.any((x) => x.$1 == e.key)) continue;
      out.add((e.key, e.value));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final admins = _admins();
    final (id, name) = admins[_i.clamp(0, admins.length - 1)];
    final v = parseNum(_amount.text) ?? 0;
    return Screen(
      title: 'হাতে আগের রিয়াল',
      bottom: Pill(
        label: 'পূর্বের হিসাবে তুলুন',
        onTap: () async {
          if (v <= 0) return snack(context, 'রিয়াল লিখুন');
          await h.addOpening(kind: 'cash', at: _at, handBy: id, handByName: name, sar: v, note: _note.text);
          if (!context.mounted) return;
          snack(context, 'পূর্বের হিসাবে উঠেছে');
          Navigator.pop(context);
        },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        Tx('কার হাতে', style: t(14, c: K.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, x) in admins.indexed) ChoiceChipX(label: x.$2, on: _i == i, onTap: () => setState(() => _i = i)),
        ]),
        const SizedBox(height: 14),
        Field(label: 'রিয়াল', controller: _amount, number: true, big: true, suffix: 'SAR', hint: '0', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _DateRow(label: 'কোন তারিখে হাতে ছিল', at: _at, onPick: (d) => setState(() => _at = d)),
        const SizedBox(height: 12),
        Field(label: 'নোট (ইচ্ছা হলে)', controller: _note, hint: 'যেমন ক্যাশবাক্সে গুনে দেখা', maxLines: 2),
        if (v > 0) ...[
          const SizedBox(height: 14),
          _effect('$name-এর হাতের হিসাবে ${dateShort(_at)} তারিখে ${sar(v)} যোগ হবে। "হিসাব বুঝিয়ে দিন"-এ "শুরুতে হাতে ছিল"-তে এটা ধরা হবে।'),
        ],
      ]),
    );
  }
}

/// A send made before the app: already done, nothing goes to the agent.
class PrevSendScreen extends StatefulWidget {
  const PrevSendScreen({super.key, required this.h});
  final Hisab h;
  @override
  State<PrevSendScreen> createState() => _PrevSendScreenState();
}

class _PrevSendScreenState extends State<PrevSendScreen> {
  Hisab get h => widget.h;
  final _sar = TextEditingController(), _no = TextEditingController(), _paid = TextEditingController(), _trx = TextEditingController(), _note = TextEditingController();
  late final _rate = TextEditingController(text: _lastRate());
  late DateTime _at = _yesterday(h).copyWith(hour: 12, minute: 0);
  Customer? _c;
  Method _method = Method.bkash;
  int _pay = 0;
  int _ai = 0;
  bool _agentPaid = true;

  String _lastRate() {
    final last = [...h.d.txns.where((t) => !t.old)]..sort((a, b) => b.at.compareTo(a.at));
    if (last.isEmpty) return '';
    final r = last.first.rate;
    return r == r.roundToDouble() ? '${r.round()}' : '$r';
  }

  @override
  Widget build(BuildContext context) {
    final agents = h.d.liveAgents;
    final a = agents.isEmpty ? null : agents[_ai.clamp(0, agents.length - 1)];
    final s = parseNum(_sar.text) ?? 0, r = parseNum(_rate.text) ?? 0;
    final tk = (s * r).roundToDouble();
    final paid = _pay == 0 ? s : (_pay == 1 ? 0.0 : (parseNum(_paid.text) ?? 0));
    final number = bdMobile(_no.text);
    final ready = _c != null && a != null && s > 0 && r > 0 && number != null && paid <= s;
    return Screen(
      title: 'আগের লেনদেন',
      bottom: Pill(
        label: 'পূর্বের হিসাবে তুলুন',
        onTap: () async {
          if (_c == null) return snack(context, 'গ্রাহক বাছুন');
          if (a == null) return snack(context, 'আগে এজেন্ট যোগ করুন');
          if (s <= 0 || r <= 0) return snack(context, 'রিয়াল আর রেট লিখুন');
          if (number == null) return snack(context, '১১ সংখ্যার নম্বর দিন (01XXXXXXXXX)');
          if (paid > s) return snack(context, 'নগদ রিয়ালের চেয়ে বেশি হতে পারে না');
          final draft = Txn(
            id: '',
            no: 0,
            customerId: _c!.id,
            recipientLabel: '',
            number: number,
            method: _method,
            kind: Kind.send,
            sarAmount: s,
            rate: r,
            taka: tk,
            fee: 0,
            agentId: a.id,
            pay: const [Pay.cash, Pay.due, Pay.partial][_pay],
            sarPaid: paid,
            at: _at,
            trxId: _trx.text.trim().toUpperCase(),
            note: _note.text.trim(),
          );
          final t = await h.addOldTxn(draft, at: _at, agentPaid: _agentPaid);
          if (!context.mounted) return;
          snack(context, '${txnNo(t.no)} পূর্বের হিসাবে উঠেছে');
          Navigator.pop(context);
        },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        const Note('এজেন্ট বা গ্রাহকের কাছে কোনো মেসেজ বা নোটিফিকেশন যাবে না — শুধু হিসাবে উঠবে।', icon: Icons.notifications_off_outlined),
        const SizedBox(height: 14),
        _DateRow(label: 'কবে পাঠানো হয়েছিল', at: _at, time: true, onPick: (d) => setState(() => _at = d)),
        const SizedBox(height: 12),
        Tx('গ্রাহক', style: t(14, c: K.muted)),
        const SizedBox(height: 6),
        _customerBox(context, h, _c, () async {
          final c = await pickCustomer(context, h);
          if (c != null) setState(() => _c = c);
        }),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Field(label: 'রিয়াল', controller: _sar, number: true, hint: '0', onChanged: (_) => setState(() {}))),
          const SizedBox(width: 10),
          Expanded(child: Field(label: 'রেট', controller: _rate, number: true, hint: '32.5', onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: 6),
        Tx('এজেন্ট পাঠিয়েছেন: ${taka(tk)}', style: t(14, w: FontWeight.w600, c: K.navy)),
        const SizedBox(height: 12),
        Field(label: 'যে নম্বরে গেছে', controller: _no, phone: true, hint: '01XXXXXXXXX', onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final m in [Method.bkash, Method.nagad, Method.rocket]) ChoiceChipX(label: m.bnName, on: _method == m, onTap: () => setState(() => _method = m)),
        ]),
        const SizedBox(height: 14),
        Tx('গ্রাহক রিয়াল দিয়েছিলেন', style: t(14, c: K.muted)),
        const SizedBox(height: 6),
        Seg<int>(items: const [(0, 'পুরো নগদ'), (1, 'পুরো বকেয়া'), (2, 'আংশিক')], value: _pay, onChanged: (v) => setState(() => _pay = v)),
        if (_pay == 2) ...[
          const SizedBox(height: 10),
          Field(label: 'নগদ পেয়েছিলেন (রিয়াল)', controller: _paid, number: true, hint: '0', onChanged: (_) => setState(() {})),
        ],
        const SizedBox(height: 14),
        Tx('এজেন্ট', style: t(14, c: K.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, x) in agents.indexed) ChoiceChipX(label: x.name, on: _ai == i, onTap: () => setState(() => _ai = i)),
        ]),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _agentPaid,
          onChanged: (v) => setState(() => _agentPaid = v),
          title: Tx('এজেন্টকে এর টাকা আগেই দেওয়া হয়েছে', style: t(14.5)),
          subtitle: Tx(_agentPaid ? 'এজেন্টের পাওনায় যোগ হবে না' : 'এজেন্টের পাওনায় যোগ হবে', style: t(12.5, c: K.muted)),
        ),
        const SizedBox(height: 6),
        Field(label: 'TrxID (ইচ্ছা হলে)', controller: _trx, hint: 'জানা থাকলে'),
        const SizedBox(height: 10),
        Field(label: 'নোট (ইচ্ছা হলে)', controller: _note, maxLines: 2),
        if (ready) ...[
          const SizedBox(height: 14),
          _effect([
            '${dateShort(_at)} তারিখে "পৌঁছেছে" লেনদেন হিসেবে উঠবে, নম্বর ${txnNo(h.d.txns.fold<int>(0, (m, t) => t.no < m ? t.no : m) - 1)}।',
            if (s - paid > 0.004) '${_c!.name}-এর বকেয়া ${sar(s - paid)} বাড়বে।',
            if (paid > 0) 'সেই দিনের হাতের হিসাবে ${sar(paid)}।',
            _agentPaid ? '${a.name}-এর পাওনায় কিছু যোগ হবে না।' : '${a.name}-এর পাওনায় ${taka(tk)} যোগ হবে (কমিশনসহ)।',
          ].join('\n')),
        ],
      ]),
    );
  }
}
