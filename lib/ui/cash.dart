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
  Period _p = Period.all();

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
          var bal = 0.0;
          final rows = <(CashLine, double)>[];
          for (final l in all) {
            bal += l.inSar - l.outSar;
            rows.add((l, bal));
          }
          final shown = rows.where((r) => _p.has(r.$1.at)).toList().reversed.toList();
          final inP = shown.fold<double>(0, (s, r) => s + r.$1.inSar);
          final outP = shown.fold<double>(0, (s, r) => s + r.$1.outSar);
          final days = <String, List<(CashLine, double)>>{};
          for (final r in shown) {
            days.putIfAbsent(dayLabel(r.$1.at, h.now), () => []).add(r);
          }
          return Screen(
            title: 'হাতের হিসাব',
            subtitle: who == null ? 'সব এডমিন মিলে' : (admins[who] ?? h.meName),
            trailing: CircleBtn(icon: Icons.handshake_outlined, label: 'কালেকশন বুঝে নিন', onTap: () => _receive(context)),
            body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
              CardBox(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx(who == null ? '${h.ownerLabel}-এর মোট হিসাবে হাতে থাকা উচিত (সব এডমিন মিলে)' : 'হাতে থাকা উচিত', style: t(13, c: K.muted)),
                  Tx(sar(bal), style: t(30, w: FontWeight.w700)),
                  Tx('এই সময়ে এসেছে ${sar(inP)} · গেছে ${sar(outP)}', style: t(12.5, c: K.muted)),
                ]),
              ),
              if (_owner && admins.length > 1) ...[
                SectionHead('এডমিনদের হাতে'),
                CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(children: [
                    for (final (i, e) in admins.entries.indexed)
                      Row2(
                        lead: dotIcon(Icons.person_rounded, e.key == _who ? K.navy : K.blueTint, e.key == _who ? Colors.white : K.blue, size: 38),
                        title: '${e.value}${e.key == h.meId ? ' (আপনি)' : ''}',
                        value: sar(cashInHand(d, me: e.key, owner: e.key == h.meId)),
                        last: i == admins.length - 1,
                        onTap: () => setState(() => _who = e.key),
                      ),
                    Row2(
                      lead: dotIcon(Icons.groups_rounded, _who == null ? K.navy : K.greenTint, _who == null ? Colors.white : K.green, size: 38),
                      title: '${h.ownerLabel}-এর মোট (সব এডমিন মিলে)',
                      value: sar(cashInHand(d)),
                      last: true,
                      onTap: () => setState(() => _who = null),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              PeriodChips(value: _p, now: h.now, onChanged: (p) => setState(() => _p = p)),
              if (shown.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Note('এই সময়ে হাতে কোনো রিয়াল আসা-যাওয়া নেই।')),
              for (final g in days.entries) ...[
                SectionHead(g.key),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Tx(
                      'এসেছে ${sar(g.value.fold<double>(0, (s, r) => s + r.$1.inSar))} · গেছে ${sar(g.value.fold<double>(0, (s, r) => s + r.$1.outSar))} · দিনের শেষে ${sar(g.value.first.$2)}',
                      style: t(12.5, c: K.navy, w: FontWeight.w600)),
                ),
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
