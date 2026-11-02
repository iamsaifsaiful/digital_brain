import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../state/hisab.dart';
import 'home.dart';
import 'kit.dart';
import '../core/lang.dart';
import 'reports.dart';
import 'send.dart';
import 'txn.dart';
import 'more.dart' show CustomerSettingsScreen;

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key, required this.h, this.onTab});
  final Hisab h;

  /// Swiping past the first or last list goes to the next main tab.
  final ValueChanged<int>? onTab;

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final _q = TextEditingController();
  int _f = 0;

  /// Swipe left or right over the list: the next or previous of সবাই ·
  /// বকেয়া · পুরনো · বকেয়া নেই (and past the ends, the next main tab).
  void _swipe(DragEndDetails e) {
    final v = e.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    if (v < 0) {
      if (_f < 3) {
        setState(() => _f++);
      } else {
        widget.onTab?.call(2);
      }
    } else {
      if (_f > 0) {
        setState(() => _f--);
      } else {
        widget.onTab?.call(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Live(
      h: widget.h,
      builder: (context) {
        final h = widget.h;
        final d = h.d;
        final oldDays = d.settings.oldDueDays;
        var list = h.searchCustomers(_q.text);
        list = list.where((c) {
          final due = customerDue(d, c.id);
          final days = oldestDueDays(d, c.id, h.now) ?? -1;
          return switch (_f) {
            1 => due > 0,
            2 => due > 0 && days >= oldDays,
            3 => due > 0 && days >= 30,
            _ => true,
          };
        }).toList();
        if (_f > 0) list.sort((a, b) => customerDue(d, b.id).compareTo(customerDue(d, a.id)));
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _swipe,
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
            Row(children: [
              Expanded(child: Tx('গ্রাহক', style: t(22, w: FontWeight.w700))),
              CircleBtn(icon: Icons.settings_outlined, label: 'গ্রাহকের সেটিংস', onTap: () => push(context, CustomerSettingsScreen(h: h))),
              const SizedBox(width: 8),
              CircleBtn(
                icon: Icons.person_add_alt_1_rounded,
                label: 'নতুন গ্রাহক',
                onTap: () async {
                  final c = await push<Customer>(context, QuickProfile(h: h));
                  if (c != null && context.mounted) push(context, CustomerScreen(h: h, id: c.id));
                },
              ),
            ]),
            const SizedBox(height: 4),
            Tx('মোট বকেয়া ${sar(totalCustomerDue(d))} · ${bn('${d.customers.length}')} জন গ্রাহক', style: t(13.5, c: K.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: t(15),
              decoration: InputDecoration(
                hintText: tr('নাম বা নম্বর দিয়ে খুঁজুন'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: K.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: K.border)),
              ),
            ),
            const SizedBox(height: 10),
            Seg<int>(items: [(0, 'সবাই'), (1, 'বকেয়া'), (2, '${bn('$oldDays')}+ দিন'), (3, '${bn('30')}+ দিন')], value: _f, onChanged: (v) => setState(() => _f = v)),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child)),
              child: KeyedSubtree(
                key: ValueKey(_f),
                child: list.isEmpty
                    ? const Note('কেউ নেই।')
                    : CardBox(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(children: [
                          for (final (i, c) in list.indexed) _CustomerRow(h: h, c: c, last: i == list.length - 1),
                        ]),
                      ),
              ),
            ),
          ]),
        );
      });
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.h, required this.c, required this.last});
  final Hisab h;
  final Customer c;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final d = h.d;
    final due = customerDue(d, c.id);
    final limit = dueLimitOf(d, c);
    final days = oldestDueDays(d, c.id, h.now);
    return InkWell(
      onTap: () => push(context, CustomerScreen(h: h, id: c.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.line))),
        child: Row(children: [
          Avatar(h: h, name: c.name, photo: c.photo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx(c.name, style: t(15, w: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              Tx(
                due > 0 ? '${sar(due)} বকেয়া${days != null && days > 0 ? ' · ${bn('$days')} দিন' : ''}' : (due < 0 ? 'অগ্রিম ${sar(-due)}' : 'বকেয়া নেই'),
                style: t(12.5, c: due > 0 ? ((days ?? 0) >= d.settings.oldDueDays ? K.red : K.muted) : K.muted),
              ),
            ]),
          ),
          if (c.promiseAt != null && due > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.notifications_active_outlined, size: 20, color: c.promiseAt!.isAfter(h.now) ? K.blue : K.amberText),
            ),
          Ring(percent: limit <= 0 ? 0 : (due > 0 ? due : 0) / limit * 100, size: 48),
        ]),
      ),
    );
  }
}

