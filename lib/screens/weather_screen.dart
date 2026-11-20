// ঋতুপঞ্জি / Almanac (owner, 19 Nov: "ক্যালেন্ডার আবহাওয়া এক সাথে রাখো, এবং
// এটার সুন্দর একটা নাম দাও"): the weather page (design 1, "ছবির আকাশ") and the
// calendar in one page. The season's picture at the top carries today — the
// English date with the chosen calendars, and the weather now — then two
// tabs: আবহাওয়া (next hours, seven days, the sun, three facts) and
// ক্যালেন্ডার (the month, with the coming days' weather in it, and the
// holidays). The date on Home opens the calendar tab, the weather the other.
// Temperatures in °C or °F, the other shown small beside (owner, 19 Nov).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/home_scene.dart';
import '../logic/lang.dart';
import '../logic/sky_light.dart';
import '../logic/weather.dart';
import '../logic/world_calendars.dart';
import '../state/brain.dart';
import '../ui/scene_layers.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart' show SegTabs;
import 'calendar_screen.dart' show CalendarPanel;
import 'place_picker.dart';

/// The page's name, in one place (the owner picks it).
String get daySkyName => tr('ঋতুপঞ্জি');

/// The weather tab of [DaySkyScreen] (kept for the places that open it).
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) => const DaySkyScreen();
}

class DaySkyScreen extends StatefulWidget {
  const DaySkyScreen({super.key, this.calendar = false});

  /// Opens on the calendar tab (else the weather).
  final bool calendar;

  @override
  State<DaySkyScreen> createState() => _DaySkyScreenState();
}

const _white = Colors.white;
const _soft = Color(0xE6FFFFFF);
const _shade = [Shadow(color: Color(0x59000000), blurRadius: 10)];

