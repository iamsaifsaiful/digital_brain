import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'home.dart';
import 'kit.dart';
import 'txn.dart';

/// The agent's account, in taka only.
class AgentTab extends StatefulWidget {
  const AgentTab({super.key, required this.h});
  final Hisab h;

  @override
  State<AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends State<AgentTab> {
  String? _agentId;
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) => Live(h: widget.h, builder: (context) {
        final h = widget.h;
        final d = h.d;
        final a = agentById(d, _agentId ?? '') ?? d.agents.first;
        final owed = agentOwed(d, a.id);
        final unpaid = unpaidForAgent(d, a.id);
        _picked.removeWhere((id) => !unpaid.any((x) => x.id == id));
        final pickedList = unpaid.where((x) => _picked.contains(x.id)).toList();
        final pickedSum = pickedList.fold<double>(0, (s, x) => s + x.agentTaka + commissionOf(x, a));
        final now = h.now;
        final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
        final vals = [for (final day in days) d.txns.where((x) => x.agentId == a.id && !x.cancelled && sameDay(x.at, day)).fold<double>(0, (s, x) => s + x.agentTaka)];
        final pays = d.agentPayments.where((p) => p.agentId == a.id).toList()..sort((x, y) => y.at.compareTo(x.at));
        const wd = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
        return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
          Row(children: [
            Expanded(child: Text('এজেন্ট', style: t(22, w: FontWeight.w700))),
            CircleBtn(icon: Icons.edit_outlined, label: 'এজেন্টের তথ্য', onTap: () => push(context, AgentEdit(h: h, a: a))),
          ]),
          if (d.agents.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in d.agents) ChoiceChipX(label: x.name, on: x.id == a.id, onTap: () => setState(() => _agentId = x.id)),
            ]),
          ],
          const SizedBox(height: 12),
          CardBox(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                dotIcon(Icons.storefront_rounded, K.navySoft, K.navy, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, style: t(16, w: FontWeight.w600)),
                    Text('হোয়াটসঅ্যাপ ${bn(a.whatsapp)}', style: t(12.5, c: K.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Text(owed >= 0 ? 'এজেন্টকে দিতে হবে' : 'এজেন্টের কাছে অগ্রিম', style: t(13, c: K.muted)),
              Text(taka(owed.abs()), style: t(30, w: FontWeight.w700, c: owed > 0 ? K.navy : K.green)),
              if (a.commissionPerThousand > 0) Text('কমিশন হাজারে ${bnNum(a.commissionPerThousand, decimals: 2)} টাকা ধরে', style: t(12.5, c: K.muted)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Pill(
                    label: 'টাকা দিলাম',
                    height: 48,
                    onTap: () async {
                      final v = await askText(context, '${a.name}-কে কত টাকা দিলেন?', number: true, hint: 'টাকা');
                      final n = v == null ? null : parseNum(v);
                      if (n == null || n <= 0) return;
                      await h.advanceAgent(a, n);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pill(
                    label: 'আজকের হিসাব',
                    color: K.navy,
                    height: 48,
                    onTap: () async {
                      await h.s.device.whatsapp(a.whatsapp, agentDayStatement(d, a, now));
                      await h.note('agent', 'এজেন্টকে দিনের হিসাব', a.name);
                    },
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('গত ৭ দিনে এজেন্ট যত টাকা পাঠালেন', style: t(15, w: FontWeight.w600)),
              const SizedBox(height: 10),
              LineChart(values: vals, labels: [for (final day in days) wd[day.weekday - 1]], caption: 'গত সাত দিনে এজেন্টের পাঠানো টাকা', markLabel: taka(vals.reduce((x, y) => x > y ? x : y))),
            ]),
          ),
          SectionHead('যেগুলোর টাকা দেওয়া হয়নি', action: unpaid.isEmpty ? null : (_picked.length == unpaid.length ? 'কোনোটা না' : 'সবগুলো'), onAction: () {
            setState(() {
              if (_picked.length == unpaid.length) {
                _picked.clear();
              } else {
                _picked
                  ..clear()
                  ..addAll(unpaid.map((x) => x.id));
              }
            });
          }),
          if (unpaid.isEmpty) const Note('সব লেনদেনের টাকা দেওয়া হয়ে গেছে।', color: K.greenTint, textColor: K.green),
          if (unpaid.isNotEmpty)
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(children: [
                for (final x in unpaid.reversed)
                  CheckboxListTile(
                    value: _picked.contains(x.id),
                    onChanged: (v) => setState(() => v == true ? _picked.add(x.id) : _picked.remove(x.id)),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('#${bn('${x.no}')} · ${bdMasked(x.number)}', style: t(14.5, w: FontWeight.w500)),
                    subtitle: Text('${dateShort(x.at)} · ${x.trxId.isEmpty ? 'TrxID বাকি' : x.trxId}', style: t(12.5, c: x.trxId.isEmpty ? K.red : K.muted)),
                    secondary: Text(taka(x.agentTaka), style: t(14.5, w: FontWeight.w600)),
                  ),
              ]),
            ),
          if (pickedList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Pill(
              label: '${bn('${pickedList.length}')}টার টাকা দিলাম · ${taka(pickedSum)}',
              color: K.green,
              onTap: () async {
                if (!await confirm(context, 'এজেন্টকে পরিশোধ', '${a.name}-কে ${taka(pickedSum)} দিয়েছেন? (${bn('${pickedList.length}')}টা লেনদেন)', yes: 'হ্যাঁ, দিয়েছি')) return;
                await h.payAgent(a, pickedList);
                setState(() => _picked.clear());
              },
            ),
          ],
          if (pays.isNotEmpty) ...[
            SectionHead('এজেন্টকে দেওয়া টাকা'),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                for (final (i, p) in pays.take(30).indexed)
                  Row2(
                    lead: dotIcon(Icons.payments_outlined, K.greenTint, K.green, size: 38),
                    title: p.txnIds.isEmpty ? 'টাকা দিলাম' : '${bn('${p.txnIds.length}')}টা লেনদেনের টাকা',
                    sub: '${dateShort(p.at)} · ${timeText(p.at)}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                    value: taka(p.taka),
                    valueColor: K.green,
                    last: i == pays.take(30).length - 1,
                  ),
              ]),
            ),
          ],
        ]);
      });
}

