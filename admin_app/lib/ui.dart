import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import 'api.dart';

typedef Guard = Future<T?> Function<T>(Future<T> Function() job);

// ── Look: My Assistant's green, Bangla type, light and dark ──

class Palette {
  const Palette._(this.dark);
  final bool dark;
  static Palette of(BuildContext c) => Palette._(Theme.of(c).brightness == Brightness.dark);

  Color get brand => const Color(0xFF0E7A5F);
  Color get brandDark => const Color(0xFF0A5C47);
  Color get tint => dark ? const Color(0xFF12352C) : const Color(0xFFE7F4EF);
  Color get ground => dark ? const Color(0xFF0E1013) : const Color(0xFFF6F7F9);
  Color get card => dark ? const Color(0xFF1A1D22) : Colors.white;
  Color get ink => dark ? const Color(0xFFE8EAED) : const Color(0xFF111827);
  Color get muted => dark ? const Color(0xFF9AA1AC) : const Color(0xFF6B7280);
  Color get line => dark ? const Color(0xFF2B3038) : const Color(0xFFE5E7EB);
  Color get amber => dark ? const Color(0xFFF59E0B) : const Color(0xFFB45309);
  Color get amberTint => dark ? const Color(0xFF3A2A12) : const Color(0xFFFEF3E2);
  Color get rose => dark ? const Color(0xFFFB7185) : const Color(0xFFBE123C);
  Color get roseTint => dark ? const Color(0xFF3A1820) : const Color(0xFFFFF1F2);
  Color get green => dark ? const Color(0xFF34D399) : const Color(0xFF0A5C47);
}

ThemeData adminTheme(Brightness b) {
  final p = Palette._(b == Brightness.dark);
  return ThemeData(
    brightness: b,
    fontFamily: 'Hind',
    colorScheme: ColorScheme.fromSeed(seedColor: p.brand, brightness: b, surface: p.card),
    scaffoldBackgroundColor: p.ground,
    navigationBarTheme: NavigationBarThemeData(backgroundColor: p.card, indicatorColor: p.tint),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

TextStyle text(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
    TextStyle(fontFamily: 'Hind', fontSize: size, fontWeight: weight, color: color, height: height);

String bn(Object n) => '$n'.replaceAllMapped(RegExp('[0-9]'), (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)]);

/// "১,২৮৪".
String count(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return bn(out);
}

String taka(int n) => '৳${count(n)}';

const _months = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];

String date(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  return '${bn(d.day)} ${_months[d.month - 1]} ${bn(d.year)}';
}

String ago(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  final s = DateTime.now().difference(d);
  if (s.inMinutes < 2) return 'এইমাত্র';
  if (s.inHours < 1) return '${bn(s.inMinutes)} মিনিট আগে';
  if (s.inDays < 1) return '${bn(s.inHours)} ঘণ্টা আগে';
  if (s.inDays < 60) return '${bn(s.inDays)} দিন আগে';
  return date(iso);
}

class PageHead extends StatelessWidget {
  const PageHead(this.title, {super.key, this.sub, this.action});
  final String title;
  final String? sub;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: text(26, weight: FontWeight.w700, color: c.ink)),
            if (sub != null) Text(sub!, style: text(14, color: c.muted)),
          ]),
        ),
        ?action,
      ]),
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, this.fg, this.bg, {super.key});
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: text(12.5, weight: FontWeight.w600, color: fg)),
      );
}

Pill statusPill(BuildContext context, String status) {
  final c = Palette.of(context);
  return switch (status) {
    'pro' || 'approved' => Pill(status == 'pro' ? 'প্রো' : 'অনুমোদিত', c.green, c.tint),
    'trial' => Pill('ট্রায়াল', c.amber, c.amberTint),
    'pending' => Pill('দেখার অপেক্ষায়', c.amber, c.amberTint),
    'expired' || 'rejected' => Pill(status == 'expired' ? 'মেয়াদ শেষ' : 'বাতিল', c.rose, c.roseTint),
    'waiting' => Pill('লগইনের অপেক্ষায়', const Color(0xFF1D4ED8), const Color(0xFFEEF2FF)),
    _ => Pill('ফ্রি', c.muted, c.ground),
  };
}

