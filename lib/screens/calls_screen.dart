import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart' show showPhone;
import '../logic/parser.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_shell.dart';
import 'new_item_screen.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/note_parts.dart' show openMap;

/// যোগাযোগ: call, SMS or WhatsApp anyone saved, or a number typed in.
/// The phone's own app opens ready; the user presses call or send there.
/// A tap on a person opens their card (all ways to reach them, edit).
class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  /// Which of the three new looks (owner picks one, 22 Nov): 1 ফোনবুক,
  /// 2 কার্ড, 3 গ্রিড.
  static int look = 1;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

/// A soft colour pair per person, the same every time for the same name.
(Color, Color) personColors(String name) {
  final pairs = [
    (C.purple, C.purpleTint),
    (C.blue, C.blueTint),
    (C.teal, C.tealTint),
    (C.ochre, C.ochreTint),
    (C.rose, C.roseTint),
    (C.green, C.greenTint),
  ];
  var h = 0;
  for (final r in name.trim().runes) {
    h = (h * 31 + r) & 0x7fffffff;
  }
  return pairs[h % pairs.length];
}

/// The letter a person is filed under: "রহিম" → "র", "rahim" → "R".
String letterOf(String name) {
  final t = name.trim();
  if (t.isEmpty) return '#';
  final first = String.fromCharCode(t.runes.first);
  if (RegExp(r'[A-Za-z]').hasMatch(first)) return first.toUpperCase();
  if (RegExp(r'[0-9০-৯+]').hasMatch(first)) return '#';
  return first;
}

/// WhatsApp green, lighter at night so it reads on the dark ground.
Color get _wa => C.mix >= 0.5 ? const Color(0xFF5FD38D) : const Color(0xFF128C4A);

Future<void> _reach(BuildContext context, Via via, String phone) async {
  final brain = BrainScope.read(context);
  final ok = await brain.services.launcher.open(via, phone);
  if (!ok && context.mounted) toast(context, tr('এই ফোনে এটা খোলার মতো অ্যাপ পাওয়া গেল না'));
}

void _edit(BuildContext context, Contact c) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(contact: c)));

class _CallsScreenState extends State<CallsScreen> {
  String _q = '';

