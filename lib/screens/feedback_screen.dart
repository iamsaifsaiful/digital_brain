import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../services/community.dart';
import '../services/files.dart' show PickedDoc;
import '../state/brain.dart';
import '../ui/file_view.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'docs_screen.dart' show sizeText;
import 'google_backup.dart' show GoogleBackupPanel;
import 'more_screen.dart' show appVersion;

/// সেটিংস › মতামত: the user's conversations with our team. A new feature
/// wish or a problem, our answers, and their answers back — each message may
/// carry a photo or PDF. Only what the user writes or attaches goes to our
/// server; none of their records.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<FeedbackThread>? _list;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final brain = BrainScope.read(context);
    if (!brain.signedIn) return;
    final (list, e) = await brain.community.threads();
    if (!mounted) return;
    setState(() {
      _list = list;
      _error = e;
    });
    brain.feedbackUnread = list.where((t) => t.unread).length;
  }

  Future<void> _new() async {
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const NewFeedbackScreen()));
    if (!mounted) return;
    await _load();
    if (id != null && mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedbackThreadScreen(id: id)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final list = _list;
    return Scaffold(
      floatingActionButton: brain.signedIn ? AddButton(key: const Key('feedback-new'), label: tr('নতুন লিখুন'), icon: Icons.edit_outlined, onPressed: _new) : null,
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('মতামত ও সমস্যা')),
          Expanded(
            child: !brain.signedIn
                ? ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                    Text(tr('আমাদের লিখতে আর উত্তর পেতে আগে Google দিয়ে লগইন করুন।'), style: body(15, color: C.muted2, height: 1.55)),
                    const SizedBox(height: 12),
                    const GoogleBackupPanel(),
                  ])
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 96), children: [
                      Text(tr('নতুন কোনো সুবিধা চাইলে বা কিছু ঠিকমতো না চললে লিখুন — ছবি বা PDF দিতে পারেন। আমাদের দল উত্তর দিলে নোটিফিকেশন আসবে, আপনিও আবার উত্তর দিতে পারবেন।'),
                          style: body(14, color: C.muted2, height: 1.55)),
                      const SizedBox(height: 16),
                      if (_error != null) ...[Text(_error!, style: body(14, color: C.red)), const SizedBox(height: 12)],
                      if (list == null)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                      else if (list.isEmpty)
                        EmptyState(icon: Icons.forum_outlined, title: tr('এখনো কিছু লেখেননি'), text: tr('নিচের “নতুন লিখুন” চাপুন।'))
                      else
                        Panel(
                          child: Rows(children: [
                            for (final t in list)
                              ListRow(
                                key: Key('thread-${t.id}'),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: t.kind == 'problem' ? C.roseTint : C.greenTint, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(t.kind == 'problem' ? Icons.report_problem_outlined : Icons.lightbulb_outline_rounded, color: t.kind == 'problem' ? C.rose : C.green, size: 21),
                                ),
                                title: t.text.isEmpty ? tr('সংযুক্তি') : t.text,
                                subtitle: t.unread
                                    ? trf('নতুন উত্তর: {0}', [t.lastText])
                                    : '${t.lastFromUs ? tr('আমাদের উত্তর') : tr('আপনি')} · ${shortDate(t.updated)}${t.status == 'done' ? ' · ${tr('শেষ')}' : ''}',
                                subtitleColor: t.unread ? C.greenDark : C.muted,
                                trailing: t.unread
                                    ? Container(width: 10, height: 10, decoration: BoxDecoration(color: C.green, shape: BoxShape.circle))
                                    : Icon(Icons.chevron_right_rounded, color: C.muted),
                                onTap: () async {
                                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedbackThreadScreen(id: t.id)));
                                  if (mounted) await _load();
                                },
                              ),
                          ]),
                        ),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Picks a photo or a PDF to send (null when cancelled or not allowed).