class Empty extends StatelessWidget {
  const Empty(this.icon, this.title, this.sub, {super.key});
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      child: Column(children: [
        Container(width: 68, height: 68, decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(22)), child: Icon(icon, size: 32, color: c.brand)),
        const SizedBox(height: 14),
        Text(title, style: text(17, weight: FontWeight.w700, color: c.ink), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(sub, style: text(14, color: c.muted, height: 1.5), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── সারাংশ ──

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api, required this.guard, required this.refresh, required this.onPending, required this.onOpenPayments, this.onFeedback});
  final Api api;
  final Guard guard;
  final ValueNotifier<int> refresh;
  final ValueChanged<int> onPending;
  final VoidCallback onOpenPayments;
  final ValueChanged<int>? onFeedback;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _s;

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
    final s = await widget.guard(() => widget.api.summary());
    if (s != null && mounted) {
      setState(() => _s = s);
      widget.onPending((s['pending_payments'] as num?)?.toInt() ?? 0);
      widget.onFeedback?.call((s['feedback_new'] as num?)?.toInt() ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final s = _s;
    int n(String k) => (s?[k] as num?)?.toInt() ?? 0;
    Widget fig(String label, String value, String sub) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: text(13, color: const Color(0xFFC9EBDD))),
              Text(value, style: text(26, weight: FontWeight.w700, color: Colors.white, height: 1.2)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: text(12, color: const Color(0xFFA7DCC8))),
            ]),
          ),
        );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0E7A5F), Color(0xFF0A5C47)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Text('My Assistant অ্যাডমিন', style: text(17, weight: FontWeight.w700, color: Colors.white)),
            ]),
            const SizedBox(height: 14),
            if (s == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Colors.white)))
            else ...[
              Row(children: [fig('মোট সদস্য', count(n('members')), 'এই সপ্তাহে নতুন ${bn(n('new_week'))}'), const SizedBox(width: 10), fig('প্রো', count(n('pro')), 'নতুন মতামত ${bn(n('feedback_new'))}')]),
              const SizedBox(height: 10),
              Row(children: [fig('এই মাসে আয়', taka(n('income_month')), 'ওয়েবসাইটের পেমেন্ট'), const SizedBox(width: 10), fig('সক্রিয়', count(n('active_week')), 'গত ৭ দিনে · আজ AI ${bn(n('ai_today'))}${s['ai_cost_today_usd'] == null ? '' : ' · ৳${bn(((s['ai_cost_today_usd'] as num) * ((s['usd_bdt'] as num?) ?? 122)).toStringAsFixed(2))}'}')]),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        if (s != null)
          CardBox(
            onTap: widget.onOpenPayments,
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: n('pending_payments') > 0 ? c.amberTint : c.tint, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.payments_outlined, color: n('pending_payments') > 0 ? c.amber : c.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n('pending_payments') > 0 ? '${bn(n('pending_payments'))}টা পেমেন্ট দেখার অপেক্ষায়' : 'সব পেমেন্ট দেখা হয়েছে',
                      style: text(16, weight: FontWeight.w700, color: c.ink)),
                  Text(n('pending_payments') > 0 ? 'মিলিয়ে দেখে অনুমোদন দিন' : 'নতুন এলে পুশ নোটিফিকেশন আসবে', style: text(13.5, color: c.muted)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ]),
          ),
      ]),
    );
  }
}