  Widget _actions(String phone) => Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAction(icon: Icons.call_rounded, tooltip: tr('ফোন দিন'), size: 38, onPressed: () => _reach(context, Via.call, phone)),
        const SizedBox(width: 6),
        CircleAction(icon: Icons.sms_outlined, tooltip: tr('মেসেজ (SMS)'), size: 38, fg: C.blue, bg: C.blueTint, onPressed: () => _reach(context, Via.sms, phone)),
        const SizedBox(width: 6),
        CircleAction(icon: Icons.chat_outlined, tooltip: 'WhatsApp', size: 38, fg: _wa, bg: C.waTint, onPressed: () => _reach(context, Via.whatsapp, phone)),
      ]);

  void _addNew() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.contact)));

  Widget _search({bool onDark = false}) => TextField(
        key: const Key('contacts-search'),
        textCapitalization: TextCapitalization.sentences,
        onChanged: (v) => setState(() => _q = v),
        style: onDark ? body(15, color: Colors.white) : null,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: onDark ? Colors.white70 : C.muted),
          hintText: tr('নাম খুঁজুন, বা নম্বর লিখুন'),
          hintStyle: onDark ? body(14.5, color: Colors.white60) : null,
          filled: true,
          fillColor: onDark ? Colors.white.withValues(alpha: 0.12) : C.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: onDark ? Colors.transparent : C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: onDark ? Colors.transparent : C.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: onDark ? Colors.white54 : C.green)),
        ),
      );

  /// A number typed in the search: reach it without saving.
  Widget _typedRow(String typed) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
          child: ListRow(
            leading: CircleAvatar(radius: 20, backgroundColor: C.greenTint, child: Icon(Icons.dialpad_rounded, color: C.green, size: 20)),
            title: bnDigits(typed),
            subtitle: tr('এই নম্বরে'),
            trailing: _actions(typed),
          ),
        ),
      );

  Widget _empty() => EmptyState(
        icon: Icons.contact_phone_outlined,
        title: tr('কোনো নম্বর রাখা নেই'),
        text: tr('ফোনের সব নম্বর এক বারে আনুন, অথবা বলুন “রহিমের নম্বর ০১৭… রাখো”।'),
        action: tr('ফোনবুক থেকে সব নম্বর আনুন'),
        onAction: () => importFromPhone(context),
      );

  /// The small "bring from phone book" line (not a big button any more).
  Widget _importLine({bool onDark = false}) => InkWell(
        key: const Key('contacts-import'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => importFromPhone(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.download_rounded, size: 17, color: onDark ? const Color(0xFF79DCF6) : C.green),
            const SizedBox(width: 5),
            Text(tr('ফোনবুক থেকে আনুন'), style: body(13, weight: FontWeight.w600, color: onDark ? const Color(0xFF79DCF6) : C.green)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = normalize(_q);
    final typed = findPhone(_q);
    final all = [...brain.data.contacts]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final list = all.where((c) => q.isEmpty || normalize('${c.name} ${c.phone} ${asciiDigits(c.phone)} ${c.note}').contains(q)).toList();
    return Scaffold(
      body: switch (CallsScreen.look) {
        2 => _cards(all, list, typed),
        3 => _grid(all, list, typed),
        _ => _book(all, list, typed),
      },
      floatingActionButton: CallsScreen.look == 2
          ? null
          : FloatingActionButton(
              key: const Key('contacts-add'),
              tooltip: tr('নতুন নম্বর রাখুন'),
              backgroundColor: C.green,
              foregroundColor: C.onAccent,
              shape: const CircleBorder(),
              onPressed: _addNew,
              child: const Icon(Icons.person_add_alt_1_rounded),
            ),
    );
  }

  // ───── 1 ফোনবুক: big title, round search, people under their letter ─────

  Widget _book(List<Contact> all, List<Contact> list, String? typed) {
    final items = <Widget>[];
    String? last;
    for (var i = 0; i < list.length; i++) {
      final c = list[i];
      final l = letterOf(c.name);
      if (l != last) {
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(6, items.isEmpty ? 4 : 14, 0, 6),
          child: Text(l, style: display(15, weight: 700, color: C.green)),
        ));
        last = l;
      }
      final next = i + 1 < list.length ? letterOf(list[i + 1].name) : null;
      final top = items.last is Padding, bottom = next != l;
      items.add(_bookRow(c, top: top, bottom: bottom));
    }
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(title: '', trailing: [
          const PdfButton({ReportPart.contacts}),
          IconButton(tooltip: tr('মুখে বলুন'), onPressed: () => openVoice(context), icon: Icon(Icons.mic_none_rounded, color: C.green)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 16, 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('যোগাযোগ'), style: display(28, weight: 700, height: 1.2)),
                Text(trf('{0} জন', [bnDigits(all.length)]), style: body(13.5, color: C.muted)),
              ]),
            ),
            _importLine(),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 6), child: _search()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
            children: [
              if (typed != null) _typedRow(typed),
              if (all.isEmpty) _empty() else if (list.isEmpty && typed == null) Text(tr('কিছু মেলেনি।'), style: body(14, color: C.muted)),
              ...items,
            ],
          ),
        ),
      ]),
    );
  }

  Widget _bookRow(Contact c, {required bool top, required bool bottom}) {
    final (fg, bg) = personColors(c.name);
    return Material(
      color: C.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(top ? 18 : 0), bottom: Radius.circular(bottom ? 18 : 0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openContactCard(context, c),
        child: Container(
          decoration: BoxDecoration(border: bottom ? null : Border(bottom: BorderSide(color: C.line2))),
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          child: Row(children: [
            Avatar(name: c.name, fg: fg, bg: bg, size: 44),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w600)),
                if (c.note.trim().isNotEmpty || c.phone.isNotEmpty)
                  Text(c.note.trim().isNotEmpty ? c.note.trim() : showPhone(c.phone), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              ]),
            ),
            if (c.phone.isNotEmpty) CircleAction(icon: Icons.call_rounded, tooltip: tr('ফোন দিন'), size: 40, onPressed: () => _reach(context, Via.call, c.phone)),
          ]),
        ),
      ),
    );
  }

  // ───── 2 কার্ড: night-blue head with the search, a card per person ─────

  Widget _cards(List<Contact> all, List<Contact> list, String? typed) {
    const head = Color(0xFF121A33);
    return Column(children: [
      Container(
        color: head,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(tooltip: tr('ফিরে যান'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left_rounded, size: 30, color: Colors.white)),
                const Spacer(),
                IconButton(tooltip: tr('মুখে বলুন'), onPressed: () => openVoice(context), icon: const Icon(Icons.mic_none_rounded, color: Color(0xFF79DCF6))),
                IconButton(
                    key: const Key('contacts-add'), tooltip: tr('নতুন নম্বর রাখুন'), onPressed: _addNew, icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white)),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('যোগাযোগ'), style: display(27, weight: 700, color: Colors.white, height: 1.2)),
                      Text(trf('{0} জন · এক ছোঁয়ায় কল, মেসেজ', [bnDigits(all.length)]), style: body(13, color: Colors.white70)),
                    ]),
                  ),
                  _importLine(onDark: true),
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(12, 14, 0, 0), child: _search(onDark: true)),
            ]),
          ),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: list.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Column(children: [
                if (typed != null) _typedRow(typed),
                if (all.isEmpty) _empty() else if (list.isEmpty && typed == null) Text(tr('কিছু মেলেনি।'), style: body(14, color: C.muted)),
              ]);
            }
            return _card(list[i - 1]);
          },
        ),
      ),
    ]);
  }

  Widget _card(Contact c) {
    final (fg, bg) = personColors(c.name);
    Widget btn(IconData icon, String label, Color f, Color b, Via via) => Expanded(
          child: Material(
            color: b,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _reach(context, via, c.phone),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 17, color: f),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: f))),
                ]),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: C.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openContactCard(context, c),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(name: c.name, fg: fg, bg: bg, size: 46, square: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w600)),
                    if (c.phone.isNotEmpty) Text(showPhone(c.phone), style: body(13, color: C.muted)),
                  ]),
                ),
                if (c.note.trim().isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                    child: Text(c.note.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, weight: FontWeight.w600, color: fg)),
                  ),
              ]),
              if (c.phone.isNotEmpty) ...[
                const SizedBox(height: 11),
                Row(children: [
                  btn(Icons.call_rounded, tr('কল'), C.green, C.greenTint, Via.call),
                  const SizedBox(width: 7),
                  btn(Icons.sms_outlined, tr('মেসেজ দিন'), C.blue, C.blueTint, Via.sms),
                  const SizedBox(width: 7),
                  btn(Icons.chat_outlined, 'WhatsApp', _wa, C.waTint, Via.whatsapp),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ───── 3 গ্রিড: two tiles a row, big face, call and WhatsApp ─────

  Widget _grid(List<Contact> all, List<Contact> list, String? typed) => SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TopBar(title: tr('যোগাযোগ'), trailing: [
            const PdfButton({ReportPart.contacts}),
            IconButton(tooltip: tr('মুখে বলুন'), onPressed: () => openVoice(context), icon: Icon(Icons.mic_none_rounded, color: C.green)),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 4), child: _search()),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 2, 14, 0),
            child: Row(children: [
              Expanded(child: Text(trf('{0} জন', [bnDigits(all.length)]), style: body(13.5, weight: FontWeight.w500, color: C.muted))),
              _importLine(),
            ]),
          ),
          Expanded(
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(children: [
                    if (typed != null) _typedRow(typed),
                    if (all.isEmpty) _empty() else if (list.isEmpty && typed == null) Text(tr('কিছু মেলেনি।'), style: body(14, color: C.muted)),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 172),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _tile(list[i]),
                ),
              ),
            ]),
          ),
        ]),
      );

  Widget _tile(Contact c) {
    final (fg, bg) = personColors(c.name);
    return Material(
      color: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: C.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openContactCard(context, c),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(children: [
            Avatar(name: c.name, fg: fg, bg: bg, size: 52),
            const SizedBox(height: 8),
            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w600)),
            Text(c.note.trim().isNotEmpty ? c.note.trim() : (c.phone.isEmpty ? ' ' : showPhone(c.phone)),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
            const Spacer(),
            if (c.phone.isNotEmpty)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAction(icon: Icons.call_rounded, tooltip: tr('ফোন দিন'), size: 36, onPressed: () => _reach(context, Via.call, c.phone)),
                const SizedBox(width: 10),
                CircleAction(icon: Icons.chat_outlined, tooltip: 'WhatsApp', size: 36, fg: _wa, bg: C.waTint, onPressed: () => _reach(context, Via.whatsapp, c.phone)),
              ]),
          ]),
        ),
      ),
    );
  }
}

