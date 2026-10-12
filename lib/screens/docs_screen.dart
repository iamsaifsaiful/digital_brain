import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../services/files.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// "১.২ MB", "৮৪০ KB".
String sizeText(int bytes) {
  if (bytes >= 1024 * 1024) return '${bnDigits((bytes / (1024 * 1024)).toStringAsFixed(1))} MB';
  return '${bnDigits((bytes / 1024).ceil())} KB';
}

/// All folders: the usual ones, then the user's own.
List<String> allDocFolders(AppData d) => [...docFolders, ...{for (final x in d.docs) x.folder}.where((f) => !docFolders.contains(f))];

/// Adds a photo or file: asks the folder, keeps it encrypted, opens it.
Future<void> addDocument(BuildContext context, {required int source, String? folder, Doc? into}) async {
  final brain = BrainScope.read(context);
  final shrink = await brain.services.lock.keys.read('doc_shrink') != 'false';
  final PickedDoc? f = switch (source) {
    0 => await brain.services.files.pickPhoto(camera: true, shrink: shrink),
    1 => await brain.services.files.pickPhoto(camera: false, shrink: shrink),
    _ => await brain.services.files.pickDocument(),
  };
  if (f == null || !context.mounted) return;
  if (f.bytes.length > 25 * 1024 * 1024) {
    toast(context, 'ফাইলটা অনেক বড় (${sizeText(f.bytes.length)}) — ২৫ MB পর্যন্ত রাখা যায়');
    return;
  }
  var target = folder ?? into?.folder;
  if (target == null) {
    target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('কোন ফোল্ডারে রাখবো?', style: body(18, weight: FontWeight.w600)),
        children: [
          for (final x in allDocFolders(brain.data))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, x), child: Text(x, style: body(16))),
        ],
      ),
    );
    if (target == null || !context.mounted) return;
  }
  final d = await brain.addDocPage(into, f, folder: target, title: target);
  if (!context.mounted) return;
  toast(context, f.mime.startsWith('image/') ? 'ছবি রাখা হলো · ${sizeText(f.bytes.length)}' : 'ফাইল রাখা হলো · ${sizeText(f.bytes.length)}');
  if (into == null) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocScreen(id: d.id, unlocked: true)));
  }
}

/// ডকুমেন্টস: NID, passport, land papers, receipts… as photos and files,
/// encrypted on this phone.
class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key, this.folder});

  /// Showing one folder; null = all.
  final String? folder;

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  bool _shrink = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final v = await BrainScope.read(context).services.lock.keys.read('doc_shrink');
      if (mounted) setState(() => _shrink = v != 'false');
    });
  }

  Future<void> _setShrink(bool v) async {
    setState(() => _shrink = v);
    await BrainScope.read(context).services.lock.keys.write('doc_shrink', v ? 'true' : 'false');
  }

  Future<void> _open(Doc d) async {
    final ok = await verifyUser(context, reason: '${d.title} — দেখতে যাচাই করুন');
    if (ok && mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocScreen(id: d.id, unlocked: true)));
  }

  Widget _addButton(IconData icon, String label, int source, {bool dark = false}) => Expanded(
        child: Material(
          color: dark ? C.green : C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: dark ? BorderSide.none : const BorderSide(color: C.inputBorder)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => addDocument(context, source: source, folder: widget.folder),
            child: SizedBox(
              height: 64,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: dark ? Colors.white : C.ink, size: 22),
                const SizedBox(height: 2),
                Text(label, style: body(13, weight: FontWeight.w600, color: dark ? Colors.white : C.ink)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final folder = widget.folder;
    final docs = ([...d.docs.where((x) => folder == null || x.folder == folder)]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
    final folders = allDocFolders(d);

    Widget docRow(Doc x) => ListRow(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(x.files.any((f) => f.isImage) ? Icons.image_outlined : Icons.description_outlined, color: C.blue, size: 20),
          ),
          title: x.title,
          subtitle: '${x.folder} · ${bnDigits(x.files.length)} পাতা · ${sizeText(x.size)}${x.expiry != null ? ' · মেয়াদ ${bnDigits(x.expiry!.day)} ${bnMonthsShort[x.expiry!.month - 1]} ${bnDigits(x.expiry!.year)}' : ''}',
          onTap: () => _open(x),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: folder ?? 'ডকুমেন্টস', trailing: const [Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.lock_outline_rounded, color: C.green))]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(children: [
                  _addButton(Icons.photo_camera_outlined, 'ছবি তুলুন', 0, dark: true),
                  const SizedBox(width: 8),
                  _addButton(Icons.photo_library_outlined, 'গ্যালারি', 1),
                  const SizedBox(width: 8),
                  _addButton(Icons.attach_file_rounded, 'ফাইল', 2),
                ]),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ছবি ছোট করে রাখুন', style: body(14.5, weight: FontWeight.w600)),
                        Text(_shrink ? 'জায়গা কম লাগে, লেখা পরিষ্কার পড়া যায়' : 'ছবি আসল মাপেই থাকবে (অনেক জায়গা লাগে)',
                            style: body(12.5, color: C.muted)),
                      ]),
                    ),
                    Switch(value: _shrink, activeTrackColor: C.green, onChanged: _setShrink),
                  ]),
                ),
                if (folder == null) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text('ফোল্ডার', style: body(13, weight: FontWeight.w600, color: C.muted))),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.05,
                    children: [
                      for (final f in folders)
                        Material(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocsScreen(folder: f))),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(11)),
                                  child: const Icon(Icons.folder_outlined, color: C.blue, size: 20),
                                ),
                                const Spacer(),
                                Text(f, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, height: 1.25)),
                                Text('${bnDigits(d.docs.where((x) => x.folder == f).length)}টি', style: body(11.5, color: C.muted)),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: Text(folder == null ? 'সম্প্রতি রাখা' : 'এই ফোল্ডারে · ${bnDigits(docs.length)}টি', style: body(13, weight: FontWeight.w600, color: C.muted)),
                ),
                if (docs.isEmpty)
                  Panel(
                    padding: const EdgeInsets.all(16),
                    child: Text('এখনো কিছু নেই। উপরের বোতাম চেপে কাগজের ছবি তুলুন বা ফাইল যোগ করুন। সব কিছু এই ফোনে তালাবদ্ধ থাকে।',
                        style: body(14, color: C.muted, height: 1.5)),
                  )
                else
                  Panel(child: Rows(children: [for (final x in docs.take(folder == null ? 8 : 200)) docRow(x)])),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// One document: its pages, the details the user adds, and its expiry.