/// A customer's page: due, chart, history, reminder and statement.
class CustomerScreen extends StatelessWidget {
  const CustomerScreen({super.key, required this.h, required this.id});
  final Hisab h;
  final String id;

  @override
  Widget build(BuildContext context) => Live(
      h: h,
      builder: (context) {
        final c = customerById(h.d, id);
        if (c == null) return const Screen(title: 'গ্রাহক', body: SizedBox());
        final d = h.d;
        final due = customerDue(d, c.id);
        final limit = dueLimitOf(d, c);
        final now = h.now;
        // Riyal sent per month, last 6 months.
        final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)];
        final vals = [
          for (final m in months) d.txns.where((x) => x.customerId == c.id && !x.cancelled && x.at.year == m.year && x.at.month == m.month).fold<double>(0, (s, x) => s + x.sarAmount),
        ];
        final rows = <(DateTime, Widget)>[
          for (final x in d.txns.where((x) => x.customerId == c.id)) (x.at, TxnRow(h: h, t: x, showCustomer: false)),
          for (final p in d.deposits.where((p) => p.customerId == c.id))
            (
              p.at,
              Row2(
                lead: dotIcon(Icons.south_west_rounded, K.greenTint, K.green),
                title: 'রিয়াল জমা',
                sub: '${dateShort(p.at)} · ${timeText(p.at)}${p.note.isEmpty ? '' : ' · ${p.note}'}',
                value: '+${sar(p.sarAmount)}',
                valueColor: K.green,
              )
            ),
          for (final l in d.losses.where((l) => l.customerId == c.id))
            (
              l.at,
              Row2(
                lead: dotIcon(Icons.money_off_rounded, K.redTint, K.red),
                title: 'লস — আদায় হবে না',
                sub: '${dateShort(l.at)} · ${timeText(l.at)}${l.note.isEmpty ? '' : ' · ${l.note}'}',
                value: sar(l.sarAmount),
                valueColor: K.red,
              )
            ),
        ]..sort((a, b) => b.$1.compareTo(a.$1));
        final lost = lossOf(d, c.id);
        return Screen(
          title: c.name,
          trailing: h.can('customers') ? CircleBtn(icon: Icons.edit_outlined, label: 'প্রোফাইল বদলান', onTap: () => push(context, EditCustomer(h: h, c: c))) : null,
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
            CardBox(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(children: [
                Row(children: [
                  Avatar(h: h, name: c.name, photo: c.photo, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Tx(due > 0 ? 'বকেয়া' : (due < 0 ? 'অগ্রিম দেওয়া' : 'বকেয়া নেই'), style: t(13, c: K.muted)),
                      Tx(due == 0 ? '—' : sar(due.abs()), style: t(26, w: FontWeight.w700, c: due > 0 ? K.red : K.ink)),
                      Tx('সীমা ${sar(limit)}${c.phone.isEmpty ? '' : ' · ${bn(c.phone)}'}', style: t(12.5, c: K.muted)),
                      if (lost > 0) Tx('লস ধরা হয়েছে ${sar(lost)}', style: t(12.5, w: FontWeight.w600, c: K.red)),
                    ]),
                  ),
                  Ring(percent: limit <= 0 ? 0 : (due > 0 ? due : 0) / limit * 100, size: 56),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  if (h.can('send')) Expanded(child: Pill(label: 'পাঠান', icon: Icons.north_east_rounded, height: 48, onTap: () => push(context, EntryScreen(h: h, c: c)))),
                  if (h.can('send') && h.can('deposit')) const SizedBox(width: 10),
                  if (h.can('deposit')) Expanded(child: Pill(label: 'জমা নিন', icon: Icons.south_west_rounded, height: 48, color: K.navy, onTap: () => push(context, DepositScreen(h: h, c: c)))),
                ]),
              ]),
            ),
            if (due > 0) ...[
              const SizedBox(height: 12),
              PromiseCard(h: h, c: c),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SoftPill(
                  label: 'PDF হিসাব',
                  icon: Icons.picture_as_pdf_outlined,
                  onTap: () => sharePdf(context, h, customerPdf(h, c), 'hisab-${c.name}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SoftPill(
                  label: 'হিসাব পাঠান',
                  icon: Icons.ios_share_rounded,
                  onTap: () async {
                    final text = customerStatement(d, c);
                    final wa = await whatsappOf(context, h, c);
                    if (wa != null) {
                      await h.s.device.whatsapp(wa, text);
                    } else {
                      await h.s.device.shareText(text);
                    }
                    await h.note('cust', 'গ্রাহককে হিসাব পাঠানো', c.name);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (c.phone.isNotEmpty) Expanded(child: SoftPill(label: 'ফোন করুন', icon: Icons.call_outlined, onTap: () => h.s.device.call(c.phone))),
              if (c.phone.isNotEmpty && due > 0 && h.can('loss')) const SizedBox(width: 8),
              if (due > 0 && h.can('loss'))
                Expanded(
                  child: SoftPill(
                    label: 'আদায় হবে না',
                    icon: Icons.money_off_rounded,
                    color: K.red,
                    onTap: () => _writeOff(context, h, c, due),
                  ),
                ),
            ]),
            if (vals.any((v) => v > 0)) ...[
              const SizedBox(height: 14),
              CardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx('মাসে কত রিয়াল পাঠান', style: t(15, w: FontWeight.w600)),
                  const SizedBox(height: 10),
                  LineChart(values: vals, labels: [for (final m in months) monthShort(m.month)], caption: 'গত ছয় মাসে পাঠানো রিয়াল', markLabel: sar(vals.reduce((a, b) => a > b ? a : b))),
                ]),
              ),
            ],
            if (c.recipients.isNotEmpty) ...[
              const SizedBox(height: 6),
              SectionHead('যাদের কাছে পাঠান'),
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  for (final (i, r) in c.recipients.indexed)
                    Row2(
                      lead: dotIcon(Icons.account_balance_wallet_outlined, K.blueTint, K.blue, size: 38),
                      title: r.label.isEmpty ? r.method.bnName : r.label,
                      sub: '${r.method.bnName} · ${r.method == Method.bank ? bn(r.number) : bdShow(r.number)}',
                      last: i == c.recipients.length - 1,
                    ),
                ]),
              ),
            ],
            if (c.home.isNotEmpty || c.salaryDay.isNotEmpty || c.referrer.isNotEmpty || c.note.isNotEmpty || c.area.isNotEmpty) ...[
              const SizedBox(height: 6),
              SectionHead('প্রোফাইল'),
              CardBox(
                child: Tx(
                  [
                    if (c.area.isNotEmpty) 'থাকেন/কাজ: ${c.area}',
                    if (c.home.isNotEmpty) 'দেশের বাড়ি: ${c.home}',
                    if (c.salaryDay.isNotEmpty) 'বেতনের তারিখ: ${c.salaryDay}',
                    if (c.referrer.isNotEmpty) 'কার মাধ্যমে: ${c.referrer}',
                    if (c.note.isNotEmpty) 'নোট: ${c.note}',
                  ].join('\n'),
                  style: t(14, h: 1.6),
                ),
              ),
            ],
            const SizedBox(height: 6),
            SectionHead('হিসাবের খাতা'),
            if (rows.isEmpty) const Note('এখনো কোনো লেনদেন নেই।'),
            if (rows.isNotEmpty) CardBox(padding: const EdgeInsets.symmetric(horizontal: 14), child: Column(children: [for (final r in rows) r.$2])),
          ]),
        );
      });
}

