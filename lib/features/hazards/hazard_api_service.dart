import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hazard_data_source.dart';
import 'hazard_model.dart';

class HazardApiService implements HazardDataSource {
  final http.Client _client;

  HazardApiService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<Hazard>> fetchHazards(double userLat, double userLng) async {
    try {
      // Simulating live weather/disaster API fetch (Open-Meteo severe weather / NDMA feed)
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$userLat&longitude=$userLng&current_weather=true',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentWeather = data['current_weather'];
        final double windSpeed = (currentWeather['windspeed'] as num?)?.toDouble() ?? 0.0;
        final int weatherCode = (currentWeather['weathercode'] as num?)?.toInt() ?? 0;

        List<Hazard> hazards = [];

        // High wind speed warning trigger
        if (windSpeed > 30.0) {
          hazards.add(
            Hazard(
              id: 'API-WIND-${DateTime.now().millisecondsSinceEpoch}',
              title: 'Severe Cyclone Wind Alert (${windSpeed.toStringAsFixed(1)} km/h)',
              type: 'Cyclone',
              severity: (windSpeed / 100.0).clamp(0.4, 0.95),
              latitude: userLat + 0.02,
              longitude: userLng + 0.01,
              timestamp: DateTime.now(),
              confidence: 0.60,
              source: HazardSource.weatherApi,
              description: 'Weather-derived estimate: high winds in the forecast for this point — not a responder-confirmed hazard.',
              responderConfirmed: false,
              supportingReports: 0,
            ),
          );
        }

        // Severe weather code triggers (thunderstorm / heavy rain)
        if (weatherCode >= 80) {
          hazards.add(
            Hazard(
              id: 'API-RAIN-${DateTime.now().millisecondsSinceEpoch}',
              title: 'Severe Torrential Rain & Flash Flood Warning',
              type: 'Flood',
              severity: 0.85,
              latitude: userLat + 0.015,
              longitude: userLng - 0.01,
              timestamp: DateTime.now(),
              confidence: 0.60,
              source: HazardSource.disasterApi,
              description: 'Weather-derived estimate: heavy rain in the forecast for this point — not a responder-confirmed hazard.',
              responderConfirmed: false,
              supportingReports: 0,
            ),
          );
        }

        return hazards;
      }
    } catch (_) {
      // Offline/Timeout fallback: live network data unavailable
    }
    return [];
  }
}
