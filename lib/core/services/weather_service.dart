import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  WeatherData? _cachedWeatherData;

  Future<WeatherData> getWeather(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,precipitation,rain,wind_speed_10m,weather_code'
        '&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];

        final weather = WeatherData(
          temperature: (current['temperature_2m'] ?? 0).toDouble(),
          humidity: (current['relative_humidity_2m'] ?? 0).toDouble(),
          precipitation: (current['precipitation'] ?? 0).toDouble(),
          rain: (current['rain'] ?? 0).toDouble(),
          windSpeed: (current['wind_speed_10m'] ?? 0).toDouble(),
          weatherCode: (current['weather_code'] ?? 0).toInt(),
          timestamp: DateTime.now(),
          isCached: false,
          provider: 'Open-Meteo Realtime API',
        );

        _cachedWeatherData = weather;
        return weather;
      }
    } catch (_) {
      // Offline fallback
    }

    if (_cachedWeatherData != null) {
      return WeatherData(
        temperature: _cachedWeatherData!.temperature,
        humidity: _cachedWeatherData!.humidity,
        precipitation: _cachedWeatherData!.precipitation,
        rain: _cachedWeatherData!.rain,
        windSpeed: _cachedWeatherData!.windSpeed,
        weatherCode: _cachedWeatherData!.weatherCode,
        timestamp: _cachedWeatherData!.timestamp,
        isCached: true,
        provider: 'Cached Forecast Telemetry',
      );
    }

    return WeatherData.fallbackDemo();
  }
}
