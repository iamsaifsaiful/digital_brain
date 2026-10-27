/// The admin app's pages from 27 Oct (owner): members by join date and
/// Premium source with a PDF, one feedback inbox per member, what
/// notifications go when and how many a day, বিকাশ মেলানো on the payment-SIM
/// phone, and the হিসাব with a month switcher and filters.
library;


import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'bkash.dart';
import 'ui.dart';

// ── সদস্য ──

class MembersPage extends StatefulWidget {
  const MembersPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

String ymName(String ym) {
  const m = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
  if (ym.length < 7) return ym;
  return '${m[int.parse(ym.substring(5, 7)) - 1]} ${bn(ym.substring(0, 4))}';
}

class _MembersPageState extends State<MembersPage> {
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _list;
  int _count = 0;
  String _words = '';
  int _page = 1;
  String _status = '';
  String _joined = '';
  String _src = '';
  Map<String, dynamic>? _growth;
  bool _daily = true;
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadGrowth();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadGrowth() async {
    final g = await widget.guard(() => widget.api.memberGrowth());
    if (g != null && mounted) setState(() => _growth = g);
  }

  Future<void> _load({bool more = false}) async {
    final page = more ? _page + 1 : 1;
    if (more) setState(() => _more = true);
    final r = await widget.guard(() => widget.api.memberList(q: _q.text.trim(), status: _status, joined: _joined, src: _src, page: page));
    if (!mounted) return;
    setState(() {
      _more = false;
      if (r == null) return;
      _page = page;
      _list = more ? [...?_list, ...r.$1] : r.$1;
      _count = r.$2;
      _words = r.$3;
    });
  }

  void _set({String? status, String? joined, String? src}) {
    setState(() {
      if (status != null) _status = status;
      if (joined != null) _joined = joined;
      if (src != null) _src = src;
      _list = null;
    });
    _load();
  }

