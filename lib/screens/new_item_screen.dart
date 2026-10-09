import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/password.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';
import 'voice_screen.dart';

enum ItemCategory {
  password('পাসওয়ার্ড', C.blue),
  contact('যোগাযোগ', C.purple),
  ledger('ধার-দেনা', C.green),
  note('নোট', C.ochre),
  reminder('রিমাইন্ডার', C.orange);

  const ItemCategory(this.label, this.color);
  final String label;
  final Color color;
}

/// Add something new, or edit an existing password, contact, note or reminder.
class NewItemScreen extends StatefulWidget {
  const NewItemScreen({super.key, this.category, this.presetTitle, this.vault, this.contact, this.note, this.reminder, this.noteCategory});
  final ItemCategory? category;

  /// For a new note: the category to put it in.
  final String? noteCategory;
  final String? presetTitle;
  final VaultItem? vault;
  final Contact? contact;
  final Note? note;
  final Reminder? reminder;

  bool get editing => vault != null || contact != null || note != null || reminder != null;

  @override
  State<NewItemScreen> createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final _form = GlobalKey<FormState>();
  late ItemCategory _cat;

  // Shared text fields (re-used by whichever form is showing).
  final _a = TextEditingController(); // name / title
  final _b = TextEditingController(); // address / phone / body
  final _c = TextEditingController(); // username / email
  final _d = TextEditingController(); // email
  final _pw = TextEditingController();
  final _noteText = TextEditingController();
  final _noteCat = TextEditingController(text: defaultNoteCategory);
  bool _pwVisible = false;

  VaultKind _vaultKind = VaultKind.website;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  int _daysBefore = 1;
  Repeat _repeat = Repeat.none;
  String? _vaultLink;

  @override
  void initState() {
    super.initState();
    final w = widget;
    _cat = w.vault != null
        ? ItemCategory.password
        : w.contact != null
            ? ItemCategory.contact
            : w.note != null
                ? ItemCategory.note
                : w.reminder != null
                    ? ItemCategory.reminder
                    : (w.category ?? ItemCategory.password);
    final now = BrainScope.read(context).services.now();
    _date = dayOnly(now).add(const Duration(days: 7));
    _a.text = w.presetTitle ?? '';
    if (w.noteCategory != null) _noteCat.text = w.noteCategory!;
    if (w.vault != null) {
      final v = w.vault!;
      _a.text = v.name;
      _vaultKind = v.kind;
      _b.text = v.address;
      _c.text = v.username;
      _d.text = v.email;
      _pw.text = v.password;
      _noteText.text = v.note;
    } else if (w.contact != null) {
      final c = w.contact!;
      _a.text = c.name;
      _b.text = c.phone;
      _c.text = c.email;
      _noteText.text = c.note;
    } else if (w.note != null) {
      _a.text = w.note!.title;
      _b.text = w.note!.body;
      _noteCat.text = w.note!.category;
    } else if (w.reminder != null) {
      final r = w.reminder!;
      _a.text = r.title;
      _date = r.date;
      _time = TimeOfDay(hour: r.hour, minute: r.minute);
      _daysBefore = r.daysBefore;
      _repeat = r.repeat;
      _noteText.text = r.note;
      _vaultLink = r.vaultId;
    }
    _pw.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_a, _b, _c, _d, _pw, _noteText, _noteCat]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'এটা লিখুন' : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final brain = BrainScope.read(context);
    final now = brain.services.now();
    String done;
    switch (_cat) {
      case ItemCategory.password:
        await brain.saveVault(VaultItem(
          id: widget.vault?.id,
          name: _a.text.trim(),
          kind: _vaultKind,
          address: _b.text.trim(),
          username: _c.text.trim(),
          email: _d.text.trim(),
          password: _pw.text,
          note: _noteText.text.trim(),
          updatedAt: now,
        ));
        brain.markVerified();
        done = 'ভল্টে রাখা হয়েছে';
      case ItemCategory.contact:
        await brain.saveContact(Contact(
          id: widget.contact?.id,
          name: _a.text.trim(),
          phone: asciiDigits(_b.text.trim()),
          email: _c.text.trim(),
          note: _noteText.text.trim(),
          updatedAt: now,
        ));
        done = 'যোগাযোগ রাখা হয়েছে';
      case ItemCategory.note:
        final cat = _noteCat.text.trim().isEmpty ? defaultNoteCategory : _noteCat.text.trim();
        await brain.saveNote(Note(id: widget.note?.id, title: _a.text.trim(), body: _b.text.trim(), category: cat, updatedAt: now));
        done = 'নোট রাখা হয়েছে';
      case ItemCategory.reminder:
        await brain.saveReminder(Reminder(
          id: widget.reminder?.id,
          title: _a.text.trim(),
          date: _date,
          hour: _time.hour,
          minute: _time.minute,
          daysBefore: _daysBefore,
          repeat: _repeat,
          note: _noteText.text.trim(),
          vaultId: _vaultLink,
        ));
        done = 'রিমাইন্ডার রাখা হয়েছে';
      case ItemCategory.ledger:
        return;
    }
    if (!mounted) return;
    toast(context, done);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final brain = BrainScope.read(context);
    final ok = await confirmDialog(context, title: 'মুছে ফেলবেন?', text: 'এটা আর ফেরত আনা যাবে না (ব্যাকআপ থেকে ছাড়া)।', yes: 'মুছুন', danger: true);
    if (!ok) return;
    if (widget.vault != null) await brain.deleteVault(widget.vault!.id);
    if (widget.contact != null) await brain.deleteContact(widget.contact!.id);
    if (widget.note != null) await brain.deleteNote(widget.note!.id);
    if (widget.reminder != null) await brain.deleteReminder(widget.reminder!.id);
    if (!mounted) return;
    toast(context, 'মুছে ফেলা হয়েছে');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.editing ? '${_cat.label} বদলান' : 'নতুন তথ্য';
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              TopBar(
                title: title,
                trailing: [
                  if (widget.editing)
                    RoundIconButton(icon: Icons.delete_outline_rounded, tooltip: 'মুছে ফেলুন', onPressed: _delete)
                  else
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VoiceScreen())),
                      style: TextButton.styleFrom(backgroundColor: C.greenTint, foregroundColor: C.greenDark, minimumSize: const Size(44, 40)),
                      icon: const Icon(Icons.mic_none_rounded, size: 18),
                      label: Text('বলে যোগ', style: body(14, weight: FontWeight.w600, color: C.greenDark)),
                    ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    if (!widget.editing) ...[
                      Text('বিভাগ', style: body(14, weight: FontWeight.w600, color: C.muted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (final c in ItemCategory.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: _CatButton(cat: c, selected: c == _cat, onTap: () => setState(() => _cat = c)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 18),
                    ],
                    ...switch (_cat) {
                      ItemCategory.password => _passwordForm(),
                      ItemCategory.contact => _contactForm(),
                      ItemCategory.ledger => _ledgerLink(),
                      ItemCategory.note => _noteForm(),
                      ItemCategory.reminder => _reminderForm(),
                    },
                  ],
                ),
              ),
              if (_cat != ItemCategory.ledger)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: PrimaryButton(label: 'সেভ করুন', icon: Icons.check_rounded, onPressed: _save),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const _gap = SizedBox(height: 12);