// ── পেমেন্ট ──

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key, required this.api, required this.guard, required this.refresh});
  final Api api;
  final Guard guard;
  final ValueNotifier<int> refresh;

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  String _status = 'pending';
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
    final l = await widget.guard(() => widget.api.payments(_status));
    if (l != null && mounted) setState(() => _list = l);
  }

  Future<void> _decide(Map<String, dynamic> p, bool approve) async {
    final c = Palette.of(context);
    final reason = TextEditingController();
    var tell = true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(approve ? 'পেমেন্ট মিলেছে?' : 'পেমেন্ট বাতিল করবেন?', style: text(21, weight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 6),
            Text(
                approve
                    ? 'আগে নিজের ${p['method']} অ্যাকাউন্টে দেখে নিন — ${p['sender']} থেকে ${taka((p['amount'] as num).toInt())} এসেছে, TrxID ${p['trx']}।'
                    : '${p['email']} · ${p['method']} · ${p['trx']}',
                style: text(14.5, color: c.muted, height: 1.55)),
            if (approve) ...[
              const SizedBox(height: 10),
              Text('${p['email']}-এ ${p['plan']} প্রো চালু হবে, আর তাঁকে ইমেইল ও পুশে জানানো হবে।', style: text(14.5, color: c.ink, height: 1.5)),
            ] else ...[
              const SizedBox(height: 12),
              TextField(controller: reason, decoration: const InputDecoration(labelText: 'কারণ (ঐচ্ছিক)', border: OutlineInputBorder())),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: tell, onChanged: (v) => setS(() => tell = v ?? true), title: const Text('ইমেইলে জানিয়ে দিন')),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: approve ? c.brand : c.rose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(approve ? 'মিলেছে — প্রো দিন' : 'বাতিল করুন', style: text(16, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final msg = await widget.guard(() => widget.api.decide((p['id'] as num).toInt(), approve: approve, reason: reason.text, tell: tell));
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      widget.refresh.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final list = _list;
    return Column(children: [
      const PageHead('পেমেন্ট', sub: 'ওয়েবসাইট থেকে জমা'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('অপেক্ষায়')),
              ButtonSegment(value: 'approved', label: Text('অনুমোদিত')),
              ButtonSegment(value: 'rejected', label: Text('বাতিল')),
            ],
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
                  ? ListView(children: [Empty(Icons.task_alt_rounded, _status == 'pending' ? 'দেখার মতো কিছু নেই' : 'এখানে কিছু নেই', 'নতুন পেমেন্ট এলে পুশ নোটিফিকেশন আসবে।')])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        return CardBox(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(taka((p['amount'] as num).toInt()), style: text(22, weight: FontWeight.w700, color: c.ink)),
                              const SizedBox(width: 8),
                              Text('${p['plan']}', style: text(14, color: c.muted)),
                              const Spacer(),
                              statusPill(context, '${p['status']}'),
                            ]),
                            const SizedBox(height: 8),
                            _kv(context, 'মাধ্যম', '${p['method']} · ${p['sender']}'),
                            _kv(context, 'TrxID', '${p['trx']}', copy: true),
                            _kv(context, 'প্রো পাবেন', '${p['email']}'),
                            if ('${p['name']}'.isNotEmpty) _kv(context, 'নাম', '${p['name']}'),
                            if ('${p['note']}'.isNotEmpty) _kv(context, 'নোট', '${p['note']}'),
                            if ('${p['reason']}'.isNotEmpty) _kv(context, 'কারণ', '${p['reason']}'),
                            _kv(context, 'জমা', ago('${p['created']}')),
                            if ('${p['reviewed_by']}'.isNotEmpty) _kv(context, 'দেখেছেন', '${p['reviewed_by']}'),
                            if (p['status'] == 'pending') ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: OutlinedButton(onPressed: () => _decide(p, false), child: const Text('বাতিল'))),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: FilledButton(onPressed: () => _decide(p, true), child: const Text('অনুমোদন'))),
                              ]),
                            ],
                          ]),
                        );
                      },
                    ),
        ),
      ),
    ]);
  }

  Widget _kv(BuildContext context, String k, String v, {bool copy = false}) {
    final c = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 82, child: Text(k, style: text(13.5, color: c.muted))),
        Expanded(child: SelectableText(v, style: text(14.5, weight: copy ? FontWeight.w700 : FontWeight.w500, color: c.ink))),
        if (copy)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: v));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কপি হয়েছে')));
            },
            child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.copy_rounded, size: 18, color: c.muted)),
          ),
      ]),
    );
  }
}

