// Choosing the place (owner, 29 Oct): follow the phone, or search — the 64
// districts and the cities abroad the app knows find themselves as typed;
// anything else in the world is asked from the weather service by name.
import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/calendar_bd.dart';
import '../logic/lang.dart';
import '../logic/strings_en.dart' show enStrings;
import '../logic/world_places.dart';
import '../services/weather.dart';
import '../state/brain.dart';
import '../ui/theme.dart';

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

Future<PlacePick?> pickPlace(BuildContext context) => showDialog<PlacePick>(context: context, builder: (_) => const _PlaceDialog());

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog();
  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
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
    final now = placeNamed(brain.district);
    final q = _q.text;
    final known = knownMatches(q);
    final bd = known.where((p) => !p.abroad).toList(), world = known.where((p) => p.abroad).toList();
    Widget row(Place p) {
      final on = !brain.autoPlace && p.name == now.name;
      return InkWell(
        key: Key('place-${p.name}'),
        onTap: () => Navigator.pop(context, PickedPlace(p)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          child: Text(p.label, style: body(16, weight: on ? FontWeight.w700 : FontWeight.w400, color: on ? C.green : C.ink)),
        ),
      );
    }

    Widget head(String t) => Padding(padding: const EdgeInsets.fromLTRB(24, 14, 24, 4), child: Text(t, style: body(13, weight: FontWeight.w600, color: C.muted)));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.max, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), child: Text(tr('আপনার জেলা/শহর'), style: body(18, weight: FontWeight.w600))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
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
          child: ListView(padding: const EdgeInsets.only(top: 4, bottom: 8), children: [
            if (q.isEmpty) ...[
              InkWell(
                key: const Key('place-auto'),
                onTap: () => Navigator.pop(context, FollowPhone()),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Row(children: [
                    Icon(Icons.my_location_rounded, size: 20, color: brain.autoPlace ? C.green : C.muted2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('ফোনের লোকেশন অনুযায়ী'), style: body(16, weight: brain.autoPlace ? FontWeight.w700 : FontWeight.w500, color: brain.autoPlace ? C.green : C.ink)),
                        Text(tr('অন্য জেলা বা দেশে গেলে নিজে বদলাবে — লোকেশন ফোনেই থাকে, কোথাও যায় না'), style: body(12.5, color: C.muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
                child: Text(tr('হাতে বেছে নিলেও অন্য জায়গায় গেলে আবার ফোনের লোকেশন ধরবে।'), style: body(12, color: C.muted)),
              ),
              const Divider(),
            ],
            if (bd.isNotEmpty) ...[if (q.isNotEmpty) head(tr('বাংলাদেশ')), for (final p in bd) row(p)],
            if (world.isNotEmpty) ...[head(tr('দেশের বাইরে')), for (final p in world) row(p)],
            if (_hits.isNotEmpty) ...[
              head(tr('আরও জায়গা')),
              for (final (i, h) in _hits.indexed)
                InkWell(
                  key: Key('place-hit-$i'),
                  onTap: () => _pickHit(h),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.name, style: body(16)),
                      if (h.area.isNotEmpty || h.country.isNotEmpty)
                        Text([if (h.area.isNotEmpty) h.area, if (h.country.isNotEmpty) h.country].join(', '), style: body(12.5, color: C.muted)),
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
          ]),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('বাতিল')))),
        ),
      ]),
    );
  }
}