Future<OutgoingFile?> pickAttachment(BuildContext context) async {
  final brain = BrainScope.read(context);
  final how = await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.photo_camera_outlined, color: C.green), title: Text(tr('ছবি তুলুন')), onTap: () => Navigator.pop(ctx, 0)),
        ListTile(leading: Icon(Icons.photo_library_outlined, color: C.green), title: Text(tr('গ্যালারি থেকে ছবি')), onTap: () => Navigator.pop(ctx, 1)),
        ListTile(leading: Icon(Icons.picture_as_pdf_outlined, color: C.green), title: Text(tr('PDF ফাইল')), onTap: () => Navigator.pop(ctx, 2)),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (how == null) return null;
  final files = brain.services.files;
  final PickedDoc? f = how == 2 ? await files.pickDocument() : await files.pickPhoto(camera: how == 0, side: 1600);
  if (f == null || !context.mounted) return null;
  final pdf = f.mime == 'application/pdf' || f.name.toLowerCase().endsWith('.pdf');
  if (!pdf && !f.mime.startsWith('image/')) {
    toast(context, tr('শুধু ছবি বা PDF দেওয়া যায়'));
    return null;
  }
  if (f.bytes.length > 5 * 1024 * 1024) {
    toast(context, tr('ফাইলটা অনেক বড় — ৫ MB পর্যন্ত দেওয়া যায়'));
    return null;
  }
  return OutgoingFile(f.bytes, f.name);
}

/// The chosen attachment, with a way to remove it.
class _AttachChip extends StatelessWidget {
  const _AttachChip({required this.file, required this.onRemove});
  final OutgoingFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InputChip(
        avatar: Icon(file.name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 18, color: C.green),
        label: Text(file.name, overflow: TextOverflow.ellipsis),
        onDeleted: onRemove,
      );
}

class NewFeedbackScreen extends StatefulWidget {
  const NewFeedbackScreen({super.key});

  @override
  State<NewFeedbackScreen> createState() => _NewFeedbackScreenState();
}

class _NewFeedbackScreenState extends State<NewFeedbackScreen> {
  final _text = TextEditingController();
  String _kind = 'idea';
  OutgoingFile? _file;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final brain = BrainScope.read(context);
    final t = _text.text.trim();
    if (t.length < 5 && _file == null) {
      setState(() => _error = tr('আরেকটু খুলে লিখুন'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final (id, e) = await brain.community.startFeedback(kind: _kind, text: t, appVersion: appVersion, file: _file);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = e;
    });
    if (e == null) {
      toast(context, tr('পাঠানো হয়েছে। ধন্যবাদ — উত্তর এলে জানাবো।'));
      Navigator.of(context).pop(id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: tr('নতুন মতামত')),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                SegTabs<String>(
                  items: [('idea', tr('নতুন সুবিধা')), ('problem', tr('সমস্যা')), ('other', tr('অন্য কিছু'))],
                  value: _kind,
                  onChanged: (v) => setState(() => _kind = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('feedback-text'),
                  controller: _text,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 2000,
                  style: body(16),
                  decoration: InputDecoration(
                    hintText: _kind == 'problem' ? tr('কী করতে গিয়ে কী হলো? যেমন: রিমাইন্ডার সময়মতো বাজেনি') : tr('কী হলে আপনার সুবিধা হয়?'),
                  ),
                ),
                Row(children: [
                  TextButton.icon(
                    key: const Key('feedback-attach'),
                    onPressed: _busy
                        ? null
                        : () async {
                            final f = await pickAttachment(context);
                            if (f != null && mounted) setState(() => _file = f);
                          },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(tr('ছবি বা PDF যুক্ত করুন')),
                  ),
                ]),
                if (_file != null) Align(alignment: Alignment.centerLeft, child: _AttachChip(file: _file!, onRemove: () => setState(() => _file = null))),
                const SizedBox(height: 6),
                Text(tr('পাসওয়ার্ড, PIN বা ব্যক্তিগত নম্বর লিখবেন না। শুধু এখানে যা লিখবেন বা যুক্ত করবেন সেটুকু আর অ্যাপের সংস্করণ যাবে — আপনার অন্য কোনো তথ্য না।'),
                    style: body(12.5, color: C.muted, height: 1.5)),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: body(14, color: C.red)),
                ],
                const SizedBox(height: 16),
                PrimaryButton(key: const Key('feedback-send'), label: _busy ? tr('পাঠাচ্ছি…') : tr('পাঠান'), icon: Icons.send_rounded, onPressed: _busy ? null : _send),
              ]),
            ),
          ]),
        ),
      );
}