  Future<void> _pdf() async {
    final url = await widget.guard(() => widget.api.membersPdfLink(q: _q.text.trim(), status: _status, joined: _joined, src: _src));
    if (url == null || !mounted) return;
    final ok = await Device.openUrl(url);
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ব্রাউজার খোলা গেল না — লিংক কপি হয়েছে, ব্রাউজারে পেস্ট করুন (১০ মিনিট চলবে)')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ব্রাউজারে খুলেছে — “PDF হিসেবে রাখুন” চাপুন')));
    }
  }

  Future<void> _pickMonth() async {
    final months = [for (final m in ((_growth?['months'] as List?) ?? const []).cast<Map>().toList().reversed) m];
    final c = Palette.of(context);
    final ym = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: Text('কোন মাসে যোগ দিয়েছেন', style: text(18, weight: FontWeight.w700, color: c.ink))),
          for (final m in months)
            ListTile(
              title: Text(ymName('${m['month']}'), style: text(15.5, color: c.ink)),
              trailing: Text('${bn(m['n'])} জন', style: text(14, color: c.muted)),
              onTap: () => Navigator.pop(ctx, '${m['month']}'),
            ),
        ]),
      ),
    );
    if (ym != null) _set(joined: ym);
  }

  Future<void> _open(Map<String, dynamic> m) async {
    final c = Palette.of(context);
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['name']}'.isEmpty ? '${m['email']}' : '${m['name']}', style: text(21, weight: FontWeight.w700, color: c.ink)),
            Text('${m['email']}', style: text(14, color: c.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              statusPill(ctx, '${m['status']}'),
              if ('${m['source_label'] ?? ''}'.isNotEmpty && m['source_label'] != '—') Pill('${m['source_label']}', c.brand, c.tint),
              if (m['pro_until'] != null) Pill('প্রিমিয়াম পর্যন্ত ${date('${m['pro_until']}')}', c.ink, c.ground),
              Pill('যোগ ${date('${m['joined']}')}', c.muted, c.ground),
              Pill('শেষ দেখা ${ago('${m['last_seen']}')}', c.muted, c.ground),
              if ('${m['version']}'.isNotEmpty) Pill('${m['version']}', c.muted, c.ground),
            ]),
            if ('${m['note']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('নোট: ${m['note']}', style: text(14, color: c.ink))),
            const SizedBox(height: 16),
            Text('প্রিমিয়াম যোগ করুন (চলমান মেয়াদের পরে যোগ হবে)', style: text(14, weight: FontWeight.w600, color: c.ink)),
            const SizedBox(height: 8),
            Row(children: [
              for (final (d, l) in [(30, '+১ মাস'), (90, '+৩ মাস'), (365, '+১ বছর')]) ...[
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, d), child: Text(l))),
                if (d != 365) const SizedBox(width: 8),
              ],
            ]),
            if (m['status'] == 'pro' || m['status'] == 'trial')
              TextButton(onPressed: () => Navigator.pop(ctx, -1), style: TextButton.styleFrom(foregroundColor: c.rose), child: const Text('প্রিমিয়াম এখনই বন্ধ করুন')),
          ]),
        ),
      ),
    );
    if (days == null) return;
    final id = (m['id'] as num).toInt();
    final r = await widget.guard(() => widget.api.changeMember(id, days: days > 0 ? days : 0, stop: days < 0));
    if (r != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(days < 0 ? 'প্রিমিয়াম বন্ধ করা হলো' : 'প্রিমিয়াম দেওয়া হলো — সদস্যের ফোনে পুশ গেছে')));
      _load();
    }
  }

  Widget _chip(String label, bool on, VoidCallback tap, {Key? key}) {
    final c = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: key,
        label: Text(label, style: text(13.5, weight: FontWeight.w600, color: on ? Colors.white : c.ink)),
        selected: on,
        showCheckmark: false,
        selectedColor: c.brand,
        backgroundColor: c.card,
        side: BorderSide(color: on ? c.brand : c.line),
        onSelected: (_) => tap(),
      ),
    );
  }

  Widget _growthCard() {
    final c = Palette.of(context);
    final g = _growth;
    if (g == null) return const SizedBox.shrink();
    final st = ((g['stats'] as Map?) ?? const {}).cast<String, dynamic>();
    final rows = ((_daily ? g['days'] : g['months']) as List? ?? const []).cast<Map>();
    final max = rows.fold<int>(1, (a, r) => (r['n'] as num).toInt() > a ? (r['n'] as num).toInt() : a);
    final sources = ((g['sources'] as List?) ?? const []).cast<Map>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        key: const Key('growth'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('নতুন সদস্য', style: text(16, weight: FontWeight.w700, color: c.ink)),
                Text('এ মাসে ${bn(st['month_new'] ?? 0)} · আজ ${bn(st['today_new'] ?? 0)} · ৭ দিনে ${bn(st['week'] ?? 0)}', style: text(12.5, color: c.muted)),
              ]),
            ),
            SegmentedButton<bool>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [ButtonSegment(value: true, label: Text('দৈনিক')), ButtonSegment(value: false, label: Text('মাসিক'))],
              selected: {_daily},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _daily = s.first),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final r in rows)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _set(joined: '${_daily ? r['day'] : r['month']}'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: _daily ? 1 : 3),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if ((r['n'] as num) > 0) Text(bn(r['n']), style: text(9.5, weight: FontWeight.w700, color: c.brand)),
                        Container(
                          height: (r['n'] as num) == 0 ? 2 : 6 + 56 * (r['n'] as num) / max,
                          decoration: BoxDecoration(
                            color: _joined == '${_daily ? r['day'] : r['month']}' ? c.brand : c.brand.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(_daily ? bn(int.parse('${r['day']}'.substring(8))) : ymName('${r['month']}').split(' ').first,
                            maxLines: 1, overflow: TextOverflow.clip, style: text(_daily ? 7.5 : 9, color: c.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Text('এখন প্রিমিয়াম যেখান থেকে', style: text(12.5, color: c.muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in sources)
              _chip('${s['label']} · ${bn(s['n'])}', _src == s['key'], () => _set(src: _src == s['key'] ? '' : '${s['key']}')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final list = _list;
    final joinedLabel = switch (_joined) {
      '' || 'today' || 'week' || 'month' => 'মাস বাছুন',
      _ when _joined.length == 7 => ymName(_joined),
      _ => date(_joined),
    };
    return Column(children: [
      PageHead('সদস্য',
          sub: list == null ? null : '${bn(_count)} জন · $_words',
          action: IconButton(key: const Key('members-pdf'), tooltip: 'PDF', onPressed: _pdf, icon: Icon(Icons.picture_as_pdf_outlined, color: c.brand))),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: 'নাম বা ইমেইল দিয়ে খুঁজুন',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: true,
            fillColor: c.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          _chip('যেকোনো সময়', _joined == '', () => _set(joined: '')),
          _chip('আজ', _joined == 'today', () => _set(joined: 'today'), key: const Key('joined-today')),
          _chip('৭ দিন', _joined == 'week', () => _set(joined: 'week')),
          _chip('এই মাস', _joined == 'month', () => _set(joined: 'month'), key: const Key('joined-month')),
          _chip(joinedLabel, _joined.length >= 7, _pickMonth),
        ]),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final (k, l) in [('', 'সবাই'), ('pro', 'প্রিমিয়াম'), ('trial', 'ট্রায়াল'), ('free', 'ফ্রি'), ('expired', 'মেয়াদ শেষ'), ('waiting', 'অপেক্ষায়')]) _chip(l, _status == k, () => _set(status: k)),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_load(), _loadGrowth()]);
          },
          child: list == null
              ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  _growthCard(),
                  OutlinedButton.icon(
                    key: const Key('heirs-open'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeirClaimsPage(api: widget.api, guard: widget.guard))),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('উত্তরাধিকারের অনুরোধ'),
                  ),
                  const SizedBox(height: 8),
                  if (list.isEmpty) const Empty(Icons.person_search_outlined, 'কাউকে পাওয়া যায়নি', 'অন্য দিন বা মাস বেছে দেখুন, অথবা “যেকোনো সময়”।'),
                  for (final m in list) ...[_row(m), const SizedBox(height: 8)],
                  if (list.length < _count)
                    Center(
                      child: TextButton(
                        onPressed: _more ? null : () => _load(more: true),
                        child: Text(_more ? 'আনছি…' : 'আরও দেখুন (${bn(_count - list.length)} জন বাকি)'),
                      ),
                    ),
                ]),
        ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> m) {
    final c = Palette.of(context);
    final name = '${m['name']}'.isEmpty ? '${m['email']}' : '${m['name']}';
    final pic = '${m['picture']}';
    final src = '${m['source_label'] ?? ''}';
    final showSrc = src.isNotEmpty && src != '—' && m['status'] != 'free';
    return CardBox(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: () => _open(m),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: pic.startsWith('https://') ? Image.network(pic, width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initial(name)) : _initial(name),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text(15, weight: FontWeight.w600, color: c.ink)),
            Text('${m['email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text(13, color: c.muted)),
            Text(['যোগ ${date('${m['joined']}')}', if (showSrc) src].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: text(12, color: c.muted)),
          ]),
        ),
        statusPill(context, '${m['status']}'),
      ]),
    );
  }

  Widget _initial(String name) {
    final c = Palette.of(context);
    return Container(
      width: 42,
      height: 42,
      color: c.tint,
      alignment: Alignment.center,
      child: Text(name.characters.first.toUpperCase(), style: text(16, weight: FontWeight.w700, color: c.brand)),
    );
  }
}