// ── সদস্য ──

class MembersPage extends StatefulWidget {
  const MembersPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await widget.guard(() => widget.api.members(q: _q.text.trim()));
    if (l != null && mounted) setState(() => _list = l);
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
              if (m['pro_until'] != null) Pill('প্রো পর্যন্ত ${date('${m['pro_until']}')}', c.ink, c.ground),
              Pill('যোগ ${date('${m['joined']}')}', c.muted, c.ground),
              Pill('শেষ দেখা ${ago('${m['last_seen']}')}', c.muted, c.ground),
              if ('${m['version']}'.isNotEmpty) Pill('${m['version']}', c.muted, c.ground),
            ]),
            if ('${m['note']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('নোট: ${m['note']}', style: text(14, color: c.ink))),
            const SizedBox(height: 16),
            Text('প্রো যোগ করুন (চলমান মেয়াদের পরে যোগ হবে)', style: text(14, weight: FontWeight.w600, color: c.ink)),
            const SizedBox(height: 8),
            Row(children: [
              for (final (d, l) in [(30, '+১ মাস'), (90, '+৩ মাস'), (365, '+১ বছর')]) ...[
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, d), child: Text(l))),
                if (d != 365) const SizedBox(width: 8),
              ],
            ]),
            if (m['status'] == 'pro' || m['status'] == 'trial')
              TextButton(onPressed: () => Navigator.pop(ctx, -1), style: TextButton.styleFrom(foregroundColor: c.rose), child: const Text('প্রো এখনই বন্ধ করুন')),
          ]),
        ),
      ),
    );
    if (days == null) return;
    final id = (m['id'] as num).toInt();
    final r = await widget.guard(() => widget.api.changeMember(id, days: days > 0 ? days : 0, stop: days < 0));
    if (r != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(days < 0 ? 'প্রো বন্ধ করা হলো' : 'প্রো দেওয়া হলো — সদস্যের ফোনে পুশ গেছে')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final list = _list;
    return Column(children: [
      const PageHead('সদস্য'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: 'নাম বা ইমেইল দিয়ে খুঁজুন',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: c.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: list == null
              ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))])
              : list.isEmpty
                  ? ListView(children: const [Empty(Icons.person_search_outlined, 'কাউকে পাওয়া যায়নি', 'অ্যাপে কেউ Google দিয়ে লগইন করলেই এখানে আসবেন।')])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final m = list[i];
                        final name = '${m['name']}'.isEmpty ? '${m['email']}' : '${m['name']}';
                        final pic = '${m['picture']}';
                        return CardBox(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          onTap: () => _open(m),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: pic.startsWith('https://')
                                  ? Image.network(pic, width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initial(context, name))
                                  : _initial(context, name),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text(15, weight: FontWeight.w600, color: c.ink)),
                                Text('${m['email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text(13, color: c.muted)),
                              ]),
                            ),
                            statusPill(context, '${m['status']}'),
                          ]),
                        );
                      },
                    ),
        ),
      ),
    ]);
  }

  Widget _initial(BuildContext context, String name) {
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

// ── নোটিফিকেশন ──

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.api, required this.guard, required this.onSignOut, required this.onFingerprint});
  final Api api;
  final Guard guard;
  final VoidCallback onSignOut;
  final VoidCallback onFingerprint;

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<Map<String, dynamic>>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await widget.guard(() => widget.api.notices());
    if (l != null && mounted) setState(() => _list = l);
  }

  Future<void> _pushNow() async {
    final c = Palette.of(context);
    final title = TextEditingController();
    final body = TextEditingController();
    var aud = 'all';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('এখনই পুশ পাঠান', style: text(21, weight: FontWeight.w700, color: c.ink)),
            Text('সদস্যদের ফোনে সাথে সাথে যাবে। নিয়মিত (প্রতিদিন/সাপ্তাহিক) নোটিফিকেশন ওয়েবসাইটের অ্যাডমিন পাতা থেকে বানান।', style: text(13.5, color: c.muted, height: 1.5)),
            const SizedBox(height: 12),
            TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'শিরোনাম', border: OutlineInputBorder())),
            TextField(controller: body, maxLength: 400, maxLines: 2, decoration: const InputDecoration(labelText: 'লেখা', border: OutlineInputBorder())),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('সবাই')),
                ButtonSegment(value: 'pro', label: Text('প্রো')),
                ButtonSegment(value: 'free', label: Text('ফ্রি')),
              ],
              selected: {aud},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setS(() => aud = s.first),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('পাঠান'))),
          ]),
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    final n = await widget.guard(() => widget.api.pushNow(title.text.trim(), body.text.trim(), aud));
    if (n != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${bn(n)}টা ফোনে পাঠানো হলো')));
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final list = _list;
    const kinds = {'once': 'একবার', 'daily': 'প্রতিদিন', 'weekly': 'প্রতি সপ্তাহে'};
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(onPressed: _pushNow, icon: const Icon(Icons.send_rounded), label: const Text('এখনই পুশ')),
      body: Column(children: [
        PageHead('নোটিফিকেশন',
            sub: 'ফোনে নিয়মিত যা যায়',
            action: PopupMenuButton<int>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 2, child: Text('আঙুলের ছাপে খোলা: চালু/বন্ধ')),
                PopupMenuItem(value: 1, child: Text('লগআউট')),
              ],
              onSelected: (v) => v == 1 ? widget.onSignOut() : widget.onFingerprint(),
            )),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: list == null
                ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))])
                : list.isEmpty
                    ? ListView(children: const [Empty(Icons.notifications_none_rounded, 'কোনো নিয়মিত নোটিফিকেশন নেই', 'ওয়েবসাইটের My Assistant › নোটিফিকেশন থেকে বানান।')])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final n = list[i];
                          final on = '${n['active']}' == '1';
                          return CardBox(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${n['title']}', style: text(15.5, weight: FontWeight.w700, color: on ? c.ink : c.muted)),
                                  if ('${n['body']}'.isNotEmpty) Text('${n['body']}', style: text(13.5, color: c.muted, height: 1.45)),
                                  const SizedBox(height: 6),
                                  Text('${kinds[n['kind']] ?? ''} · ${bn(n['at_time'])}', style: text(12.5, color: c.muted)),
                                ]),
                              ),
                              Switch(
                                value: on,
                                onChanged: (_) async {
                                  await widget.guard(() => widget.api.toggleNotice(int.parse('${n['id']}')));
                                  _load();
                                },
                              ),
                            ]),
                          );
                        },
                      ),
          ),
        ),
      ]),
    );
  }
}

