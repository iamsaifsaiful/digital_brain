import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../state/brain.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opens a kept file the right way: a photo full screen, a PDF page by
/// page inside the app, anything else in another app — each with
/// "অন্য অ্যাপে খুলুন", "ডাউনলোড" (save to the phone) and "শেয়ার".
Future<void> viewFile(BuildContext context, Uint8List bytes, {required String name, required String mime, required String title}) async {
  final pdf = mime == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
  if (mime.startsWith('image/')) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImageView(bytes: bytes, name: name, mime: mime, title: title)));
  } else if (pdf) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfViewScreen(bytes: bytes, name: name, title: title)));
  } else {
    await _otherFile(context, bytes, name, mime, title);
  }
}

/// The three ways out of the app for a file.
List<Widget> _fileActions(BuildContext context, Uint8List bytes, String name, String mime, String title, {Color? color}) {
  final files = BrainScope.read(context).services.files;
  return [
    IconButton(
      tooltip: tr('অন্য অ্যাপে খুলুন'),
      color: color,
      icon: const Icon(Icons.open_in_new_rounded),
      onPressed: () async {
        final ok = await files.openWith(bytes, name, mime);
        if (!ok && context.mounted) toast(context, tr('এই ফাইল খোলার মতো অ্যাপ ফোনে পাওয়া যায়নি।'));
      },
    ),
    IconButton(
      tooltip: tr('ডাউনলোড করুন'),
      color: color,
      icon: const Icon(Icons.download_rounded),
      onPressed: () async {
        final ok = await files.saveFile(bytes, name, mime: mime);
        if (ok && context.mounted) toast(context, tr('ফোনে সেভ হলো।'));
      },
    ),
    IconButton(tooltip: tr('শেয়ার'), color: color, icon: const Icon(Icons.share_outlined), onPressed: () => files.shareFile(bytes, name, mime, title)),
  ];
}

class _ImageView extends StatelessWidget {
  const _ImageView({required this.bytes, required this.name, required this.mime, required this.title});
  final Uint8List bytes;
  final String name;
  final String mime;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title, style: body(16, color: Colors.white)),
          actions: _fileActions(context, bytes, name, mime, title, color: Colors.white),
        ),
        body: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
      );
}

/// A PDF read inside the app: every page, pinch to zoom.
class PdfViewScreen extends StatefulWidget {
  const PdfViewScreen({super.key, required this.bytes, required this.name, required this.title});
  final Uint8List bytes;
  final String name;
  final String title;

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  int? _id;
  int _pages = 0;
  bool _failed = false;
  final _cache = <int, Future<Uint8List?>>{};
  late final _files = BrainScope.read(context).services.files;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final r = await _files.pdfOpen(widget.bytes);
    if (!mounted) {
      if (r != null) await _files.pdfClose(r.$1);
      return;
    }
    setState(() {
      if (r == null) {
        _failed = true;
      } else {
        _id = r.$1;
        _pages = r.$2;
      }
    });
  }

  @override
  void dispose() {
    final id = _id;
    if (id != null) _files.pdfClose(id);
    super.dispose();
  }

  Future<Uint8List?> _page(int i, int width) => _cache.putIfAbsent(i, () => _files.pdfPage(_id!, i, width));

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = (mq.size.width * mq.devicePixelRatio).round().clamp(600, 1800);
    return Scaffold(
      backgroundColor: C.soft,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w600)),
        actions: _fileActions(context, widget.bytes, widget.name, 'application/pdf', widget.title),
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr('এই PDF অ্যাপের ভেতরে খোলা গেল না (পাসওয়ার্ড দেওয়া বা নষ্ট ফাইল হতে পারে)।'), textAlign: TextAlign.center, style: body(15)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _files.openWith(widget.bytes, widget.name, 'application/pdf'),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(tr('অন্য অ্যাপে খুলুন')),
                  ),
                ]),
              ),
            )
          : _id == null
              ? const Center(child: CircularProgressIndicator())
              : InteractiveViewer(
                  maxScale: 5,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemCount: _pages,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(children: [
                        Material(
                          elevation: 1,
                          color: Colors.white,
                          child: FutureBuilder<Uint8List?>(
                            future: _page(i, width),
                            builder: (_, s) => s.data == null
                                ? AspectRatio(
                                    aspectRatio: 1 / 1.414,
                                    child: Center(child: s.connectionState == ConnectionState.done ? Icon(Icons.broken_image_outlined, color: C.muted) : const CircularProgressIndicator()),
                                  )
                                : Image.memory(s.data!, fit: BoxFit.fitWidth, width: double.infinity, gaplessPlayback: true),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(trf('পাতা {0} / {1}', [bnDigits(i + 1), bnDigits(_pages)]), style: body(11.5, color: C.muted)),
                      ]),
                    ),
                  ),
                ),
    );
  }
}

/// Word, Excel and other files: opened in another app, or saved or shared.
Future<void> _otherFile(BuildContext context, Uint8List bytes, String name, String mime, String title) async {
  final files = BrainScope.read(context).services.files;
  final pick = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(17, weight: 700))),
        ListTile(leading: const Icon(Icons.open_in_new_rounded), title: Text(tr('অন্য অ্যাপে খুলুন'), style: body(16)), onTap: () => Navigator.pop(ctx, 0)),
        ListTile(leading: const Icon(Icons.download_rounded), title: Text(tr('ডাউনলোড করুন (ফোনে সেভ)'), style: body(16)), onTap: () => Navigator.pop(ctx, 1)),
        ListTile(leading: const Icon(Icons.share_outlined), title: Text(tr('শেয়ার'), style: body(16)), onTap: () => Navigator.pop(ctx, 2)),
      ]),
    ),
  );
  if (!context.mounted) return;
  switch (pick) {
    case 0:
      final ok = await files.openWith(bytes, name, mime);
      if (!ok && context.mounted) toast(context, tr('এই ফাইল খোলার মতো অ্যাপ ফোনে পাওয়া যায়নি।'));
    case 1:
      final ok = await files.saveFile(bytes, name, mime: mime);
      if (ok && context.mounted) toast(context, tr('ফোনে সেভ হলো।'));
    case 2:
      await files.shareFile(bytes, name, mime, title);
  }
}
