/// The weather now (Open-Meteo: free, no key), said in Bengali.
library;

import 'bn.dart';
import 'lang.dart';

class Weather {
  const Weather({required this.temp, required this.feels, required this.min, required this.max, required this.humidity, required this.code, required this.place, required this.at});
  final double temp;
  final double feels;
  final double min;
  final double max;
  final int humidity;
  final int code;
  final String place;
  final DateTime at;

  static Weather? fromOpenMeteo(Map<String, dynamic> j, String place, DateTime at) {
    final c = j['current'], d = j['daily'];
    if (c is! Map || d is! Map) return null;
    double? n(Object? x) => x is num ? x.toDouble() : null;
    double? first(Object? x) => x is List && x.isNotEmpty ? n(x.first) : null;
    final t = n(c['temperature_2m']);
    if (t == null) return null;
    return Weather(
      temp: t,
      feels: n(c['apparent_temperature']) ?? t,
      min: first(d['temperature_2m_min']) ?? t,
      max: first(d['temperature_2m_max']) ?? t,
      humidity: (n(c['relative_humidity_2m']) ?? 0).round(),
      code: (n(c['weather_code']) ?? 0).round(),
      place: place,
      at: at,
    );
  }

  /// "২৮°" — the label on the home sky.
  String get short => '${bnDigits(temp.round())}°';

  String get sky => weatherWords(code);

  /// The full answer to "আজ তাপমাত্রা কত?".
  String said() => trf('{0}: এখন {1}°সে ({2}) — অনুভূত {3}°, আজ সর্বনিম্ন {4}° আর সর্বোচ্চ {5}°, আর্দ্রতা {6}%।',
      [tr(place), bnDigits(temp.round()), sky, bnDigits(feels.round()), bnDigits(min.round()), bnDigits(max.round()), bnDigits(humidity)]);
}

/// The WMO weather code in words.
String weatherWords(int code) => tr(switch (code) {
      0 => 'পরিষ্কার আকাশ',
      1 || 2 => 'আংশিক মেঘলা',
      3 => 'মেঘলা',
      45 || 48 => 'কুয়াশা',
      >= 51 && <= 57 => 'গুঁড়ি গুঁড়ি বৃষ্টি',
      >= 61 && <= 67 => 'বৃষ্টি',
      >= 71 && <= 77 => 'তুষার',
      >= 80 && <= 82 => 'বৃষ্টির ঝাপটা',
      >= 95 => 'বজ্রসহ বৃষ্টি',
      _ => 'মেঘলা',
    });

/// One hour ahead on the weather page.
class HourCast {
  const HourCast(this.at, this.temp, this.code, {this.day = true});
  final DateTime at;
  final double temp;
  final int code;
  final bool day;
}

/// One day on the weather page.
class DayCast {
  const DayCast(this.date, this.code, this.min, this.max, {this.rain = 0});
  final DateTime date;
  final int code;
  final double min, max;

  /// The chance of rain, 0–100.
  final int rain;
}

/// The weather page (owner, 19 Nov: tap the weather on Home): now, the next
/// hours, seven days, and a few facts.
class Forecast {
  const Forecast({required this.now, required this.hours, required this.days, this.wind = 0, this.sunrise, this.sunset});
  final Weather now;
  final List<HourCast> hours;
  final List<DayCast> days;

  /// km/h.
  final double wind;

  /// Local clock times at the place.
  final DateTime? sunrise, sunset;

  /// Today's chance of rain, 0–100.
  int get rain => days.isEmpty ? 0 : days.first.rain;

  /// From Open-Meteo's answer (current + hourly + daily, timezone auto).
  /// Times are the place's own clock; [at] is when it was asked.
  static Forecast? fromOpenMeteo(Map<String, dynamic> j, String place, DateTime at) {
    final w = Weather.fromOpenMeteo(j, place, at);
    if (w == null) return null;
    double? n(Object? x) => x is num ? x.toDouble() : null;
    List l(Object? x) => x is List ? x : const [];
    final h = j['hourly'] is Map ? j['hourly'] as Map : const {};
    final d = j['daily'] as Map;
    final c = j['current'] as Map;
    final nowThere = DateTime.tryParse('${c['time'] ?? ''}');
    final hours = <HourCast>[];
    final ht = l(h['time']), htemp = l(h['temperature_2m']), hcode = l(h['weather_code']), hday = l(h['is_day']);
    for (var i = 0; i < ht.length && i < htemp.length && hours.length < 24; i++) {
      final t = DateTime.tryParse('${ht[i]}');
      final v = n(htemp[i]);
      if (t == null || v == null) continue;
      // From this hour on.
      if (nowThere != null && t.isBefore(DateTime(nowThere.year, nowThere.month, nowThere.day, nowThere.hour))) continue;
      hours.add(HourCast(t, v, i < hcode.length ? (n(hcode[i]) ?? 0).round() : 0, day: i < hday.length ? hday[i] != 0 : true));
    }
    final days = <DayCast>[];
    final dt = l(d['time']), dcode = l(d['weather_code']), dmin = l(d['temperature_2m_min']), dmax = l(d['temperature_2m_max']), drain = l(d['precipitation_probability_max']);
    for (var i = 0; i < dt.length && i < dmin.length && i < dmax.length; i++) {
      final t = DateTime.tryParse('${dt[i]}');
      final lo = n(dmin[i]), hi = n(dmax[i]);
      if (t == null || lo == null || hi == null) continue;
      days.add(DayCast(t, i < dcode.length ? (n(dcode[i]) ?? 0).round() : 0, lo, hi, rain: i < drain.length ? (n(drain[i]) ?? 0).round() : 0));
    }
    DateTime? first(Object? x) => l(x).isEmpty ? null : DateTime.tryParse('${l(x).first}');
    return Forecast(now: w, hours: hours, days: days, wind: n(c['wind_speed_10m']) ?? 0, sunrise: first(d['sunrise']), sunset: first(d['sunset']));
  }
}
