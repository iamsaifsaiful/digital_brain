import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/me.dart' show bloodGroups;
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'blood_details.dart';
import 'docs_screen.dart';
import 'new_item_screen.dart';

void _push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

// ───────────────────────── Tags ─────────────────────────

/// Tag chips with "+ ট্যাগ", for a note, document or contact ([tagKey] like "note:<id>").
class TagEditor extends StatelessWidget {
  const TagEditor({super.key, required this.tagKey});
  final String tagKey;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final tags = brain.tagsOf(tagKey);
    Future<void> add() async {
      final all = brain.data.allTags.where((t) => !tags.contains(t)).toList();
      final picked = await showAppSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('ট্যাগ লাগান'), style: display(19, weight: 700)),
              const SizedBox(height: 10),
              if (all.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: [for (final t in all) ActionChip(label: Text('#$t'), onPressed: () => Navigator.pop(ctx, t))]),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: () => Navigator.pop(ctx, ''), icon: const Icon(Icons.add_rounded), label: Text(tr('নতুন ট্যাগ'))),
            ]),
          ),
        ),
      );
      if (picked == null || !context.mounted) return;
      var t = picked;
      if (t.isEmpty) t = (await askText(context, tr('নতুন ট্যাগ'), hint: tr('যেমন: গাড়ি, অফিস, বাবার'))) ?? '';
      t = t.replaceAll('#', '').trim();
      if (t.isNotEmpty) await brain.setTags(tagKey, [...tags, t]);
    }

    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final t in tags)
        InputChip(
          label: Text('#$t'),
          labelStyle: body(13, weight: FontWeight.w500, color: C.greenDark),
          backgroundColor: C.greenTint,
          onDeleted: () => brain.setTags(tagKey, [...tags]..remove(t)),
          onPressed: () => _push(context, TagScreen(tag: t)),
        ),
      ActionChip(avatar: const Icon(Icons.sell_outlined, size: 16), label: Text(tr('ট্যাগ')), onPressed: add),
    ]);
  }
}

