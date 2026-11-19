// The weather page (owner, 19 Nov: tap the weather on Home, like the date
// opens the calendar). Design 1 of three, "ছবির আকাশ": the season's picture
// at the top with the big temperature, the places as chips under the title
// (the user's own place first), then the next hours, seven days and four
// small facts. Other places are added from + and kept on the phone.
import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/home_scene.dart';
import '../logic/lang.dart';
import '../logic/weather.dart';
import '../state/brain.dart';
import '../ui/scene_layers.dart' show sceneAlign;
import '../ui/theme.dart';
import 'place_picker.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

const _white = Colors.white;
const _shade = [Shadow(color: Color(0x59000000), blurRadius: 10)];

class _WeatherScreenState extends State<WeatherScreen> {
  /// The place shown ([Place.key]); null = the user's own.
  String? _key;
  final Set<String> _asking = {};

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
    final top = MediaQuery.of(context).padding.top;
    final night = f != null && f.hours.isNotEmpty ? !f.hours.first.day : now.hour < 6 || now.hour >= 18;
    final scene = sceneFor(brain.text('home_scene'), now);
    const heroH = 360.0;

    Widget chip(String k) {
      final on = k == key;
      final mine = k == brain.district;
      final kf = brain.forecastKept(k);
      final label = placeNamed(k).label;
      return Padding(
        padding: const EdgeInsets.only(right: 7),
        child: Material(
          color: on ? _white : _white.withValues(alpha: 0.18),
          shape: StadiumBorder(side: BorderSide(color: on ? _white : _white.withValues(alpha: 0.45))),
          child: InkWell(
            key: Key('wx-chip-$label'),
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _key = k),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (mine) ...[Icon(Icons.place_outlined, size: 15, color: on ? const Color(0xFF13718A) : _white), const SizedBox(width: 3)],
                Text(on || kf == null ? label : '$label ${bnDigits(kf.now.temp.round())}°',
                    style: body(13, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? const Color(0xFF192E28) : _white, height: 1.3)),
              ]),
            ),
          ),
        ),
      );
    }

    final hero = SizedBox(
      height: top + heroH,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(sceneAsset(scene, night: night), fit: BoxFit.cover, alignment: sceneAlign, gaplessPlayback: true, excludeFromSemantics: true),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [
              0,
              0.45,
              0.78,
              1
            ], colors: [
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0),
              C.ground.withValues(alpha: 0),
              C.ground,
            ]),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: top),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(tooltip: tr('ফিরে যান'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left_rounded, size: 30, color: _white, shadows: _shade)),
              Expanded(child: Text(tr('আবহাওয়া'), style: display(20, weight: 600, color: _white).copyWith(shadows: _shade))),
              IconButton(
                key: const Key('wx-places'),
                tooltip: tr('লোকেশন'),
                onPressed: () => _places(context),
                icon: const Icon(Icons.add_rounded, size: 27, color: _white, shadows: _shade),
              ),
            ]),
            SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [for (final k in keys) chip(k)]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: f == null
                  ? Text(_asking.contains(key) ? tr('আবহাওয়া আনা হচ্ছে…') : tr('এখন আবহাওয়া আনা গেল না — ইন্টারনেট চালু করে আবার খুলুন।'),
                      style: body(15, weight: FontWeight.w600, color: _white).copyWith(shadows: _shade))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${bnDigits(f.now.temp.round())}°', key: const Key('wx-temp'), style: display(88, weight: 500, height: 1.0, color: _white).copyWith(shadows: _shade)),
                      const SizedBox(height: 4),
                      Text(f.now.sky, style: body(18, weight: FontWeight.w600, color: _white).copyWith(shadows: _shade)),
                      Text.rich(
                        TextSpan(children: [
                          const WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.arrow_upward_rounded, size: 14, color: _white, shadows: _shade)),
                          TextSpan(text: '${bnDigits(f.now.max.round())}°  '),
                          const WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.arrow_downward_rounded, size: 14, color: _white, shadows: _shade)),
                          TextSpan(text: '${bnDigits(f.now.min.round())}° · ${trf('অনুভূত {0}°', [bnDigits(f.now.feels.round())])}'),
                        ]),
                        style: body(13.5, color: _white.withValues(alpha: 0.92)).copyWith(shadows: _shade),
                      ),
                    ]),
            ),
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
          if (f != null)
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (f.hours.isNotEmpty) _hours(f),
                  if (f.days.isNotEmpty) ...[const SizedBox(height: 10), _days(f)],
                  const SizedBox(height: 10),
                  _facts(f),
                  const SizedBox(height: 10),
                  Text(tr('Open-Meteo থেকে · শুধু জায়গার অবস্থান পাঠানো হয়'), textAlign: TextAlign.center, style: body(11.5, color: C.muted)),
                ]),
              ),
            ),
        ]),
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
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: f.hours.length,
          separatorBuilder: (_, i) => const SizedBox(width: 4),
          itemBuilder: (_, i) {
            final h = f.hours[i];
            return Container(
              width: 54,
              decoration: BoxDecoration(color: i == 0 ? C.greenTint : null, borderRadius: BorderRadius.circular(14)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label(h, i), style: body(12, color: C.muted, height: 1.2)),
                const SizedBox(height: 6),
                WeatherIcon(h.code, day: h.day, size: 26),
                const SizedBox(height: 6),
                Text('${bnDigits(h.temp.round())}°', style: display(15, weight: 600, height: 1.1)),
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
              WeatherIcon(d.code, size: 22),
              SizedBox(
                width: 36,
                child: Text('${bnDigits(d.min.round())}°', textAlign: TextAlign.right, style: body(13.5, color: C.muted)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LayoutBuilder(builder: (_, c) {
                    final l = (d.min - lo) / span * c.maxWidth, r = (hi - d.max) / span * c.maxWidth;
                    return Container(
                      height: 5,
                      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(3)),
                      child: Padding(
                        padding: EdgeInsets.only(left: l, right: r),
                        child:
                            const DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(3)), gradient: LinearGradient(colors: [Color(0xFF7CC4D6), Color(0xFFF2B35A)]))),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(width: 32, child: Text('${bnDigits(d.max.round())}°', style: body(13.5, weight: FontWeight.w600))),
            ]),
          ),
      ]),
    );
  }

  Widget _facts(Forecast f) {
    final now = DateTime.now();
    final set = f.sunset, rise = f.sunrise;
    // Clock times at the place: before sunset shows sunset, after it sunrise.
    final hereNow = f.hours.isNotEmpty ? f.hours.first.at : now;
    final showSet = set != null && (hereNow.isBefore(set) || rise == null);
    final sun = showSet ? set : rise;
    Widget tile(IconData icon, String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, size: 20, color: C.green),
              const SizedBox(width: 8),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted, height: 1.2)),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(15.5, weight: 600, height: 1.3)),
                ]),
              ),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        tile(Icons.water_drop_outlined, tr('আর্দ্রতা'), '${bnDigits(f.now.humidity)}%'),
        const SizedBox(width: 8),
        tile(Icons.air_rounded, tr('বাতাস'), trf('{0} কিমি/ঘ', [bnDigits(f.wind.round())])),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        tile(Icons.umbrella_outlined, tr('বৃষ্টির সম্ভাবনা'), '${bnDigits(f.rain)}%'),
        const SizedBox(width: 8),
        tile(showSet ? Icons.wb_twilight_rounded : Icons.wb_sunny_outlined, showSet ? tr('সূর্যাস্ত') : tr('সূর্যোদয়'), sun == null ? '—' : bnTime(sun.hour, sun.minute)),
      ]),
    ]);
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
                    SizedBox(width: 44, child: Text('${bnDigits(kf.now.temp.round())}°', textAlign: TextAlign.right, style: display(17, weight: 600))),
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
