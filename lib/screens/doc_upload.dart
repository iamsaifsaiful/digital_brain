import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../services/files.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'docs_screen.dart';

/// What the user says about a photo, a group of photos or a file while
/// keeping it, so the assistant can find it later ("বিয়ের ছবিগুলো দেখাও").
class DocInfo {
  const DocInfo(this.doc, this.tags, {this.sameForRest = false});

  /// Name, folder, description, people, place and date (no files yet).
  final Doc doc;
  final List<String> tags;

  /// "বাকিগুলোতেও একই তথ্য" while keeping photos one by one.
  final bool sameForRest;
}

/// Adds photos or files: one or many. Many can be kept together as one
/// group or each on its own; every group (or each one) gets a name, a
/// folder and a few words about it.
Future<void> addDocuments(BuildContext context, {required int source, String? folder, Doc? into, List<PickedDoc>? shared}) async {
  final brain = BrainScope.read(context);
  final shrink = await brain.services.lock.keys.read('doc_shrink') != 'false';
  final files = brain.services.files;
  var picked = shared ??
      switch (source) {
        0 => [if (await files.pickPhoto(camera: true, shrink: shrink) case final p?) p],
        1 => await files.pickPhotos(shrink: shrink),
        _ => await files.pickDocuments(),
      };
  if (picked.isEmpty || !context.mounted) return;
  final big = picked.where((f) => f.bytes.length > 25 * 1024 * 1024).toList();
  if (big.isNotEmpty) {
    toast(context, trf('ফাইলটা অনেক বড় ({0}) — ২৫ MB পর্যন্ত রাখা যায়', [sizeText(big.first.bytes.length)]));
    picked = [for (final f in picked) if (f.bytes.length <= 25 * 1024 * 1024) f];
    if (picked.isEmpty) return;
  }

  // More pages for a document that is open.
  if (into != null) {
    await brain.addDocGroup(picked, into);
    if (context.mounted) toast(context, trf('{0}টা পাতা যোগ হলো', [bnDigits(picked.length)]));
    return;
  }

  var together = true;
  if (picked.length > 1) {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(trf('{0}টা বেছে নিয়েছেন — কীভাবে রাখবো?', [bnDigits(picked.length)]), style: display(18)),
          ),
          ListTile(
            leading: Icon(Icons.collections_outlined, color: C.green),
            title: Text(tr('সবগুলো এক সাথে, একটা গ্রুপে'), style: body(16, weight: FontWeight.w600)),
            subtitle: Text(tr('যেমন: বিয়ের ছবি, জমির দলিলের সব পাতা'), style: body(13, color: C.muted)),
            onTap: () => Navigator.pop(ctx, true),
          ),
          ListTile(
            leading: Icon(Icons.grid_view_rounded, color: C.green),
            title: Text(tr('প্রতিটা আলাদা'), style: body(16, weight: FontWeight.w600)),
            subtitle: Text(tr('যেমন: NID, পাসপোর্ট আর লাইসেন্স একসাথে তুলেছেন'), style: body(13, color: C.muted)),
            onTap: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;
    together = choice;
  }

  final made = <Doc>[];
  if (together) {
    final info = await askDocInfo(context, picked, folder: folder);
    if (info == null || !context.mounted) return;
    final d = await brain.addDocGroup(picked, info.doc);
    if (info.tags.isNotEmpty) await brain.setTags('doc:${d.id}', info.tags);
    made.add(d);
  } else {
    DocInfo? same;
    for (var i = 0; i < picked.length; i++) {
      if (!context.mounted) return;
      var info = same;
      if (info == null) {
        info = await askDocInfo(context, [picked[i]], folder: folder, index: i, of: picked.length);
        if (info == null) break;
        if (info.sameForRest) same = info;
      }
      final title = same != null && picked.length > 1 ? '${info.doc.title} ${bnDigits(i + 1)}' : info.doc.title;
      final d = await brain.addDocGroup([picked[i]], Doc(title: title, folder: info.doc.folder, about: info.doc.about, people: info.doc.people, place: info.doc.place, taken: info.doc.taken));
      if (info.tags.isNotEmpty) await brain.setTags('doc:${d.id}', info.tags);
      made.add(d);
    }
  }
  if (made.isEmpty || !context.mounted) return;
  final count = made.fold<int>(0, (a, d) => a + d.files.length);
  toast(context, made.length == 1 ? trf('“{0}” রাখা হলো · {1}টা', [made.first.title, bnDigits(count)]) : trf('{0}টা ডকুমেন্ট রাখা হলো', [bnDigits(made.length)]));
  if (made.length == 1) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocScreen(id: made.first.id, unlocked: true)));
  }
}

/// The form shown while keeping photos or files.
Future<DocInfo?> askDocInfo(BuildContext context, List<PickedDoc> files, {String? folder, int index = 0, int of = 1, Doc? edit}) =>
    showModalBottomSheet<DocInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DocInfoSheet(files: files, folder: folder, index: index, of: of, edit: edit),
    );

class _DocInfoSheet extends StatefulWidget {
  const _DocInfoSheet({required this.files, this.folder, this.index = 0, this.of = 1, this.edit});
  final List<PickedDoc> files;
  final String? folder;
  final int index;
  final int of;
  final Doc? edit;

  @override
  State<_DocInfoSheet> createState() => _DocInfoSheetState();
}

