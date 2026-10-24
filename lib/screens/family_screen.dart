// ফ্যামিলি (Pro): add family members by e-mail, choose what each may do for
// you, send them to-dos, reminders, medicine reminders and notes, see where
// they are (if they allow), and heirs (lib/state/family_state.dart).
import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/ledger.dart';
import '../logic/pro.dart';
import '../models/models.dart';
import '../services/location_share.dart';
import '../state/brain.dart';
import '../state/family_state.dart';
import '../ui/pro_gate.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../ui/file_view.dart';
import '../ui/widgets.dart';
import 'google_backup.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool _busy = false;
  List<String> _scope = const [];
  Map<String, bool> _loc = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final brain = BrainScope.read(context);
    if (!brain.signedIn) return;
    setState(() => _busy = true);
    await brain.family.refresh();
    final scope = await brain.family.heirScope();
    final loc = await LocationShareChannel.status();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _scope = scope;
      _loc = loc;
    });
  }

  Future<void> _invite() async {
    if (!await needPro(context, ProFeature.family)) return;
    if (!mounted) return;
    final r = await showAppSheet<(String, String, List<String>)>(context: context, isScrollControlled: true, builder: (_) => const _AddSheet());
    if (r == null || !mounted) return;
    final ok = await BrainScope.read(context).family.invite(r.$1, r.$2, r.$3);
    if (ok && mounted) toast(context, tr('অনুরোধ পাঠানো হয়েছে — তিনি অ্যাপে মেনে নিলে যুক্ত হবেন'));
  }

  Future<void> _answer(FamilyLink l) async {
    final r = await showAppSheet<(String, String, List<String>)>(context: context, isScrollControlled: true, builder: (_) => _AddSheet(accepting: l));
    if (r == null || !mounted) return;
    await BrainScope.read(context).family.answer(l, true, relation: r.$2, allow: r.$3);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final fam = brain.family;
    return ListenableBuilder(
      listenable: fam,
      builder: (context, _) {
        final incoming = [
          for (final l in fam.links)
            if (l.incoming) l
        ];
        final mine = [
          for (final l in fam.links)
            if (!l.incoming) l
        ];
        final sharing = mine.any((l) => l.active && l.iAllow.contains('location'));
        final heirs = mine.where((l) => l.active && l.theyAreMyHeir).toList();
        return Scaffold(
          floatingActionButton: brain.signedIn ? AddButton(key: const Key('family-add'), label: tr('সদস্য যোগ'), icon: Icons.person_add_alt_1_rounded, onPressed: _invite) : null,
          body: SafeArea(
            child: Column(children: [
              TopBar(title: tr('ফ্যামিলি'), sub: tr('একে অপরের পাশে, সবসময়')),
              Expanded(
                child: !brain.signedIn
                    ? ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                        Text(tr('ফ্যামিলিতে যুক্ত হতে আগে Google দিয়ে লগইন করুন — সবাই নিজের ইমেইলে যুক্ত হন।'), style: body(15, color: C.muted2, height: 1.55)),
                        const SizedBox(height: 12),
                        const GoogleBackupPanel(),
                      ])
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
                          for (final c in fam.claimsOnMe)
                            Panel(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Text(trf('{0} জানিয়েছেন আপনি ইন্তেকাল করেছেন', [c.$2]), style: body(16, weight: FontWeight.w700, color: C.red)),
                                const SizedBox(height: 4),
                                Text(tr('ভুল হলে এখনই বাতিল করুন। বাতিল না করলে যাচাইয়ের পর ১৪ দিনে তিনি আপনার বেছে রাখা অংশ দেখতে পাবেন।'), style: body(13.5, height: 1.45)),
                                const SizedBox(height: 8),
                                PrimaryButton(key: Key('claim-cancel-${c.$1}'), label: tr('আমি বেঁচে আছি — বাতিল করুন'), color: C.red, onPressed: () => fam.cancelClaim(c.$1)),
                              ]),
                            ),
                          if (fam.error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(fam.error!, style: body(14, color: C.red))),
                          if (!fam.loaded && _busy) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                          if (fam.received.isNotEmpty) ...[
                            SectionTitle(tr('ফ্যামিলি থেকে এসেছে')),
                            Panel(
                              child: Rows(children: [
                                for (final r in fam.received.take(5))
                                  ListRow(leading: Icon(Icons.inbox_rounded, color: C.green), title: r.$2, subtitle: r.$1.isEmpty ? null : trf('{0} দিয়েছেন', [r.$1])),
                              ]),
                            ),
                          ],
                          if (incoming.isNotEmpty) ...[
                            SectionTitle(tr('যুক্ত হওয়ার অনুরোধ')),
                            for (final l in incoming)
                              Panel(
                                padding: const EdgeInsets.all(14),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  Text(trf('{0} আপনাকে ফ্যামিলিতে যুক্ত করতে চান', [l.name]), style: body(15.5, weight: FontWeight.w600)),
                                  if (l.theyCall.isNotEmpty) Text(trf('তিনি আপনাকে বলেছেন: {0}', [l.theyCall]), style: body(13.5, color: C.muted)),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child: PrimaryButton(key: Key('family-accept-${l.id}'), label: tr('যুক্ত হোন'), height: 46, onPressed: () => _answer(l))),
                                    const SizedBox(width: 8),
                                    Expanded(child: SecondaryButton(label: tr('না'), height: 46, onPressed: () => fam.answer(l, false))),
                                  ]),
                                ]),
                              ),
                          ],
                          if (mine.isNotEmpty) ...[
                            HeroCard(
                              key: const Key('family-hero'),
                              label: tr('আমার পরিবার'),
                              side: AvatarStack([for (final l in mine) l.name], size: 34),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(trf('{0} জন সদস্য', [bnDigits(mine.length + 1)]), style: display(26, weight: 700, color: Colors.white, height: 1.35)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                                  const SizedBox(width: 5),
                                  Expanded(child: Text(tr('যা পাঠান, তালাবদ্ধ যায় — আমরাও খুলতে পারি না'), style: body(12.5, color: Colors.white.withValues(alpha: 0.8)))),
                                ]),
                              ]),
                            ),
                            const SizedBox(height: 6),
                          ],
                          SectionTitle(tr('আমার ফ্যামিলি')),
                          if (fam.loaded && mine.isEmpty)
                            EmptyState(
                              icon: Icons.family_restroom_rounded,
                              title: tr('এখনো কেউ নেই'),
                              text: tr(
                                  'মা-বাবা, স্বামী-স্ত্রী, সন্তান — তাঁদের ইমেইল দিয়ে যুক্ত করুন। তাঁরা যা অনুমতি দেবেন, শুধু তা-ই করতে পারবেন: কাজ, রিমাইন্ডার, ওষুধের রিমাইন্ডার, নোট, লাইভ লোকেশন।'),
                            ),
                          if (mine.isNotEmpty)
                            Panel(
                              child: Rows(children: [
                                for (final l in mine)
                                  ListRow(
                                    key: Key('family-${l.id}'),
                                    leading: Avatar(name: l.name, fg: Colors.white, bg: AvatarStack.toneOf(l.name)),
                                    title: l.title,
                                    subtitle: l.active
                                        ? (l.theyAllow.isEmpty ? tr('আপনাকে এখনো কিছুর অনুমতি দেননি') : trf('অনুমতি: {0}', [l.theyAllow.map(_short).join(', ')]))
                                        : tr('উত্তরের অপেক্ষায় — তিনি অ্যাপ খুলে মেনে নেবেন'),
                                    trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                                    onTap: l.active ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FamilyMemberScreen(linkId: l.id))) : null,
                                  ),
                              ]),
                            ),
                          if (sharing) ...[
                            const SizedBox(height: 16),
                            SectionTitle(tr('আমার লোকেশন')),
                            Panel(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Text(
                                    _loc['fine'] != true
                                        ? tr('লোকেশন দেখাতে ফোনের অনুমতি লাগবে।')
                                        : (_loc['background'] != true
                                            ? tr('অ্যাপ খোলা থাকলে লোকেশন যায়। ফোন হারালেও খুঁজে পেতে “সবসময়” অনুমতি দিন।')
                                            : tr('চালু — অ্যাপ বন্ধ থাকলেও “এখন কোথায়?” জিজ্ঞেস করলে ফোন নিজে জানাবে।')),
                                    style: body(14, height: 1.45)),
                                const SizedBox(height: 8),
                                if (_loc['fine'] != true)
                                  PrimaryButton(
                                      label: tr('লোকেশনের অনুমতি দিন'),
                                      height: 44,
                                      onPressed: () async {
                                        if (!await _disclose(context)) return;
                                        await LocationShareChannel.ask();
                                        await Future<void>.delayed(const Duration(seconds: 2));
                                        await _load();
                                      })
                                else if (_loc['background'] != true)
                                  SecondaryButton(
                                      label: tr('“সবসময় অনুমতি দিন” বেছে নিন'),
                                      height: 44,
                                      onPressed: () async {
                                        if (!await _disclose(context)) return;
                                        await LocationShareChannel.askBackground();
                                      }),
                                const SizedBox(height: 6),
                                Text(tr('লোকেশন তালাবদ্ধ হয়ে যায় — শুধু যাঁদের অনুমতি দিয়েছেন তাঁরাই খুলতে পারেন, আমাদের সার্ভারও না।'), style: body(12.5, color: C.muted, height: 1.4)),
                              ]),
                            ),
                          ],
                          if (mine.any((l) => l.active)) ...[
                            const SizedBox(height: 16),
                            SectionTitle(tr('উত্তরাধিকারী')),
                            Text(
                                heirs.isEmpty
                                    ? tr(
                                        'কোনো সদস্যকে খুলে “আমার উত্তরাধিকারী” চালু করলে, আপনার ইন্তেকালের পর (কাগজ যাচাই আর ১৪ দিন অপেক্ষার পর) বা আপনি এখনই অনুমতি দিলে তিনি নিচে বাছাই করা অংশ দেখতে পাবেন।')
                                    : trf('উত্তরাধিকারী: {0}। তাঁরা যা দেখতে পাবেন:', [heirs.map((h) => h.title).join(', ')]),
                                style: body(13.5, color: C.muted2, height: 1.45)),
                            const SizedBox(height: 6),
                            Panel(
                              child: Rows(children: [
                                for (final p in heirParts.keys)
                                  CheckboxListTile(
                                    key: Key('heir-part-$p'),
                                    value: _scope.contains(p),
                                    onChanged: (v) async {
                                      final next = [
                                        for (final x in heirParts.keys)
                                          if (x == p ? v == true : _scope.contains(x)) x
                                      ];
                                      setState(() => _scope = next);
                                      await fam.setHeirScope(next);
                                    },
                                    title: Text(heirPartLabel(p), style: body(14.5)),
                                    subtitle: p == 'vault' || p == 'health' ? Text(tr('নিজে টিক না দিলে যাবে না'), style: body(12, color: C.muted)) : null,
                                  ),
                              ]),
                            ),
                            const SizedBox(height: 6),
                            Text(tr('উত্তরাধিকারীর কপি আপনার ফোনেই তালাবদ্ধ হয়ে সার্ভারে থাকে — শুধু তিনি খুলতে পারেন, আমরা না।'), style: body(12.5, color: C.muted, height: 1.4)),
                          ],
                        ]),
                      ),
              ),
            ]),
          ),
        );
      },
    );
  }

  /// Google Play's prominent disclosure: said before the phone asks for location.
  Future<bool> _disclose(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('লোকেশন কীভাবে ব্যবহার হয়')),
          content: Text(
              tr('My Assistant আপনার ফোনের লোকেশন নেয় — অ্যাপ বন্ধ থাকলেও — শুধু তখন, যখন আপনি যাঁদের অনুমতি দিয়েছেন সেই পরিবারের কেউ “এখন কোথায়?” জিজ্ঞেস করেন (যেমন ফোন হারালে খুঁজতে)। লোকেশন তালাবদ্ধ হয়ে শুধু তাঁদের কাছে যায়; আমরা দেখতে পারি না, বিজ্ঞাপনে বা অন্য কিছুতে ব্যবহার হয় না। ফ্যামিলি পাতা থেকে যেকোনো সময় বন্ধ করা যায়।'),
              style: body(14.5, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('এখন না'))),
            FilledButton(key: const Key('location-disclosure-ok'), onPressed: () => Navigator.pop(ctx, true), child: Text(tr('বুঝেছি, চালিয়ে যান'))),
          ],
        ),
      ) ==
      true;

  String _short(String p) => switch (p) {
        'task' => tr('কাজ'),
        'reminder' => tr('রিমাইন্ডার'),
        'medicine' => tr('ওষুধ'),
        'note' => tr('নোট'),
        'location' => tr('লোকেশন'),
        _ => p,
      };
}

