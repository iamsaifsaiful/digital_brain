import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../state/hisab.dart';
import 'home.dart' show push;
import 'kit.dart';
import 'reports.dart';
import 'txn.dart';
import 'customers.dart';
import 'users.dart' show AppUser;

/// "হাতে থাকা উচিত": every riyal in and out of a hand, day by day, with the
/// balance. Each admin has their own; the main admin sees everyone's and
/// the shop's total (a handover between admins is never counted twice).
class CashScreen extends StatefulWidget {
  const CashScreen({super.key, required this.h});
  final Hisab h;

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  Hisab get h => widget.h;

  /// null = the whole shop (main admin only).
  late int? _who = h.meId;
  late Period _p = Period.of('today', h.now);
  bool _detail = false;

  bool get _owner => h.isOwner;

  @override
  Widget build(BuildContext context) => Live(
        h: h,
        builder: (context) {
          final d = h.d;
          final admins = adminsIn(d);
          if (h.session != null) admins[h.meId] = h.meName;
          if (_owner) admins.remove(0);
          final who = _owner ? _who : h.meId;
          // The main admin's hand also holds what was done before the server.
          final ownerHand = who != null && (who == h.meId ? _owner : false);
          final all = cashLines(d, me: who, owner: ownerHand);
          var bal = 0.0, opening = 0.0;
          final rows = <(CashLine, double)>[];
          for (final l in all) {
            if (l.at.isBefore(_p.from)) opening += l.inSar - l.outSar;
            bal += l.inSar - l.outSar;
            rows.add((l, bal));
          }
          final shown = rows.where((r) => _p.has(r.$1.at)).toList().reversed.toList();
          double sumIn(String kind) => shown.where((r) => r.$1.kind == kind).fold<double>(0, (s, r) => s + r.$1.inSar);
          double sumOut(String kind) => shown.where((r) => r.$1.kind == kind).fold<double>(0, (s, r) => s + r.$1.outSar);
          int count(String kind, {bool inbound = true}) => shown.where((r) => r.$1.kind == kind && (inbound ? r.$1.inSar > 0 : r.$1.outSar > 0)).length;
          final closing = opening + shown.fold<double>(0, (s, r) => s + r.$1.inSar - r.$1.outSar);
          // Sends made on credit by this hand in the period: no riyal came.
          bool mineTxn(int by) => who == null || by == who || (ownerHand && by == 0);
          final sends = d.txns.where((x) => !x.cancelled && _p.has(x.at) && mineTxn(x.by)).toList();
          final credit = sends.where((x) => x.sarDueAtSend > 0).toList();
          final creditSar = credit.fold<double>(0, (s, x) => s + x.sarDueAtSend);
          final whoName = who == null ? '${h.ownerLabel}-এর মোট (সব এডমিন)' : (admins[who] ?? h.meName);
          final other = sumIn('adjust') + sumIn('close') - sumOut('adjust') - sumOut('close');
          final lines = <(String, double, int)>[
            ('লেনদেনে নগদ পেলাম', sumIn('txn'), count('txn')),
            ('আগের বকেয়া আদায়', sumIn('deposit'), count('deposit')),
            if (who != null) ('অন্য এডমিনের কাছ থেকে বুঝে নিলাম', sumIn('handover'), count('handover')),
            ('খরচ / রিয়াল বের', -sumOut('expense'), count('expense', inbound: false)),
            ('এজেন্টকে দিলাম', -sumOut('payment'), count('payment', inbound: false)),
            if (who != null) ('অন্য এডমিনকে বুঝিয়ে দিলাম', -sumOut('handover'), count('handover', inbound: false)),
            ('অতিরিক্ত হিসাব ও গরমিল', other, 0),
          ];
          final days = <String, List<(CashLine, double)>>{};
          for (final r in shown) {
            days.putIfAbsent(dayLabel(r.$1.at, h.now), () => []).add(r);
          }
          String summaryText() => [
                'হাতের হিসাব — $whoName',
                '${_p.label}${_p.key == 'today' ? ' (${dateShort(h.now)})' : ''}',
                'শুরুতে হাতে ছিল: ${sar(opening)}',
                for (final (label, v, n) in lines)
                  if (v.abs() >= 0.005) '${v > 0 ? '+' : '−'} $label: ${sar(v.abs())}${n > 0 ? ' (${bn('$n')}টা)' : ''}',
                'এখন হাতে আছে: ${sar(closing)}',
                if (credit.isNotEmpty) 'বকেয়ায় দেওয়া (হাতে আসেনি): ${sar(creditSar)} · ${bn('${credit.length}')}টা লেনদেন',
                'মোট লেনদেন: ${bn('${sends.length}')}টা · ${sar(sends.fold<double>(0, (s, x) => s + x.sarAmount))}',
              ].join('\n');
          return Screen(
            title: 'হাতের হিসাব',
            subtitle: whoName,
            trailing: CircleBtn(icon: Icons.handshake_outlined, label: 'কালেকশন বুঝে নিন', onTap: () => _receive(context)),
            body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
              if (_owner && admins.length > 1) ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in admins.entries) ChoiceChipX(label: '${e.value}${e.key == h.meId ? ' (আপনি)' : ''}', on: _who == e.key, onTap: () => setState(() => _who = e.key)),
                  ChoiceChipX(label: 'সব এডমিন মিলে', on: _who == null, onTap: () => setState(() => _who = null)),
                ]),
                const SizedBox(height: 10),
              ],
              PeriodChips(value: _p, now: h.now, onChanged: (p) => setState(() => _p = p)),
              const SizedBox(height: 12),
              // The handover sheet: from what was in hand to what is in hand.
              CardBox(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _line('শুরুতে হাতে ছিল', sar(opening), bold: true),
                  const Divider(height: 18, color: K.line),
                  for (final (label, v, n) in lines)
                    if (v.abs() >= 0.005) _line('${v > 0 ? '+' : '−'}  $label${n > 0 ? ' · ${bn('$n')}টা' : ''}', sar(v.abs()), color: v > 0 ? K.green : K.red),
                  if (lines.every((l) => l.$2.abs() < 0.005)) Tx('এই সময়ে হাতে কোনো রিয়াল আসা-যাওয়া নেই।', style: t(13, c: K.muted)),
                  const Divider(height: 18, color: K.line),
                  _line('এখন হাতে আছে', sar(closing), bold: true, big: true),
                ]),
              ),
              const SizedBox(height: 10),
              CardBox(
                color: K.amberTint,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _line('বকেয়ায় দেওয়া (হাতে আসেনি)', '${sar(creditSar)} · ${bn('${credit.length}')}টা', color: K.amberText),
                  _line('মোট লেনদেন', '${bn('${sends.length}')}টা · ${sar(sends.fold<double>(0, (s, x) => s + x.sarAmount))}'),
                ]),
              ),
              const SizedBox(height: 12),
              Pill(
                label: 'হিসাব বুঝিয়ে দিন (মেসেজ)',
                icon: Icons.ios_share_rounded,
                color: K.navy,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(ctx).padding.bottom),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Tx('পরের এডমিনকে যা জানাবেন', style: t(17, w: FontWeight.w600), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Flexible(child: SingleChildScrollView(child: CardBox(child: SelectableText(summaryText(), style: t(14, h: 1.55))))),
                      const SizedBox(height: 12),
                      Pill(
                        label: 'শেয়ার / হোয়াটসঅ্যাপ',
                        onTap: () async {
                          Navigator.pop(ctx);
                          await h.s.device.shareText(summaryText());
                        },
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() => _detail = !_detail),
                child: Tx(_detail ? 'বিস্তারিত লুকান' : 'প্রতিটা আসা-যাওয়া দেখুন (${bn('${shown.length}')}টা)', style: t(14, c: K.blue, w: FontWeight.w600)),
              ),
              if (_detail)
                for (final g in days.entries) ...[
                  SectionHead(g.key),
                  CardBox(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(children: [
                      for (final (i, r) in g.value.indexed)
                        Row2(
                          lead: dotIcon(r.$1.inSar > 0 ? Icons.south_west_rounded : Icons.north_east_rounded, r.$1.inSar > 0 ? K.greenTint : K.redTint, r.$1.inSar > 0 ? K.green : K.red, size: 36),
                          title: r.$1.title,
                          sub: '${timeText(r.$1.at)}${r.$1.sub.isEmpty ? '' : ' · ${r.$1.sub}'}${who == null && r.$1.byName.isNotEmpty ? ' · ${r.$1.byName}' : ''}',
                          value: r.$1.inSar > 0 ? '+${sar(r.$1.inSar)}' : '−${sar(r.$1.outSar)}',
                          valueColor: r.$1.inSar > 0 ? K.green : K.red,
                          valueSub: 'থাকে ${bnNum(r.$2, decimals: 2)}',
                          last: i == g.value.length - 1,
                          onTap: switch (r.$1.kind) {
                            'txn' => () => push(context, TxnScreen(h: h, id: r.$1.ref)),
                            'deposit' => () => push(context, CustomerScreen(h: h, id: r.$1.ref)),
                            _ => null,
                          },
                        ),
                    ]),
                  ),
                ],
            ]),
          );
        },
      );

  Widget _line(String label, String value, {Color color = K.ink, bool bold = false, bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Tx(label, style: t(big ? 15.5 : 14, w: bold ? FontWeight.w600 : FontWeight.w400))),
          Tx(value, style: t(big ? 20 : 14.5, w: bold ? FontWeight.w700 : FontWeight.w600, c: color)),
        ]),
      );

  /// Riyal handed over by another admin: I take it into my hand.
  Future<void> _receive(BuildContext context) async {
    final others = <int, String>{...adminsIn(h.d)}..remove(h.meId);
    others.remove(0);
    try {
      final r = await h.s.api.get('/users');
      for (final u in ((r['users'] as List?) ?? const []).cast<Map>()) {
        final x = AppUser(u.cast<String, Object?>());
        if (x.role != 'agent' && x.id != h.meId) others[x.id] = x.name;
      }
    } catch (_) {}
    if (!context.mounted) return;
    if (others.isEmpty) {
      snack(context, 'আর কোনো এডমিন নেই');
      return;
    }
    final from = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Tx('কার কাছ থেকে রিয়াল বুঝে নিলেন?', style: t(17, w: FontWeight.w600)),
          for (final e in others.entries)
            ListTile(
              title: Tx(e.value, style: t(15)),
              subtitle: Tx('তাঁর হাতে থাকা উচিত ${sar(cashInHand(h.d, me: e.key))}', style: t(12.5, c: K.muted)),
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ]),
      ),
    );
    if (from == null || !context.mounted) return;
    final v = await askText(context, '${others[from]}-এর কাছ থেকে কত রিয়াল?', number: true, hint: 'SAR');
    final n = v == null ? null : parseNum(v);
    if (n == null || n <= 0 || !context.mounted) return;
    final note = await askText(context, 'নোট (ইচ্ছা হলে)', ok: 'বুঝে নিলাম');
    if (note == null || !context.mounted) return;
    if (!await confirm(context, 'কালেকশন বুঝে নিলেন?', '${others[from]}-এর হাত থেকে ${sar(n)} আপনার হাতে আসবে। মোট হিসাবে কোনো বদল হবে না।', yes: 'হ্যাঁ, বুঝে নিলাম')) return;
    await h.receiveFrom(from, others[from]!, n, note);
    if (context.mounted) snack(context, '${sar(n)} বুঝে নেওয়া হলো');
  }
}
