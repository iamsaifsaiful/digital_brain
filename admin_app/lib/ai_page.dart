// "AI ও বোঝা": what AI costs and where answers come from, the readings to
// check, the on-phone model versions, and the AI settings (step H of the
// 22 Oct 2026 brief). Everything comes from the server; nothing is kept here.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'ui.dart';

class AiPage extends StatelessWidget {
  const AiPage({super.key, required this.api, required this.guard, required this.refresh});
  final Api api;
  final Guard guard;
  final ValueNotifier<int> refresh;

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return DefaultTabController(
      length: 4,
      child: Column(children: [
        const PageHead('AI ও বোঝা', sub: 'খরচ, ফোনে কতটা বোঝে, ভুলগুলো আর সেটিংস'),
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: text(15, weight: FontWeight.w600),
          unselectedLabelColor: c.muted,
          tabs: const [Tab(text: 'সারাংশ'), Tab(text: 'পর্যালোচনা'), Tab(text: 'মডেল'), Tab(text: 'সেটিংস')],
        ),
        Expanded(
          child: TabBarView(children: [
            AiSummary(api: api, guard: guard, refresh: refresh),
            AiReview(api: api, guard: guard),
            AiModels(api: api, guard: guard),
            AiSettings(api: api, guard: guard),
          ]),
        ),
      ]),
    );
  }
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

/// Dollars as taka for the owner ("৳১২.৫০"); tiny sums keep two decimals.
String tk(double usd, double rate) {
  final t = usd * rate;
  if (t >= 100) return taka(t.round());
  return '৳${bn(t.toStringAsFixed(2))}';
}

String pct(double x) => '${bn((x * 100).toStringAsFixed(x < 0.1 ? 1 : 0))}%';

// ── সারাংশ ──

class AiSummary extends StatefulWidget {
  const AiSummary({super.key, required this.api, required this.guard, required this.refresh});
  final Api api;
  final Guard guard;
  final ValueNotifier<int> refresh;

  @override
  State<AiSummary> createState() => _AiSummaryState();
}

class _AiSummaryState extends State<AiSummary> {
  Map<String, dynamic>? _o;

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
    final o = await widget.guard(() => widget.api.aiOverview());
    if (o != null && mounted) setState(() => _o = o);
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final o = _o;
    if (o == null) return const Center(child: CircularProgressIndicator());
    final rate = _d(o['usd_bdt']) > 0 ? _d(o['usd_bdt']) : 122.0;
    double spent(String span) => [for (final r in (o[span] as List? ?? const [])) _d((r as Map)['cost_usd'])].fold(0.0, (a, b) => a + b);
    final budget = (o['budget'] as Map?)?.cast<String, dynamic>() ?? {};
    double cap(String span) => ['free', 'pro'].map((p) => _d((budget[p] as Map?)?[span])).fold(0.0, (a, b) => a + b);
    final src = (o['sources_month'] as Map?)?.cast<String, dynamic>() ?? {};
    // "On" mode: an agreement answered on the phone (the AI not asked); the
    // cloud asked but the rules' reading kept, or the cloud not reachable.
    final agreed = _i(src['nlu_agree']), cloudKept = _i(src['nlu_cloud_rules']), cloudUsed = _i(src['nlu_cloud']), cloudFail = _i(src['nlu_cloud_fail']);
    final phone = _i(src['rules']) + _i(src['local']) + agreed + cloudKept + cloudFail;
    final gem = _i(src['gemini']) + cloudUsed, hai = _i(src['haiku']), son = _i(src['sonnet']), fail = _i(src['failed']);
    final total = phone + gem + hai + son + fail;
    final nlu = (o['nlu'] as Map?)?.cast<String, dynamic>() ?? {};
    final weak = (nlu['weakest'] as List? ?? const []).cast<Map>();
    final shadowSame = _i(src['nlu_same_sure']) + _i(src['nlu_same']);
    final shadowAll = shadowSame + _i(src['nlu_differ_sure']) + _i(src['nlu_differ']);

