import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/engine/context_engine.dart';
import 'package:resqmesh_ai/core/models/weather_data.dart';
import 'package:resqmesh_ai/core/models/risk_state.dart';

void main() {
  group('ContextEngine Scoring & Risk Level Tests', () {
    final engine = ContextEngine();

    test('Critical distance (<= 5km) and heavy rain triggers high risk score', () {
      final score = engine.calculateRiskScore(
        distanceKm: 3.5,
        rainfall: 25.0,
        windSpeed: 55.0,
        hazardSeverity: 25,
      );
      // 35 (dist) + 20 (rain) + 15 (wind) + 25 (severity) = 95
      expect(score, 95);
      expect(engine.scoreToRiskLevel(score), ContextRiskLevel.critical);
    });

    test('Monitoring distance (12km) produces moderate warning level', () {
      final score = engine.calculateRiskScore(
        distanceKm: 12.0,
        rainfall: 8.0,
        windSpeed: 20.0,
        hazardSeverity: 15,
      );
      // 15 (dist) + 10 (rain) + 0 (wind) + 15 (severity) = 40
      expect(score, 40);
      expect(engine.scoreToRiskLevel(score), ContextRiskLevel.warning);
    });

    test('Full context evaluation overrides to SOS level when active SOS', () {
      final weather = WeatherData.fallbackDemo();
      final result = engine.evaluateContext(
        userLat: 18.5204,
        userLon: 73.8567,
        weather: weather,
        hazards: [],
        isSosActive: true,
        isOnline: false,
      );
      expect(result.level, ContextRiskLevel.sos);
      expect(result.score, 100);
      expect(result.sourceMode, 'MESH');
    });
  });
}