// ── মতামত: one inbox per member ──

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.api, required this.guard, required this.refresh});
  final Api api;
  final Guard guard;
  final ValueNotifier<int> refresh;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  String _status = 'open';
  List<Map<String, dynamic>>? _list;

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final l = await widget.guard(() => widget.api.inbox(_status));
    if (l != null && mounted) setState(() => _list = l);
  }

  Future<void> _open(Map<String, dynamic> g) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberInboxPage(api: widget.api, guard: widget.guard, memberKey: '${g['key']}')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final list = _list;
    return Column(children: [
      const PageHead('মতামত', sub: 'প্রতিটি সদস্যের সব কথা এক জায়গায়'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'open', label: Text('খোলা')), ButtonSegment(value: 'done', label: Text('শেষ')), ButtonSegment(value: 'all', label: Text('সব'))],
            selected: {_status},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() {
                _status = s.first;
                _list = null;
              });
              _load();
            },
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: list == null
              ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))])
              : list.isEmpty
                  ? ListView(children: const [Empty(Icons.forum_outlined, 'এখানে কিছু নেই', 'সদস্যরা নতুন সুবিধা চাইলে বা সমস্যা জানালে পুশ নোটিফিকেশন আসবে।')])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final g = list[i];
                        final name = '${g['name']}'.isEmpty ? '${g['email']}' : '${g['name']}';
                        final last = g['last'] as Map?;
                        final fresh = (g['new'] as num? ?? 0).toInt();
                        final kinds = ((g['kind_labels'] as List?) ?? const []).cast<Object>();
                        return CardBox(
                          onTap: () => _open(g),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text(15.5, weight: FontWeight.w700, color: c.ink))),
                              Text(ago('${g['updated']}'), style: text(12.5, color: c.muted)),
                              if (fresh > 0) ...[
                                const SizedBox(width: 8),
                                Badge(label: Text(bn(fresh)), backgroundColor: c.amber),
                              ],
                            ]),
                            if (last != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text('${last['from'] == 'admin' ? 'আমরা: ' : ''}${last['text']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: text(14, color: c.ink, height: 1.45)),
                              ),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              for (final k in kinds) Pill('$k', k == 'সমস্যা' ? c.rose : c.green, k == 'সমস্যা' ? c.roseTint : c.tint),
                              Text('${bn(g['threads'])}টা কথোপকথন', style: text(12.5, color: c.muted)),
                            ]),
                          ]),
                        );
                      },
                    ),
        ),
      ),
    ]);
  }
}

/// One member: every conversation in one chat; a reply goes to the newest open one.
class MemberInboxPage extends StatefulWidget {
  const MemberInboxPage({super.key, required this.api, required this.guard, required this.memberKey, this.picker});
  final Api api;
  final Guard guard;
  final String memberKey;

  /// Picks a photo or PDF: (name, bytes), or null. Tests pass their own.
  final Future<(String, Uint8List)?> Function()? picker;

  @override
  State<MemberInboxPage> createState() => _MemberInboxPageState();
}

class _MemberInboxPageState extends State<MemberInboxPage> {
  final _text = TextEditingController();
  Map<String, dynamic>? _one;
  (String, Uint8List)? _file;
  bool _busy = false;
  final _images = <int, Future<Uint8List?>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await widget.guard(() => widget.api.inboxOne(widget.memberKey));
    if (d != null && mounted) setState(() => _one = d);
  }

  Future<(String, Uint8List)?> _pick() async {
    if (widget.picker != null) return widget.picker!();
    const types = XTypeGroup(label: 'ছবি বা PDF', extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'], mimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);
    final x = await openFile(acceptedTypeGroups: [types]);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ফাইলটা অনেক বড় — ৫ MB পর্যন্ত')));
      return null;
    }
    return (x.name, bytes);
  }

  Future<void> _send() async {
    final one = _one;
    final t = _text.text.trim();
    if (one == null || (t.isEmpty && _file == null)) return;
    setState(() => _busy = true);
    final ok = await widget.guard(() async {
      await widget.api.replyFeedback((one['reply_to'] as num).toInt(), t, fileName: _file?.$1, bytes: _file?.$2);
      return true;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) {
      _text.clear();
      _file = null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('উত্তর গেছে — সদস্যের ফোনে নোটিফিকেশন')));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final one = _one;
    final msgs = ((one?['messages'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final threads = {for (final t in ((one?['threads'] as List?) ?? const []).cast<Map>()) (t['id'] as num).toInt(): t};
    final name = one == null ? 'মতামত' : ('${one['name']}'.isEmpty ? '${one['email']}' : '${one['name']}');
    final children = <Widget>[];
    var thread = -1;
    for (final m in msgs) {
      final tid = (m['thread'] as num).toInt();
      if (tid != thread) {
        thread = tid;
        final t = threads[tid];
        children.add(Center(
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(999)),
            child: Text('${t?['kind_label'] ?? ''} · ${date('${t?['created']}')}${t?['status'] == 'done' ? ' · শেষ' : ''}', style: text(12, color: c.muted)),
          ),
        ));
      }
      children.add(_bubble(m));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: text(18, weight: FontWeight.w700, color: c.ink)),
        actions: [
          if (one != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'copy') {
                  await Clipboard.setData(ClipboardData(text: '${one['email']}'));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ইমেইল কপি হয়েছে')));
                  return;
                }
                await widget.guard(() async {
                  await widget.api.setInbox(widget.memberKey, v);
                  return true;
                });
                if (v == 'done' && context.mounted) {
                  Navigator.of(context).pop();
                } else {
                  await _load();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: one['open'] == true ? 'done' : 'open', child: Text(one['open'] == true ? 'সব শেষ হিসেবে রাখুন' : 'আবার খুলুন')),
                const PopupMenuItem(value: 'copy', child: Text('ইমেইল কপি')),
              ],
            ),
        ],
      ),
      body: Column(children: [
        if (one != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Align(alignment: Alignment.centerLeft, child: Text('${one['email']}', style: text(13, color: c.muted)))),
        Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 14), children: children))),
        if (_file != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(alignment: Alignment.centerLeft, child: InputChip(label: Text(_file!.$1), onDeleted: () => setState(() => _file = null))),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
            decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              IconButton(
                key: const Key('admin-attach'),
                tooltip: 'ছবি বা PDF',
                onPressed: _busy
                    ? null
                    : () async {
                        final p = await _pick();
                        if (p != null && mounted) setState(() => _file = p);
                      },
                icon: Icon(Icons.attach_file_rounded, color: c.muted),
              ),
              Expanded(
                child: TextField(
                  key: const Key('admin-reply'),
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: 'উত্তর লিখুন…', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(key: const Key('admin-send'), onPressed: _busy ? null : _send, icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final c = Palette.of(context);
    final us = m['from'] == 'admin';
    final file = m['file'] as Map?;
    final id = (m['id'] as num).toInt();
    return Align(
      alignment: us ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(color: us ? c.tint : c.card, border: us ? null : Border.all(color: c.line), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ('${m['text']}'.isNotEmpty) SelectableText('${m['text']}', style: text(15, color: c.ink, height: 1.5)),
          if (file != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: '${file['mime']}'.startsWith('image/')
                  ? FutureBuilder<Uint8List?>(
                      future: _images.putIfAbsent(id, () => widget.guard(() => widget.api.feedbackFile(id))),
                      builder: (_, snap) => snap.data == null
                          ? const SizedBox(width: 120, height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                          : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(snap.data!, width: 220, fit: BoxFit.cover)),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.picture_as_pdf_outlined, color: c.brand),
                      const SizedBox(width: 6),
                      Flexible(child: Text('${file['name']} — ওয়েবসাইটের অ্যাডমিন পাতায় খুলুন', style: text(13.5, color: c.ink))),
                    ]),
            ),
          const SizedBox(height: 2),
          Text('${us ? ('${m['admin']}'.isEmpty ? 'আমরা' : m['admin']) : 'সদস্য'} · ${ago('${m['created']}')}', style: text(11.5, color: c.muted)),
        ]),
      ),
    );
  }
}