/// A person's card: big face, every way to reach them, and edit.
Future<void> openContactCard(BuildContext context, Contact c) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final brain = BrainScope.read(ctx);
        final (fg, bg) = personColors(c.name);
        Widget act(IconData icon, String label, Color f, Color b, VoidCallback onTap) => Expanded(
              child: Column(children: [
                CircleAction(icon: icon, tooltip: label, size: 52, fg: f, bg: b, onPressed: onTap),
                const SizedBox(height: 6),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, weight: FontWeight.w500, color: C.muted2)),
              ]),
            );
        Widget line(IconData icon, String text, {Widget? trailing}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(icon, size: 20, color: C.muted),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: body(14.5))),
                if (trailing != null) trailing,
              ]),
            );
        return Padding(
          key: const Key('contact-card'),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Avatar(name: c.name, fg: fg, bg: bg, size: 72),
            const SizedBox(height: 10),
            Text(c.name, textAlign: TextAlign.center, style: display(22, weight: 700)),
            if (c.phone.isNotEmpty) Text(showPhone(c.phone), style: body(15, color: C.muted)),
            const SizedBox(height: 18),
            if (c.phone.isNotEmpty)
              Row(children: [
                act(Icons.call_rounded, tr('কল'), C.green, C.greenTint, () => _reach(ctx, Via.call, c.phone)),
                act(Icons.sms_outlined, tr('মেসেজ দিন'), C.blue, C.blueTint, () => _reach(ctx, Via.sms, c.phone)),
                act(Icons.chat_outlined, 'WhatsApp', _wa, C.waTint, () => _reach(ctx, Via.whatsapp, c.phone)),
                act(Icons.copy_rounded, tr('কপি'), C.muted2, C.surface2, () async {
                  await brain.services.files.copy(c.phone);
                  if (ctx.mounted) toast(ctx, tr('নম্বর কপি হয়েছে'));
                }),
              ]),
            if (c.note.trim().isNotEmpty || c.email.isNotEmpty || c.address.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  if (c.note.trim().isNotEmpty) line(Icons.sticky_note_2_outlined, c.note.trim()),
                  if (c.email.isNotEmpty) line(Icons.mail_outline_rounded, c.email),
                  if (c.address.isNotEmpty)
                    line(Icons.place_outlined, c.address,
                        trailing: IconButton(tooltip: tr('ম্যাপে দেখুন'), onPressed: () => openMap(ctx, c.address), icon: Icon(Icons.map_outlined, color: C.green, size: 20))),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: SecondaryButton(
                  label: tr('শেয়ার'),
                  icon: Icons.share_outlined,
                  onPressed: () => brain.services.files.shareText([c.name, if (c.phone.isNotEmpty) c.phone, if (c.email.isNotEmpty) c.email].join('\n')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: tr('এডিট করুন'),
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _edit(context, c);
                  },
                ),
              ),
            ]),
          ]),
        );
      },
    );

