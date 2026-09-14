import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hazard_data.dart';
import 'hazard_provider.dart';

class RealHazardProvider implements HazardProvider {
  final http.Client _client;

  RealHazardProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<HazardData>> getHazards({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,precipitation,rain,wind_speed_10m,weather_code'
        '&timezone=auto',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];

        final double windSpeed = (current['wind_speed_10m'] ?? 0).toDouble();
        final double rain = (current['rain'] ?? 0).toDouble();
        final int weatherCode = (current['weather_code'] ?? 0).toInt();

        List<HazardData> hazards = [];

        // Dynamic High Wind / Gale Warning (Location-relative offset)
        if (windSpeed > 35.0) {
          hazards.add(
            HazardData(
              id: 'REAL-WIND-${latitude.toStringAsFixed(2)}-${longitude.toStringAsFixed(2)}',
              title: 'Severe Gale & High Wind Warning (${windSpeed.toStringAsFixed(1)} km/h)',
              type: HazardType.cyclone.label,
              source: 'WEATHER-DERIVED TELEMETRY (Open-Meteo API)',
              severity: (windSpeed / 2.5).clamp(15, 35).toInt(),
              latitude: latitude + 0.02,
              longitude: longitude + 0.01,
              description: 'Dangerous high velocity gale winds active in sector.',
              timestamp: DateTime.now(),
              confidence: 0.92,
              dataState: HazardDataState.live,
            ),
          );
        }

        // Severe Precipitation / Cloudburst / Flood Risk
        if (rain > 15.0 || weatherCode >= 80) {
          hazards.add(
            HazardData(
              id: 'REAL-RAIN-${latitude.toStringAsFixed(2)}-${longitude.toStringAsFixed(2)}',
              title: 'Flash Flood & Heavy Rainfall Alert (${rain.toStringAsFixed(1)} mm/h)',
              type: HazardType.flood.label,
              source: 'WEATHER-DERIVED TELEMETRY (Open-Meteo API)',
              severity: (rain * 2.0).clamp(20, 38).toInt(),
              latitude: latitude + 0.015,
              longitude: longitude - 0.01,
              description: 'Torrential precipitation creating severe waterlogging and flash flood risk.',
              timestamp: DateTime.now(),
              confidence: 0.88,
              dataState: HazardDataState.live,
            ),
          );
        }

        // Thunderstorm & Lightning Alert
        if (weatherCode >= 95) {
          hazards.add(
            HazardData(
              id: 'REAL-STORM-${latitude.toStringAsFixed(2)}-${longitude.toStringAsFixed(2)}',
              title: 'Thunderstorm & Severe Lightning Warning',
              type: HazardType.thunderstorm.label,
              source: 'WEATHER-DERIVED TELEMETRY (Open-Meteo API)',
              severity: 30,
              latitude: latitude - 0.01,
              longitude: longitude + 0.015,
              description: 'Severe electrical activity and cloud-to-ground strikes reported.',
              timestamp: DateTime.now(),
              confidence: 0.90,
              dataState: HazardDataState.live,
            ),
          );
        }

        return hazards;
      }
    } catch (_) {
      // Timeout/Network Error
    }

    return [];
  }
}