    Widget money(String label, double usd, double limit) => Expanded(
          child: CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: text(13, color: c.muted)),
              Text(tk(usd, rate), style: text(24, weight: FontWeight.w700, color: c.ink)),
              Text(limit > 0 ? 'বাজেটের ${pct(usd / limit)} (${tk(limit, rate)})' : 'বাজেটের সীমা নেই', style: text(12.5, color: limit > 0 && usd / limit > 0.8 ? c.rose : c.muted)),
            ]),
          ),
        );
    Widget bar(String label, int n, Color color) {
      final share = total == 0 ? 0.0 : n / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 74, child: Text(label, style: text(14, color: c.ink))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: share, minHeight: 10, color: color, backgroundColor: c.line))),
          SizedBox(width: 74, child: Text('${count(n)} · ${pct(share)}', textAlign: TextAlign.end, style: text(12.5, color: c.muted))),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Row(children: [money('আজ খরচ', spent('today'), cap('day')), const SizedBox(width: 10), money('এই মাসে', spent('month'), cap('month'))]),
        const SizedBox(height: 12),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('উত্তর কোথা থেকে (এই মাসে)', style: text(16, weight: FontWeight.w700, color: c.ink)),
            Text(total == 0 ? 'এখনো কোনো গণনা আসেনি — অ্যাপ আগের দিনের হিসাব পরদিন পাঠায়' : 'ফোনে সমাধান ${pct(phone / total)}', style: text(13.5, color: c.muted)),
            const SizedBox(height: 8),
            bar('ফোন', phone, c.green),
            bar('ক্লাউড', gem, const Color(0xFF2563EB)),
            bar('Haiku', hai, c.amber),
            bar('Sonnet', son, c.rose),
          ]),
        ),
        const SizedBox(height: 12),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ফোনের নতুন মডেল', style: text(16, weight: FontWeight.w700, color: c.ink)),
            Text(shadowAll == 0 ? 'এখনো গণনা আসেনি' : 'পুরনো নিয়মের সাথে মিল ${pct(shadowSame / shadowAll)} (${count(shadowAll)} বার্তা)', style: text(13.5, color: c.muted)),
            if (agreed + cloudKept + cloudUsed + cloudFail > 0) ...[
              const SizedBox(height: 6),
              Text('চালু মোড: মিলে যাওয়ায় AI-কে না জিজ্ঞেস ${count(agreed)} · ক্লাউডে জিজ্ঞেস ${count(cloudKept + cloudUsed)} (ক্লাউডের উত্তর নেওয়া ${count(cloudUsed)}) · ক্লাউড পাওয়া যায়নি ${count(cloudFail)}', style: text(13.5, color: c.ink)),
            ],
            const SizedBox(height: 6),
            Text('ভুলের সংকেত: প্রতি ১০০ উত্তরে ${bn(_d(nlu['error_signals_per_100']).toStringAsFixed(1))} · শেখার নমুনা (৩০ দিন) ${count(_i(nlu['samples_30d']))}', style: text(13.5, color: c.ink)),
          ]),
        ),
        const SizedBox(height: 12),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('সবচেয়ে দুর্বল ৫টা কাজের ধরন', style: text(16, weight: FontWeight.w700, color: c.ink)),
            if (weak.isEmpty) Text('যথেষ্ট নমুনা আসেনি', style: text(13.5, color: c.muted)),
            for (final w in weak)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Expanded(child: Text('${w['intent']}', style: text(14, color: c.ink))),
                  Text('${pct(_d(w['ok_share']))} ঠিক · ${bn(_i(w['n']))}টা', style: text(13, color: c.muted)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── পর্যালোচনা ──

class AiReview extends StatefulWidget {
  const AiReview({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<AiReview> createState() => _AiReviewState();
}

class _AiReviewState extends State<AiReview> {
  List<Map<String, dynamic>>? _items;
  List<String> _intents = const [];
  final _pages = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await widget.guard(() => widget.api.review());
    if (r != null && mounted) {
      setState(() {
        _items = r.$1;
        _intents = r.$2;
      });
    }
  }

  Future<void> _decide(Map<String, dynamic> s, String pick) async {
    var intents = switch (pick) {
      'phone' => (s['phone'] as List).cast<String>(),
      'cloud' => (s['cloud'] as List).cast<String>(),
      _ => <String>[],
    };
    if (pick == 'other') {
      final chosen = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (ctx, scroll) => ListView(controller: scroll, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text('ঠিক কাজের ধরন বাছুন', style: text(17, weight: FontWeight.w700))),
            for (final i in _intents) ListTile(title: Text(i), onTap: () => Navigator.pop(ctx, i)),
          ]),
        ),
      );
      if (chosen == null) return;
      intents = [chosen];
    }
    if (intents.isEmpty) return;
    final ok = await widget.guard(() => widget.api.label(_i(s['id']), intents, pick));
    if (ok != true || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _items!.remove(s));
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Empty(Icons.task_alt_rounded, 'দেখার মতো কিছু নেই', 'ফোন, ক্লাউড আর সদস্যের শেষ কাজ যেখানে মেলেনি, সেগুলো এখানে আসবে।');
    String list(Object? v) => (v as List? ?? const []).isEmpty ? '—' : (v as List).join(' + ');
    return PageView.builder(
      controller: _pages,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final s = items[i];
        Widget line(String k, String v, {Color? color}) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 92, child: Text(k, style: text(13.5, color: c.muted))),
                Expanded(child: Text(v, style: text(15, weight: FontWeight.w600, color: color ?? c.ink))),
              ]),
            );
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Text('${bn(i + 1)} / ${bn(items.length)} · ${ago('${s['created']}'.replaceFirst(' ', 'T'))}', style: text(13, color: c.muted)),
          const SizedBox(height: 8),
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['text']}', style: text(19, weight: FontWeight.w700, color: c.ink, height: 1.4)),
              line('অবস্থা', '${s['state']}'),
              line('ফোন', '${list(s['phone'])} (${pct(_d(s['phone_conf']))})'),
              line('ক্লাউড', '${list(s['cloud'])}${'${s['cloud_provider']}'.isEmpty ? '' : ' · ${s['cloud_provider']}'}'),
              line('সদস্য শেষে', list(s['final'])),
              if ('${s['signal']}'.isNotEmpty) line('সংকেত', '${s['signal']}', color: c.rose),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => _decide(s, 'phone'), icon: const Icon(Icons.phone_android_rounded), label: const Text('ফোন ঠিক')),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(onPressed: (s['cloud'] as List? ?? const []).isEmpty ? null : () => _decide(s, 'cloud'), icon: const Icon(Icons.cloud_outlined), label: const Text('ক্লাউড ঠিক')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => _decide(s, 'other'), icon: const Icon(Icons.edit_outlined), label: const Text('দুটোই ভুল — ঠিকটা বাছুন')),
          const SizedBox(height: 10),
          Text('পরেরটায় যেতে বাঁয়ে সোয়াইপ করুন', textAlign: TextAlign.center, style: text(12.5, color: c.muted)),
        ]);
      },
    );
  }
}

