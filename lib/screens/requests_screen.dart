import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart' show bdPlaces;
import '../logic/lang.dart';
import '../logic/me.dart' show bloodGroups;
import '../logic/when.dart' show sayWhen;
import '../models/models.dart' show Via;
import '../services/community.dart';
import '../state/brain.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'google_backup.dart' show GoogleBackupPanel;

/// অনুরোধ: blood requests between members. Ask for blood, see the requests
/// near you that your group can give to, say "আমি দিতে পারব", and see who
/// said yes to yours. Only what is written here goes to our server.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, this.inTab = false});

  /// Shown as a tab (no back arrow).
  final bool inTab;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  bool _mine = false;

  /// Filters for the whole country's list ('' = all).
  String _group = '';
  String _place = '';
  DonorProfile? _donor;

  /// Each tab's list (false: the whole country, true: mine); null while loading.
  final Map<bool, List<BloodRequest>?> _lists = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load([bool? which]) async {
    final brain = BrainScope.read(context);
    if (!brain.signedIn) return;
    final mine = which ?? _mine;
    final c = brain.community;
    final (donor, e1) = _donor == null ? await c.donor() : (_donor!, null);
    final (list, e2) = mine ? await c.requests(scope: 'mine') : await c.requests(scope: 'all', district: _place, blood: _group);
    if (!mounted) return;
    setState(() {
      _donor = donor;
      _lists[mine] = list;
      _error = e2 ?? e1;
    });
  }

  Future<void> _reload([bool? which]) async {
    setState(() => _lists[which ?? _mine] = null);
    await _load(which);
  }

  Future<void> _ask() async {
    final told = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => AskBloodScreen(phone: _donor?.phone ?? '')));
    if (told == null || !mounted) return;
    toast(context, told == 0 ? tr('অনুরোধ রাখা হয়েছে') : trf('অনুরোধ রাখা হয়েছে — {0} জন দাতাকে জানানো হলো', [bnDigits(told)]));
    setState(() => _mine = true);
    await _reload(true);
  }

  Future<void> _donorSetup() async {
    final d = await showAppSheet<DonorProfile>(context: context, isScrollControlled: true, builder: (_) => _DonorSheet(current: _donor ?? const DonorProfile()));
    if (d == null || !mounted) return;
    setState(() => _donor = d);
    await _reload();
  }

  Future<void> _accept(BloodRequest r) async {
    final brain = BrainScope.read(context);
    final phone = TextEditingController(text: _donor?.phone ?? '');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('{0} রক্ত দিতে পারবেন?', [r.blood]), style: display(19)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('যিনি চেয়েছেন, তিনি আপনার নাম আর নম্বর দেখবেন এবং যোগাযোগ করবেন।'), style: body(14, color: C.muted2, height: 1.5)),
          const SizedBox(height: 12),
          TextField(key: const Key('accept-phone'), controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('আপনার মোবাইল নম্বর'))),
          const SizedBox(height: 10),
          TextField(controller: note, decoration: InputDecoration(labelText: tr('কিছু বলার থাকলে (ঐচ্ছিক)'), hintText: tr('যেমন: বিকেল ৪টায় আসতে পারব'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('বাতিল'))),
          FilledButton(key: const Key('accept-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(tr('হ্যাঁ, দিতে পারব'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final (_, e) = await brain.community.act(r.id, 'accept', phone: asciiDigits(phone.text.trim()), note: note.text.trim());
    if (!mounted) return;
    if (e != null) {
      toast(context, e);
      return;
    }
    toast(context, tr('ধন্যবাদ! যিনি চেয়েছেন, তাঁকে জানানো হয়েছে।'));
    await _reload();
  }

  Future<void> _act(BloodRequest r, String what, {String status = 'done'}) async {
    final (_, e) = await BrainScope.read(context).community.act(r.id, what, status: status);
    if (!mounted) return;
    if (e != null) toast(context, e);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final donor = _donor;
    final now = brain.services.now();
    // Each tab is its own page; swiping left/right moves between them.
    List<Widget> page(bool mine) {
      final list = _lists[mine];
      return [
        if (!mine) ...[
          if (donor != null) _DonorCard(donor: donor, onTap: _donorSetup),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('blood-filter-group'),
                initialValue: _group,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('গ্রুপ'), isDense: true),
                items: [DropdownMenuItem(value: '', child: Text(tr('সব গ্রুপ'))), for (final g in bloodGroups) DropdownMenuItem(value: g, child: Text(g))],
                onChanged: (v) {
                  setState(() => _group = v ?? '');
                  _reload(false);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('blood-filter-place'),
                initialValue: _place,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('জেলা'), isDense: true),
                items: [DropdownMenuItem(value: '', child: Text(tr('সারা দেশ'))), for (final p in bdPlaces) DropdownMenuItem(value: p.name, child: Text(p.label))],
                onChanged: (v) {
                  setState(() => _place = v ?? '');
                  _reload(false);
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: body(14, color: C.red))),
        if (list == null)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          EmptyState(
            icon: Icons.bloodtype_outlined,
            title: mine ? tr('আপনার কোনো অনুরোধ নেই') : tr('এখন কোনো অনুরোধ নেই'),
            text: mine
                ? tr('রক্ত দরকার হলে নিচের “রক্ত চাই” চাপুন — সারা দেশের সবাই দেখবেন, আর আপনার জেলার দাতারা সাথে সাথে জানবেন।')
                : tr('দেশের যেকোনো জায়গায় কারো রক্ত লাগলে এখানে দেখাবে; দাতা হলে নিজের জেলার অনুরোধে নোটিফিকেশনও পাবেন।'),
          )
        else
          for (final r in list) ...[
            _RequestCard(
              request: r,
              now: now,
              onCall: (p) => brain.services.launcher.open(Via.call, p),
              onAccept: () => _accept(r),
              onWithdraw: () => _act(r, 'withdraw'),
              onDone: () => _act(r, 'close'),
              onCancel: () => _act(r, 'close', status: 'cancelled'),
            ),
            const SizedBox(height: 10),
          ],
      ];
    }

    final content = !brain.signedIn
        ? ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            Text(tr('রক্ত চাইতে, দাতা হতে বা অনুরোধ দেখতে আগে Google দিয়ে লগইন করুন।'), style: body(15, color: C.muted2, height: 1.55)),
            const SizedBox(height: 12),
            const GoogleBackupPanel(),
          ])
        : RefreshIndicator(
            // The lists are inside the pages (one level down).
            notificationPredicate: (n) => n.depth == 1 && n.metrics.axis == Axis.vertical,
            onRefresh: () => _load(),
            child: TabPages<bool>(
              items: [(false, tr('সারা দেশের অনুরোধ')), (true, tr('আমার অনুরোধ'))],
              value: _mine,
              tabsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              onChanged: (v) {
                setState(() => _mine = v);
                if (_lists[v] == null) _load(v);
              },
              page: page,
            ),
          );
    return Scaffold(
      floatingActionButton: brain.signedIn ? AddButton(key: const Key('blood-ask'), label: tr('রক্ত চাই'), icon: Icons.bloodtype_outlined, onPressed: _ask) : null,
      body: SafeArea(
        bottom: !widget.inTab,
        child: Column(children: [
          if (widget.inTab) Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: TabTitle(tr('ব্লাড ডোনেশন'), sub: tr('রক্ত দিন, জীবন বাঁচান'))) else TopBar(title: tr('ব্লাড ডোনেশন'), sub: tr('রক্ত দিন, জীবন বাঁচান'), note: HandNote(tr('এক ব্যাগ রক্ত, একটা জীবন'), size: 12.5, rotate: -5)),
          Expanded(child: content),
        ]),
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  const _DonorCard({required this.donor, required this.onTap});
  final DonorProfile donor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = donor.on;
    final fg = on ? Colors.white : C.ink;
    final sub = on ? Colors.white.withValues(alpha: 0.75) : C.muted;
    return Material(
      color: on ? C.fill : C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: on ? C.fillEdge : (C.dark ? C.line : Colors.transparent))),
      child: InkWell(
        key: const Key('donor-card'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(children: [
            Container(
              width: on ? 56 : 44,
              height: on ? 56 : 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.roseFill, borderRadius: BorderRadius.circular(on ? 16 : 22)),
              child: on ? Text(bloodLabel(donor.blood), style: display(19, weight: 700, color: Colors.white)) : const Icon(Icons.volunteer_activism_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(on ? '${tr('আপনি রক্তদাতা')} · ${tr(donor.district)}' : tr('আমি রক্ত দিতে চাই'), style: body(15.5, weight: FontWeight.w700, color: fg)),
                Text(
                    on
                        ? '${donor.lastDonated == null ? '' : '${trf('শেষ দিয়েছেন {0}', [shortDate(donor.lastDonated!)])} · '}${tr('বদলান')}'
                        : tr('দাতা হলে আপনার জেলায় কারো রক্ত লাগলে নোটিফিকেশন পাবেন'),
                    style: body(13, color: sub)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: sub),
          ]),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.now, required this.onCall, required this.onAccept, required this.onWithdraw, required this.onDone, required this.onCancel});
  final BloodRequest request;
  final DateTime now;
  final void Function(String phone) onCall;
  final VoidCallback onAccept;
  final VoidCallback onWithdraw;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final urgent = r.open && r.needBy.difference(now).inHours < 24;
    final state = switch (r.status) {
      'done' => (tr('রক্ত পাওয়া গেছে'), C.green, C.greenTint),
      'cancelled' => (tr('বাতিল'), C.muted2, C.soft),
      'expired' => (tr('সময় পার হয়ে গেছে'), C.muted2, C.soft),
      _ => urgent ? (tr('জরুরি'), C.rose, C.roseTint) : (tr('খোলা'), C.greenDark, C.greenTint),
    };
    return Panel(
      key: Key('request-${r.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.roseTint, borderRadius: BorderRadius.circular(16)),
            child: Text(r.blood, style: display(20, weight: 800, color: C.rose)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(trf('{0} ব্যাগ রক্ত দরকার', [bnDigits(r.bags)]), style: body(16, weight: FontWeight.w700))),
                Pill(state.$1, fg: state.$2, bg: state.$3),
              ]),
              Text([if (r.hospital.isNotEmpty) r.hospital, if (r.location.isNotEmpty) r.location, tr(r.district)].join(', '), style: body(14, color: C.muted2)),
              Text(trf('লাগবে: {0}', [sayWhen(r.needBy, now)]), style: body(13.5, weight: FontWeight.w600, color: urgent ? C.rose : C.muted2)),
            ]),
          ),
        ]),
        if (r.patient.isNotEmpty || r.problem.isNotEmpty || r.note.isNotEmpty) ...[
          const SizedBox(height: 8),
          if (r.patient.isNotEmpty) Text(trf('কার জন্যে: {0}', [r.patient]), style: body(14, height: 1.5)),
          if (r.problem.isNotEmpty) Text(trf('রোগীর সমস্যা: {0}', [r.problem]), style: body(14, height: 1.5)),
          if (r.note.isNotEmpty) Text(r.note, style: body(14, height: 1.5, color: C.muted2)),
        ],
        if (!r.mine) Text(trf('যোগাযোগ: {0}', [bnDigits(r.phone)]), style: body(14, weight: FontWeight.w600, height: 1.6)),
        const SizedBox(height: 8),
        if (!r.mine) ...[
          Text(
              trf('চেয়েছেন {0}{1}', [
                r.by,
                r.accepted > 0 ? ' · ${trf('{0} জন রাজি', [bnDigits(r.accepted)])}' : ''
              ]),
              style: body(12.5, color: C.muted)),
          const SizedBox(height: 10),
          if (r.open)
            Row(children: [
              Expanded(
                child: r.iAccepted
                    ? SecondaryButton(label: tr('রাজি আছি · ফিরিয়ে নিন'), height: 46, onPressed: onWithdraw)
                    : PrimaryButton(key: Key('accept-${r.id}'), label: tr('আমি দিতে পারব'), icon: Icons.volunteer_activism_outlined, height: 46, color: C.roseFill, onPressed: onAccept),
              ),
              const SizedBox(width: 8),
              CircleAction(icon: Icons.call_rounded, tooltip: trf('ফোন দিন {0}', [bnDigits(r.phone)]), size: 46, onPressed: () => onCall(r.phone)),
            ]),
        ] else ...[
          Text(r.donors.isEmpty ? tr('এখনো কেউ রাজি হননি — দাতারা নোটিফিকেশন পেয়েছেন।') : trf('{0} জন রক্ত দিতে রাজি:', [bnDigits(r.donors.length)]),
              style: body(13.5, weight: FontWeight.w600, color: r.donors.isEmpty ? C.muted : C.greenDark)),
          for (final d in r.donors)
            ListRow(
              leading: Avatar(name: d.name),
              title: d.name,
              subtitle: [bnDigits(d.phone), if (d.note.isNotEmpty) d.note].join(' · '),
              trailing: CircleAction(icon: Icons.call_rounded, tooltip: tr('ফোন দিন'), onPressed: () => onCall(d.phone)),
            ),
          if (r.open) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: PrimaryButton(key: Key('done-${r.id}'), label: tr('রক্ত পেয়েছি'), icon: Icons.check_rounded, height: 46, onPressed: onDone)),
              const SizedBox(width: 8),
              Expanded(child: SecondaryButton(label: tr('বাতিল করুন'), height: 46, onPressed: onCancel)),
            ]),
          ],
        ],
      ]),
    );
  }
}