// ── নোটিফিকেশন: what goes, when, how many a day ──

class NoticeStatsPage extends StatefulWidget {
  const NoticeStatsPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<NoticeStatsPage> createState() => _NoticeStatsPageState();
}

class _NoticeStatsPageState extends State<NoticeStatsPage> {
  Map<String, dynamic>? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.guard(() => widget.api.noticeStats());
    if (s != null && mounted) setState(() => _s = s);
  }

  String _hm(String hm) {
    final p = hm.split(':');
    final h = int.tryParse(p.first) ?? 0;
    final part = h < 12 ? 'সকাল' : (h < 15 ? 'দুপুর' : (h < 18 ? 'বিকেল' : (h < 20 ? 'সন্ধ্যা' : 'রাত')));
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$part ${bn(h12)}:${bn(p.length > 1 ? p[1] : '00')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final s = _s;
    final groups = ((s?['groups'] as Map?) ?? const {}).cast<String, dynamic>();
    final days = ((s?['days'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final up = ((s?['upcoming'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final max = days.fold<int>(1, (a, d) => (d['total'] as num).toInt() > a ? (d['total'] as num).toInt() : a);
    final widgets = <Widget>[];
    if (s != null) {
      widgets.add(CardBox(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(s['push_on'] == true ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: s['push_on'] == true ? c.brand : c.rose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s['push_on'] == true
                  ? 'শর্ত ছাড়া নোটিফিকেশন সার্ভার নিজে ঠিক সময়ে পুশ করে। পুশ পাচ্ছে ${bn(s['phones'])}টি ফোন, নতুন অ্যাপে ${bn(s['phones_new_app'])}টি।'
                  : 'Firebase বসানো নেই — সার্ভার পুশ করতে পারছে না। ওয়েবসাইটের সেটিংসে বসান।',
              style: text(13.5, color: c.ink, height: 1.5),
            ),
          ),
        ]),
      ));
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: FilledButton.tonalIcon(
          key: const Key('notice-today'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoticeDayPage(api: widget.api, guard: widget.guard, day: ''))),
          icon: const Icon(Icons.today_rounded),
          label: const Text('অ্যাপ থেকে কোন কোন নোটিফিকেশন যায়, কে কতগুলো'),
        ),
      ));
      widgets.add(Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 8), child: Text('সামনের ৭ দিন', style: text(16, weight: FontWeight.w700, color: c.ink))));
      if (up.isEmpty) widgets.add(Text('চালু থাকা কোনো নোটিফিকেশন সামনের ৭ দিনে পড়েনি।', style: text(13.5, color: c.muted)));
      var day = '';
      for (final u in up) {
        if (u['day'] != day) {
          day = '${u['day']}';
          widgets.add(Padding(padding: const EdgeInsets.fromLTRB(2, 8, 2, 4), child: Text(date(day), style: text(13.5, weight: FontWeight.w700, color: c.muted))));
        }
        final push = u['how'] == 'push';
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: CardBox(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              SizedBox(width: 82, child: Text(_hm('${u['time']}'), style: text(13.5, weight: FontWeight.w700, color: c.ink))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${u['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text(14.5, weight: FontWeight.w600, color: c.ink)),
                  Text('${u['audience']} · ${push ? '${bn(u['phones'] ?? 0)}টি ফোনে পুশ' : '${u['how_label']}'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: text(12, color: c.muted)),
                ]),
              ),
              Icon(push ? Icons.send_rounded : Icons.phone_android_rounded, size: 18, color: push ? c.brand : c.muted),
            ]),
          ),
        ));
      }
      widgets.add(Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 4), child: Text('দিনে কতটি', style: text(16, weight: FontWeight.w700, color: c.ink))));
      widgets.add(Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 8), child: Text('সব সদস্য মিলে, ধরন অনুযায়ী — কোনো দিনে চাপলে সেদিনের তালিকা আর কে কতগুলো পেয়েছেন।', style: text(12.5, color: c.muted))));
      for (final d in days) {
        final parts = [for (final g in groups.entries) if ((d[g.key] as num? ?? 0) > 0) '${g.value} ${bn(d[g.key])}'];
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: CardBox(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoticeDayPage(api: widget.api, guard: widget.guard, day: '${d['day']}'))),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(width: 92, child: Text(date('${d['day']}'), style: text(13.5, weight: FontWeight.w600, color: c.ink))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: (d['total'] as num) / max, minHeight: 10, backgroundColor: c.ground, color: c.brand.withValues(alpha: 0.55)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(bn(d['total']), style: text(14, weight: FontWeight.w700, color: c.ink)),
              ]),
              if (parts.isNotEmpty || (d['failed'] as num? ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text([...parts, if ((d['failed'] as num? ?? 0) > 0) 'পৌঁছায়নি ${bn(d['failed'])}'].join(' · '), style: text(12, color: (d['failed'] as num? ?? 0) > 0 ? c.rose : c.muted)),
                ),
            ]),
          ),
        ));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('কী কখন যাচ্ছে')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: widgets)),
    );
  }
}

/// One day: which notifications went (or will go), what, when, to how many;
/// and how many each member gets — members' own reminders only as a kind.
class NoticeDayPage extends StatefulWidget {
  const NoticeDayPage({super.key, required this.api, required this.guard, required this.day});
  final Api api;
  final Guard guard;
  final String day;

  @override
  State<NoticeDayPage> createState() => _NoticeDayPageState();
}

