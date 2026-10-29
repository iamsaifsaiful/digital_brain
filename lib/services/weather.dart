import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logic/holidays_abroad.dart';
import '../logic/weather.dart';
export '../logic/holidays_abroad.dart' show AbroadHoliday;

/// Today's weather for a place; null offline.
abstract class WeatherSource {
  Future<Weather?> now(double lat, double lon, String place, DateTime at);

  /// Places in the world whose name starts like [q] (owner, 29 Oct: search
  /// in the place picker). Only the typed name is sent; [] offline.
  Future<List<PlaceHit>> search(String q, {String lang = 'bn'}) async => const [];

  /// Minutes from UTC of the clock at ([lat], [lon]) today; null offline.
  Future<int?> offsetAt(double lat, double lon) async => null;

  /// A country's public holidays in [year] ([cc]: two letters), from
  /// Nager.Date (free, no key; only the country code is sent). Null offline
  /// or for a country it does not know.
  Future<List<AbroadHoliday>?> holidays(String cc, int year) async => null;
}


/// A place found by [WeatherSource.search].
class PlaceHit {
  const PlaceHit(this.name, this.lat, this.lon, {this.area = '', this.country = '', this.countryCode = ''});
  final String name;
  final double lat, lon;

  /// The state or division, and the country, to tell same names apart.
  final String area, country, countryCode;
}

/// Open-Meteo: free and needs no key (nothing secret in the app).
class OpenMeteo implements WeatherSource {
  OpenMeteo([http.Client? client]) : _http = client ?? http.Client();
  final http.Client _http;

  @override
  Future<Weather?> now(double lat, double lon, String place, DateTime at) async {
    try {
      final u = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lon',
        'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': '1',
      });
      final r = await _http.get(u).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return Weather.fromOpenMeteo(jsonDecode(r.body) as Map<String, dynamic>, place, at);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<PlaceHit>> search(String q, {String lang = 'bn'}) async {
    if (q.trim().length < 2) return const [];
    try {
      final u = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': q.trim(), 'count': '12', 'language': lang, 'format': 'json'});
      final r = await _http.get(u).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(r.body);
      final list = j is Map && j['results'] is List ? j['results'] as List : const [];
      return [
        for (final x in list)
          if (x is Map && x['latitude'] is num && x['longitude'] is num)
            PlaceHit('${x['name'] ?? ''}', (x['latitude'] as num).toDouble(), (x['longitude'] as num).toDouble(),
                area: '${x['admin1'] ?? ''}', country: '${x['country'] ?? ''}', countryCode: '${x['country_code'] ?? ''}'),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<AbroadHoliday>?> holidays(String cc, int year) async {
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return null;
    try {
      final r = await _http.get(Uri.https('date.nager.at', '/api/v3/PublicHolidays/$year/$cc')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200 || r.body.trim().isEmpty) return null;
      final j = jsonDecode(r.body);
      if (j is! List) return null;
      final seen = <String>{};
      return [
        for (final x in j)
          if (x is Map && DateTime.tryParse('${x['date']}') != null && x['global'] != false && seen.add('${x['date']}'))
            AbroadHoliday(DateTime.parse('${x['date']}'), '${x['name'] ?? ''}', local: '${x['localName'] ?? ''}'),
      ];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> offsetAt(double lat, double lon) async {
    try {
      final u = Uri.https('api.open-meteo.com', '/v1/forecast', {'latitude': '$lat', 'longitude': '$lon', 'current': 'temperature_2m', 'timezone': 'auto', 'forecast_days': '1'});
      final r = await _http.get(u).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      final o = j is Map ? j['utc_offset_seconds'] : null;
      return o is num ? o ~/ 60 : null;
    } catch (_) {
      return null;
    }
  }
}

/// Tests: no network.
class FakeWeather implements WeatherSource {
  FakeWeather([this.answer]);
  Weather? answer;
  int asked = 0;

  /// What a search finds, and the clock offset there.
  List<PlaceHit> hits = const [];
  int? offset;

  @override
  Future<List<PlaceHit>> search(String q, {String lang = 'bn'}) async => [for (final h in hits) if (h.name.toLowerCase().startsWith(q.trim().toLowerCase())) h];

  @override
  Future<int?> offsetAt(double lat, double lon) async => offset;

  /// Holidays by country.
  Map<String, List<AbroadHoliday>> days = {};
  int holidayAsks = 0;

  @override
  Future<List<AbroadHoliday>?> holidays(String cc, int year) async {
    holidayAsks++;
    return days[cc]?.where((h) => h.date.year == year).toList();
  }

  @override
  Future<Weather?> now(double lat, double lon, String place, DateTime at) async {
    asked++;
    return answer;
  }
}