Future<void> _writeOff(BuildContext context, Hisab h, Customer c, double due) async {
  final v = await askText(context, 'কত রিয়াল আর পাওয়া যাবে না?', initial: groupEn(due, decimals: 2).replaceAll(',', ''), number: true, ok: 'এগোন');
  final amount = v == null ? null : parseNum(v);
  if (amount == null || amount <= 0 || !context.mounted) return;
  if (amount > due + 0.001) {
    snack(context, 'বকেয়ার (${sar(due)}) চেয়ে বেশি লস ধরা যায় না');
    return;
  }
  final note = await askText(context, 'কারণ (ইচ্ছা হলে)', hint: 'যেমন দেশে চলে গেছেন, যোগাযোগ নেই', ok: 'লস হিসেবে রাখুন');
  if (note == null || !context.mounted) return;
  if (!await confirm(context, 'লস হিসেবে রাখবেন?', '${c.name}-এর ${sar(amount)} বকেয়া থেকে বাদ যাবে আর রিপোর্টে "লস" হিসেবে দেখাবে। হাতের রিয়ালে কিছু যোগ হবে না।',
      yes: 'হ্যাঁ, রাখুন', danger: true)) {
    return;
  }
  await h.addLoss(c, amount, note);
  if (context.mounted) snack(context, '${sar(amount)} লস হিসেবে রাখা হলো');
}