/// Becoming a donor (or stopping): group, district, last donation, number.
class _DonorSheet extends StatefulWidget {
  const _DonorSheet({required this.current});
  final DonorProfile current;

  @override
  State<_DonorSheet> createState() => _DonorSheetState();
}

class _DonorSheetState extends State<_DonorSheet> {
  late String _blood = widget.current.blood.isEmpty ? '' : bloodLabel(widget.current.blood);
  late String _district = widget.current.district;
  late DateTime? _last = widget.current.lastDonated;
  late final _phone = TextEditingController(text: widget.current.phone);
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final brain = BrainScope.read(context);
    if (_blood.isEmpty) _blood = brain.data.emergency.blood;
    if (_district.isEmpty) _district = brain.district;
    _last ??= DateTime.tryParse(brain.text('blood_last'));
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(bool on) async {
    final brain = BrainScope.read(context);
    if (on && _blood.isEmpty) {
      setState(() => _error = tr('রক্তের গ্রুপ বেছে নিন'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final (d, e) = await brain.community.setDonor(on: on, blood: _blood, district: _district, lastDonated: _last, phone: asciiDigits(_phone.text.trim()));
    if (!mounted) return;
    setState(() => _busy = false);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    // The app's own donor reminder (next donation day) follows this.
    await brain.setPref('donor_on', on);
    if (_last != null) await brain.setPref('blood_last', _last!.toIso8601String());
    if (on && brain.data.emergency.blood.isEmpty) await brain.saveEmergency(brain.data.emergency.copyWith(blood: _blood));
    if (mounted) Navigator.pop(context, d);
  }

  @override
  Widget build(BuildContext context) {
    final now = BrainScope.of(context).services.now();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('আমি রক্ত দিতে চাই'), style: display(20, weight: 700)),
            const SizedBox(height: 4),
            Text(
                tr('আপনার জেলায় কারো এই গ্রুপের রক্ত লাগলে নোটিফিকেশন পাবেন (দিনে ৩টার বেশি না; রক্ত দেওয়ার ৩ মাসের মধ্যে একটাও না)। শুধু গ্রুপ, জেলা, শেষ দেওয়ার দিন আর নম্বর সার্ভারে থাকে — নম্বর দেখবেন শুধু যাঁকে আপনি রাজি বলবেন।'),
                style: body(13, color: C.muted, height: 1.5)),
            const SizedBox(height: 14),
            Text(tr('রক্তের গ্রুপ'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in bloodGroups) ChoiceChip(label: Text(g, style: body(15, weight: FontWeight.w600)), selected: _blood == g, onSelected: (_) => setState(() => _blood = g)),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: bdPlaces.any((p) => p.name == _district) ? _district : bdPlaces.first.name,
              decoration: InputDecoration(labelText: tr('জেলা')),
              items: [for (final p in bdPlaces) DropdownMenuItem(value: p.name, child: Text(p.label))],
              onChanged: (v) => setState(() => _district = v ?? _district),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _last ?? now, firstDate: DateTime(now.year - 5), lastDate: now);
                if (d != null) setState(() => _last = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: tr('শেষ কবে রক্ত দিয়েছেন (ঐচ্ছিক)')),
                child: Text(_last == null ? tr('জানা নেই / কখনো না') : fullDate(_last!), style: body(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('মোবাইল নম্বর (রাজি হলে যাঁকে দেবেন, তিনি দেখবেন)'))),
            if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: body(14, color: C.red))],
            const SizedBox(height: 16),
            PrimaryButton(key: const Key('donor-save'), label: widget.current.on ? tr('রাখুন') : tr('দাতা হিসেবে যুক্ত হোন'), color: C.roseFill, onPressed: _busy ? null : () => _save(true)),
            if (widget.current.on) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: _busy ? null : () => _save(false), child: Text(tr('দাতা থাকতে চাই না (তথ্য মুছে যাবে)'), style: body(14, color: C.red))),
            ],
          ]),
        ),
      ),
    );
  }
}