class _DocInfoSheetState extends State<_DocInfoSheet> {
  late final _title = TextEditingController(text: widget.edit?.title ?? '');
  late final _about = TextEditingController(text: widget.edit?.about ?? '');
  late final _people = TextEditingController(text: widget.edit?.people ?? '');
  late final _place = TextEditingController(text: widget.edit?.place ?? '');
  final _tags = TextEditingController();
  late String _folder = widget.edit?.folder ?? widget.folder ?? 'অন্যান্য';
  late DateTime? _taken = widget.edit?.taken;
  bool _same = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) _tags.text = BrainScope.read(context).tagsOf('doc:${e.id}').join(', ');
  }

  @override
  void dispose() {
    for (final c in [_title, _about, _people, _place, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    final title = _title.text.trim().isEmpty ? tr(_folder) : _title.text.trim();
    final base = widget.edit ?? Doc(title: title, folder: _folder);
    final doc = base.copyWith(
      title: title,
      folder: _folder,
      about: _about.text.trim(),
      people: _people.text.trim(),
      place: _place.text.trim(),
      taken: _taken,
      clearTaken: _taken == null,
    );
    final tags = [for (final t in _tags.text.split(RegExp(r'[,،;]'))) if (t.trim().isNotEmpty) t.trim()];
    Navigator.of(context).pop(DocInfo(doc, tags, sameForRest: _same));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final folders = allDocFolders(brain.data);
    final now = brain.services.now();
    Widget field(TextEditingController c, String label, String hint, {int lines = 1, IconData? icon}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            minLines: lines,
            maxLines: lines == 1 ? 1 : 4,
            style: body(16),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: icon == null ? null : Icon(icon, size: 20)),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(
              widget.edit != null
                  ? tr('বিবরণ বদলান')
                  : widget.of > 1
                      ? trf('{0}টার {1} নম্বর — কী এটা?', [bnDigits(widget.of), bnDigits(widget.index + 1)])
                      : (widget.files.length > 1 ? trf('{0}টা একসাথে — কী এগুলো?', [bnDigits(widget.files.length)]) : tr('কী এটা?')),
              style: display(19)),
          const SizedBox(height: 4),
          Text(tr('যত লিখবেন, পরে মুখে জিজ্ঞেস করলে তত সহজে খুঁজে দেবে'), style: body(13, color: C.muted)),
          const SizedBox(height: 12),
          if (widget.files.isNotEmpty)
            SizedBox(
              height: 76,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final f in widget.files.take(12))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: f.mime.startsWith('image/')
                          ? Image.memory(f.bytes, width: 76, height: 76, fit: BoxFit.cover, cacheWidth: 200)
                          : Container(width: 76, height: 76, color: C.blueTint, child: Icon(Icons.description_outlined, color: C.blue)),
                    ),
                  ),
                if (widget.files.length > 12) Center(child: Text('+${bnDigits(widget.files.length - 12)}', style: body(15, weight: FontWeight.w600))),
              ]),
            ),
          const SizedBox(height: 14),
          field(_title, tr('নাম'), tr('যেমন: রুমার পাসপোর্ট, ভাইয়ের বিয়ের ছবি'), icon: Icons.label_outline_rounded),
          Text(tr('ফোল্ডার'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final x in folders)
              ChoiceChip(label: Text(tr(x)), selected: _folder == x, onSelected: (_) => setState(() => _folder = x)),
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text(tr('নতুন ফোল্ডার')),
              onPressed: () async {
                final c = TextEditingController();
                final v = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(tr('নতুন ফোল্ডারের নাম'), style: body(18, weight: FontWeight.w600)),
                    content: TextField(controller: c, autofocus: true, style: body(16)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(tr('রাখুন'))),
                    ],
                  ),
                );
                c.dispose();
                if (v != null && v.isNotEmpty) setState(() => _folder = v);
              },
            ),
          ]),
          const SizedBox(height: 14),
          field(_about, tr('কী আছে (বিবরণ)'), tr('যেমন: গায়ে হলুদ আর বিয়ের দিনের ছবি, কাজী অফিসের কাগজ'), lines: 2, icon: Icons.notes_rounded),
          field(_people, tr('কারা আছেন / কার কাগজ'), tr('যেমন: আব্বা, রুমা, রহিম'), icon: Icons.people_outline_rounded),
          field(_place, tr('কোথায়'), tr('যেমন: কক্সবাজার, গ্রামের বাড়ি'), icon: Icons.place_outlined),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final p = await showDatePicker(context: context, initialDate: _taken ?? now, firstDate: DateTime(1950), lastDate: DateTime(now.year + 1));
                  if (p != null) setState(() => _taken = p);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_taken == null ? tr('কবেকার (তারিখ)') : fullDate(_taken!)),
              ),
            ),
            if (_taken != null) IconButton(tooltip: tr('তারিখ মুছুন'), onPressed: () => setState(() => _taken = null), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 12),
          field(_tags, tr('ট্যাগ (কমা দিয়ে)'), tr('যেমন: পরিবার, জরুরি'), icon: Icons.sell_outlined),
          if (widget.of > 1 && widget.index < widget.of - 1)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _same,
              onChanged: (v) => setState(() => _same = v ?? false),
              title: Text(trf('বাকি {0}টাতেও একই তথ্য দিন', [bnDigits(widget.of - widget.index - 1)]), style: body(14.5)),
            ),
          const SizedBox(height: 6),
          PrimaryButton(label: widget.edit != null ? tr('রাখুন') : tr('রাখুন'), icon: Icons.check_rounded, onPressed: _done),
        ]),
      ),
    );
  }
}