class _DaySkyScreenState extends State<DaySkyScreen> {
  /// The place shown ([Place.key]); null = the user's own.
  String? _key;
  final Set<String> _asking = {};
  late bool _cal = widget.calendar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brain = BrainScope.read(context);
    for (final k in [brain.district, ...brain.weatherPlaces]) {
      _ask(brain, k);
    }
  }

  Future<void> _ask(Brain brain, String key) async {
    if (!_asking.add(key)) return;
    await brain.forecastFor(key);
    _asking.remove(key);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final keys = [brain.district, ...brain.weatherPlaces];
    final key = keys.contains(_key) ? _key! : brain.district;
    final f = brain.forecastKept(key);
    final now = brain.services.now();
    final today = dayOnly(now);
    final top = MediaQuery.of(context).padding.top;
    // The light at the place itself (its own clock and sun), else at home.
    final home = sunTimes(now, placeNamed(brain.district));
    final light = f != null && f.sunrise != null && f.sunset != null && f.hours.isNotEmpty
        ? skyLight(f.hours.first.at.add(Duration(minutes: now.minute)), f.sunrise!, f.sunset!)
        : skyLight(now, home.sunrise, home.sunset);
    final scene = sceneFor(brain.text('home_scene'), now);
    // As on Home: in the dark look the day is a little dimmer, so it sits with the page.
    final dim = (light.dim + 0.16 * C.mix * (1 - light.night)).clamp(0.0, 0.6);

    // The places, in the weather tab (the user's own first).
    Widget chip(String k) {
      final on = k == key;
      final mine = k == brain.district;
      final kf = brain.forecastKept(k);
      final label = placeNamed(k).label;
      return Padding(
        padding: const EdgeInsets.only(right: 7),
        child: Material(
          color: on ? C.green : C.surface,
          shape: StadiumBorder(side: BorderSide(color: on ? C.green : C.border)),
          child: InkWell(
            key: Key('wx-chip-$label'),
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _key = k),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (mine) ...[Icon(Icons.place_outlined, size: 15, color: on ? C.onAccent : C.green), const SizedBox(width: 3)],
                Text(on || kf == null ? label : '$label ${deg(kf.now.temp)}',
                    style: body(13, weight: on ? FontWeight.w600 : FontWeight.w500, color: on ? C.onAccent : C.ink, height: 1.3)),
              ]),
            ),
          ),
        ),
      );
    }

    // Owner, 19 Nov: the top "Home-এর মতো" — the same picture, veil, letters
    // and places as the Home's top: today's date large where Home greets,
    // the calendars under it, the weather row as on Home, sunrise and sunset
    // along the foot.
    final soft = body(13.5, color: _soft).copyWith(shadows: _shade);
    final extra = [for (final id in brain.calendars) calDate(id, today, hijriShift: brain.hijriShift)?.text].whereType<String>().toList();
    final sunNow = f != null && f.sunrise != null && f.sunset != null ? (f.sunrise!, f.sunset!) : (home.sunrise, home.sunset);
    final rowStyle = body(12.5, weight: FontWeight.w500, color: _white).copyWith(shadows: _shade);

    final weatherRow = f == null
        ? Text(_asking.contains(key) ? tr('আবহাওয়া আনা হচ্ছে…') : tr('এখন আবহাওয়া আনা গেল না — ইন্টারনেট চালু করে আবার খুলুন।'),
            style: body(15, weight: FontWeight.w600, color: _white).copyWith(shadows: _shade))
        : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(deg(f.now.temp), key: const Key('wx-temp'), style: display(62, weight: 400, height: 1.05, color: _white).copyWith(shadows: _shade)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${f.now.sky} · ${placeNamed(key).label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16.5, weight: FontWeight.w600, color: _white).copyWith(shadows: _shade)),
                Text.rich(
                  TextSpan(children: [
                    const WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.arrow_upward_rounded, size: 13, color: _soft, shadows: _shade)),
                    TextSpan(text: '${deg(f.now.max)}  '),
                    const WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.arrow_downward_rounded, size: 13, color: _soft, shadows: _shade)),
                    TextSpan(text: '${deg(f.now.min)} · ${trf('অনুভূত {0}°', [degN(f.now.feels)])}'),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12.5, color: _soft).copyWith(shadows: _shade),
                ),
                // The other scale, small.
                Text(degOther(f.now.temp), key: const Key('wx-other'), style: body(12.5, color: _soft).copyWith(shadows: _shade)),
              ]),
            ),
          ]);

    final hero = SizedBox(
      height: top + 340,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(sceneAsset(scene, night: false), fit: BoxFit.cover, alignment: sceneAlign, gaplessPlayback: true, excludeFromSemantics: true),
        if (light.night > 0)
          Opacity(
            opacity: light.night.clamp(0.0, 1.0),
            child: Image.asset(sceneAsset(scene, night: true), fit: BoxFit.cover, alignment: sceneAlign, gaplessPlayback: true, excludeFromSemantics: true),
          ),
        // The sky moves with the weather there: clouds, rain, fog.
        SceneLayers(
          scene: scene,
          night: light.night,
          phase: light.phase,
          moon: moonOf(hijriDate(now, adjust: brain.hijriShift)),
          weather: weatherKind(f?.now.code),
          special: null,
          motion: brain.text('scene_motion') != 'off',
        ),
        if (dim > 0) ColoredBox(color: Colors.black.withValues(alpha: dim)),
        // A veil at the top for the words, and the fade into the page (as on Home).
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.42, 0.8, 1], colors: [
              Colors.black.withValues(alpha: 0.30),
              Colors.black.withValues(alpha: 0),
              C.ground.withValues(alpha: 0),
              C.ground,
            ]),
          ),
        ),
        Positioned(
          top: top,
          left: 8,
          right: 8,
          child: Row(children: [
            IconButton(tooltip: tr('ফিরে যান'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left_rounded, size: 30, color: _white, shadows: _shade)),
            Expanded(child: Text(daySkyName, key: const Key('ds-title'), style: body(15, weight: FontWeight.w600, color: _white).copyWith(shadows: _shade))),
            _unit(brain),
            IconButton(
              key: const Key('wx-places'),
              tooltip: tr('লোকেশন'),
              onPressed: () => _places(context),
              icon: const Icon(Icons.add_location_alt_outlined, size: 23, color: _white, shadows: _shade),
            ),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 56, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${weekdayName(today)}, ${bnDigits(today.day)} ${monthName(today.month)}',
                key: const Key('ds-date'), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(25, weight: 600, height: 1.3, color: _white).copyWith(shadows: _shade)),
            const SizedBox(height: 2),
            Text(extra.isEmpty ? bnDigits(today.year) : '${bnDigits(today.year)}  •  ${extra.first}', maxLines: 1, overflow: TextOverflow.ellipsis, style: soft),
            if (extra.length > 1) Text(extra.sublist(1).join('  •  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: _soft).copyWith(shadows: _shade)),
            const SizedBox(height: 10),
            weatherRow,
            const Spacer(),
            Row(children: [
              const Icon(Icons.wb_twilight_rounded, size: 17, color: _white, shadows: _shade),
              const SizedBox(width: 5),
              Text('${tr('সূর্যোদয়')} ${bnTime(sunNow.$1.hour, sunNow.$1.minute)}', style: rowStyle),
              const Spacer(),
              const Icon(Icons.nightlight_outlined, size: 16, color: _white, shadows: _shade),
              const SizedBox(width: 5),
              Text('${tr('সূর্যাস্ত')} ${bnTime(sunNow.$2.hour, sunNow.$2.minute)}', style: rowStyle),
            ]),
          ]),
        ),
      ]),
    );

    return Scaffold(
      backgroundColor: C.ground,
      body: RefreshIndicator(
        onRefresh: () => brain.forecastFor(key),
        child: ListView(padding: EdgeInsets.zero, children: [
          hero,
          // (No overlap on the picture: a part moved up over it cannot be tapped there.)
          Padding(
            // Above the phone's own buttons at the foot (owner, 20 Nov: the last card hid under them).
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).padding.bottom),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SegTabs<bool>(
                  key: const Key('ds-tabs'),
                  items: [(false, tr('আবহাওয়া')), (true, tr('ক্যালেন্ডার'))],
                  value: _cal,
                  onChanged: (v) => setState(() => _cal = v),
                ),
                const SizedBox(height: 10),
                // Owner, 20 Nov: "সোয়াইপ দরকার" — a sideways swipe on a tab's
                // page turns to the other tab (the month's own swipe and the
                // sideways lists still scroll themselves).
                GestureDetector(
                  key: const Key('ds-swipe'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v.abs() < 250) return;
                    final cal = v < 0; // to the left: the calendar (the tab on the right)
                    if (cal != _cal) setState(() => _cal = cal);
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
                    transitionBuilder: (child, anim) {
                      // The calendar comes from the right, the weather from the left.
                      final fromRight = child.key == const ValueKey('ds-cal');
                      return SlideTransition(
                        position: Tween<Offset>(begin: Offset(fromRight ? 0.25 : -0.25, 0), end: Offset.zero).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      );
                    },
                    child: _cal
                        ? KeyedSubtree(key: const ValueKey('ds-cal'), child: CalendarPanel(forecast: brain.forecastKept(brain.district)))
                        : Column(key: const ValueKey('ds-wx'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            SizedBox(
                              height: 34,
                              child: ListView(scrollDirection: Axis.horizontal, children: [for (final k in keys) chip(k)]),
                            ),
                            const SizedBox(height: 12),
                            if (f != null) ...[
                              // One line worth knowing, in the tab (the picture stays calm).
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                                child: Row(children: [
                                  Icon(_tip(f).$1, size: 18, color: C.green),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_tip(f).$2, key: const Key('wx-tip'), maxLines: 2, style: body(13.5, weight: FontWeight.w500))),
                                ]),
                              ),
                              if (f.hours.isNotEmpty) _hours(f),
                              if (f.days.isNotEmpty) ...[const SizedBox(height: 10), _days(f)],
                              if (f.sunrise != null && f.sunset != null) ...[const SizedBox(height: 10), _sun(f)],
                              const SizedBox(height: 10),
                              _facts(f),
                              const SizedBox(height: 10),
                              Text(tr('Open-Meteo থেকে · শুধু জায়গার অবস্থান পাঠানো হয়'), textAlign: TextAlign.center, style: body(11.5, color: C.muted)),
                            ],
                          ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  /// °C | °F, a small glass switch (kept on the phone).
  Widget _unit(Brain brain) {
    Widget side(String label, bool f) {
      final on = tempF == f;
      return GestureDetector(
        key: Key(f ? 'wx-unit-f' : 'wx-unit-c'),
        behavior: HitTestBehavior.opaque,
        onTap: () => brain.setPref('temp_unit', f ? 'f' : 'c'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: on ? _white : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: body(12.5, weight: FontWeight.w700, color: on ? const Color(0xFF192E28) : _white, height: 1.2)),
        ),
      );
    }

    return Semantics(
      label: tr('তাপমাত্রার একক'),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: _white.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [side('°C', false), side('°F', true)]),
      ),
    );
  }

  BoxDecoration get _card => BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: C.border));

  Widget _hours(Forecast f) {
    String label(HourCast h, int i) {
      if (i == 0) return tr('এখন');
      final h12 = h.at.hour % 12 == 0 ? 12 : h.at.hour % 12;
      return isEn ? '$h12 ${h.at.hour < 12 ? 'AM' : 'PM'}' : '${bnDigits(h12)}টা';
    }

    return Container(
      key: const Key('wx-hours'),
      decoration: _card,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: f.hours.length,
          separatorBuilder: (_, i) => const SizedBox(width: 4),
          itemBuilder: (_, i) {
            final h = f.hours[i];
            final on = i == 0;
            return Container(
              width: 56,
              decoration: BoxDecoration(
                gradient: on ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.green, Color.lerp(C.green, Colors.black, 0.25)!]) : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label(h, i), style: body(12, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? C.onAccent : C.muted, height: 1.2)),
                const SizedBox(height: 7),
                WeatherIcon(h.code, day: h.day, size: 26),
                const SizedBox(height: 7),
                Text(deg(h.temp), style: display(15.5, weight: 600, height: 1.1, color: on ? C.onAccent : null)),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _days(Forecast f) {
    final lo = f.days.map((d) => d.min).reduce((a, b) => a < b ? a : b);
    final hi = f.days.map((d) => d.max).reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    return Container(
      key: const Key('wx-days'),
      decoration: _card,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(trf('{0} দিনের পূর্বাভাস', [bnDigits(f.days.length)]), style: display(14, weight: 600)),
        const SizedBox(height: 2),
        for (final (i, d) in f.days.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 58, child: Text(i == 0 ? tr('আজ') : weekdayShort(d.date), style: body(13.5))),
              SizedBox(
                width: 34,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  WeatherIcon(d.code, size: 22),
                  if (d.rain >= 30) Text('${bnDigits(d.rain)}%', style: body(10, weight: FontWeight.w600, color: const Color(0xFF3F8BCB), height: 1.1)),
                ]),
              ),
              SizedBox(
                width: 36,
                child: Text(deg(d.min), textAlign: TextAlign.right, style: body(13.5, color: C.muted)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LayoutBuilder(builder: (_, c) {
                    final l = (d.min - lo) / span * c.maxWidth, r = (hi - d.max) / span * c.maxWidth;
                    // Today: a dot where the temperature is now.
                    final dot = i == 0 ? ((f.now.temp - lo) / span * c.maxWidth).clamp(0.0, c.maxWidth - 9) : null;
                    return SizedBox(
                      height: 9,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 2,
                          height: 5,
                          child: Container(
                            decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(3)),
                            padding: EdgeInsets.only(left: l, right: r),
                            child: const DecoratedBox(
                                decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(3)), gradient: LinearGradient(colors: [Color(0xFF7CC4D6), Color(0xFFF2B35A)]))),
                          ),
                        ),
                        if (dot != null)
                          Positioned(
                            left: dot,
                            top: 0,
                            child: Container(width: 9, height: 9, decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle, border: Border.all(color: C.ink, width: 2))),
                          ),
                      ]),
                    );
                  }),
                ),
              ),
              SizedBox(width: 32, child: Text(deg(d.max), style: body(13.5, weight: FontWeight.w600))),
            ]),
          ),
      ]),
    );
  }

  /// Three small facts side by side.
  Widget _facts(Forecast f) {
    Widget tile(IconData icon, Color c, String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: _card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: c),
              ),
              const SizedBox(height: 10),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(17, weight: 600, height: 1.2)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted, height: 1.3)),
            ]),
          ),
        );
    return Row(children: [
      tile(Icons.water_drop_outlined, const Color(0xFF3F8BCB), tr('আর্দ্রতা'), '${bnDigits(f.now.humidity)}%'),
      const SizedBox(width: 8),
      tile(Icons.air_rounded, const Color(0xFF2F8F83), tr('বাতাস'), trf('{0} কিমি/ঘ', [bnDigits(f.wind.round())])),
      const SizedBox(width: 8),
      tile(Icons.umbrella_outlined, const Color(0xFF6A5A8E), tr('বৃষ্টির সম্ভাবনা'), '${bnDigits(f.rain)}%'),
    ]);
  }

  /// The sun's path today: sunrise on the left, sunset on the right, the sun
  /// where it is now (at the place's own clock).
  Widget _sun(Forecast f) {
    final rise = f.sunrise!, set = f.sunset!;
    final here = f.hours.isNotEmpty ? f.hours.first.at.add(Duration(minutes: BrainScope.read(context).services.now().minute)) : rise;
    final total = set.difference(rise).inMinutes;
    final t = total <= 0 ? 0.0 : (here.difference(rise).inMinutes / total);
    Widget end(IconData icon, String label, DateTime at, CrossAxisAlignment a) => Column(crossAxisAlignment: a, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: const Color(0xFFE09A2B)),
            const SizedBox(width: 4),
            Text(label, style: body(11.5, color: C.muted, height: 1.2)),
          ]),
          Text(bnTime(at.hour, at.minute), style: display(14.5, weight: 600, height: 1.3)),
        ]);
    return Container(
      key: const Key('wx-sun'),
      decoration: _card,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(children: [
        SizedBox(height: 74, width: double.infinity, child: CustomPaint(painter: _SunPath(t, line: C.line, ink: C.muted))),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          end(Icons.wb_twilight_rounded, tr('সূর্যোদয়'), rise, CrossAxisAlignment.start),
          end(Icons.nights_stay_outlined, tr('সূর্যাস্ত'), set, CrossAxisAlignment.end),
        ]),
      ]),
    );
  }

  /// One line worth knowing: rain in the next days, else how low it goes tonight.
  (IconData, String) _tip(Forecast f) {
    for (final (i, d) in f.days.take(3).indexed) {
      if (d.rain >= 50) {
        return (Icons.umbrella_outlined, i == 0 ? tr('আজ বৃষ্টি হতে পারে — ছাতা সাথে রাখুন') : trf('{0} বৃষ্টি হতে পারে', [weekdayName(d.date)]));
      }
    }
    final next = f.hours.take(12).map((h) => h.temp);
    if (next.isNotEmpty) {
      final low = next.reduce(math.min);
      if (low <= f.now.temp - 3) return (Icons.nights_stay_outlined, trf('রাতে {0}° পর্যন্ত নামবে', [degN(low)]));
    }
    return (Icons.wb_sunny_outlined, tr('আগামী ৩ দিন বৃষ্টির সম্ভাবনা কম'));
  }

  /// The places: the user's own first, the others with × to remove, and
  /// "লোকেশন যোগ করুন" (the same search as the district picker).
  Future<void> _places(BuildContext context) async {
    final brain = BrainScope.read(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: C.surface,
      builder: (ctx) => ListenableBuilder(
        listenable: brain,
        builder: (ctx, _) {
          Widget row(String k, {bool mine = false}) {
            final p = placeNamed(k);
            final kf = brain.forecastKept(k);
            return InkWell(
              key: Key('wx-place-${p.label}'),
              onTap: () => Navigator.pop(ctx, k),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 9, 8, 9),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600))),
                        if (mine) ...[const SizedBox(width: 4), Icon(Icons.place_outlined, size: 15, color: C.green)],
                      ]),
                      if (mine) Text(tr('আপনার জেলা/শহর'), style: body(12, color: C.muted)),
                    ]),
                  ),
                  if (kf != null) ...[
                    WeatherIcon(kf.now.code, size: 24),
                    SizedBox(width: 44, child: Text(deg(kf.now.temp), textAlign: TextAlign.right, style: display(17, weight: 600))),
                  ],
                  SizedBox(
                    width: 44,
                    child: mine
                        ? null
                        : IconButton(
                            key: Key('wx-remove-${p.label}'),
                            tooltip: tr('বাদ দিন'),
                            onPressed: () => brain.removeWeatherPlace(k),
                            icon: Icon(Icons.close_rounded, size: 20, color: C.muted),
                          ),
                  ),
                ]),
              ),
            );
          }

          return SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Text(tr('লোকেশন'), style: display(19, weight: 600))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  key: const Key('wx-add'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final got = await pickPlace(ctx, adding: true);
                    if (got is PickedPlace) {
                      await brain.addWeatherPlace(got.place);
                      _ask(brain, got.place.key);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: C.inputBorder)),
                    child: Row(children: [
                      Icon(Icons.search_rounded, size: 21, color: C.muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr('জেলা, শহর বা দেশের নাম লিখুন'), style: body(14, color: C.muted))),
                      Icon(Icons.add_rounded, size: 21, color: C.green),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  row(brain.district, mine: true),
                  for (final k in brain.weatherPlaces) row(k),
                ]),
              ),
              const SizedBox(height: 12),
            ]),
          );
        },
      ),
    );
    if (picked != null && mounted) setState(() => _key = picked);
  }
}