/// Every tag in use; tap one to see everything with it.
class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    int count(String t) => d.tags.values.where((l) => l.contains(t)).length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('ট্যাগ')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (d.allTags.isEmpty)
                EmptyState(
                  icon: Icons.sell_outlined,
                  title: tr('কোনো ট্যাগ নেই'),
                  text: tr('নোট, ডকুমেন্ট বা যোগাযোগ খুলে “ট্যাগ” চাপুন — যেমন #গাড়ি। একই ট্যাগের সব কিছু এক জায়গায় দেখা যাবে।'),
                )
              else
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final t in d.allTags)
                    ActionChip(
                      label: Text('#$t  ${bnDigits(count(t))}'),
                      labelStyle: body(15, weight: FontWeight.w600, color: C.greenDark),
                      backgroundColor: C.greenTint,
                      onPressed: () => _push(context, TagScreen(tag: t)),
                    ),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class TagScreen extends StatelessWidget {
  const TagScreen({super.key, required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    bool has(String k) => (d.tags[k] ?? const []).contains(tag);
    final notes = d.notes.where((n) => has('note:${n.id}')).toList();
    final docs = d.docs.where((x) => has('doc:${x.id}')).toList();
    final contacts = d.contacts.where((c) => has('contact:${c.id}')).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: '#$tag'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (notes.isEmpty && docs.isEmpty && contacts.isEmpty) Text(tr('এই ট্যাগে এখন কিছু নেই।'), style: body(14, color: C.muted)),
              if (notes.isNotEmpty) ...[
                SectionTitle(trf('নোট · {0}', [bnDigits(notes.length)])),
                Panel(
                  child: Rows(children: [
                    for (final n in notes)
                      ListRow(leading: Icon(Icons.sticky_note_2_outlined, color: C.ochre), title: n.title, subtitle: n.body, onTap: () => _push(context, NewItemScreen(note: n))),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              if (docs.isNotEmpty) ...[
                SectionTitle(trf('ডকুমেন্টস · {0}', [bnDigits(docs.length)])),
                Panel(
                  child: Rows(children: [
                    for (final x in docs)
                      ListRow(
                        leading: Icon(Icons.folder_copy_outlined, color: C.blue),
                        title: x.title,
                        subtitle: x.folder,
                        onTap: () async {
                          final ok = await verifyUser(context, reason: trf('{0} — দেখতে যাচাই করুন', [x.title]));
                          if (ok && context.mounted) _push(context, DocScreen(id: x.id, unlocked: true));
                        },
                      ),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              if (contacts.isNotEmpty) ...[
                SectionTitle(trf('যোগাযোগ · {0}', [bnDigits(contacts.length)])),
                Panel(
                  child: Rows(children: [
                    for (final c in contacts)
                      ListRow(
                        leading: Avatar(name: c.name),
                        title: c.name,
                        subtitle: c.phone,
                        onTap: () => _push(context, NewItemScreen(contact: c)),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Expiry dates ─────────────────────────

/// Every paper's expiry on one page, soonest first.
class ExpiryScreen extends StatelessWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final docs = brain.data.docs.where((x) => x.expiry != null).toList()..sort((a, b) => a.expiry!.compareTo(b.expiry!));
    final noDate = brain.data.docs.where((x) => x.expiry == null).toList();
    Color colorFor(int days) => days < 0 ? C.red : (days <= 30 ? C.orange : (days <= 182 ? C.ochre : C.green));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('কাগজের মেয়াদ')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (docs.isEmpty)
                EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: tr('কোনো মেয়াদ দেওয়া নেই'),
                  text: tr('পাসপোর্ট, ড্রাইভিং লাইসেন্স, ট্রেড লাইসেন্স — ডকুমেন্ট খুলে মেয়াদ শেষের তারিখ দিন। ৬ মাস আগে, ১ মাস আগে আর শেষের দিন মনে করাবো।'),
                )
              else
                Panel(
                  child: Rows(children: [
                    for (final x in docs)
                      ListRow(
                        leading: Container(
                          width: 12,
                          height: 44,
                          decoration: BoxDecoration(color: colorFor(dayOnly(x.expiry!).difference(dayOnly(now)).inDays), borderRadius: BorderRadius.circular(6)),
                        ),
                        title: x.title,
                        subtitle: '${fullDate(x.expiry!)} · ${dayOnly(x.expiry!).isBefore(dayOnly(now)) ? tr('মেয়াদ শেষ') : daysLeftLabel(x.expiry!, now)}',
                        subtitleColor: colorFor(dayOnly(x.expiry!).difference(dayOnly(now)).inDays),
                        trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                        onTap: () async {
                          final ok = await verifyUser(context, reason: trf('{0} — দেখতে যাচাই করুন', [x.title]));
                          if (ok && context.mounted) _push(context, DocScreen(id: x.id, unlocked: true));
                        },
                      ),
                  ]),
                ),
              if (noDate.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(trf('{0}টি ডকুমেন্টে মেয়াদ দেওয়া নেই', [bnDigits(noDate.length)]), style: body(13, color: C.muted)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Emergency card ─────────────────────────


/// The card itself, readable without the PIN.
class EmergencyView extends StatelessWidget {
  const EmergencyView({super.key, required this.card, this.onCall});
  final EmergencyCard card;
  final void Function(String phone)? onCall;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: body(12.5, color: C.muted)),
            Text(value, style: body(16, weight: FontWeight.w600)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.roseTint, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.rose, shape: BoxShape.circle),
            child: Text(card.blood.isEmpty ? '?' : card.blood, style: display(22, weight: 700, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('জরুরি তথ্য'), style: body(13, color: C.roseDark, weight: FontWeight.w600)),
              Text(card.name.isEmpty ? tr('নাম দেওয়া নেই') : card.name, style: display(20, weight: 700)),
              Text(tr('রক্তের গ্রুপ'), style: body(12.5, color: C.muted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (final c in card.contacts)
        if (c.split('|').length >= 2 && c.split('|')[1].trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: C.surface,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                leading: Icon(Icons.call_rounded, color: C.green),
                title: Text(c.split('|')[0], style: body(16, weight: FontWeight.w600)),
                subtitle: Text('${c.split('|').length > 2 ? '${c.split('|')[2]} · ' : ''}${bnDigits(c.split('|')[1])}', style: body(14, color: C.muted)),
                onTap: onCall == null ? null : () => onCall!(c.split('|')[1]),
              ),
            ),
          ),
      const SizedBox(height: 4),
      Panel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (card.conditions.isNotEmpty) line(tr('রোগ / অবস্থা'), card.conditions),
          if (card.medicines.isNotEmpty) line(tr('নিয়মিত ওষুধ'), card.medicines),
          if (card.allergies.isNotEmpty) line(tr('অ্যালার্জি'), card.allergies),
          if (card.conditions.isEmpty && card.medicines.isEmpty && card.allergies.isEmpty) Text(tr('আর কোনো তথ্য দেওয়া নেই'), style: body(14, color: C.muted)),
        ]),
      ),
    ]);
  }
}

/// সংরক্ষণ › জরুরি কার্ড: view and edit.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final card = brain.data.emergency;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('জরুরি কার্ড'), trailing: [
            IconButton(tooltip: tr('বদলান'), onPressed: () => _push(context, const EmergencyEditScreen()), icon: const Icon(Icons.edit_outlined)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (card.isEmpty)
                EmptyState(
                  icon: Icons.emergency_outlined,
                  title: tr('জরুরি কার্ড বানান'),
                  text: tr('রক্তের গ্রুপ, জরুরি নম্বর, ওষুধ আর অ্যালার্জি। বিপদে কেউ যেন PIN ছাড়াই দেখতে পারে — অ্যাপের লক পাতায় আর চাইলে ফোনের লক স্ক্রিনে।'),
                  action: tr('এখনই বানাই'),
                  onAction: () => _push(context, const EmergencyEditScreen()),
                )
              else ...[
                EmergencyView(card: card, onCall: (p) => brain.services.launcher.open(Via.call, p)),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: card.onLockScreen,
                  onChanged: (v) => brain.saveEmergency(card.copyWith(onLockScreen: v)),
                  title: Text(tr('ফোনের লক স্ক্রিনে দেখাও'), style: body(15, weight: FontWeight.w500)),
                  subtitle: Text(tr('নোটিফিকেশনে থাকবে, ফোন না খুলেই দেখা যাবে। শুধু এই কার্ডের তথ্য — আর কিছু না।'), style: body(12.5, color: C.muted)),
                ),
                Text(tr('অ্যাপ লক থাকলেও লক পাতার “জরুরি তথ্য” বোতাম থেকে এটা দেখা যায়।'), style: body(12.5, color: C.muted, height: 1.5)),
              ],
              const SizedBox(height: 18),
              SectionTitle(tr('জাতীয় জরুরি নম্বর')),
              Panel(
                child: Rows(children: [
                  for (final (n, label, sub) in emergencyNumbers)
                    ListRow(
                      leading: Container(
                        width: 54,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.roseTint, borderRadius: BorderRadius.circular(10)),
                        child: Text(bnDigits(n), style: display(15, weight: 700, color: C.rose)),
                      ),
                      title: tr(label),
                      subtitle: tr(sub),
                      trailing: Icon(Icons.call_rounded, color: C.green),
                      onTap: () => brain.services.launcher.open(Via.call, n),
                    ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class EmergencyEditScreen extends StatefulWidget {
  const EmergencyEditScreen({super.key});
  @override
  State<EmergencyEditScreen> createState() => _EmergencyEditScreenState();
}

class _EmergencyEditScreenState extends State<EmergencyEditScreen> {
  late final EmergencyCard _old = BrainScope.read(context).data.emergency;
  late final _name = TextEditingController(text: _old.name.isEmpty ? BrainScope.read(context).userName : _old.name);
  late String _blood = _old.blood;
  late final _med = TextEditingController(text: _old.medicines);
  late final _all = TextEditingController(text: _old.allergies);
  late final _cond = TextEditingController(text: _old.conditions);
  late final List<(TextEditingController, TextEditingController, TextEditingController)> _contacts = [
    for (final c in [..._old.contacts, if (_old.contacts.length < 3) ...List.filled(3 - _old.contacts.length, '||')])
      (TextEditingController(text: c.split('|')[0]), TextEditingController(text: c.split('|').length > 1 ? c.split('|')[1] : ''), TextEditingController(text: c.split('|').length > 2 ? c.split('|')[2] : '')),
  ];

  @override
  void dispose() {
    for (final c in [_name, _med, _all, _cond]) {
      c.dispose();
    }
    for (final r in _contacts) {
      r.$1.dispose();
      r.$2.dispose();
      r.$3.dispose();
    }
    super.dispose();
  }

  Future<void> _pickContact(int i) async {
    final brain = BrainScope.read(context);
    final picked = await pickContact(context, brain.data.contacts);
    if (picked == null) return;
    setState(() {
      _contacts[i].$1.text = picked.name;
      _contacts[i].$2.text = picked.phone;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('জরুরি কার্ড')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              TextField(controller: _name, decoration: InputDecoration(labelText: tr('নাম'))),
              FieldLabel(tr('রক্তের গ্রুপ')),
              ChoiceChips<String>(items: [for (final b in bloodGroups) (b, b), ('', tr('জানি না'))], value: _blood, onChanged: (v) => setState(() => _blood = v)),
              FieldLabel(tr('জরুরি যোগাযোগ')),
              for (final (i, r) in _contacts.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(flex: 4, child: TextField(controller: r.$1, decoration: InputDecoration(hintText: tr('নাম'), isDense: true))),
                    const SizedBox(width: 6),
                    Expanded(flex: 3, child: TextField(controller: r.$3, decoration: InputDecoration(hintText: tr('সম্পর্ক'), isDense: true))),
                    const SizedBox(width: 6),
                    Expanded(flex: 4, child: TextField(controller: r.$2, keyboardType: TextInputType.phone, decoration: InputDecoration(hintText: tr('নম্বর'), isDense: true))),
                    IconButton(tooltip: tr('যোগাযোগ থেকে'), onPressed: () => _pickContact(i), icon: Icon(Icons.contacts_outlined, color: C.green)),
                  ]),
                ),
              FieldLabel(tr('রোগ / অবস্থা')),
              TextField(controller: _cond, decoration: InputDecoration(hintText: tr('যেমন: ডায়াবেটিস, উচ্চ রক্তচাপ'))),
              FieldLabel(tr('নিয়মিত ওষুধ')),
              TextField(controller: _med, decoration: InputDecoration(hintText: tr('যেমন: ইনসুলিন সকাল-রাত'))),
              FieldLabel(tr('অ্যালার্জি')),
              TextField(controller: _all, decoration: InputDecoration(hintText: tr('যেমন: পেনিসিলিন'))),
              const SizedBox(height: 18),
              PrimaryButton(
                label: tr('রাখুন'),
                onPressed: () async {
                  // A new group needs its number and last donation (owner, 28 Oct).
                  if (_blood.isNotEmpty && _blood != _old.blood && !await askBloodDetails(context, _blood)) return;
                  await brain.saveEmergency(_old.copyWith(
                    name: _name.text.trim(),
                    blood: _blood,
                    medicines: _med.text.trim(),
                    allergies: _all.text.trim(),
                    conditions: _cond.text.trim(),
                    contacts: [
                      for (final r in _contacts)
                        if (r.$2.text.trim().isNotEmpty) '${r.$1.text.trim().replaceAll('|', ' ')}|${r.$2.text.trim()}|${r.$3.text.trim().replaceAll('|', ' ')}',
                    ],
                  ));
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Small list of saved contacts to pick one.
Future<Contact?> pickContact(BuildContext context, List<Contact> contacts) => showAppSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: contacts.isEmpty
              ? Padding(padding: const EdgeInsets.all(20), child: Text(tr('যোগাযোগে কোনো নম্বর নেই'), style: body(15)))
              : ListView(shrinkWrap: true, children: [
                  for (final c in [...contacts]..sort((a, b) => a.name.compareTo(b.name)))
                    if (c.phone.isNotEmpty) ListTile(title: Text(c.name), subtitle: Text(c.phone), onTap: () => Navigator.pop(ctx, c)),
                ]),
        ),
      ),
    );


/// Bangladesh's national helplines (fire service moved from 16163 to 102 in 2025).
const emergencyNumbers = [
  ('999', 'জাতীয় জরুরি সেবা', 'পুলিশ, ফায়ার সার্ভিস, অ্যাম্বুলেন্স — এক নম্বরে'),
  ('102', 'ফায়ার সার্ভিস', 'আগুন বা দুর্ঘটনায় সরাসরি'),
  ('109', 'নারী ও শিশু নির্যাতন প্রতিরোধ', 'হয়রানি বা নির্যাতনের শিকার হলে'),
  ('1098', 'শিশু সহায়তা', 'বিপদে পড়া শিশুর জন্য'),
  ('333', 'জাতীয় তথ্য ও সেবা', 'সরকারি তথ্য, বাল্যবিবাহ ও সামাজিক সমস্যা'),
  ('16263', 'স্বাস্থ্য বাতায়ন', 'ডাক্তারের পরামর্শ, ২৪ ঘণ্টা'),
  ('16430', 'সরকারি আইনি সহায়তা', 'বিনামূল্যে আইনি পরামর্শ'),
  ('106', 'দুর্নীতি দমন কমিশন', 'দুর্নীতির অভিযোগ'),
  ('1090', 'দুর্যোগের আগাম বার্তা', 'ঘূর্ণিঝড়, বন্যা, আবহাওয়া'),
];

/// "আমি রক্ত দিতে চাই": the user's own group, the last time they gave, and
/// the day they can give again (a note comes that morning).
class DonorPanel extends StatelessWidget {
  const DonorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final blood = brain.data.emergency.blood;
    final last = DateTime.tryParse(brain.text('blood_last'));
    final next = last == null ? null : DateTime(last.year, last.month + 3, last.day);
    final now = brain.services.now();
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bloodtype_outlined, color: C.rose),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('আমি রক্ত দিতে আগ্রহী'), style: body(15, weight: FontWeight.w600)),
              Text(blood.isEmpty ? tr('উপরে প্রোফাইলে রক্তের গ্রুপ দিন') : trf('আপনার গ্রুপ {0}', [blood]), style: body(12.5, color: C.muted)),
            ]),
          ),
          Switch(value: brain.flag('donor_on'), onChanged: (v) => brain.setPref('donor_on', v)),
        ]),
        if (brain.flag('donor_on')) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: last ?? now, firstDate: DateTime(now.year - 5), lastDate: now);
              if (d != null) await brain.setPref('blood_last', d.toIso8601String());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(last == null ? tr('শেষ কবে রক্ত দিয়েছেন? তারিখ দিন') : trf('শেষ রক্তদান: {0} · বদলান', [fullDate(last)]),
                  style: body(14, weight: FontWeight.w600, color: C.green)),
            ),
          ),
          if (next != null)
            Text(
                next.isAfter(now)
                    ? trf('আবার দিতে পারবেন {0} থেকে ({1}) — সেদিন সকালে মনে করাবো।', [fullDate(next), daysLeftLabel(next, now)])
                    : tr('এখন আবার রক্ত দিতে পারবেন।'),
                style: body(13, color: C.muted2, height: 1.5)),
          const SizedBox(height: 6),
          Text(tr('আশপাশে কারো রক্ত লাগলে অ্যাপের মাধ্যমে খবর পাওয়ার ব্যবস্থা আসছে — শুধু আপনি রাজি থাকলে, আর বারবার বিরক্ত না করে।'),
              style: body(12, color: C.muted, height: 1.5)),
        ],
      ]),
    );
  }
}