// ── মতামত ──

/// Members' feature wishes and problems, as conversations. Open one to read
/// it, see photos, answer (with a photo or PDF) or mark it done. Nothing is
/// kept on this phone.
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
    final l = await widget.guard(() => widget.api.feedback(_status));
    if (l != null && mounted) setState(() => _list = l);
  }

  Future<void> _open(Map<String, dynamic> f) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedbackThreadPage(api: widget.api, guard: widget.guard, id: (f['id'] as num).toInt())));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final list = _list;
    return Column(children: [
      const PageHead('মতামত', sub: 'অ্যাপ থেকে সদস্যদের লেখা'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'open', label: Text('খোলা')),
              ButtonSegment(value: 'done', label: Text('শেষ')),
              ButtonSegment(value: 'all', label: Text('সব')),
            ],
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
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final f = list[i];
                        final st = '${f['status']}';
                        final kind = '${f['kind']}';
                        final last = f['last'] as Map?;
                        final count = (f['count'] as num?)?.toInt() ?? 1;
                        return CardBox(
                          onTap: () => _open(f),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Pill('${f['kind_label']}', kind == 'problem' ? c.rose : c.green, kind == 'problem' ? c.roseTint : c.tint),
                              const SizedBox(width: 6),
                              if (st == 'new') Pill('নতুন', c.amber, c.amberTint) else if (st == 'done') Pill('শেষ', c.green, c.tint),
                              const Spacer(),
                              Text(ago('${f['updated'] ?? f['created']}'), style: text(12.5, color: c.muted)),
                            ]),
                            const SizedBox(height: 8),
                            Text('${'${f['name']}'.isEmpty ? f['email'] : f['name']}', style: text(15, weight: FontWeight.w700, color: c.ink)),
                            Text('${f['text']}'.isEmpty ? '📎 সংযুক্তি' : '${f['text']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: text(14.5, color: c.ink, height: 1.5)),
                            if (count > 1 && last != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${last['from'] == 'admin' ? 'আমরা' : 'সদস্য'}: ${last['text']} · ${bn(count)}টা বার্তা',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: text(13, color: c.muted)),
                              ),
                          ]),
                        );
                      },
                    ),
        ),
      ),
    ]);
  }
}

