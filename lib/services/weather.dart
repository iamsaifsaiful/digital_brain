import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logic/weather.dart';

/// Today's weather for a place; null offline.
abstract class WeatherSource {
  Future<Weather?> now(double lat, double lon, String place, DateTime at);
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
}

/// Tests: no network.
class FakeWeather implements WeatherSource {
  FakeWeather([this.answer]);
  Weather? answer;
  int asked = 0;

  @override
  Future<Weather?> now(double lat, double lon, String place, DateTime at) async {
    asked++;
    return answer;
  }
}