/// A coloured weather sign from the WMO code.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon(this.code, {super.key, this.day = true, this.size = 24});
  final int code;
  final bool day;
  final double size;

  static const _sun = Color(0xFFF2B035), _moon = Color(0xFFE9C966), _cloud = Color(0xFF93A6AE), _rain = Color(0xFF4F9BD9);

  @override
  Widget build(BuildContext context) {
    final (IconData i, Color c) = switch (code) {
      0 => day ? (Icons.wb_sunny_rounded, _sun) : (Icons.nightlight_round, _moon),
      1 || 2 => day ? (Icons.wb_cloudy_outlined, _sun) : (Icons.nights_stay_outlined, _moon),
      3 => (Icons.cloud_rounded, _cloud),
      45 || 48 => (Icons.foggy, _cloud),
      >= 51 && <= 67 || >= 80 && <= 82 => (Icons.grain_rounded, _rain),
      >= 71 && <= 77 => (Icons.ac_unit_rounded, _rain),
      >= 95 => (Icons.thunderstorm_outlined, _rain),
      _ => (Icons.cloud_rounded, _cloud),
    };
    if (code == 1 || code == 2) {
      // Sun (or moon) behind a cloud.
      return SizedBox(
        width: size,
        height: size,
        child: Stack(children: [
          Positioned(left: 0, top: 0, child: Icon(day ? Icons.wb_sunny_rounded : Icons.nightlight_round, size: size * 0.66, color: day ? _sun : _moon)),
          Positioned(right: 0, bottom: 0, child: Icon(Icons.cloud_rounded, size: size * 0.78, color: _cloud)),
        ]),
      );
    }
    return Icon(i, size: size, color: c);
  }
}