// ── মডেল ──

class AiModels extends StatefulWidget {
  const AiModels({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<AiModels> createState() => _AiModelsState();
}

class _AiModelsState extends State<AiModels> {
  List<Map<String, dynamic>>? _m;
  final _pct = <String, double>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await widget.guard(() => widget.api.models());
    if (m != null && mounted) setState(() => _m = m);
  }

  Future<void> _act(String version, String action, {int? pct}) async {
    final r = await widget.guard(() => widget.api.modelAction(version, action, pct: pct));
    if (r != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final m = _m;
    if (m == null) return const Center(child: CircularProgressIndicator());
    if (m.isEmpty) return const Empty(Icons.memory_rounded, 'অ্যাপের ভেতরের মডেলই চলছে', 'নতুন মডেল শেখানো হলে এখানে draft হিসেবে আসবে; এখান থেকে অল্প সদস্যকে দিয়ে শুরু করবেন।');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        for (final x in m) ...[
          CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${x['version']}', style: text(18, weight: FontWeight.w700, color: c.ink))),
                switch ('${x['status']}') {
                  'live' => Pill('চালু · ${bn(_i(x['rollout_pct']))}%', c.green, c.tint),
                  'draft' => Pill('draft', c.amber, c.amberTint),
                  _ => Pill('বন্ধ', c.muted, c.ground),
                },
              ]),
              Text('${date('${x['created']}'.replaceFirst(' ', 'T'))} · ${bn((_d(x['size']) / 1e6).toStringAsFixed(1))} MB', style: text(13, color: c.muted)),
              if ((x['eval'] as Map?)?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text([for (final e in (x['eval'] as Map).entries) '${e.key}: ${e.value is num ? pct(_d(e.value)) : e.value}'].join(' · '), style: text(13.5, color: c.ink)),
                ),
              if (x['status'] != 'retired') ...[
                const SizedBox(height: 8),
                Text('কত % সদস্য পাবেন: ${bn((_pct['${x['version']}'] ?? _d(x['rollout_pct'])).round())}%', style: text(14, color: c.ink)),
                Slider(
                  value: (_pct['${x['version']}'] ?? _d(x['rollout_pct'])).clamp(0, 100),
                  max: 100,
                  divisions: 20,
                  onChanged: (v) => setState(() => _pct['${x['version']}'] = v),
                ),
                Row(children: [
                  if (x['status'] == 'draft')
                    FilledButton(onPressed: () => _act('${x['version']}', 'live', pct: (_pct['${x['version']}'] ?? 10).round()), child: const Text('চালু করুন'))
                  else
                    FilledButton(onPressed: () => _act('${x['version']}', 'pct', pct: (_pct['${x['version']}'] ?? _d(x['rollout_pct'])).round()), child: const Text('% রাখুন')),
                  const SizedBox(width: 8),
                  if (x['status'] == 'live') OutlinedButton(onPressed: () => _act('${x['version']}', 'rollback'), child: const Text('ফিরিয়ে নিন (rollback)')),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

// ── সেটিংস ──

class AiSettings extends StatefulWidget {
  const AiSettings({super.key, required this.api, required this.guard});
  final Api api;
  final Guard guard;

  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  Map<String, dynamic>? _s;
  final _num = <String, TextEditingController>{};
  String _mode = 'shadow';
  double _pctV = 100;
  bool _aiOn = true;
  bool _auto = true;
  bool _busy = false;
  String? _test;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final t in _num.values) {
      t.dispose();
    }
    super.dispose();
  }

  TextEditingController _f(String k, Object? v) => _num.putIfAbsent(k, () => TextEditingController())..text = v == null ? '' : '$v';

  Future<void> _load() async {
    final s = await widget.guard(() => widget.api.aiSettings());
    if (s == null || !mounted) return;
    final n = (s['nlu'] as Map).cast<String, dynamic>();
    final b = (s['budgets'] as Map).cast<String, dynamic>();
    setState(() {
      _s = s;
      _mode = '${n['mode']}';
      _pctV = _d(n['pct']);
      _aiOn = s['ai_on'] == true;
      _auto = b['auto'] == true;
      _f('free_model', n['free_model']);
      _f('pro_model', n['pro_model']);
      _f('escalate_model', n['escalate_model']);
      _f('free_per_user', n['free_per_user']);
      _f('pro_per_user', n['pro_per_user']);
      for (final p in ['free', 'pro']) {
        for (final k in ['day', 'month']) {
          _f('$p.$k', (b[p] as Map?)?[k]);
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final change = <String, Object?>{
      'ai_on': _aiOn,
      'nlu': {
        'mode': _mode,
        'pct': _pctV.round(),
        'free_model': _num['free_model']!.text.trim(),
        'pro_model': _num['pro_model']!.text.trim(),
        'escalate_model': _num['escalate_model']!.text.trim(),
        'free_per_user': int.tryParse(_num['free_per_user']!.text.trim()) ?? 20,
        'pro_per_user': int.tryParse(_num['pro_per_user']!.text.trim()) ?? 60,
      },
      if (_auto) 'budgets_auto': true,
      if (!_auto)
        'budgets': {
          for (final p in ['free', 'pro']) p: {for (final k in ['day', 'month']) k: double.tryParse(_num['$p.$k']!.text.trim()) ?? 0},
        },
    };
    final r = await widget.guard(() => widget.api.saveAiSettings(change));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('রাখা হয়েছে')));
      await _load();
    }
  }

  Future<void> _selfTest() async {
    setState(() {
      _busy = true;
      _test = null;
    });
    final r = await widget.guard(() => widget.api.aiSelfTest());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) {
        _test = [
          for (final e in r.entries)
            if (e.value is Map)
              '${e.key == 'gemini' ? 'Gemini' : 'Claude'}: ${(e.value as Map)['ok'] == true ? 'কাজ করছে (${bn((e.value as Map)['ms'])} ms)' : 'কাজ করছে না ${(e.value as Map)['error'] ?? ''}'}',
        ].join('\n');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final s = _s;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final rate = _d(s['usd_bdt']) > 0 ? _d(s['usd_bdt']) : 122.0;
    Widget field(String k, String label, {bool numeric = false}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextField(controller: _num[k], keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
        );
    Widget head(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 4), child: Text(t, style: text(16, weight: FontWeight.w700, color: c.ink)));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      CardBox(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _aiOn,
          onChanged: (v) => setState(() => _aiOn = v),
          title: Text('সব ক্লাউড AI চালু', style: text(16, weight: FontWeight.w700, color: c.ink)),
          subtitle: Text('বন্ধ করলে সাথে সাথে সব ক্লাউড কল থামে — অ্যাপ ফোনে নিজের নিয়মে চলে', style: text(13, color: c.muted)),
        ),
      ),
      head('ফোনের মডেল (nlu_mode)'),
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'off', label: Text('বন্ধ')), ButtonSegment(value: 'shadow', label: Text('ছায়া')), ButtonSegment(value: 'on', label: Text('চালু'))],
        selected: {_mode},
        onSelectionChanged: (v) => setState(() => _mode = v.first),
      ),
      const SizedBox(height: 6),
      Text('কত % সদস্য: ${bn(_pctV.round())}%', style: text(14, color: c.ink)),
      Slider(value: _pctV.clamp(0, 100), max: 100, divisions: 20, onChanged: (v) => setState(() => _pctV = v)),
      head('মডেল'),
      field('free_model', 'ফ্রি সদস্য'),
      field('pro_model', 'প্রো সদস্য'),
      field('escalate_model', 'ফোন খুব অনিশ্চিত হলে (প্রো, দিনে ≤৫%)'),
      head('সদস্যপ্রতি দিনে ক্লাউডে বোঝা'),
      Row(children: [Expanded(child: field('free_per_user', 'ফ্রি', numeric: true)), const SizedBox(width: 10), Expanded(child: field('pro_per_user', 'প্রো', numeric: true))]),
      head('বাজেট (ডলার)'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _auto,
        onChanged: (v) => setState(() => _auto = v ?? true),
        title: Text('আয় অনুযায়ী নিজে ঠিক হোক (লোকসান নয়)', style: text(14.5, color: c.ink)),
        subtitle: Text('প্রো-র আয়ের ২০% পর্যন্ত; একজন প্রো সদস্য মাসে ${tk(_d(s['member_cap_usd']), rate)} পর্যন্ত; ফ্রি সবাই মিলে মাসে \$৩', style: text(12.5, color: c.muted)),
      ),
      if (!_auto) ...[
        Row(children: [Expanded(child: field('free.day', 'ফ্রি — দিনে', numeric: true)), const SizedBox(width: 10), Expanded(child: field('free.month', 'ফ্রি — মাসে', numeric: true))]),
        Row(children: [Expanded(child: field('pro.day', 'প্রো — দিনে', numeric: true)), const SizedBox(width: 10), Expanded(child: field('pro.month', 'প্রো — মাসে', numeric: true))]),
      ],
      const SizedBox(height: 6),
      Text('নির্দেশনার সংস্করণ: ${s['prompt_ver'] ?? '—'} · Claude key: ${s['anthropic_key'] == '' ? 'নেই' : 'আছে'} · Gemini key: ${s['gemini_key'] == true ? 'আছে' : 'নেই'}', style: text(12.5, color: c.muted)),
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _save, child: const Text('রাখুন')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _busy ? null : _selfTest, icon: const Icon(Icons.science_outlined), label: const Text('Gemini আর Claude পরীক্ষা')),
      if (_test != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_test!, style: text(14, color: c.ink))),
    ]);
  }
}
