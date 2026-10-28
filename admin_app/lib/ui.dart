import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'pages2.dart';

export 'pages2.dart';

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
    'pro' || 'approved' => Pill(status == 'pro' ? 'প্রিমিয়াম' : 'অনুমোদিত', c.green, c.tint),
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
              Row(children: [fig('মোট সদস্য', count(n('members')), 'এই সপ্তাহে নতুন ${bn(n('new_week'))}'), const SizedBox(width: 10), fig('প্রিমিয়াম', count(n('pro')), 'নতুন মতামত ${bn(n('feedback_new'))}')]),
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
        const SizedBox(height: 10),
        CardBox(
          key: const Key('open-errors'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ErrorsPage(api: widget.api, guard: widget.guard))),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.bug_report_outlined, color: c.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('সমস্যার লগ', style: text(16, weight: FontWeight.w700, color: c.ink)),
                Text('সদস্যদের ফোন থেকে সরাসরি — ক্র্যাশ আর সমস্যা', style: text(13.5, color: c.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ]),
        ),
        const SizedBox(height: 10),
        CardBox(
          key: const Key('open-finance'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FinancePage(api: widget.api, guard: widget.guard))),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.account_balance_outlined, color: c.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('হিসাব', style: text(16, weight: FontWeight.w700, color: c.ink)),
                Text('আয়, ব্যয়, লাভ/লস আর বিনিয়োগকারী', style: text(13.5, color: c.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ]),
        ),
        const SizedBox(height: 10),
        CardBox(
          key: const Key('open-blood'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BloodPage(api: widget.api, guard: widget.guard))),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.bloodtype_outlined, color: c.rose),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('রক্তের গ্রুপ', style: text(16, weight: FontWeight.w700, color: c.ink)),
                Text('বিপদে খোঁজার জন্য — গ্রুপ, জেলা, নম্বর, শেষ রক্তদান', style: text(13.5, color: c.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ]),
        ),
      ]),
    );
  }
}

// ── হিসাব (site owner only) ──

/// সমস্যার লগ, as on the site: the kind, the cleaned first line, how many
/// times, the version and when; tap for the code places.
class ErrorsPage extends StatefulWidget {
  const ErrorsPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<ErrorsPage> createState() => _ErrorsPageState();
}