/// "রক্ত চাই": group, bags, where, by when, and a number to call. Returns
/// how many donors were told, or null when not sent.
class AskBloodScreen extends StatefulWidget {
  const AskBloodScreen({super.key, this.phone = ''});
  final String phone;

  @override
  State<AskBloodScreen> createState() => _AskBloodScreenState();
}

class _AskBloodScreenState extends State<AskBloodScreen> {
  String _blood = '';
  int _bags = 1;
  late String _district;
  late DateTime _need;
  final _hospital = TextEditingController();
  final _patient = TextEditingController();
  final _problem = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  late final _phone = TextEditingController(text: widget.phone);
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final brain = BrainScope.read(context);
    _district = brain.district;
    final now = brain.services.now();
    _need = DateTime(now.year, now.month, now.day, 18).isAfter(now) ? DateTime(now.year, now.month, now.day, 18) : DateTime(now.year, now.month, now.day + 1, 10);
  }

  @override
  void dispose() {
    for (final c in [_hospital, _patient, _problem, _location, _note, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_blood.isEmpty) {
      setState(() => _error = tr('কোন গ্রুপের রক্ত লাগবে, বেছে নিন'));
      return;
    }
    if (_patient.text.trim().isEmpty || _problem.text.trim().isEmpty || _hospital.text.trim().isEmpty) {
      setState(() => _error = tr('কার জন্যে, রোগীর সমস্যা আর হাসপাতালের নাম দিন'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final (told, e) = await BrainScope.read(context).community.ask(
          blood: _blood,
          bags: _bags,
          district: _district,
          hospital: _hospital.text.trim(),
          needBy: _need,
          phone: asciiDigits(_phone.text.trim()),
          patient: _patient.text.trim(),
          problem: _problem.text.trim(),
          location: _location.text.trim(),
          note: _note.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = e;
    });
    if (e == null) Navigator.of(context).pop(told);
  }

  @override
  Widget build(BuildContext context) {
    final now = BrainScope.of(context).services.now();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('রক্ত চাই')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(tr('কোন গ্রুপ'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in bloodGroups)
                  ChoiceChip(key: Key('ask-$g'), label: Text(g, style: body(16, weight: FontWeight.w700)), selected: _blood == g, onSelected: (_) => setState(() => _blood = g)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text(tr('কত ব্যাগ'), style: body(15, weight: FontWeight.w600))),
                IconButton.outlined(onPressed: _bags > 1 ? () => setState(() => _bags--) : null, icon: const Icon(Icons.remove_rounded)),
                SizedBox(width: 44, child: Text(bnDigits(_bags), textAlign: TextAlign.center, style: display(20, weight: 700))),
                IconButton.outlined(onPressed: _bags < 10 ? () => setState(() => _bags++) : null, icon: const Icon(Icons.add_rounded)),
              ]),
              const SizedBox(height: 14),
              TextField(key: const Key('ask-patient'), controller: _patient, decoration: InputDecoration(labelText: tr('কার জন্যে'), hintText: tr('যেমন: আমার বাবা, রহিম (৪৫)'))),
              const SizedBox(height: 12),
              TextField(
                  key: const Key('ask-problem'), controller: _problem, decoration: InputDecoration(labelText: tr('রোগীর সমস্যা'), hintText: tr('যেমন: সিজারিয়ান অপারেশন, থ্যালাসেমিয়া, দুর্ঘটনা'))),
              const SizedBox(height: 12),
              TextField(key: const Key('ask-hospital'), controller: _hospital, decoration: InputDecoration(labelText: tr('হাসপাতাল'), hintText: tr('যেমন: ঢাকা মেডিকেল কলেজ হাসপাতাল'))),
              const SizedBox(height: 12),
              TextField(
                  key: const Key('ask-location'),
                  controller: _location,
                  decoration: InputDecoration(labelText: tr('হাসপাতালের অবস্থান (এলাকা, ঠিকানা, ওয়ার্ড)'), hintText: tr('যেমন: বকশিবাজার, ওয়ার্ড ৩'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: bdPlaces.any((p) => p.name == _district) ? _district : bdPlaces.first.name,
                decoration: InputDecoration(labelText: tr('জেলা')),
                items: [for (final p in bdPlaces) DropdownMenuItem(value: p.name, child: Text(p.label))],
                onChanged: (v) => setState(() => _district = v ?? _district),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context, initialDate: _need.isBefore(now) ? now : _need, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 30)));
                  if (d == null || !context.mounted) return;
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_need));
                  setState(() => _need = DateTime(d.year, d.month, d.day, t?.hour ?? _need.hour, t?.minute ?? 0));
                },
                child: InputDecorator(decoration: InputDecoration(labelText: tr('কবে লাগবে')), child: Text(sayWhen(_need, now), style: body(16))),
              ),
              const SizedBox(height: 12),
              TextField(key: const Key('ask-phone'), controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('যোগাযোগের মোবাইল নম্বর'))),
              const SizedBox(height: 12),
              TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: tr('আর কিছু বলার থাকলে (ঐচ্ছিক)'), hintText: tr('যেমন: সকাল ১০টার আগে আসুন'))),
              const SizedBox(height: 8),
              Text(
                  tr('অনুরোধটা সারা দেশের সবাই দেখবেন — কার জন্যে, সমস্যা, হাসপাতাল, তারিখ আর আপনার নম্বরসহ। আপনার জেলার যাঁরা দাতা আর এই গ্রুপে দিতে পারেন, তাঁরা নোটিফিকেশনও পাবেন। একসাথে ৩টা পর্যন্ত অনুরোধ খোলা রাখা যায়।'),
                  style: body(12.5, color: C.muted, height: 1.5)),
              if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: body(14, color: C.red))],
              const SizedBox(height: 16),
              PrimaryButton(key: const Key('ask-send'), label: _busy ? tr('পাঠাচ্ছি…') : tr('অনুরোধ পাঠান'), icon: Icons.send_rounded, color: C.roseFill, onPressed: _busy ? null : _send),
            ]),
          ),
        ]),
      ),
    );
  }
}
