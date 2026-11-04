import 'dart:convert';
import 'package:http/http.dart' as http;

enum WeatherStateTag { live, cached, stale, unavailable }

class WeatherSnapshot {
  final double temperatureC;
  final double feelsLikeC;
  final double precipitationMm;
  final int humidity;
  final double windKmh;
  final String condition;
  final WeatherStateTag stateTag;
  final DateTime observedAt;
  final String provider;

  WeatherSnapshot({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.precipitationMm,
    required this.humidity,
    required this.windKmh,
    required this.condition,
    required this.stateTag,
    required this.observedAt,
    this.provider = 'Open-Meteo API',
  });
}

abstract class WeatherService {
  Future<WeatherSnapshot> getWeather({required double latitude, required double longitude});
}

class MockableWeatherService implements WeatherService {
  WeatherSnapshot? _cachedSnapshot;

  @override
  Future<WeatherSnapshot> getWeather({required double latitude, required double longitude}) async {
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m');
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        final snapshot = WeatherSnapshot(
          temperatureC: (current['temperature_2m'] as num).toDouble(),
          feelsLikeC: (current['apparent_temperature'] as num).toDouble(),
          precipitationMm: (current['precipitation'] as num).toDouble(),
          humidity: (current['relative_humidity_2m'] as num).toInt(),
          windKmh: (current['wind_speed_10m'] as num).toDouble(),
          condition: _mapWeatherCode((current['weather_code'] as num).toInt()),
          stateTag: WeatherStateTag.live,
          observedAt: DateTime.now(),
          provider: 'Open-Meteo Realtime',
        );
        _cachedSnapshot = snapshot;
        return snapshot;
      }
    } catch (_) {
      // Fallback to cached or realistic emergency weather snapshot
    }

    if (_cachedSnapshot != null) {
      return WeatherSnapshot(
        temperatureC: _cachedSnapshot!.temperatureC,
        feelsLikeC: _cachedSnapshot!.feelsLikeC,
        precipitationMm: _cachedSnapshot!.precipitationMm,
        humidity: _cachedSnapshot!.humidity,
        windKmh: _cachedSnapshot!.windKmh,
        condition: _cachedSnapshot!.condition,
        stateTag: WeatherStateTag.cached,
        observedAt: _cachedSnapshot!.observedAt,
        provider: 'Cached Local Forecast',
      );
    }

    // Phase 0 safety: no invented offline weather. Zeroes here are
    // placeholders for a snapshot the UI must render as UNAVAILABLE
    // (see WeatherSummaryCard), never as a calm-weather reading.
    return WeatherSnapshot(
      temperatureC: 0.0,
      feelsLikeC: 0.0,
      precipitationMm: 0.0,
      humidity: 0,
      windKmh: 0.0,
      condition: 'Unavailable',
      stateTag: WeatherStateTag.unavailable,
      observedAt: DateTime.now(),
      provider: 'Unavailable — no live or cached data',
    );

  }

  String _mapWeatherCode(int code) {
    if (code >= 95) return 'Thunderstorm & Heavy Rain';
    if (code >= 80) return 'Torrential Showers';
    if (code >= 60) return 'Heavy Rainfall';
    if (code >= 50) return 'Drizzle & High Humidity';
    if (code >= 1) return 'Partly Cloudy';
    return 'Clear Skies';
  }
}