class DocScreen extends StatefulWidget {
  const DocScreen({super.key, required this.id, this.unlocked = false});
  final String id;
  final bool unlocked;

  @override
  State<DocScreen> createState() => _DocScreenState();
}

class _DocScreenState extends State<DocScreen> {
  final _cache = <String, Future<Uint8List?>>{};

  Doc? _doc(Brain b) => b.data.docs.where((x) => x.id == widget.id).firstOrNull;

  Future<Uint8List?> _bytes(Brain b, DocFile f) => _cache.putIfAbsent(f.id, () => b.docBytes(f));

  Future<String?> _ask(String title, String initial, {String hint = ''}) async {
    final c = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: body(18, weight: FontWeight.w600)),
        content: TextField(controller: c, autofocus: true, style: body(16), decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাদ দিন')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text('রাখুন', style: body(15, weight: FontWeight.w600, color: C.green))),
        ],
      ),
    );
    c.dispose();
    return v;
  }

  Future<void> _addField(Brain b, Doc d) async {
    final label = await _ask('কী তথ্য?', '', hint: 'যেমন: NID নম্বর, পাসপোর্ট নম্বর');
    if (label == null || label.isEmpty || !mounted) return;
    final value = await _ask(label, '');
    if (value == null || !mounted) return;
    await b.saveDoc(d.copyWith(fields: [...d.fields, DocField(label, value)]));
  }

  Future<void> _view(Brain b, Doc d, DocFile f) async {
    final bytes = await _bytes(b, f);
    if (bytes == null || !mounted) return;
    if (!f.isImage) {
      await b.services.files.shareFile(bytes, f.name, f.mime, d.title);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(d.title, style: body(16, color: Colors.white)),
          actions: [
            IconButton(tooltip: 'পাঠান', onPressed: () => b.services.files.shareFile(bytes, f.name, f.mime, d.title), icon: const Icon(Icons.share_outlined)),
          ],
        ),
        body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = _doc(brain);
    if (d == null) {
      return const Scaffold(body: SafeArea(child: Column(children: [TopBar(title: 'ডকুমেন্ট'), Expanded(child: Center(child: Text('মুছে ফেলা হয়েছে')))])));
    }
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: d.title, trailing: [
            IconButton(
              tooltip: 'নাম বদলান',
              onPressed: () async {
                final v = await _ask('নাম', d.title);
                if (v != null && v.isNotEmpty) await brain.saveDoc(d.copyWith(title: v));
              },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'মুছুন',
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'ডকুমেন্টটা মুছবেন?', text: '“${d.title}”-এর সব পাতা মুছে যাবে।', yes: 'মুছুন', danger: true);
                if (!ok || !context.mounted) return;
                await brain.deleteDoc(d);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(children: [
                  ActionChip(
                    avatar: const Icon(Icons.folder_outlined, size: 18, color: C.blue),
                    label: Text(d.folder, style: body(13.5)),
                    onPressed: () async {
                      final f = await showDialog<String>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: Text('ফোল্ডার', style: body(18, weight: FontWeight.w600)),
                          children: [
                            for (final x in allDocFolders(brain.data)) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, x), child: Text(x, style: body(16))),
                            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, '+'), child: Text('+ নতুন ফোল্ডার', style: body(16, color: C.green))),
                          ],
                        ),
                      );
                      if (f == null) return;
                      final name = f == '+' ? await _ask('নতুন ফোল্ডারের নাম', '') : f;
                      if (name != null && name.isNotEmpty) await brain.saveDoc(d.copyWith(folder: name));
                    },
                  ),
                  const Spacer(),
                  Text('${bnDigits(d.files.length)} পাতা · ${sizeText(d.size)}', style: body(12.5, color: C.muted)),
                ]),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                  children: [
                    for (final f in d.files)
                      Material(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _view(brain, d, f),
                          onLongPress: () async {
                            final ok = await confirmDialog(context, title: 'এই পাতাটা সরাবেন?', text: f.name, yes: 'সরান', danger: true);
                            if (ok) await brain.removeDocPage(d, f);
                          },
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Expanded(
                              child: f.isImage
                                  ? FutureBuilder<Uint8List?>(
                                      future: _bytes(brain, f),
                                      builder: (_, s) => s.data == null
                                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                                          : Image.memory(s.data!, fit: BoxFit.cover, cacheWidth: 500, gaplessPlayback: true),
                                    )
                                  : Container(
                                      color: C.blueTint,
                                      child: const Icon(Icons.description_outlined, color: C.blue, size: 40),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                              child: Text('${f.isImage ? 'ছবি' : f.name} · ${sizeText(f.size)}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                            ),
                          ]),
                        ),
                      ),
                    Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.inputBorder)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final src = await showModalBottomSheet<int>(
                            context: context,
                            showDragHandle: true,
                            builder: (ctx) => SafeArea(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('ছবি তুলুন', style: body(16)), onTap: () => Navigator.pop(ctx, 0)),
                                ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('গ্যালারি থেকে', style: body(16)), onTap: () => Navigator.pop(ctx, 1)),
                                ListTile(leading: const Icon(Icons.attach_file_rounded), title: Text('ফাইল (PDF ইত্যাদি)', style: body(16)), onTap: () => Navigator.pop(ctx, 2)),
                              ]),
                            ),
                          );
                          if (src != null && context.mounted) await addDocument(context, source: src, into: d);
                        },
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.add_rounded, color: C.green, size: 28),
                          Text('পাতা যোগ', style: body(13.5, weight: FontWeight.w600, color: C.green)),
                        ]),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: Text('দরকারি তথ্য', style: body(13, weight: FontWeight.w600, color: C.muted)),
                ),
                Panel(
                  child: Rows(children: [
                    for (final (i, f) in d.fields.indexed)
                      ListRow(
                        leading: const Icon(Icons.info_outline_rounded, color: C.blue),
                        title: f.label,
                        subtitle: f.value,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'কপি',
                            onPressed: () {
                              brain.services.files.copy(f.value);
                              toast(context, 'কপি হয়েছে');
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18, color: C.green),
                          ),
                          IconButton(
                            tooltip: 'সরান',
                            onPressed: () => brain.saveDoc(d.copyWith(fields: [...d.fields]..removeAt(i))),
                            icon: const Icon(Icons.close_rounded, size: 18, color: C.muted),
                          ),
                        ]),
                      ),
                    ListRow(
                      leading: const Icon(Icons.add_rounded, color: C.green),
                      title: 'নতুন তথ্য যোগ করুন',
                      subtitle: 'যেমন NID নম্বর, পাসপোর্ট নম্বর, দলিল নম্বর',
                      onTap: () => _addField(brain, d),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Panel(
                  child: ListRow(
                    leading: const Icon(Icons.event_busy_outlined, color: C.orange),
                    title: d.expiry == null ? 'মেয়াদ শেষের তারিখ' : 'মেয়াদ শেষ: ${bnDigits(d.expiry!.day)} ${bnMonths[d.expiry!.month - 1]} ${bnDigits(d.expiry!.year)}',
                    subtitle: d.expiry == null ? 'দিলে এক মাস আগে আর শেষের দিন মনে করাবো' : 'এক মাস আগে আর শেষের দিন মনে করাবো',
                    trailing: d.expiry == null
                        ? null
                        : IconButton(tooltip: 'মেয়াদ সরান', onPressed: () => brain.setDocExpiry(d, null), icon: const Icon(Icons.close_rounded, color: C.muted)),
                    onTap: () async {
                      final now = brain.services.now();
                      final p = await showDatePicker(
                        context: context,
                        initialDate: d.expiry ?? now.add(const Duration(days: 365)),
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 30),
                      );
                      if (p != null) await brain.setDocExpiry(d, p);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text('ছবিতে চাপ দিলে বড় করে দেখা যায়, চেপে ধরে রাখলে সরানো যায়। সব পাতা এই ফোনে তালাবদ্ধ থাকে।', style: body(12.5, color: C.muted, height: 1.5)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