  List<Widget> _passwordForm() {
    final s = strengthOf(_pw.text);
    final sColor = switch (s) {
      Strength.strong => C.green,
      Strength.fair => C.ochre,
      _ => C.orange,
    };
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in VaultKind.values)
          ChoiceChip(
            label: Text(k.label, style: body(14, color: k == _vaultKind ? Colors.white : C.ink, weight: k == _vaultKind ? FontWeight.w600 : FontWeight.w400)),
            selected: k == _vaultKind,
            showCheckmark: false,
            selectedColor: C.ink,
            backgroundColor: C.surface,
            side: BorderSide(color: k == _vaultKind ? C.ink : C.border),
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() => _vaultKind = k),
          ),
      ]),
      const SizedBox(height: 14),
      TextFormField(
        controller: _a,
        decoration: InputDecoration(labelText: _vaultKind == VaultKind.wifi ? 'নাম (যেমন: বাসার Wi-Fi)' : 'ওয়েবসাইট বা অ্যাপের নাম'),
        validator: _required,
      ),
      _gap,
      TextFormField(
        controller: _b,
        keyboardType: _vaultKind == VaultKind.wifi ? TextInputType.text : TextInputType.url,
        decoration: InputDecoration(labelText: _vaultKind == VaultKind.wifi ? 'নেটওয়ার্কের নাম (SSID)' : 'ঠিকানা (ঐচ্ছিক)'),
      ),
      if (_vaultKind != VaultKind.wifi) ...[
        _gap,
        TextFormField(controller: _c, decoration: const InputDecoration(labelText: 'ইউজারনেম')),
        _gap,
        TextFormField(controller: _d, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ইমেইল (ঐচ্ছিক)')),
      ],
      _gap,
      TextFormField(
        controller: _pw,
        obscureText: !_pwVisible,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: _vaultKind == VaultKind.bank ? 'পাসওয়ার্ড বা PIN' : 'পাসওয়ার্ড',
          suffixIcon: IconButton(
            tooltip: _pwVisible ? 'লুকান' : 'দেখুন',
            onPressed: () => setState(() => _pwVisible = !_pwVisible),
            icon: Icon(_pwVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (s != Strength.empty)
        Row(children: [
          for (var i = 1; i <= 3; i++)
            Container(
              width: 22,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(color: i <= s.level ? sColor : C.line, borderRadius: BorderRadius.circular(3)),
            ),
          const SizedBox(width: 6),
          Flexible(child: Text(s.label, style: body(13, weight: FontWeight.w600, color: sColor))),
        ]),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => setState(() {
            _pw.text = generatePassword();
            _pwVisible = true;
          }),
          icon: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: Text('শক্ত পাসওয়ার্ড বানান', style: body(14, weight: FontWeight.w600, color: C.green)),
        ),
      ),
      _gap,
      TextFormField(controller: _noteText, maxLines: 2, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)', hintText: 'যেমন: ২-ধাপের যাচাই চালু')),
      const SizedBox(height: 14),
      const InfoBanner(text: 'ফোনের সুরক্ষিত চাবি দিয়ে এনক্রিপ্ট করে রাখা হবে। খুলতে আঙুলের ছাপ বা PIN লাগবে।'),
    ];
  }

  List<Widget> _contactForm() => [
        TextFormField(controller: _a, decoration: const InputDecoration(labelText: 'নাম', hintText: 'যেমন: ইলেকট্রিশিয়ান করিম'), validator: _required),
        _gap,
        TextFormField(controller: _b, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'মোবাইল নম্বর')),
        _gap,
        TextFormField(controller: _c, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ইমেইল (ঐচ্ছিক)')),
        _gap,
        TextFormField(controller: _noteText, maxLines: 3, decoration: const InputDecoration(labelText: 'নোট', hintText: 'কোথায় পরিচয়, কী কাজে লাগে')),
      ];

  List<Widget> _ledgerLink() => [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Text('ধার-দেনার জন্য আলাদা ফর্ম আছে — কাকে দিলেন, কার থেকে নিলেন, আর এখন কত বাকি, সব হিসাব করে দেখায়।', style: body(16, height: 1.5)),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'ধার-দেনার ফর্ম খুলুন',
              height: 48,
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LedgerFormScreen())),
            ),
          ]),
        ),
      ];

  List<Widget> _noteForm() => [
        TextFormField(controller: _a, decoration: const InputDecoration(labelText: 'শিরোনাম', hintText: 'যেমন: বাজারের তালিকা'), validator: _required),
        _gap,
        TextFormField(controller: _noteCat, decoration: const InputDecoration(labelText: 'বিভাগ', hintText: 'যেমন: নোট, যানবাহন, স্বাস্থ্য')),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in {defaultNoteCategory, ...BrainScope.of(context).data.noteCategories})
            ActionChip(
              label: Text(c, style: body(13)),
              backgroundColor: _noteCat.text.trim() == c ? C.ochreTint : C.surface,
              side: const BorderSide(color: C.border),
              onPressed: () => setState(() => _noteCat.text = c),
            ),
        ]),
        _gap,
        TextFormField(
          controller: _b,
          minLines: 6,
          maxLines: 14,
          decoration: const InputDecoration(labelText: 'লেখা', hintText: 'যা মনে রাখতে চান…', alignLabelWithHint: true),
        ),
      ];

  List<Widget> _reminderForm() {
    final brain = BrainScope.of(context);
    final vault = [...brain.data.vault]..sort((a, b) => a.name.compareTo(b.name));
    return [
      TextFormField(controller: _a, decoration: const InputDecoration(labelText: 'কী মনে করাতে হবে', hintText: 'যেমন: ডোমেইন রিনিউ'), validator: _required),
      _gap,
      Row(children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final now = brain.services.now();
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 30));
              if (d != null) setState(() => _date = d);
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'তারিখ'), child: Text(fullDate(_date), style: body(16), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'সময়'), child: Text(bnTime(_time.hour, _time.minute), style: body(16))),
          ),
        ),
      ]),
      _gap,
      DropdownButtonFormField<int>(
        initialValue: _daysBefore,
        decoration: const InputDecoration(labelText: 'কত আগে মনে করাবে'),
        items: [
          for (final d in const [0, 1, 2, 3, 7, 15, 30])
            DropdownMenuItem(value: d, child: Text(d == 0 ? 'সেদিনই' : '${bnDigits(d)} দিন আগে', style: body(16))),
        ],
        onChanged: (v) => setState(() => _daysBefore = v ?? 1),
      ),
      _gap,
      Text('বারবার?', style: body(14, weight: FontWeight.w600, color: C.muted)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (final r in Repeat.values)
          ChoiceChip(
            label: Text(r.label, style: body(14, color: r == _repeat ? Colors.white : C.ink)),
            selected: r == _repeat,
            showCheckmark: false,
            selectedColor: C.ink,
            backgroundColor: C.surface,
            side: BorderSide(color: r == _repeat ? C.ink : C.border),
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() => _repeat = r),
          ),
      ]),
      _gap,
      TextFormField(controller: _noteText, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
      if (vault.isNotEmpty) ...[
        _gap,
        DropdownButtonFormField<String?>(
          initialValue: vault.any((v) => v.id == _vaultLink) ? _vaultLink : null,
          decoration: const InputDecoration(labelText: 'সাথে যুক্ত লগইন (ঐচ্ছিক)'),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('কিছু না', style: body(16))),
            for (final v in vault) DropdownMenuItem<String?>(value: v.id, child: Text(v.name, style: body(16))),
          ],
          onChanged: (v) => setState(() => _vaultLink = v),
        ),
      ],
    ];
  }
}

class _CatButton extends StatelessWidget {
  const _CatButton({required this.cat, required this.selected, required this.onTap});
  final ItemCategory cat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? C.surface : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? cat.color : C.border, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle)),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(cat.label, style: body(12, weight: FontWeight.w600, height: 1.2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
