import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/models/weather_data.dart';
import 'package:resqmesh_ai/core/services/weather_service.dart';

void main() {
  group('WeatherData & WeatherService Core Unit Tests', () {
    test('WMO Weather Code interpretation maps correctly', () {
      expect(WeatherData.weatherDescription(0), 'Clear');
      expect(WeatherData.weatherDescription(2), 'Cloudy');
      expect(WeatherData.weatherDescription(61), 'Rain');
      expect(WeatherData.weatherDescription(81), 'Heavy Rain');
      expect(WeatherData.weatherDescription(95), 'Thunderstorm');
    });

    test('WeatherData fallbackDemo produces realistic parameters', () {
      final weather = WeatherData.fallbackDemo();
      expect(weather.temperature, 27.0);
      expect(weather.humidity, 82.0);
      expect(weather.precipitation, 8.2);
      expect(weather.rain, 8.2);
      expect(weather.windSpeed, 24.0);
      expect(weather.weatherCode, 81);
      expect(weather.conditionText, 'Heavy Rain');
      expect(weather.isCached, isTrue);
    });

    test('WeatherService returns fallback or live weather telemetry', () async {
      final service = WeatherService();
      final weather = await service.getWeather(18.5204, 73.8567);
      expect(weather.temperature, isNotNull);
      expect(weather.humidity, isNotNull);
      expect(weather.conditionText, isNotEmpty);
    });
  });
}