/// "ফোনবুক থেকে আনুন": every number in the phone, without repeats.
Future<void> importFromPhone(BuildContext context) async {
  final brain = BrainScope.read(context);
  final r = await brain.importPhonebook();
  if (!context.mounted) return;
  if (r == null) {
    toast(context, tr('ফোনবুক পড়ার অনুমতি দেওয়া হয়নি। আবার চাপলে অনুমতি চাইব।'));
    return;
  }
  final (added, skipped) = r;
  toast(
    context,
    added == 0
        ? trf('নতুন কোনো নম্বর পাওয়া যায়নি{0}', [skipped > 0 ? ' — ${bnDigits(skipped)}টি আগেই ছিল' : ''])
        : trf('{0} জনের নম্বর আনা হলো{1}', [bnDigits(added), skipped > 0 ? ' · ${bnDigits(skipped)}টি একই নম্বর বাদ দিলাম' : '']),
  );
}

/// Choose someone from যোগাযোগ (with search), or bring the phone book first.
Future<Contact?> pickContact(BuildContext context) async {
  final brain = BrainScope.read(context);
  if (!brain.data.contacts.any((c) => c.phone.trim().isNotEmpty)) {
    final ok = await confirmDialog(context,
        title: tr('ফোনবুক থেকে আনব?'), text: tr('যোগাযোগে এখনো কোনো নম্বর নেই। ফোনের সব নম্বর এক বারে নিয়ে আসি? একই নম্বর দুবার আসবে না।'), yes: tr('আনুন'));
    if (!ok || !context.mounted) return null;
    await importFromPhone(context);
    if (!context.mounted || !brain.data.contacts.any((c) => c.phone.trim().isNotEmpty)) return null;
  }
  return showAppSheet<Contact>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ContactPicker(),
  );
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker();

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = normalize(_q);
    final list = ([...brain.data.contacts.where((c) => c.phone.trim().isNotEmpty)]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
        .where((c) => q.isEmpty || normalize('${c.name} ${asciiDigits(c.phone)}').contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(textCapitalization: TextCapitalization.sentences, 
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: tr('নাম বা নম্বর খুঁজুন')),
          ),
        ),
        ListTile(
          leading: Icon(Icons.download_rounded, color: C.green),
          title: Text(tr('ফোনবুক থেকে নতুন নম্বর আনুন'), style: body(15, weight: FontWeight.w600, color: C.green)),
          onTap: () => importFromPhone(context),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => ListTile(
              leading: Avatar(name: list[i].name, size: 36, fg: C.purple, bg: C.purpleTint),
              title: Text(list[i].name, style: body(15, weight: FontWeight.w600)),
              subtitle: Text(showPhone(list[i].phone), style: body(13, color: C.muted)),
              onTap: () => Navigator.pop(context, list[i]),
            ),
          ),
        ),
      ]),
    );
  }
}