/// The customer's WhatsApp (Saudi) number; when there is none yet, asks
/// for it once and keeps it in the profile. Null = not given.
Future<String?> whatsappOf(BuildContext context, Hisab h, Customer c) async {
  if (c.phone.trim().isNotEmpty) return c.phone;
  final v = await askText(context, '${c.name}-এর হোয়াটসঅ্যাপ নম্বর', hint: '05XXXXXXXX', number: true, ok: 'রাখুন ও পাঠান');
  if (v == null || v.trim().isEmpty) return null;
  final n = saMobile(v);
  if (n == null) {
    if (context.mounted) snack(context, 'সৌদি মোবাইল নম্বর ঠিক নেই — 05 দিয়ে শুরু, মোট ১০ সংখ্যা');
    return null;
  }
  c.phone = n;
  await h.customerChanged(c, 'হোয়াটসঅ্যাপ নম্বর যোগ ${bn(n)}');
  return n;
}

/// When the customer said they would pay. The phone rings that day; then
/// the reminder message goes to them on WhatsApp with one tap.
class PromiseCard extends StatelessWidget {
  const PromiseCard({super.key, required this.h, required this.c});
  final Hisab h;
  final Customer c;

  Future<void> _set(BuildContext context) async {
    final now = h.now;
    final init = c.promiseAt ?? DateTime(now.year, now.month, now.day + 3, 10);
    final day = await showDatePicker(
      context: context,
      initialDate: init.isBefore(now) ? now : init,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'কবে বকেয়া দেবেন বলেছেন?',
      cancelText: 'বাতিল',
      confirmText: 'ঠিক আছে',
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: init.hour, minute: init.minute), helpText: 'কখন মনে করাবে?', cancelText: 'বাতিল', confirmText: 'ঠিক আছে');
    if (time == null || !context.mounted) return;
    final note = await askText(context, 'নোট (ইচ্ছা হলে)', hint: 'যেমন বেতন পেলে দেবেন', initial: c.promiseNote, ok: 'রিমাইন্ডার দিন');
    if (note == null) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!at.isAfter(h.now)) {
      if (context.mounted) snack(context, 'সময়টা পেরিয়ে গেছে, পরের কোনো সময় দিন');
      return;
    }
    await h.s.reminders.askPermission();
    await h.setPromise(c, at, note);
    if (context.mounted) snack(context, '${dateShort(at)}, ${timeText(at)}-এ মনে করাবে');
  }

  @override
  Widget build(BuildContext context) {
    final at = c.promiseAt;
    final came = at != null && !at.isAfter(h.now);
    return CardBox(
      color: came ? K.amberTint : K.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          dotIcon(came ? Icons.notifications_active_rounded : Icons.event_outlined, came ? Colors.white : K.blueTint, came ? K.amberText : K.blue, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Tx(at == null ? 'বকেয়া কবে দেবেন বলেছেন?' : (came ? 'বকেয়া দেওয়ার দিন এসেছে' : 'বকেয়া দেওয়ার কথা'), style: t(15, w: FontWeight.w600, c: came ? K.amberText : K.ink)),
              Tx(
                at == null ? 'তারিখ দিলে সেদিন ফোনে রিমাইন্ডার বাজবে' : '${dayLabel(at, h.now)}, ${timeText(at)}${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}',
                style: t(12.5, c: came ? K.amberText : K.muted),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SoftPill(
              label: at == null ? 'তারিখ দিন' : 'তারিখ বদলান',
              icon: Icons.edit_calendar_outlined,
              onTap: h.can('customers') || h.can('deposit') ? () => _set(context) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SoftPill(
              label: 'তাগাদা পাঠান',
              icon: Icons.chat_outlined,
              onTap: () async {
                final wa = await whatsappOf(context, h, c);
                if (wa == null) return;
                await h.s.device.whatsapp(wa, dueReminder(h.d, c));
                await h.note('cust', 'বকেয়ার তাগাদা পাঠানো', '${c.name} · ${sar(customerDue(h.d, c.id))}');
              },
            ),
          ),
        ]),
        if (at != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => h.clearPromise(c), child: Tx('রিমাইন্ডার বন্ধ করুন', style: t(13, c: K.muted))),
          ),
      ]),
    );
  }
}