/// One conversation: messages as bubbles (ours on the left), attachments
/// that open on tap, and an answer box with a paper clip.
class FeedbackThreadScreen extends StatefulWidget {
  const FeedbackThreadScreen({super.key, required this.id});
  final int id;

  @override
  State<FeedbackThreadScreen> createState() => _FeedbackThreadScreenState();
}

class _FeedbackThreadScreenState extends State<FeedbackThreadScreen> {
  final _text = TextEditingController();
  FeedbackThread? _thread;
  List<FeedbackMessage> _messages = const [];
  OutgoingFile? _file;
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final (t, msgs, e) = await BrainScope.read(context).community.thread(widget.id);
    if (!mounted) return;
    setState(() {
      _thread = t ?? _thread;
      _messages = t == null ? _messages : msgs;
      _error = e;
      _loaded = true;
    });
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty && _file == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await BrainScope.read(context).community.reply(widget.id, t, file: _file);
    if (!mounted) return;
    if (e == null) {
      _text.clear();
      _file = null;
      await _load();
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  Future<void> _open(FeedbackMessage m) async {
    final f = m.file!;
    toast(context, tr('খুলছি…'));
    final (bytes, e) = await BrainScope.read(context).community.file(m.id);
    if (!mounted) return;
    if (bytes == null) {
      toast(context, e ?? tr('ফাইলটা খোলা গেল না'));
      return;
    }
    await viewFile(context, bytes, name: f.name, mime: f.mime, title: f.name);
  }

  @override
  Widget build(BuildContext context) {
    final t = _thread;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t == null ? tr('মতামত') : t.kindLabel),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                      for (final m in _messages) _Bubble(message: m, onOpen: () => _open(m)),
                      if (t?.status == 'done')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(tr('আমাদের দিক থেকে এটা শেষ হিসেবে রাখা আছে — আবার লিখলে খুলে যাবে।'), textAlign: TextAlign.center, style: body(12.5, color: C.muted)),
                        ),
                    ]),
                  ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 6), child: Text(_error!, style: body(13.5, color: C.red))),
          if (_file != null) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 4), child: Align(alignment: Alignment.centerLeft, child: _AttachChip(file: _file!, onRemove: () => setState(() => _file = null)))),
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
            decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(
                key: const Key('reply-attach'),
                tooltip: tr('ছবি বা PDF'),
                onPressed: _busy
                    ? null
                    : () async {
                        final f = await pickAttachment(context);
                        if (f != null && mounted) setState(() => _file = f);
                      },
                icon: Icon(Icons.attach_file_rounded, color: C.muted2),
              ),
              Expanded(
                child: TextField(
                  key: const Key('reply-text'),
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  style: body(16),
                  decoration: InputDecoration(hintText: tr('উত্তর লিখুন…'), counterText: '', isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                key: const Key('reply-send'),
                tooltip: tr('পাঠান'),
                style: IconButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white),
                onPressed: _busy ? null : _send,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onOpen});
  final FeedbackMessage message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final us = m.fromUs;
    final f = m.file;
    return Align(
      alignment: us ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: us ? C.surface : C.greenTint,
          border: us ? Border.all(color: C.line) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(us ? 4 : 16),
            bottomRight: Radius.circular(us ? 16 : 4),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (us) Text(trf('My Assistant দল{0}', [m.admin.isEmpty ? '' : ' · ${m.admin}']), style: body(12, weight: FontWeight.w600, color: C.green)),
          if (m.text.isNotEmpty) SelectableText(m.text, style: body(15.5, height: 1.5)),
          if (f != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                key: Key('file-${m.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: onOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.image ? Icons.image_outlined : Icons.picture_as_pdf_outlined, size: 20, color: C.green),
                    const SizedBox(width: 8),
                    Flexible(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600))),
                    const SizedBox(width: 6),
                    Text(sizeText(f.size), style: body(12, color: C.muted)),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text('${shortDate(m.at)} ${bnTime(m.at.hour, m.at.minute)}', style: body(11.5, color: C.muted)),
        ]),
      ),
    );
  }
}