/// Adding someone (e-mail, relation, what they may do), or accepting an invite (relation, what they may do).
class _AddSheet extends StatefulWidget {
  const _AddSheet({this.accepting});
  final FamilyLink? accepting;
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _email = TextEditingController();
  final _relation = TextEditingController();
  final _allow = <String>{'task', 'reminder', 'medicine', 'note'};
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final acc = widget.accepting;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(acc == null ? tr('ফ্যামিলিতে যোগ করুন') : trf('{0}-এর সাথে যুক্ত হোন', [acc.name]), style: display(20, weight: 700)),
          const SizedBox(height: 12),
          if (acc == null) ...[
            TextField(
                key: const Key('family-email'), controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('তাঁর ইমেইল (যেটা দিয়ে অ্যাপে লগইন করেন)'))),
            const SizedBox(height: 10),
          ],
          TextField(key: const Key('family-relation'), controller: _relation, decoration: InputDecoration(labelText: tr('তিনি আপনার কে?'), hintText: tr('যেমন: আম্মা, ছেলে, স্ত্রী'))),
          const SizedBox(height: 12),
          Text(tr('তিনি আমার জন্য যা করতে পারবেন'), style: body(13.5, weight: FontWeight.w600, color: C.muted2)),
          for (final p in familyPerms)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allow.contains(p),
              onChanged: (v) => setState(() => v == true ? _allow.add(p) : _allow.remove(p)),
              title: Text(familyPermLabel(p), style: body(14.5)),
            ),
          if (_error != null) Text(_error!, style: body(14, color: C.red)),
          const SizedBox(height: 8),
          PrimaryButton(
            key: const Key('family-send'),
            label: acc == null ? tr('অনুরোধ পাঠান') : tr('যুক্ত হোন'),
            onPressed: () {
              final email = _email.text.trim();
              if (acc == null && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                setState(() => _error = tr('ঠিক ইমেইল দিন'));
                return;
              }
              Navigator.pop(context, (
                email,
                _relation.text.trim(),
                [
                  for (final p in familyPerms)
                    if (_allow.contains(p)) p
                ]
              ));
            },
          ),
        ]),
      ),
    );
  }
}