/// Full profile form.
class EditCustomer extends StatefulWidget {
  const EditCustomer({super.key, required this.h, required this.c});
  final Hisab h;
  final Customer c;

  @override
  State<EditCustomer> createState() => _EditCustomerState();
}

class _EditCustomerState extends State<EditCustomer> {
  Customer get c => widget.c;
  late final _name = TextEditingController(text: c.name);
  late final _phone = TextEditingController(text: c.phone);
  late final _area = TextEditingController(text: c.area);
  late final _home = TextEditingController(text: c.home);
  late final _salary = TextEditingController(text: c.salaryDay);
  late final _limit = TextEditingController(text: c.dueLimit == null ? '' : groupEn(c.dueLimit!, decimals: 2).replaceAll(',', ''));
  late final _ref = TextEditingController(text: c.referrer);
  late final _note = TextEditingController(text: c.note);

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      snack(context, 'নাম লিখুন');
      return;
    }
    final typedPhone = _phone.text.trim();
    final phone = typedPhone.isEmpty ? '' : saMobile(typedPhone);
    if (phone == null) {
      snack(context, 'সৌদি মোবাইল নম্বর ঠিক নেই — 05 দিয়ে শুরু, মোট ১০ সংখ্যা');
      return;
    }
    _phone.text = phone;
    final limit = _limit.text.trim().isEmpty ? null : parseNum(_limit.text);
    final changes = <String>[
      if (c.name != _name.text.trim()) 'নাম ${c.name} → ${_name.text.trim()}',
      if (c.phone != _phone.text.trim()) 'মোবাইল ${bn(c.phone)} → ${bn(_phone.text.trim())}',
      if (c.area != _area.text.trim()) 'থাকেন ${_area.text.trim()}',
      if (c.home != _home.text.trim()) 'বাড়ি ${_home.text.trim()}',
      if (c.salaryDay != _salary.text.trim()) 'বেতনের তারিখ ${_salary.text.trim()}',
      if (c.dueLimit != limit) 'বকেয়ার সীমা ${c.dueLimit == null ? 'সাধারণ' : sar(c.dueLimit!)} → ${limit == null ? 'সাধারণ' : sar(limit)}',
      if (c.referrer != _ref.text.trim()) 'কার মাধ্যমে ${_ref.text.trim()}',
      if (c.note != _note.text.trim()) 'নোট বদল',
    ];
    c
      ..name = _name.text.trim()
      ..phone = _phone.text.trim()
      ..area = _area.text.trim()
      ..home = _home.text.trim()
      ..salaryDay = _salary.text.trim()
      ..dueLimit = limit
      ..referrer = _ref.text.trim()
      ..note = _note.text.trim();
    if (changes.isNotEmpty) await widget.h.customerChanged(c, changes.join(' · '));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Screen(
        title: 'প্রোফাইল',
        bottom: Pill(label: 'সংরক্ষণ', onTap: _save),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
          Center(
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                final b = await widget.h.s.device.takePhoto();
                if (b != null) await widget.h.setPhoto(c, b);
                if (mounted) setState(() {});
              },
              child: Stack(children: [
                Avatar(h: widget.h, name: c.name, photo: c.photo, size: 96),
                const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 16, backgroundColor: K.blue, child: Icon(Icons.photo_camera_rounded, size: 17, color: Colors.white))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Field(label: 'নাম', controller: _name),
          const SizedBox(height: 12),
          Field(label: 'সৌদি মোবাইল (হোয়াটসঅ্যাপ — রসিদ ও তাগাদা এখানে যায়)', controller: _phone, saudi: true, hint: '05XXXXXXXX'),
          const SizedBox(height: 12),
          Field(label: 'কোথায় থাকেন / কাজ করেন', controller: _area),
          const SizedBox(height: 12),
          Field(label: 'দেশের বাড়ি', controller: _home),
          const SizedBox(height: 12),
          Field(label: 'বেতনের তারিখ (যেমন মাসের ২৮)', controller: _salary),
          const SizedBox(height: 12),
          Field(label: 'বকেয়ার সীমা (খালি = সাধারণ ${sar(widget.h.d.settings.defaultDueLimit)})', controller: _limit, number: true, suffix: 'SAR'),
          const SizedBox(height: 12),
          Field(label: 'কার মাধ্যমে এসেছেন', controller: _ref),
          const SizedBox(height: 12),
          Field(label: 'নোট', controller: _note, maxLines: 3),
        ]),
      );
}