class _NoticeDayPageState extends State<NoticeDayPage> {
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.guard(() => widget.api.noticeDay(widget.day));
    if (d != null && mounted) setState(() => _d = d);
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final d = _d;
    final items = ((d?['app'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final members = ((d?['members'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final rem = (d?['reminders'] as Map?) ?? const {};
    String hm(String t) {
      final p = t.split(':');
      final h = int.tryParse(p.first) ?? 0;
      final part = h < 12 ? 'সকাল' : (h < 15 ? 'দুপুর' : (h < 18 ? 'বিকেল' : (h < 20 ? 'সন্ধ্যা' : 'রাত')));
      return '$part ${bn(h % 12 == 0 ? 12 : h % 12)}:${bn(p.length > 1 ? p[1] : '00')}';
    }
    Widget tag(String t, Color bg, Color fg) => Container(
          margin: const EdgeInsets.only(right: 6, top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
          child: Text(t, style: text(11, weight: FontWeight.w600, color: fg)),
        );
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? 'নোটিফিকেশন' : (widget.day.isEmpty ? 'আজ' : date('${d['day']}')))),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                Text('অ্যাপ থেকে কোন কোন নোটিফিকেশন যায়', style: text(17, weight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 4),
                Text('এদিন মোট ${bn(d['total'])}টি · ${bn(d['people'])} জন সদস্য · জনপ্রতি গড় ${bn(d['avg'])}, সর্বোচ্চ ${bn(d['max'])}', style: text(13.5, weight: FontWeight.w600, color: c.ink)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
                  child: Text('${(d['rules'] as Map?)?['daily'] ?? ''} চুপ থাকার সময় ${(d['rules'] as Map?)?['quiet'] ?? ''}।', style: text(12.5, color: c.muted)),
                ),
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Opacity(
                      opacity: (it['count'] as num? ?? 0) == 0 && (it['failed'] as num? ?? 0) == 0 ? 0.55 : 1,
                      child: CardBox(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(
                            width: 82,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(((it['times'] as List?) ?? const []).isNotEmpty ? [for (final t in (it['times'] as List)) hm('$t')].join('\n') : ('${it['at']}'.isEmpty ? '—' : hm('${it['at']}')),
                                  style: text(12.5, weight: FontWeight.w700, color: c.ink)),
                              if ((it['ahead'] as num? ?? 0) > 0) Text('${bn(it['ahead'])}টি আসবে', style: text(11, color: c.amber)),
                            ]),
                          ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${it['label']}', style: text(14.5, weight: FontWeight.w600, color: c.ink)),
                              Text('“${it['sample']}”', maxLines: 1, overflow: TextOverflow.ellipsis, style: text(12.5, color: c.ink)),
                              Text('${it['when']}', style: text(12, color: c.muted)),
                              Wrap(children: [
                                if (it['cap'] == false) tag('সীমার বাইরে', c.line, c.muted),
                                if (it['by'] == 'server') tag('সার্ভার থেকে পুশ', c.brand.withValues(alpha: .12), c.brand),
                                if (it['off'] == true) tag('চালু করলে', c.line, c.muted),
                                if ((it['failed'] as num? ?? 0) > 0) tag('পৌঁছায়নি ${bn(it['failed'])}', c.rose.withValues(alpha: .12), c.rose),
                              ]),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text((it['count'] as num? ?? 0) == 0 ? '—' : bn(it['count']), style: text(16, weight: FontWeight.w700, color: c.brand)),
                            if ((it['count'] as num? ?? 0) > 0) Text('${bn(it['people'])} জন', style: text(11.5, color: c.muted)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: CardBox(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('সদস্যের নিজের রিমাইন্ডার', style: text(14.5, weight: FontWeight.w600, color: c.ink)),
                          Text('অ্যাপ নিজে পাঠায় না — সদস্য যা রাখেন; লেখা ফোনেই থাকে।', style: text(12, color: c.muted)),
                        ]),
                      ),
                      Text('${bn(rem['count'] ?? 0)} · ${bn(rem['people'] ?? 0)} জন', style: text(13.5, weight: FontWeight.w700, color: c.muted)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Text('কে দিনে কতগুলো পাচ্ছে', style: text(16, weight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 8),
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: CardBox(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${m['name']}'.isEmpty ? '${m['email']}' : '${m['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text(14.5, weight: FontWeight.w600, color: c.ink)),
                            Text('${m['email']}${(m['reminders'] as num? ?? 0) > 0 ? ' · নিজের রিমাইন্ডার ${bn(m['reminders'])}' : ''}${(m['failed'] as num? ?? 0) > 0 ? ' · পৌঁছায়নি ${bn(m['failed'])}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text(12, color: c.muted)),
                          ]),
                        ),
                        Text('${bn(m['count'])}টি', style: text(15, weight: FontWeight.w700, color: c.ink)),
                      ]),
                    ),
                  ),
              ]),
            ),
    );
  }
}

// ── বিকাশ মেলানো ──

/// The card on the payments page.
class BkashCard extends StatelessWidget {
  const BkashCard({super.key, required this.api, required this.guard, required this.info, required this.onChanged});
  final Api api;
  final Guard guard;
  final Map<String, dynamic>? info;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final i = info;
    final auto = i?['auto'] == true;
    final last = i?['last_sms'];
    return CardBox(
      key: const Key('bkash-card'),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BkashPage(api: api, guard: guard)));
        onChanged();
      },
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: const Color(0xFFD12053), borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Text('বিকাশ', style: text(11, weight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('বিকাশ মেলানো', style: text(15.5, weight: FontWeight.w700, color: c.ink)),
            Text(
              i == null
                  ? '…'
                  : [auto ? 'নিজে থেকে অনুমোদন চালু' : 'নিজে থেকে অনুমোদন বন্ধ', i['phone_set'] == true ? (last == null ? 'ফোন যুক্ত' : 'শেষ SMS ${ago('$last')}') : 'ফোন যুক্ত হয়নি'].join(' · '),
              style: text(12.5, color: c.muted),
            ),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: c.muted),
      ]),
    );
  }
}

class BkashPage extends StatefulWidget {
  const BkashPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<BkashPage> createState() => _BkashPageState();
}