/// One conversation with a member.
class FeedbackThreadPage extends StatefulWidget {
  const FeedbackThreadPage({super.key, required this.api, required this.guard, required this.id, this.picker});
  final Api api;
  final Guard guard;
  final int id;

  /// Picks a photo or PDF: (name, bytes), or null. Tests pass their own.
  final Future<(String, Uint8List)?> Function()? picker;

  @override
  State<FeedbackThreadPage> createState() => _FeedbackThreadPageState();
}

class _FeedbackThreadPageState extends State<FeedbackThreadPage> {
  final _text = TextEditingController();
  Map<String, dynamic>? _f;
  List<Map<String, dynamic>> _msgs = const [];
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
    final d = await widget.guard(() => widget.api.feedbackThread(widget.id));
    if (d != null && mounted) {
      setState(() {
        _f = (d['feedback'] as Map).cast<String, dynamic>();
        _msgs = (d['messages'] as List).cast<Map<String, dynamic>>();
      });
    }
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
    final t = _text.text.trim();
    if (t.isEmpty && _file == null) return;
    setState(() => _busy = true);
    final ok = await widget.guard(() async {
      await widget.api.replyFeedback(widget.id, t, fileName: _file?.$1, bytes: _file?.$2);
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

  Future<void> _status(String st) async {
    await widget.guard(() async {
      await widget.api.setFeedback(widget.id, st);
      return true;
    });
    if (!mounted) return;
    if (st == 'delete') {
      Navigator.of(context).pop();
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final f = _f;
    return Scaffold(
      appBar: AppBar(
        title: Text(f == null ? 'মতামত' : ('${f['name']}'.isEmpty ? '${f['email']}' : '${f['name']}'), style: text(18, weight: FontWeight.w700, color: c.ink)),
        actions: [
          if (f != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'copy') {
                  await Clipboard.setData(ClipboardData(text: '${f['email']}'));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ইমেইল কপি হয়েছে')));
                } else {
                  await _status(v);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: f['status'] == 'done' ? 'new' : 'done', child: Text(f['status'] == 'done' ? 'আবার খুলুন' : 'শেষ হিসেবে রাখুন')),
                const PopupMenuItem(value: 'copy', child: Text('ইমেইল কপি')),
                const PopupMenuItem(value: 'delete', child: Text('মুছে ফেলুন')),
              ],
            ),
        ],
      ),
      body: Column(children: [
        if (f != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(children: [
              Pill('${f['kind_label']}', f['kind'] == 'problem' ? c.rose : c.green, f['kind'] == 'problem' ? c.roseTint : c.tint),
              const SizedBox(width: 8),
              Expanded(child: Text('${f['email']}${'${f['version']}'.isEmpty ? '' : ' · v${f['version']}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text(13, color: c.muted))),
            ]),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 14), children: [
              for (final m in _msgs) _bubble(context, m),
            ]),
          ),
        ),
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

  Widget _bubble(BuildContext context, Map<String, dynamic> m) {
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