/// One family member: what I let them do, heir, sending things, location, their copy.
class FamilyMemberScreen extends StatefulWidget {
  const FamilyMemberScreen({super.key, required this.linkId});
  final int linkId;
  @override
  State<FamilyMemberScreen> createState() => _FamilyMemberScreenState();
}

class _FamilyMemberScreenState extends State<FamilyMemberScreen> {
  bool _locating = false;

  Future<void> _send(FamilyLink l, String kind) async {
    final fam = BrainScope.read(context).family;
    if (!await needPro(context, ProFeature.family)) return;
    if (!mounted) return;
    final payload = await showAppSheet<Map<String, Object?>>(context: context, isScrollControlled: true, builder: (_) => _SendSheet(kind: kind, to: l.title));
    if (payload == null || !mounted) return;
    final ok = await fam.send(l, kind, payload);
    if (ok && mounted) toast(context, trf('{0}-কে পাঠানো হয়েছে', [l.iCall.isEmpty ? l.name : l.iCall]));
  }

  Future<void> _locate(FamilyLink l) async {
    final brain = BrainScope.read(context);
    setState(() => _locating = true);
    final p = await brain.family.locate(l);
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      toast(context, tr('ফোনটা সাড়া দেয়নি — হয়তো বন্ধ, ইন্টারনেট নেই, বা লোকেশন বন্ধ'));
      return;
    }
    final at = DateTime.tryParse('${p['at'] ?? ''}')?.toLocal();
    final lat = (p['lat'] as num).toDouble(), lon = (p['lon'] as num).toDouble();
    final now = brain.services.now();
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(trf('{0} এখন যেখানে', [l.iCall.isEmpty ? l.name : l.iCall]), style: display(20, weight: 700)),
            const SizedBox(height: 6),
            if (at != null) Text(trf('{0} মিনিট আগের', [bnDigits(now.difference(at).inMinutes.clamp(0, 99999))]), style: body(14, color: C.muted2)),
            Text(trf('আনুমানিক {0} মিটারের মধ্যে', [bnDigits(((p['acc'] as num?) ?? 0).round())]), style: body(14, color: C.muted2)),
            if ((p['battery'] as num? ?? -1) >= 0) Text(trf('ফোনের চার্জ {0}%', [bnDigits((p['battery'] as num).round())]), style: body(14, color: C.muted2)),
            const SizedBox(height: 12),
            PrimaryButton(
              label: tr('ম্যাপে দেখুন'),
              icon: Icons.map_outlined,
              onPressed: () => brain.services.launcher.openUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon')),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _claim(FamilyLink l) async {
    final brain = BrainScope.read(context);
    final note = await showDialog<String>(context: context, builder: (_) => const _ClaimDialog());
    if (note == null || !mounted) return;
    final doc = await brain.services.files.pickPhoto(camera: false);
    if (doc == null || !mounted) return;
    final sent = await brain.family.claim(l, doc, note);
    if (sent && mounted) toast(context, tr('পাঠানো হয়েছে — যাচাই হলে জানাব'));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final fam = brain.family;
    return ListenableBuilder(
      listenable: fam,
      builder: (context, _) {
        final l = fam.links.where((x) => x.id == widget.linkId).firstOrNull;
        if (l == null) return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('ফ্যামিলি')), Expanded(child: Center(child: Text(tr('আর ফ্যামিলিতে নেই'))))])));
        Widget action(String perm, IconData icon, String label, VoidCallback onTap) => l.theyAllow.contains(perm)
            ? ListRow(key: Key('family-do-$perm'), leading: Icon(icon, color: C.green), title: label, trailing: Icon(Icons.chevron_right_rounded, color: C.muted), onTap: onTap)
            : ListRow(leading: Icon(icon, color: C.muted2), title: label, subtitle: tr('তিনি অনুমতি দেননি'), subtitleColor: C.muted2);
        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              TopBar(title: l.title),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
                  Text(l.email, style: body(13.5, color: C.muted)),
                  if (fam.error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(fam.error!, style: body(14, color: C.red))),
                  const SizedBox(height: 8),
                  SectionTitle(trf('{0}-এর জন্য', [l.iCall.isEmpty ? l.name : l.iCall])),
                  Panel(
                    child: Rows(children: [
                      action('task', Icons.task_alt_rounded, tr('কাজ দিন'), () => _send(l, 'task')),
                      action('reminder', Icons.alarm_rounded, tr('রিমাইন্ডার দিন'), () => _send(l, 'reminder')),
                      action('medicine', Icons.medication_outlined, tr('ওষুধের রিমাইন্ডার দিন'), () => _send(l, 'medicine')),
                      action('note', Icons.sticky_note_2_outlined, tr('নোট পাঠান'), () => _send(l, 'note')),
                      if (l.theyAllow.contains('location'))
                        ListRow(
                          key: const Key('family-locate'),
                          leading: Icon(Icons.my_location_rounded, color: C.blue),
                          title: _locating ? tr('খুঁজছি… (৩০ সেকেন্ড পর্যন্ত)') : tr('এখন কোথায়?'),
                          trailing: _locating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.chevron_right_rounded, color: C.muted),
                          onTap: _locating ? null : () => _locate(l),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(tr('তিনি আমার জন্য যা করতে পারবেন')),
                  Panel(
                    child: Rows(children: [
                      for (final p in familyPerms)
                        CheckboxListTile(
                          key: Key('family-allow-$p'),
                          value: l.iAllow.contains(p),
                          onChanged: (v) => fam.setAllow(l, allow: [
                            for (final x in familyPerms)
                              if (x == p ? v == true : l.iAllow.contains(x)) x
                          ]),
                          title: Text(familyPermLabel(p), style: body(14.5)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(tr('উত্তরাধিকার')),
                  Panel(
                    child: Rows(children: [
                      SwitchListTile(
                        key: const Key('family-heir'),
                        value: l.theyAreMyHeir,
                        onChanged: (v) => fam.setAllow(l, heir: v),
                        title: Text(tr('আমার উত্তরাধিকারী'), style: body(15, weight: FontWeight.w600)),
                        subtitle: Text(tr('আমার ইন্তেকালের পর (কাগজ যাচাই আর ১৪ দিন পর) ফ্যামিলি পাতায় বাছাই করা অংশ দেখবেন'), style: body(12.5, color: C.muted)),
                      ),
                      if (l.theyAreMyHeir)
                        SwitchListTile(
                          key: const Key('family-open-now'),
                          value: l.iOpened,
                          onChanged: (v) => fam.setAllow(l, openNow: v),
                          title: Text(tr('এখনই পুরো অ্যাক্সেস দিন'), style: body(15)),
                          subtitle: Text(tr('অপেক্ষা ছাড়াই এখন থেকে দেখতে পাবেন'), style: body(12.5, color: C.muted)),
                        ),
                      if (l.iAmTheirHeir) ...[
                        ListRow(
                          leading: Icon(Icons.shield_outlined, color: C.ochre),
                          title: tr('আমি তাঁর উত্তরাধিকারী'),
                          subtitle: l.canOpen
                              ? tr('দেখা যাবে')
                              : switch (l.claim?.status) {
                                  'review' => tr('খবর দেওয়া হয়েছে — যাচাই চলছে'),
                                  'waiting' => trf('যাচাই হয়েছে — {0} থেকে দেখা যাবে', [l.claim?.openAt == null ? '' : fullDate(l.claim!.openAt!)]),
                                  _ => tr('তিনি জীবিত থাকতে পুরো অ্যাক্সেস না দিলে, ইন্তেকালের পর খবর দিয়ে দেখা যাবে'),
                                },
                        ),
                        if (l.canOpen)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: PrimaryButton(
                                key: const Key('family-open'),
                                label: tr('দেখুন'),
                                icon: Icons.folder_open_rounded,
                                onPressed: () async {
                                  final data = await fam.openPackage(l);
                                  if (data != null && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => HeirViewScreen(title: l.title, data: data, link: l)));
                                }),
                          )
                        else if (l.claim == null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: SecondaryButton(key: const Key('family-claim'), label: tr('ইন্তেকালের খবর দিন'), onPressed: () => _claim(l)),
                          ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      if (await confirmDialog(context, title: tr('ফ্যামিলি থেকে সরাবেন?'), text: tr('দুজনের দেওয়া সব অনুমতি, উত্তরাধিকার আর লোকেশন দেখা বন্ধ হবে।'), yes: tr('সরান'), danger: true)) {
                        await fam.remove(l);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    child: Text(tr('ফ্যামিলি থেকে সরান'), style: body(14, color: C.red)),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// What to send: a to-do, a reminder, a medicine reminder or a note.
class _SendSheet extends StatefulWidget {
  const _SendSheet({required this.kind, required this.to});
  final String kind;
  final String to;
  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime? _day;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _dose = 1;
  int _days = 0;
  final _times = <int>{8 * 60, 21 * 60};
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = BrainScope.of(context).services.now();
    final k = widget.kind;
    final heading = switch (k) { 'task' => tr('কাজ দিন'), 'reminder' => tr('রিমাইন্ডার দিন'), 'medicine' => tr('ওষুধের রিমাইন্ডার দিন'), _ => tr('নোট পাঠান') };
    String hm(int m) => bnTime(m ~/ 60, m % 60);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$heading · ${widget.to}', style: display(19, weight: 700)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('family-item-title'),
            controller: _title,
            decoration: InputDecoration(labelText: k == 'medicine' ? tr('ওষুধের নাম') : (k == 'note' ? tr('শিরোনাম') : tr('কী'))),
          ),
          if (k == 'note') ...[
            const SizedBox(height: 10),
            TextField(controller: _body, maxLines: 4, decoration: InputDecoration(labelText: tr('লেখা'))),
          ],
          if (k == 'task' || k == 'reminder') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _day ?? now, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 3650)));
                if (d != null) setState(() => _day = d);
              },
              child: InputDecorator(
                  decoration: InputDecoration(labelText: tr('কবে')), child: Text(_day == null ? (k == 'task' ? tr('দিন ছাড়া') : tr('দিন বেছে নিন')) : fullDate(_day!), style: body(16))),
            ),
          ],
          if (k == 'reminder') ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
              child: InputDecorator(decoration: InputDecoration(labelText: tr('কয়টায়')), child: Text(hm(_time.hour * 60 + _time.minute), style: body(16))),
            ),
          ],
          if (k == 'medicine') ...[
            const SizedBox(height: 10),
            Text(tr('কখন খাবেন'), style: body(13.5, weight: FontWeight.w600, color: C.muted2)),
            Wrap(spacing: 8, children: [
              for (final m in [7 * 60, 8 * 60, 13 * 60, 14 * 60, 20 * 60, 21 * 60, 22 * 60])
                FilterChip(label: Text(hm(m)), selected: _times.contains(m), onSelected: (v) => setState(() => v ? _times.add(m) : _times.remove(m))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(tr('প্রতিবার কয়টা'), style: body(15))),
              IconButton.outlined(onPressed: _dose > 1 ? () => setState(() => _dose--) : null, icon: const Icon(Icons.remove_rounded)),
              SizedBox(width: 40, child: Text(bnDigits(_dose), textAlign: TextAlign.center, style: display(18, weight: 700))),
              IconButton.outlined(onPressed: () => setState(() => _dose++), icon: const Icon(Icons.add_rounded)),
            ]),
            Row(children: [
              Expanded(child: Text(_days == 0 ? tr('কত দিন: চলতে থাকবে') : trf('কত দিন: {0} দিন', [bnDigits(_days)]), style: body(15))),
              IconButton.outlined(onPressed: _days > 0 ? () => setState(() => _days = _days <= 7 ? 0 : _days - 7) : null, icon: const Icon(Icons.remove_rounded)),
              IconButton.outlined(onPressed: () => setState(() => _days += 7), icon: const Icon(Icons.add_rounded)),
            ]),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: body(14, color: C.red))),
          const SizedBox(height: 12),
          PrimaryButton(
            key: const Key('family-item-send'),
            label: tr('পাঠান'),
            icon: Icons.send_rounded,
            onPressed: () {
              final t = _title.text.trim();
              if (t.isEmpty && !(k == 'note' && _body.text.trim().isNotEmpty)) {
                setState(() => _error = tr('কী, লিখে দিন'));
                return;
              }
              if (k == 'reminder' && _day == null) {
                setState(() => _error = tr('দিন বেছে নিন'));
                return;
              }
              if (k == 'medicine' && _times.isEmpty) {
                setState(() => _error = tr('অন্তত একটা সময় বেছে নিন'));
                return;
              }
              Navigator.pop(context, <String, Object?>{
                'title': t,
                if (k == 'note') 'body': _body.text.trim(),
                if (_day != null) 'date': _key(_day!),
                if (k == 'reminder') ...{'hour': _time.hour, 'minute': _time.minute},
                if (k == 'medicine') ...{'times': (_times.toList()..sort()), 'dose': _dose, if (_days > 0) 'until': _key(now.add(Duration(days: _days)))},
              });
            },
          ),
        ]),
      ),
    );
  }
}

