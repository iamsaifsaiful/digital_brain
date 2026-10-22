import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../services/launcher.dart';
import '../state/brain.dart';
import 'file_view.dart';
import 'theme.dart';
import 'widgets.dart';

// ───────────────────────── Checklists in notes ─────────────────────────

/// A note body written as a checklist: one item per line, "[x] " when ticked.
bool isChecklist(String body) => body.split('\n').where((l) => l.trim().isNotEmpty).every((l) => l.startsWith('[ ] ') || l.startsWith('[x] '));

List<(bool, String)> checklistItems(String body) => [
      for (final l in body.split('\n'))
        if (l.trim().isNotEmpty) (l.startsWith('[x] '), l.startsWith('[ ] ') || l.startsWith('[x] ') ? l.substring(4) : l.trim()),
    ];

String checklistBody(List<(bool, String)> items) => [for (final (done, t) in items) if (t.trim().isNotEmpty) '${done ? '[x]' : '[ ]'} ${t.trim()}'].join('\n');

/// "৩/৫" ticked.
String checklistProgress(String body) {
  final items = checklistItems(body);
  return '${bnDigits(items.where((i) => i.$1).length)}/${bnDigits(items.length)}';
}

/// Tick-box list editing: tick, type, add a line, remove a line. The box grows with the list.
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({super.key, required this.items, required this.onChanged});
  final List<(bool, String)> items;
  final ValueChanged<List<(bool, String)>> onChanged;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  late final List<(bool, TextEditingController, FocusNode)> _rows = [
    for (final (d, t) in widget.items) (d, TextEditingController(text: t), FocusNode()),
    if (widget.items.isEmpty) (false, TextEditingController(), FocusNode()),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.$2.dispose();
      r.$3.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([for (final r in _rows) (r.$1, r.$2.text)]);

  void _add({int? after}) {
    final row = (false, TextEditingController(), FocusNode());
    setState(() => after == null ? _rows.add(row) : _rows.insert(after + 1, row));
    WidgetsBinding.instance.addPostFrameCallback((_) => row.$3.requestFocus());
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        for (var i = 0; i < _rows.length; i++)
          Row(children: [
            Checkbox(
              value: _rows[i].$1,
              onChanged: (v) {
                setState(() => _rows[i] = (v ?? false, _rows[i].$2, _rows[i].$3));
                _emit();
              },
            ),
            Expanded(
              child: TextField(
                controller: _rows[i].$2,
                focusNode: _rows[i].$3,
                onChanged: (_) => _emit(),
                onSubmitted: (_) => _add(after: i),
                textInputAction: TextInputAction.next,
                style: body(16, color: _rows[i].$1 ? C.muted : C.ink).copyWith(decoration: _rows[i].$1 ? TextDecoration.lineThrough : null),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: tr('নতুন জিনিস…'),
                ),
              ),
            ),
            IconButton(
              tooltip: tr('সরান'),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  final r = _rows.removeAt(i);
                  r.$2.dispose();
                  r.$3.dispose();
                  if (_rows.isEmpty) _rows.add((false, TextEditingController(), FocusNode()));
                });
                _emit();
              },
              icon: Icon(Icons.close_rounded, size: 18, color: C.muted),
            ),
          ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: Text(tr('আরেকটা যোগ করুন'))),
        ),
      ]),
    );
  }
}

// ───────────────────────── Photos and files in notes ─────────────────────────

/// The photos and files kept with a note: thumbnails, tap to see big (or
/// share a PDF), long-press to remove, and a button to add more (many at once).
class AttachmentsEditor extends StatefulWidget {
  const AttachmentsEditor({super.key, required this.files, required this.onAdd, required this.onRemove, required this.title});
  final List<DocFile> files;
  final String title;
  final Future<void> Function(int source) onAdd;
  final Future<void> Function(DocFile f) onRemove;

  @override
  State<AttachmentsEditor> createState() => _AttachmentsEditorState();
}

class _AttachmentsEditorState extends State<AttachmentsEditor> {
  final _cache = <String, Future<Uint8List?>>{};

  Future<Uint8List?> _bytes(Brain b, DocFile f) => _cache.putIfAbsent(f.id, () => b.docBytes(f));

  Future<void> _view(Brain b, DocFile f) async {
    final bytes = await _bytes(b, f);
    if (bytes == null || !mounted) return;
    await viewFile(context, bytes, name: f.name, mime: f.mime, title: widget.title);
  }

  Future<void> _pick() async {
    final src = await showAppSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(tr('ছবি তুলুন'), style: body(16)), onTap: () => Navigator.pop(ctx, 0)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(tr('গ্যালারি থেকে (একাধিক)'), style: body(16)), onTap: () => Navigator.pop(ctx, 1)),
          ListTile(leading: const Icon(Icons.attach_file_rounded), title: Text(tr('ফাইল (PDF ইত্যাদি)'), style: body(16)), onTap: () => Navigator.pop(ctx, 2)),
        ]),
      ),
    );
    if (src != null) await widget.onAdd(src);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.files.isEmpty ? tr('ছবি ও ফাইল') : trf('ছবি ও ফাইল · {0}', [bnDigits(widget.files.length)]),
          style: body(14, weight: FontWeight.w600, color: C.muted)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in widget.files)
          Tooltip(
            message: f.name,
            child: Material(
              color: C.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _view(brain, f),
                onLongPress: () async {
                  final ok = await confirmDialog(context, title: tr('এটা সরাবেন?'), text: f.name, yes: tr('সরান'), danger: true);
                  if (ok) await widget.onRemove(f);
                },
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: f.isImage
                      ? FutureBuilder<Uint8List?>(
                          future: _bytes(brain, f),
                          builder: (_, s) => s.data == null
                              ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                              : Image.memory(s.data!, fit: BoxFit.cover, cacheWidth: 240, gaplessPlayback: true),
                        )
                      : Container(
                          color: C.blueTint,
                          padding: const EdgeInsets.all(6),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.description_outlined, color: C.blue),
                            Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(10.5, color: C.blueText)),
                          ]),
                        ),
                ),
              ),
            ),
          ),
        Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: C.inputBorder)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pick,
            child: SizedBox(
              width: 84,
              height: 84,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: C.green),
                Text(tr('যোগ করুন'), style: body(12, weight: FontWeight.w600, color: C.green)),
              ]),
            ),
          ),
        ),
      ]),
    ]);
  }
}

/// One line about a note for lists: its text, or a checklist's progress, and how many photos/files it has.
String notePreview(Note n) {
  final text = n.body.trim().isNotEmpty && isChecklist(n.body)
      ? '☑ ${checklistProgress(n.body)} · ${checklistItems(n.body).where((i) => !i.$1).map((i) => i.$2).take(4).join(', ')}'
      : n.body.replaceAll('\n', ' ');
  return n.files.isEmpty ? text : '📎 ${bnDigits(n.files.length)}${text.isEmpty ? '' : ' · $text'}';
}


/// Shows a written address or place on the map.
Future<void> openMap(BuildContext context, String place) async {
  if (place.trim().isEmpty) {
    toast(context, tr('আগে ঠিকানা লিখুন'));
    return;
  }
  final ok = await BrainScope.read(context).services.launcher.openUrl(mapUri(place));
  if (!ok && context.mounted) toast(context, tr('ম্যাপ খোলা গেল না'));
}