class _BkashPageState extends State<BkashPage> {
  Map<String, dynamic>? _server;
  Map<String, dynamic> _phone = const {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.guard(() => widget.api.bkash());
    final p = await Device.bkashStatus();
    if ((p['queued'] as num? ?? 0) > 0) await Device.bkashFlush();
    if (mounted) {
      setState(() {
        if (s != null) _server = s;
        _phone = p;
      });
    }
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// This phone becomes the payment-SIM phone: SMS permission, a key of its own.
  Future<void> _turnOn() async {
    final c = Palette.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('এই ফোনে চালু করবেন?'),
        content: Text(
          'শুধু সেই ফোনে চালু করুন, যাতে পেমেন্টের বিকাশ সিম আছে।\n\nবিকাশের “You have received …” মেসেজ এলে শুধু টাকা, TrxID, কোন নম্বর থেকে আর কখন — এই চারটা সার্ভারে যাবে। মেসেজের বাকি লেখা, ব্যালান্স বা অন্য কোনো মেসেজ যাবে না।\n\nAndroid SMS পড়ার অনুমতি চাইবে।',
          style: text(14.5, color: c.ink, height: 1.55),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('চালু করুন'))],
      ),
    );
    if (yes != true) return;
    setState(() => _busy = true);
    final allowed = await Device.bkashPermission();
    if (!allowed) {
      if (mounted) {
        setState(() => _busy = false);
        _say('SMS-এর অনুমতি দেওয়া হয়নি — ফোনের Settings › Apps › MA অ্যাডমিন › Permissions থেকে দিন');
      }
      return;
    }
    final key = await widget.guard(() => widget.api.bkashKey());
    if (key != null && key.isNotEmpty) await Device.bkashSetup(key, widget.api.base);
    if (!mounted) return;
    setState(() => _busy = false);
    _say('চালু হলো — এখন থেকে বিকাশের টাকা এলে নিজে থেকে মিলবে');
    await _scan(silent: true);
    await _load();
  }

  Future<void> _turnOff() async {
    await Device.bkashOff();
    if (mounted) _say('এই ফোনে বন্ধ হলো');
    await _load();
  }

  /// The last 3 days' bKash payments from this phone's inbox (missed while off).
  Future<void> _scan({bool silent = false}) async {
    setState(() => _busy = true);
    final items = await Device.bkashScan(3);
    var n = 0;
    for (final it in items) {
      final r = await widget.guard(() => widget.api.bkashManual(it));
      if (r != null) n++;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!silent) _say(items.isEmpty ? 'গত ৩ দিনে বিকাশে টাকা আসার কোনো মেসেজ পাওয়া যায়নি' : '${bn(n)}টা মেলানো হলো');
    await _load();
  }

  Future<void> _paste() async {
    final c = Palette.of(context);
    final t = TextEditingController();
    // A bKash message just copied is filled in (never waited on for long).
    try {
      final clip = await Clipboard.getData('text/plain').timeout(const Duration(milliseconds: 500));
      if (clip?.text != null && parseBkash(clip!.text!) != null) t.text = clip.text!;
    } catch (_) {}
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('বিকাশের SMS পেস্ট করুন', style: text(20, weight: FontWeight.w700, color: c.ink)),
          Text('ফোনেই পড়া হয় — শুধু টাকা, TrxID, নম্বর আর সময় সার্ভারে যায়।', style: text(13.5, color: c.muted, height: 1.5)),
          const SizedBox(height: 10),
          TextField(key: const Key('bkash-paste'), controller: t, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: 'You have received Tk …', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('মেলান'))),
        ]),
      ),
    );
    if (ok != true) return;
    final p = parseBkash(t.text);
    if (p == null) {
      _say('TrxID বা টাকা পড়া যায়নি — বিকাশের “You have received …” মেসেজটা পুরোটা দিন');
      return;
    }
    final r = await widget.guard(() => widget.api.bkashManual(p));
    if (r != null && mounted) _say('TrxID ${p['trx']} · ${taka(p['amount'] as int)} — $r');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final s = _server;
    final on = _phone['on'] == true;
    final received = ((s?['received'] as List?) ?? const []).cast<Map<String, dynamic>>();
    Color tone(String st) => st == 'matched' ? c.green : (st == 'new' ? c.muted : (st == 'found' ? c.amber : c.rose));
    return Scaffold(
      appBar: AppBar(title: const Text('বিকাশ মেলানো')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                Text('নিজে থেকে অনুমোদন চালু থাকলে: TrxID মিললে, অন্তত প্ল্যানের দাম এলে, আর এই ফোন বিকাশের ব্যালেন্স মিলিয়ে মেসেজটা আসল বলে নিশ্চিত হলে প্রিমিয়াম চালু হয়। ব্যালেন্সের অঙ্ক এই ফোনেই থাকে। না মিললে আপনার অনুমোদনের জন্য অপেক্ষা করে।',
                    style: text(13.5, color: c.muted, height: 1.55)),
                const SizedBox(height: 12),
                CardBox(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  child: SwitchListTile(
                    key: const Key('bkash-auto'),
                    contentPadding: EdgeInsets.zero,
                    value: s['auto'] == true,
                    onChanged: (v) async {
                      final r = await widget.guard(() => widget.api.setBkashAuto(v));
                      if (r != null && mounted) setState(() => _server = r);
                    },
                    title: Text('নিজে থেকে অনুমোদন', style: text(15, weight: FontWeight.w700, color: c.ink)),
                    subtitle: Text(s['auto'] == true ? 'TrxID আর বিকাশের ব্যালেন্স দুটোই মিললে প্রিমিয়াম চালু; ভুয়া SMS আপনার জন্য অপেক্ষা করবে' : 'মিললেও আপনি দেখে অনুমোদন দেবেন', style: text(12.5, color: c.muted)),
                  ),
                ),
                const SizedBox(height: 10),
                CardBox(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(on ? Icons.sim_card_rounded : Icons.sim_card_outlined, color: on ? c.brand : c.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(on ? 'এই ফোনে চালু' : 'এই ফোনে বন্ধ', style: text(15, weight: FontWeight.w700, color: c.ink)),
                          Text(
                            on
                                ? [if (_phone['last'] != null) 'শেষ পাঠানো ${ago('${_phone['last']}')}', if ((_phone['queued'] as num? ?? 0) > 0) 'ইন্টারনেট এলে যাবে ${bn(_phone['queued'])}টা'].join(' · ').ifEmpty('বিকাশের টাকা এলে নিজে থেকে মিলবে')
                                : (s['phone_set'] == true ? 'অন্য একটা ফোনে চালু আছে${s['last_sms'] == null ? '' : ' · শেষ SMS ${ago('${s['last_sms']}')}'}' : 'যে ফোনে পেমেন্টের বিকাশ সিম আছে, সেটাতে চালু করুন'),
                            style: text(12.5, color: c.muted),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: on
                            ? OutlinedButton(onPressed: _busy ? null : _turnOff, child: const Text('এই ফোনে বন্ধ'))
                            : FilledButton(key: const Key('bkash-on'), onPressed: _busy ? null : _turnOn, child: const Text('এই ফোনে চালু করুন')),
                      ),
                      if (on) ...[
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _scan(), child: const Text('গত ৩ দিন মেলান'))),
                      ],
                    ]),
                  ]),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(key: const Key('bkash-paste-open'), onPressed: _paste, icon: const Icon(Icons.content_paste_rounded), label: const Text('বিকাশের SMS পেস্ট করে মেলান')),
                Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 8), child: Text('বিকাশে আসা টাকা', style: text(16, weight: FontWeight.w700, color: c.ink))),
                if (received.isEmpty) Text('এখনো কিছু আসেনি।', style: text(13.5, color: c.muted)),
                for (final r in received)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: CardBox(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${taka((r['amount'] as num).toInt())} · ${r['trx']}', style: text(14.5, weight: FontWeight.w700, color: c.ink)),
                            Text(['${r['sender']}'.isEmpty ? 'নম্বর নেই' : '${r['sender']}', ago('${r['at']}'), if (r['source'] == 'manual') 'হাতে'].join(' · '), style: text(12, color: c.muted)),
                          ]),
                        ),
                        Text('${r['status_label']}', style: text(12, weight: FontWeight.w700, color: tone('${r['status']}'))),
                      ]),
                    ),
                  ),
              ]),
            ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