/// The arc of the day with the sun on it ([t]: 0 at sunrise, 1 at sunset).
class _SunPath extends CustomPainter {
  _SunPath(this.t, {required this.line, required this.ink});
  final double t;
  final Color line, ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final base = h - 6;
    Offset at(double x) => Offset(x * w, base - math.sin(x * math.pi) * (h - 14));
    final path = Path()..moveTo(0, base);
    for (var i = 1; i <= 60; i++) {
      final p = at(i / 60);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawLine(Offset(0, base), Offset(w, base), Paint()..color = line..strokeWidth = 1.2);
    final dash = Paint()
      ..color = ink.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), dash);
      }
    }
    final x = t.clamp(0.0, 1.0);
    if (t > 0 && t < 1) {
      // The part of the day already gone, warm.
      final done = Path()..moveTo(0, base);
      for (var i = 1; i <= 60; i++) {
        final p = at(x * i / 60);
        done.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          done,
          Paint()
            ..color = const Color(0xFFF2B035)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round);
      final s = at(x);
      canvas.drawCircle(s, 12, Paint()..color = const Color(0x33F2B035));
      canvas.drawCircle(s, 7, Paint()..color = const Color(0xFFF2B035));
    }
  }

  @override
  bool shouldRepaint(_SunPath o) => o.t != t || o.line != line || o.ink != ink;
}
