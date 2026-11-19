// Choosing the place (owner, 29 Oct): follow the phone, or search — the 64
// districts and the cities abroad the app knows find themselves as typed;
// anything else in the world is asked from the weather service by name.
// Owner, 19 Nov (design 1 of three): a sheet from below — search on top,
// "where I am now", the places picked before, then the districts by division.
import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/lang.dart';
import '../logic/strings_en.dart' show enStrings;
import '../logic/world_places.dart';
import '../services/weather.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart' show showAppSheet;

/// What was picked: '*' to follow the phone, or a [Place].
sealed class PlacePick {}

class FollowPhone extends PlacePick {}

class PickedPlace extends PlacePick {
  PickedPlace(this.place);
  final Place place;
}

/// Bangla and English, lower case, no spaces: what is matched.
String _fold(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// The places the app knows that match [q] (by either name).
List<Place> knownMatches(String q) {
  final f = _fold(q);
  bool hit(Place p) => f.isEmpty || _fold(p.name).contains(f) || _fold(enName(p.name)).contains(f);
  return [...bdPlaces.where(hit), ...worldPlaces.where(hit)];
}

/// A place's name in English (the app's own list), else itself.
String enName(String bn) => enStrings[bn] ?? bn;

/// The eight divisions and their districts (the names as in [bdPlaces]).
const bdDivisions = <String, List<String>>{
  'ঢাকা': ['ঢাকা', 'গাজীপুর', 'নারায়ণগঞ্জ', 'নরসিংদী', 'টাঙ্গাইল', 'কিশোরগঞ্জ', 'মানিকগঞ্জ', 'মুন্সীগঞ্জ', 'ফরিদপুর', 'গোপালগঞ্জ', 'মাদারীপুর', 'রাজবাড়ী', 'শরীয়তপুর'],
  'চট্টগ্রাম': ['চট্টগ্রাম', 'কুমিল্লা', 'কক্সবাজার', 'নোয়াখালী', 'ফেনী', 'ব্রাহ্মণবাড়িয়া', 'চাঁদপুর', 'লক্ষ্মীপুর', 'রাঙ্গামাটি', 'খাগড়াছড়ি', 'বান্দরবান'],
  'রাজশাহী': ['রাজশাহী', 'বগুড়া', 'পাবনা', 'সিরাজগঞ্জ', 'নাটোর', 'নওগাঁ', 'চাঁপাইনবাবগঞ্জ', 'জয়পুরহাট'],
  'খুলনা': ['খুলনা', 'যশোর', 'কুষ্টিয়া', 'সাতক্ষীরা', 'বাগেরহাট', 'ঝিনাইদহ', 'মাগুরা', 'নড়াইল', 'চুয়াডাঙ্গা', 'মেহেরপুর'],
  'বরিশাল': ['বরিশাল', 'পটুয়াখালী', 'ভোলা', 'পিরোজপুর', 'ঝালকাঠি', 'বরগুনা'],
  'সিলেট': ['সিলেট', 'মৌলভীবাজার', 'হবিগঞ্জ', 'সুনামগঞ্জ'],
  'রংপুর': ['রংপুর', 'দিনাজপুর', 'কুড়িগ্রাম', 'গাইবান্ধা', 'নীলফামারী', 'লালমনিরহাট', 'ঠাকুরগাঁও', 'পঞ্চগড়'],
  'ময়মনসিংহ': ['ময়মনসিংহ', 'জামালপুর', 'শেরপুর', 'নেত্রকোনা'],
};

/// The division a district is in ('' when not a district).
String divisionOf(String district) {
  for (final e in bdDivisions.entries) {
    if (e.value.contains(district)) return e.key;
  }
  return '';
}

/// "ঢাকা বিভাগ" / "Dhaka Division".
String divisionLabel(String div) => trf('{0} বিভাগ', [tr(div)]);

/// The places picked before, newest first (their keys).
List<String> recentPlaces(Brain brain) => [for (final k in brain.text('place_recent').split('\n')) if (k.isNotEmpty) k];

/// [adding]: a place for the weather page (owner, 19 Nov) — no "follow the
/// phone" and nothing marked as chosen.
Future<PlacePick?> pickPlace(BuildContext context, {bool adding = false}) async {
  final brain = BrainScope.read(context);
  final got = await showAppSheet<PlacePick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: C.surface,
    builder: (_) => _PlaceSheet(adding: adding),
  );
  if (got is PickedPlace) {
    final k = got.place.key;
    await brain.setPref('place_recent', [k, ...recentPlaces(brain).where((e) => e != k)].take(5).join('\n'));
  }
  return got;
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({this.adding = false});
  final bool adding;
  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final _q = TextEditingController();
  Timer? _wait;
  List<PlaceHit> _hits = const [];
  bool _searching = false;
  int _asked = 0;

  @override
  void dispose() {
    _wait?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _wait?.cancel();
    if (v.trim().length < 2) {
      setState(() => _hits = const []);
      return;
    }
    _wait = Timer(const Duration(milliseconds: 450), () async {
      final n = ++_asked;
      setState(() => _searching = true);
      final brain = BrainScope.read(context);
      final got = await brain.services.weather.search(v, lang: brain.english ? 'en' : 'bn');
      if (!mounted || n != _asked) return;
      // Not the ones already listed from the app's own list.
      final known = knownMatches(v);
      setState(() {
        _searching = false;
        _hits = [for (final h in got) if (!known.any((p) => kmBetween(p.lat, p.lon, h.lat, h.lon) < 15)) h];
      });
    });
  }

  Future<void> _pickHit(PlaceHit h) async {
    final brain = BrainScope.read(context);
    final p = await brain.placeFromHit(h);
    if (mounted) Navigator.pop(context, PickedPlace(p));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final adding = widget.adding;
    final now = placeNamed(brain.district);
    bool chosen(Place p) => !adding && !brain.autoPlace && p.name == now.name;
    final q = _q.text;
    final known = knownMatches(q);
    final bd = known.where((p) => !p.abroad).toList(), world = known.where((p) => p.abroad).toList();
    void pick(Place p) => Navigator.pop(context, PickedPlace(p));

    Widget cap(String t, {String? end}) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(children: [
            Expanded(child: Text(t, style: body(12.5, weight: FontWeight.w600, color: C.muted))),
            if (end != null) Text(end, style: body(12, color: C.muted)),
          ]),
        );

    // One place in the list: its name, where it is (when searching), and
    // the English name on the right in Bangla.
    Widget row(Place p, {bool where = false}) {
      final on = chosen(p);
      final div = p.abroad ? '' : divisionOf(p.name);
      final en = brain.english ? '' : enName(p.name);
      return InkWell(
        key: Key('place-${p.name}'),
        onTap: () => pick(p),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, where ? 9 : 12, 20, where ? 9 : 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line2))),
          child: Row(children: [
            if (where) ...[Icon(p.abroad ? Icons.public_outlined : Icons.place_outlined, size: 20, color: C.muted), const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.label, style: body(15.5, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? C.green : C.ink)),
                if (where && div.isNotEmpty) Text(divisionLabel(div), style: body(12, color: C.muted)),
              ]),
            ),
            if (en.isNotEmpty && en != p.name) Text(en, style: body(12.5, color: on ? C.green : C.muted)),
            if (on) ...[const SizedBox(width: 8), Icon(Icons.check_rounded, size: 20, color: C.green)],
          ]),
        ),
      );
    }

    // "Where I am now": follow the phone.
    Widget here() {
      final on = brain.autoPlace;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: on ? C.greenTint : C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: on ? C.green.withValues(alpha: 0.5) : C.line)),
          child: InkWell(
            key: const Key('place-auto'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(context, FollowPhone()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? C.green.withValues(alpha: 0.5) : C.line)),
                  child: Icon(Icons.my_location_outlined, size: 19, color: C.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('এখন যেখানে আছি'), style: body(15, weight: FontWeight.w600, color: on ? C.green : C.ink)),
                    Text(on ? trf('চালু আছে · এখন: {0}', [brain.placeLabel]) : tr('ফোনের লোকেশন থেকে · অন্য জেলায় গেলে নিজে বদলাবে'), style: body(12.5, color: C.muted)),
                  ]),
                ),
                if (on) Icon(Icons.check_rounded, size: 20, color: C.green),
              ]),
            ),
          ),
        ),
      );
    }

    // The places picked before (the chosen one first), as chips.
    Widget recent() {
      final keys = [if (!adding) now.key, ...recentPlaces(brain)];
      final seen = <String>{};
      final places = [for (final k in keys) if (seen.add(placeNamed(k).label)) placeNamed(k)].take(5).toList();
      if (places.length < (adding ? 1 : 2)) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        cap(tr('আগে বাছাই করা')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in places)
              Material(
                color: chosen(p) ? C.greenTint : C.surface,
                shape: StadiumBorder(side: BorderSide(color: chosen(p) ? C.green.withValues(alpha: 0.6) : C.line)),
                child: InkWell(
                  key: Key('place-recent-${p.name}'),
                  customBorder: const StadiumBorder(),
                  onTap: () => pick(p),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 6, 14, 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(chosen(p) ? Icons.check_rounded : Icons.history_rounded, size: 16, color: chosen(p) ? C.green : C.muted),
                      const SizedBox(width: 5),
                      Text(p.label, style: body(14, weight: chosen(p) ? FontWeight.w600 : FontWeight.w400, color: chosen(p) ? C.green : C.ink)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]);
    }

    final byName = {for (final p in bdPlaces) p.name: p};
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(adding ? tr('লোকেশন যোগ করুন') : tr('লোকেশন বাছুন'), style: display(20, weight: 700)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            textCapitalization: TextCapitalization.sentences,
            key: const Key('place-search'),
            controller: _q,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: tr('জেলা, শহর বা দেশের নাম লিখুন'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('মুছুন'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _q.clear();
                        _changed('');
                      }),
            ),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 16), children: [
            if (q.isEmpty) ...[
              if (!adding) here(),
              recent(),
              cap(tr('সব জেলা · বিভাগ অনুযায়ী')),
              for (final e in bdDivisions.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(children: [
                    Expanded(child: Text(divisionLabel(e.key), style: body(12, weight: FontWeight.w600, color: C.muted2))),
                    Text(bnDigits(e.value.length), style: body(12, color: C.muted)),
                  ]),
                ),
                for (final n in e.value)
                  if (byName[n] != null) row(byName[n]!),
              ],
              if (world.isNotEmpty) ...[cap(tr('দেশের বাইরে')), for (final p in world) row(p)],
            ] else ...[
              if (bd.isNotEmpty) ...[cap(tr('বাংলাদেশ')), for (final p in bd) row(p, where: true)],
              if (world.isNotEmpty) ...[cap(tr('দেশের বাইরে')), for (final p in world) row(p, where: true)],
              if (_hits.isNotEmpty) ...[
                cap(tr('আরও জায়গা')),
                for (final (i, h) in _hits.indexed)
                  InkWell(
                    key: Key('place-hit-$i'),
                    onTap: () => _pickHit(h),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 9, 20, 9),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line2))),
                      child: Row(children: [
                        Icon(Icons.public_outlined, size: 20, color: C.muted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(h.name, style: body(15.5, weight: FontWeight.w500)),
                            if (h.area.isNotEmpty || h.country.isNotEmpty)
                              Text([if (h.area.isNotEmpty) h.area, if (h.country.isNotEmpty) h.country].join(', '), style: body(12, color: C.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ],
              if (_searching) const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
              if (q.trim().length >= 2 && !_searching && known.isEmpty && _hits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tr('এই নামে কিছু পাইনি। বানানটা দেখে নিন, বা ইন্টারনেট চালু করে আবার লিখুন।'), style: body(14, color: C.muted)),
                ),
              if (q.trim().length < 2)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(tr('বাংলা বা ইংরেজি, যেভাবে খুশি লিখুন'), textAlign: TextAlign.center, style: body(13, color: C.muted)),
                ),
            ],
          ]),
        ),
      ]),
    );
  }
}