// ── হিসাব ──

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  Map<String, dynamic>? _f;
  String? _error;
  String _month = '';
  String _kind = '';
  String _cat = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await widget.api.finance(month: _month, kind: _kind, category: _cat);
      if (mounted) {
        setState(() {
          _f = f;
          _error = null;
          if (_month.isEmpty) _month = '${(f['month_lines'] as Map?)?['month'] ?? (f['month'] as Map?)?['month'] ?? ''}';
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _shift(int by) {
    final y = int.parse(_month.substring(0, 4));
    final m = int.parse(_month.substring(5, 7)) + by;
    final d = DateTime(y, m);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  String get _now {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  Future<void> _addEntry() async {
    final c = Palette.of(context);
    final cats = ((_f?['categories'] as Map?) ?? const {}).cast<String, dynamic>();
    var kind = 'expense';
    final cat = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var day = _month == _now ? DateTime.now() : DateTime(int.parse(_month.substring(0, 4)), int.parse(_month.substring(5, 7)));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('আয় বা খরচ লিখুন', style: text(21, weight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'expense', label: Text('খরচ')), ButtonSegment(value: 'income', label: Text('আয়'))],
                selected: {kind},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setS(() => kind = v.first),
              ),
              const SizedBox(height: 10),
              TextField(key: const Key('fin-amount'), controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'টাকা', prefixText: '৳ ', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final x in ((cats[kind] as List?) ?? const []).cast<Object>()) ActionChip(label: Text('$x'), onPressed: () => setS(() => cat.text = '$x')),
              ]),
              const SizedBox(height: 10),
              TextField(key: const Key('fin-cat'), controller: cat, decoration: const InputDecoration(labelText: 'খাত', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: day, firstDate: DateTime(2024), lastDate: DateTime.now());
                  if (d != null) setS(() => day = d);
                },
                icon: const Icon(Icons.event_rounded),
                label: Text('তারিখ: ${bn(day.day)} ${ymName('${day.year}-${day.month.toString().padLeft(2, '0')}')}'),
              ),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'বিবরণ (ঐচ্ছিক)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('রাখুন'))),
            ]),
          ),
        ),
      ),
    );
    final n = int.tryParse(amount.text.trim()) ?? 0;
    if (ok != true || n <= 0) return;
    final iso = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    await widget.guard(() => widget.api.addFinanceEntry(kind: kind, category: cat.text.trim(), amount: n, date: iso, note: note.text.trim()));
    _load();
  }

  Future<void> _addInvestor() async {
    final c = Palette.of(context);
    final name = TextEditingController();
    final contact = TextEditingController();
    final amount = TextEditingController();
    final share = TextEditingController();
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('বিনিয়োগকারী', style: text(21, weight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 12),
            TextField(key: const Key('inv-name'), controller: name, decoration: const InputDecoration(labelText: 'নাম', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: contact, decoration: const InputDecoration(labelText: 'মোবাইল/ইমেইল', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(key: const Key('inv-amount'), controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'বিনিয়োগ', prefixText: '৳ ', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: share, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'শেয়ার (%)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'নোট', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('যোগ করুন'))),
          ]),
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final d = DateTime.now();
    await widget.guard(() => widget.api.addInvestor(
        name: name.text.trim(), contact: contact.text.trim(), amount: int.tryParse(amount.text.trim()) ?? 0, share: share.text.trim(),
        date: '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}', note: note.text.trim()));
    _load();
  }

  Future<void> _delete(String which, Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('মুছে ফেলবেন?'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('মুছুন'))],
      ),
    );
    if (yes != true) return;
    await widget.guard(() => widget.api.deleteFinance(which, (row['id'] as num).toInt()));
    _load();
  }

  String _signed(num n) => '${n < 0 ? '−' : ''}${taka(n.abs().toInt())}';

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final f = _f;
    num v(Map? m, String k) => (m?[k] as num?) ?? 0;
    final lines = ((f?['month_lines'] as Map?) ?? const {}).cast<String, dynamic>();
    final rows = ((lines['lines'] as List?) ?? (f?['entries'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final cats = ((lines['categories'] as List?) ?? const []).cast<Object>();
    final sum = ((lines['sum'] as Map?) ?? const {}).cast<String, dynamic>();
    Widget fig(String label, num value, String sub, Color color) => Expanded(
          child: Container(
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: text(12.5, weight: FontWeight.w600, color: c.muted)),
                      Text(_signed(value), style: text(20, weight: FontWeight.w700, color: color)),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: text(11.5, color: c.muted)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label),
            selected: on,
            showCheckmark: false,
            onSelected: (_) => tap(),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('হিসাব'), actions: [IconButton(key: const Key('inv-add'), tooltip: 'বিনিয়োগকারী যোগ', onPressed: _addInvestor, icon: const Icon(Icons.person_add_alt_1_outlined))]),
      floatingActionButton: f == null ? null : FloatingActionButton.extended(key: const Key('fin-add'), onPressed: _addEntry, icon: const Icon(Icons.add_rounded), label: const Text('আয়/খরচ')),
      body: _error != null
          ? ListView(children: [Empty(Icons.lock_outline_rounded, 'দেখা যাচ্ছে না', _error!)])
          : f == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
                    if (_month.length == 7)
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        IconButton(
                            key: const Key('fin-prev'),
                            onPressed: () {
                              setState(() => _month = _shift(-1));
                              _load();
                            },
                            icon: const Icon(Icons.chevron_left_rounded)),
                        Text(ymName(_month), style: text(17, weight: FontWeight.w700, color: c.ink)),
                        IconButton(
                            onPressed: _month == _now
                                ? null
                                : () {
                                    setState(() => _month = _shift(1));
                                    _load();
                                  },
                            icon: const Icon(Icons.chevron_right_rounded)),
                      ]),
                    Row(children: [
                      fig('এ মাসে আয়', v(f['month'], 'income'), 'পেমেন্ট ${_signed(v(f['month'], 'payments'))}', c.green),
                      const SizedBox(width: 10),
                      fig('এ মাসে ব্যয়', v(f['month'], 'expense'), 'AI ${_signed(v(f['month'], 'ai'))}', c.amber),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      fig(v(f['month'], 'net') < 0 ? 'এ মাসে লস' : 'এ মাসে লাভ', v(f['month'], 'net'), 'শুরু থেকে ${_signed(v(f['all'], 'net'))}', v(f['month'], 'net') < 0 ? c.rose : c.green),
                      const SizedBox(width: 10),
                      fig('হাতে থাকার কথা', v(f, 'cash'), 'বিনিয়োগ ${_signed(v(f, 'invested'))}', const Color(0xFF1D4ED8)),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 44,
                      child: ListView(scrollDirection: Axis.horizontal, children: [
                        for (final (k, l) in [('', 'সব'), ('income', 'আয়'), ('expense', 'খরচ')])
                          chip(l, _kind == k, () {
                            setState(() => _kind = k);
                            _load();
                          }),
                        if (cats.isNotEmpty)
                          PopupMenuButton<String>(
                            onSelected: (x) {
                              setState(() => _cat = x);
                              _load();
                            },
                            itemBuilder: (_) => [const PopupMenuItem(value: '', child: Text('সব খাত')), for (final x in cats) PopupMenuItem(value: '$x', child: Text('$x'))],
                            child: Chip(label: Text(_cat.isEmpty ? 'খাত ▾' : '$_cat ▾')),
                          ),
                      ]),
                    ),
                    if (sum.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
                        child: Text('দেখানো: +${taka(v(sum, 'income').toInt())}  −${taka(v(sum, 'expense').toInt())}', style: text(12.5, color: c.muted)),
                      ),
                    if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('এই মাসে কিছু নেই।', textAlign: TextAlign.center, style: text(14, color: c.muted))),
                    for (final e in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CardBox(
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${e['category']}', style: text(15, weight: FontWeight.w700, color: c.ink)),
                                Text([date('${e['date'] ?? e['on_date']}'), if ('${e['note'] ?? ''}'.isNotEmpty) '${e['note']}', if (e['auto'] == true) 'নিজে থেকে'].join(' · '),
                                    maxLines: 2, overflow: TextOverflow.ellipsis, style: text(12.5, color: c.muted)),
                              ]),
                            ),
                            Text('${e['kind'] == 'income' ? '+' : '−'}${taka(v(e, 'amount').toInt())}', style: text(15, weight: FontWeight.w700, color: e['kind'] == 'income' ? c.green : c.amber)),
                            if (e['auto'] != true && (e['id'] as num? ?? 0) > 0)
                              IconButton(tooltip: 'মুছুন', onPressed: () => _delete('entry', e), icon: Icon(Icons.delete_outline_rounded, color: c.muted))
                            else
                              const SizedBox(width: 12),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text('মাস অনুযায়ী', style: text(16, weight: FontWeight.w700, color: c.ink)),
                    const SizedBox(height: 8),
                    for (final m in ((f['months'] as List?) ?? const []).cast<Map>())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CardBox(
                          padding: const EdgeInsets.all(14),
                          onTap: () {
                            setState(() => _month = '${m['month']}');
                            _load();
                          },
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(ymName('${m['month']}'), style: text(15, weight: FontWeight.w700, color: c.ink)),
                                Text('আয় ${_signed(v(m, 'income'))} · ব্যয় ${_signed(v(m, 'expense'))}', style: text(12.5, color: c.muted)),
                              ]),
                            ),
                            Text(_signed(v(m, 'net')), style: text(16, weight: FontWeight.w700, color: v(m, 'net') < 0 ? c.rose : c.green)),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text('বিনিয়োগকারী', style: text(16, weight: FontWeight.w700, color: c.ink)),
                    const SizedBox(height: 8),
                    for (final i in ((f['investors'] as List?) ?? const []).cast<Map<String, dynamic>>())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CardBox(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${i['name']}', style: text(15, weight: FontWeight.w700, color: c.ink)),
                                Text([if ('${i['contact'] ?? ''}'.isNotEmpty) '${i['contact']}', date('${i['on_date']}'), if ('${i['share'] ?? ''}'.isNotEmpty) 'শেয়ার ${bn(i['share'])}%'].join(' · '),
                                    style: text(12.5, color: c.muted)),
                              ]),
                            ),
                            Text(_signed(v(i, 'amount')), style: text(15, weight: FontWeight.w700, color: c.ink)),
                            IconButton(tooltip: 'মুছুন', onPressed: () => _delete('investor', i), icon: Icon(Icons.delete_outline_rounded, color: c.muted)),
                          ]),
                        ),
                      ),
                  ]),
                ),
    );
  }
}