/// Riyal paid in: any amount, shown against the oldest sends first.
class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key, required this.h, required this.c});
  final Hisab h;
  final Customer c;

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _way = 'cash';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final c = widget.c;
    final d = h.d;
    final amt = parseNum(_amount.text) ?? 0;
    final due = customerDue(d, c.id);
    final after = due - amt;
    final before = {for (final o in openSends(d, c.id)) o.txn.id: o.left};
    final open = openSends(d, c.id, extraPayment: amt).where((o) => (before[o.txn.id] ?? 0) > 0).toList();
    return Screen(
      title: 'রিয়াল জমা',
      subtitle: c.name,
      bottom: Pill(
        label: 'জমা সংরক্ষণ',
        onTap: amt <= 0 || _busy
            ? null
            : () async {
                setState(() => _busy = true);
                final p = await h.addDeposit(c, amt, way: _way, note: _note.text);
                if (!context.mounted) return;
                final send = await confirm(context, 'জমা হয়েছে', '${sar(amt)} জমা হলো। ${c.name}-কে রসিদ পাঠাবেন?', yes: 'হোয়াটসঅ্যাপে পাঠান', no: 'না');
                final wa = send && context.mounted ? await whatsappOf(context, h, c) : null;
                if (wa != null) {
                  await h.s.device.whatsapp(wa, depositReceipt(h.d, p));
                  await h.note('recv', 'জমার রসিদ', c.name);
                }
                if (context.mounted) Navigator.pop(context);
              },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        CardBox(
          child: Row(children: [
            Avatar(h: h, name: c.name, photo: c.photo),
            const SizedBox(width: 12),
            Expanded(child: Tx(c.name, style: t(16, w: FontWeight.w600))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Tx(sar(due > 0 ? due : 0), style: t(15, w: FontWeight.w700, c: due > 0 ? K.red : K.green)),
              Tx('এখনকার বকেয়া', style: t(12, c: K.muted)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Field(label: 'কত রিয়াল দিলেন', controller: _amount, number: true, big: true, suffix: 'SAR', autofocus: true, hint: '০', onChanged: (_) => setState(() {})),
        if (due > 0) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChipX(label: 'পুরো বকেয়া ${sar(due)}', on: amt == due, onTap: () => setState(() => _amount.text = groupEn(due, decimals: 2).replaceAll(',', ''))),
          ]),
        ],
        const SizedBox(height: 14),
        Seg<String>(items: const [('cash', 'নগদ হাতে'), ('bank', 'ব্যাংক / ট্রান্সফার')], value: _way, onChanged: (v) => setState(() => _way = v)),
        const SizedBox(height: 12),
        Field(label: 'নোট (ইচ্ছা হলে)', controller: _note),
        const SizedBox(height: 14),
        CardBox(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Tx('জমার পর', style: t(13, c: K.muted)),
                Tx(after > 0 ? '${sar(after)} বকেয়া' : (after < 0 ? 'অগ্রিম ${sar(-after)}' : 'বকেয়া নেই'), style: t(18, w: FontWeight.w700, c: after > 0 ? K.red : K.green)),
              ]),
            ),
            Ring(percent: dueLimitOf(d, c) <= 0 ? 0 : (after > 0 ? after : 0) / dueLimitOf(d, c) * 100, size: 52),
          ]),
        ),
        if (open.isNotEmpty && amt > 0) ...[
          const SizedBox(height: 6),
          SectionHead('পুরনো বকেয়া আগে শোধ হবে'),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              for (final (i, o) in open.indexed)
                Row2(
                  lead: dotIcon(o.left <= 0 ? Icons.check_rounded : Icons.more_horiz_rounded, o.left <= 0 ? K.greenTint : K.redTint, o.left <= 0 ? K.green : K.red, size: 36),
                  title: '#${bn('${o.txn.no}')} · ${dateShort(o.txn.at)}',
                  sub: '${o.txn.recipientLabel.isEmpty ? bdShow(o.txn.number) : o.txn.recipientLabel} · বকেয়া ছিল ${sar(before[o.txn.id] ?? 0)}',
                  value: o.left <= 0 ? 'শোধ' : '${sar(o.left)} বকেয়া',
                  valueColor: o.left <= 0 ? K.green : K.red,
                  last: i == open.length - 1,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}