class _ErrorsPageState extends State<ErrorsPage> {
  List<Map<String, dynamic>>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.guard(() => widget.api.errors());
    if (r != null && mounted) setState(() => _rows = r);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('সব লগ মুছবেন?'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('মুছুন'))],
      ),
    );
    if (ok != true) return;
    await widget.guard(() => widget.api.clearErrors());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('সমস্যার লগ'), actions: [
        IconButton(
            key: const Key('open-traces'),
            tooltip: 'সদস্যদের পাঠানো লগ',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TracesPage(api: widget.api, guard: widget.guard))),
            icon: const Icon(Icons.receipt_long_outlined)),
        if (rows != null && rows.isNotEmpty) IconButton(key: const Key('errors-clear'), tooltip: 'সব মুছুন', onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined)),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: rows == null
            ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))])
            : rows.isEmpty
                ? ListView(children: const [Empty(Icons.bug_report_outlined, 'কোনো সমস্যা আসেনি', 'সদস্যদের ফোনে ক্র্যাশ বা সমস্যা হলে কয়েক সেকেন্ডের মধ্যে এখানে আসে — সদস্যের লেখা বা গোপন কিছু আসে না।')])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      return CardBox(
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text('${r['meaning'] ?? r['kind']}', style: text(15, weight: FontWeight.w700, color: c.ink)),
                            subtitle: Text('${r['level'] == 'problem' ? 'সমস্যা' : 'ক্র্যাশ'} · ${bn(r['count'] ?? 1)} বার · ${r['kind']} ${r['message']}\n${r['version']} · ${date('${r['last_at']}')}${'${r['email'] ?? ''}'.isEmpty ? '' : ' · ${r['email']}'}',
                                style: text(12.5, color: r['level'] == 'problem' ? c.muted : c.rose)),
                            children: [
                              Align(alignment: Alignment.centerLeft, child: SelectableText('${r['stack']}', style: text(12, color: c.ink))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// সমস্যা খোঁজার লগ that members chose to send (their conversations about
/// passwords, health, medicines or messages never come).
class TracesPage extends StatefulWidget {
  const TracesPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<TracesPage> createState() => _TracesPageState();
}

class _TracesPageState extends State<TracesPage> {
  List<Map<String, dynamic>>? _rows;
  final Map<int, String> _body = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.guard(() => widget.api.traces());
    if (r != null && mounted) setState(() => _rows = r);
  }

  Future<void> _open(int id) async {
    if (_body.containsKey(id)) return;
    final b = await widget.guard(() => widget.api.trace(id));
    if (b != null && mounted) setState(() => _body[id] = b);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('সব পাঠানো লগ মুছবেন?'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('মুছুন'))],
      ),
    );
    if (ok != true) return;
    await widget.guard(() => widget.api.clearTraces());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('সদস্যদের পাঠানো লগ'), actions: [
        if (rows != null && rows.isNotEmpty) IconButton(key: const Key('traces-clear'), tooltip: 'সব মুছুন', onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined)),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: rows == null
            ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))])
            : rows.isEmpty
                ? ListView(children: const [Empty(Icons.receipt_long_outlined, 'কোনো লগ আসেনি', 'সদস্য অ্যাপের আরও › সমস্যা খোঁজার লগ থেকে পাঠালে এখানে আসে — ৩০ দিন থাকে। পাসওয়ার্ড, স্বাস্থ্য, ওষুধ বা মেসেজের কথোপকথন আসে না, নম্বর লুকানো থাকে।')])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final id = (r['id'] as num).toInt();
                      return CardBox(
                        key: Key('trace-$id'),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            onExpansionChanged: (open) {
                              if (open) _open(id);
                            },
                            title: Text('${bn(r['lines'] ?? 0)} লাইন · ${r['version']}', style: text(15, weight: FontWeight.w700, color: c.ink)),
                            subtitle: Text('${date('${r['at']}')}${'${r['email'] ?? ''}'.isEmpty ? '' : ' · ${r['email']}'}', style: text(12.5, color: c.muted)),
                            children: [
                              Align(alignment: Alignment.centerLeft, child: SelectableText(_body[id] ?? 'খুলছে…', style: text(12, color: c.ink))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// রক্তের গ্রুপ (owner, 28 Oct): members who gave their group, to find blood in an emergency.
class BloodPage extends StatefulWidget {
  const BloodPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<BloodPage> createState() => _BloodPageState();
}

class _BloodPageState extends State<BloodPage> {
  static const groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String _group = '';
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.guard(() => widget.api.bloodGroups(_group));
    if (r != null && mounted) setState(() => _data = r);
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final rows = [for (final m in (_data?['members'] as List? ?? const [])) (m as Map).cast<String, dynamic>()];
    final counts = (_data?['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text('রক্তের গ্রুপ')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(label: const Text('সব'), selected: _group.isEmpty, onSelected: (_) => setState(() {
              _group = '';
              _load();
            })),
            for (final g in groups)
              ChoiceChip(
                key: Key('blood-$g'),
                label: Text('$g · ${bn(counts[g] ?? 0)}'),
                selected: _group == g,
                onSelected: (_) => setState(() {
                  _group = g;
                  _load();
                }),
              ),
          ]),
          const SizedBox(height: 12),
          if (_data == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            const Empty(Icons.bloodtype_outlined, 'কেউ নেই', 'সদস্য অ্যাপে নিজের রক্তের গ্রুপ দিলে এখানে আসে — নম্বর আর শেষ রক্তদানের তারিখসহ।')
          else
            for (final r in rows) ...[
              CardBox(
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(14)),
                    child: Text('${r['blood']}', style: text(16, weight: FontWeight.w800, color: c.rose)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['name']}'.isEmpty ? '${r['email']}' : '${r['name']}', style: text(15, weight: FontWeight.w700, color: c.ink)),
                      SelectableText('${r['phone']}${'${r['district']}'.isEmpty ? '' : ' · ${r['district']}'}', style: text(13.5, color: c.ink)),
                      Text(r['last_unknown'] == true || r['last_donated'] == null ? 'শেষ রক্তদান: মনে নেই' : 'শেষ রক্তদান: ${date('${r['last_donated']}')}', style: text(12.5, color: c.muted)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
        ]),
      ),
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
  Map<String, dynamic>? _bkash;

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
    try {
      final b = await widget.api.bkash();
      if (mounted) setState(() => _bkash = b);
    } on ApiError catch (_) {}
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
              Text('${p['email']}-এ ${p['plan']} প্রিমিয়াম চালু হবে, আর তাঁকে ইমেইল ও পুশে জানানো হবে।', style: text(14.5, color: c.ink, height: 1.5)),
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
                child: Text(approve ? 'মিলেছে — প্রিমিয়াম দিন' : 'বাতিল করুন', style: text(16, weight: FontWeight.w700, color: Colors.white)),
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
              : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length + 1 + (list.isEmpty ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == 0) return BkashCard(api: widget.api, guard: widget.guard, info: _bkash, onChanged: _load);
                        if (list.isEmpty) return Empty(Icons.task_alt_rounded, _status == 'pending' ? 'দেখার মতো কিছু নেই' : 'এখানে কিছু নেই', 'নতুন পেমেন্ট এলে পুশ নোটিফিকেশন আসবে।');
                        final p = list[i - 1];
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
                            _kv(context, 'প্রিমিয়াম পাবেন', '${p['email']}'),
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

// ── নোটিফিকেশন ── (সদস্য, মতামত, হিসাব: pages2.dart)

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

  void _openLog() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoticeStatsPage(api: widget.api, guard: widget.guard)));

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
                ButtonSegment(value: 'pro', label: Text('প্রিমিয়াম')),
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
                PopupMenuItem(value: 3, child: Text('কী কখন যাচ্ছে, দিনে কতটি')),
                PopupMenuItem(value: 2, child: Text('আঙুলের ছাপে খোলা: চালু/বন্ধ')),
                PopupMenuItem(value: 1, child: Text('লগআউট')),
              ],
              onSelected: (v) => v == 3 ? _openLog() : (v == 1 ? widget.onSignOut() : widget.onFingerprint()),
            )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: CardBox(
            key: const Key('notice-log'),
            onTap: _openLog,
            child: Row(children: [
              Icon(Icons.receipt_long_outlined, color: c.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('কী কখন যাচ্ছে, দিনে কতটি', style: text(15.5, weight: FontWeight.w700, color: c.ink)),
                  Text('সামনের ৭ দিনের নোটিফিকেশন আর গত ১৪ দিনের হিসাব', style: text(13, color: c.muted)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ]),
          ),
        ),
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


/// উত্তরাধিকার: deaths reported by an heir the member chose, with the
/// certificate — the same list and decision as on the site's tab.
class HeirClaimsPage extends StatefulWidget {
  const HeirClaimsPage({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<HeirClaimsPage> createState() => _HeirClaimsPageState();
}

class _HeirClaimsPageState extends State<HeirClaimsPage> {
  List<Map<String, dynamic>>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await widget.guard(() => widget.api.heirClaims());
    if (l != null && mounted) setState(() => _list = l);
  }

  Future<void> _decide(Map<String, dynamic> cl, String action) async {
    final note = await showDialog<String>(context: context, builder: (_) => _NoteDialog(approve: action == 'approve'));
    if (note == null) return;
    final r = await widget.guard(() async {
      await widget.api.decideClaim((cl['id'] as num).toInt(), action, note);
      return true;
    });
    if (r == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'approve' ? 'মানা হলো — সদস্যকে জানানো হয়েছে, ১৪ দিন পর খুলবে' : 'মানা হয়নি — উত্তরাধিকারীকে জানানো হয়েছে')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final list = _list;
    const names = {'review': 'যাচাই বাকি', 'waiting': '১৪ দিনের অপেক্ষা', 'open': 'খোলা', 'rejected': 'মানা হয়নি', 'cancelled': 'বাতিল'};
    return Scaffold(
      appBar: AppBar(title: const Text('উত্তরাধিকারের অনুরোধ')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: list == null
            ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))])
            : list.isEmpty
                ? ListView(children: const [Empty(Icons.shield_outlined, 'কোনো অনুরোধ নেই', 'সদস্য যাঁকে উত্তরাধিকারী বেছেছেন, তিনি মৃত্যু সনদসহ খবর দিলে এখানে আসবে।')])
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                    Text('সদস্যের বেছে রাখা অংশ তালাবদ্ধ — আমরা খুলতে পারি না; মানলে সদস্যের ফোন আর ইমেইলে জানানো হয়, ১৪ দিনের মধ্যে তিনি বাতিল না করলে উত্তরাধিকারী দেখতে পান।', style: text(13, color: c.muted)),
                    const SizedBox(height: 10),
                    for (final cl in list) ...[
                      CardBox(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('${(cl['owner'] as Map)['name'] ?? ''}'.isEmpty ? '${(cl['owner'] as Map)['email']}' : '${(cl['owner'] as Map)['name']}', style: text(17, weight: FontWeight.w700, color: c.ink))),
                            Pill(names['${cl['status']}'] ?? '${cl['status']}', cl['status'] == 'review' ? c.amber : c.muted, c.ground),
                          ]),
                          Text('${(cl['owner'] as Map)['email']}', style: text(13, color: c.muted)),
                          const SizedBox(height: 6),
                          Text('খবর দিয়েছেন: ${(cl['heir'] as Map)['name']} · ${(cl['heir'] as Map)['email']}${'${(cl['heir'] as Map)['relation']}'.isEmpty ? '' : ' · সম্পর্ক: ${(cl['heir'] as Map)['relation']}'}', style: text(14, color: c.ink)),
                          Text(ago('${cl['created']}'), style: text(12.5, color: c.muted)),
                          if ('${cl['note']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${cl['note']}', style: text(14, color: c.ink))),
                          if (cl['has_file'] == true)
                            FutureBuilder<(Uint8List, String)>(
                              future: widget.api.claimFile((cl['id'] as num).toInt()),
                              builder: (context, snap) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: snap.data == null
                                    ? Text(snap.hasError ? 'কাগজ খোলা গেল না' : 'কাগজ আনছি…', style: text(13, color: c.muted))
                                    : snap.data!.$2.startsWith('image/')
                                        ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(snap.data!.$1, height: 220, fit: BoxFit.contain))
                                        : Text('কাগজ: PDF (${bn((snap.data!.$1.length / 1024).round())} KB) — সাইটের পাতায় খুলুন', style: text(13, color: c.muted)),
                              ),
                            ),
                          if ('${cl['admin_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('নোট: ${cl['admin_note']}', style: text(13, color: c.muted))),
                          if (cl['status'] == 'review') ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: FilledButton(key: Key('claim-approve-${cl['id']}'), onPressed: () => _decide(cl, 'approve'), child: const Text('কাগজ ঠিক — মানুন'))),
                              const SizedBox(width: 8),
                              Expanded(child: OutlinedButton(onPressed: () => _decide(cl, 'reject'), child: const Text('মানবেন না'))),
                            ]),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ]),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.approve});
  final bool approve;
  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _t = TextEditingController();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.approve ? 'কাগজ ঠিক — মানবেন?' : 'মানবেন না?'),
        content: TextField(controller: _t, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)', hintText: 'যেমন: সনদ মিলেছে / ছবি অস্পষ্ট')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          FilledButton(key: const Key('claim-confirm'), onPressed: () => Navigator.pop(context, _t.text.trim()), child: Text(widget.approve ? 'মানুন' : 'মানবেন না')),
        ],
      );
}
