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