class AgentEdit extends StatefulWidget {
  const AgentEdit({super.key, required this.h, this.a});
  final Hisab h;
  final Agent? a;

  @override
  State<AgentEdit> createState() => _AgentEditState();
}

class _AgentEditState extends State<AgentEdit> {
  late final _name = TextEditingController(text: widget.a?.name ?? '');
  late final _wa = TextEditingController(text: widget.a?.whatsapp ?? '');
  late final _comm = TextEditingController(text: widget.a == null ? '0' : groupEn(widget.a!.commissionPerThousand, decimals: 2).replaceAll(',', ''));

  @override
  Widget build(BuildContext context) => Screen(
        title: widget.a == null ? 'নতুন এজেন্ট' : 'এজেন্টের তথ্য',
        bottom: Pill(
          label: 'সংরক্ষণ',
          onTap: () async {
            final wa = en(_wa.text).replaceAll(RegExp(r'[^0-9+]'), '');
            if (_name.text.trim().isEmpty || wa.replaceAll('+', '').length < 9) {
              snack(context, 'নাম আর হোয়াটসঅ্যাপ নম্বর ঠিকমতো দিন');
              return;
            }
            final comm = parseNum(_comm.text) ?? 0;
            if (widget.a == null) {
              await widget.h.addAgent(_name.text, wa, comm);
            } else {
              await widget.h.updateAgent(widget.a!, name: _name.text, whatsapp: wa, commission: comm);
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
          Field(label: 'নাম', controller: _name),
          const SizedBox(height: 12),
          Field(label: 'হোয়াটসঅ্যাপ নম্বর (সব মেসেজ এই চ্যাটে যাবে)', controller: _wa, phone: true),
          const SizedBox(height: 12),
          Field(label: 'কমিশন (প্রতি হাজার টাকায়)', controller: _comm, number: true, suffix: '৳/হাজার'),
          const SizedBox(height: 14),
          if (widget.a != null)
            SoftPill(
              label: 'আরেকজন এজেন্ট যোগ করুন',
              icon: Icons.add_rounded,
              onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AgentEdit(h: widget.h))),
            ),
        ]),
      );
}