/// What an heir sees: the parts the member chose, read-only.
class HeirViewScreen extends StatelessWidget {
  const HeirViewScreen({super.key, required this.title, required this.data, this.link});
  final String title;
  final Map<String, dynamic> data;

  /// Whose copy this is; needed to fetch photos (null in tests without a server).
  final FamilyLink? link;

  /// Photos and files of a note or document, as chips that open on tap.
  Widget _files(BuildContext context, List<DocFile> files) {
    if (files.isEmpty) return const SizedBox.shrink();
    final key = '${data['files_key'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final f in files)
          ActionChip(
            key: Key('heir-file-${f.id}'),
            avatar: Icon(f.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 18, color: C.green),
            label: Text(f.isImage ? tr('ছবি দেখুন') : f.name, style: body(13)),
            onPressed: () async {
              final l = link;
              final bytes = l == null || key.isEmpty ? null : await BrainScope.read(context).family.openFile(l, f.id, key);
              if (!context.mounted) return;
              if (bytes == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('এখনো আসেনি — তাঁর ফোন Wi-Fi-তে থাকলে পাঠাবে'))));
                return;
              }
              await viewFile(context, bytes, name: f.name, mime: f.mime, title: f.name);
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = AppData.fromJson(data);
    final parts = [for (final p in (data['parts'] as List? ?? const [])) '$p'];
    final at = DateTime.tryParse('${data['at'] ?? ''}')?.toLocal();
    Widget section(String head, List<Widget> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.only(top: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SectionTitle(head), Panel(child: Rows(children: rows))]));
    Widget row(String t, [String? sub, String? trail]) =>
        ListRow(leading: const SizedBox(width: 4), title: t, subtitle: sub, trailing: trail == null ? null : Text(trail, style: body(14.5, weight: FontWeight.w600)));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: title),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
              Text(at == null ? '' : trf('{0} পর্যন্ত যা ছিল — শুধু দেখা যায়, বদলানো যায় না', [fullDate(at)]), style: body(13.5, color: C.muted)),
              if (parts.contains('money')) ...[
                section(tr('ধার-দেনা'), [
                  for (final p in balances(d.ledger))
                    if (p.balance != 0) row(p.name, p.balance > 0 ? tr('তাঁর কাছে পাওনা') : tr('তাঁকে দিতে হবে'), taka(p.balance.abs())),
                ]),
                section(tr('অ্যাকাউন্ট'), [for (final a in d.accounts) row(a.name, tr(a.kind.bn))]),
                section(tr('সঞ্চয় ও কিস্তি'), [
                  for (final g in d.goals) row(g.name, tr('সঞ্চয়'), taka(g.saved)),
                  for (final i in d.installments) row(i.name, tr(i.kind.bn), trf('{0}/{1}', [bnDigits(i.paidCount), bnDigits(i.months)])),
                ]),
                section(tr('শেষ আয়-ব্যয়'), [
                  for (final e in (d.cash.toList()..sort((a, b) => b.date.compareTo(a.date))).take(50))
                    row(e.category, '${fullDate(e.date)}${e.note.isEmpty ? '' : ' · ${e.note}'}', '${e.kind == CashKind.income ? '+' : '−'}${taka(e.amount)}'),
                ]),
              ],
              if (parts.contains('notes')) ...[
                section(tr('নোট'), [
                  for (final n in d.notes)
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [row(n.title.isEmpty ? n.body : n.title, n.title.isEmpty ? null : n.body), _files(context, n.files)]),
                ]),
                section(tr('মনে রাখা কথা'), [for (final m in d.memories) row(m.text)]),
              ],
              if (parts.contains('docs'))
                section(tr('ডকুমেন্ট'), [
                  for (final x in d.docs)
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      row(x.title, [x.folder, for (final f in x.fields) '${f.label}: ${f.value}'].where((s) => s.isNotEmpty).join(' · ')),
                      _files(context, x.files),
                    ]),
                ]),
              if (parts.contains('tasks')) ...[
                section(tr('কাজ'), [for (final t in d.tasks.where((t) => !t.done)) row(t.title, t.due == null ? null : fullDate(t.due!))]),
                section(tr('রিমাইন্ডার'), [for (final r in d.reminders.where((r) => r.enabled && r.vaultId == null)) row(r.title, fullDate(r.date))]),
                section(tr('বিশেষ দিন'), [for (final s in d.specialDays) row(s.person, tr(s.kind.bn))]),
              ],
              if (parts.contains('contacts')) section(tr('নম্বর'), [for (final c in d.contacts) row(c.name, bnDigits(c.phone))]),
              if (parts.contains('health')) section(tr('ওষুধ'), [for (final m in d.medicines) row(m.name, m.note)]),
              if (parts.contains('vault'))
                section(tr('পাসওয়ার্ড ও ভল্ট'), [
                  for (final v in d.vault) row(v.name, [v.username, v.password].where((s) => s.isNotEmpty).join(' · '))
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Reporting a death: what the heir wants to add (null = not now).
class _ClaimDialog extends StatefulWidget {
  const _ClaimDialog();
  @override
  State<_ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends State<_ClaimDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('ইন্তেকালের খবর দিন')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('মৃত্যু সনদের ছবি লাগবে। আমরা যাচাই করব, তাঁর ফোন আর ইমেইলে জানাব; ১৪ দিনের মধ্যে কেউ বাতিল না করলে তিনি যা বেছে রেখেছেন, আপনি দেখতে পাবেন।'), style: body(14, height: 1.45)),
          const SizedBox(height: 10),
          TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: tr('কিছু লিখতে চাইলে (তারিখ, কোথায়)'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('বাতিল'))),
          FilledButton(onPressed: () => Navigator.pop(context, _note.text.trim()), child: Text(tr('সনদের ছবি বেছে নিন'))),
        ],
      );
}
