import '../models/weather_data.dart';
import '../models/hazard_data.dart';
import '../models/risk_state.dart';
import '../services/location_service.dart';

class ContextEngine {
  /// Multi-source risk score calculation
  int calculateRiskScore({
    required double distanceKm,
    required double rainfall,
    required double windSpeed,
    required int hazardSeverity,
  }) {
    int score = 0;

    // Proximity Risk (5 km critical zone vs 20 km monitoring radius)
    if (distanceKm <= 5.0) {
      score += 35;
    } else if (distanceKm <= 20.0) {
      score += 15;
    }

    // Weather Intensity (Rainfall mm)
    if (rainfall > 20.0) {
      score += 20;
    } else if (rainfall > 5.0) {
      score += 10;
    }

    // Wind Speed Telemetry (km/h)
    if (windSpeed > 50.0) {
      score += 15;
    } else if (windSpeed > 25.0) {
      score += 8;
    }

    // Official SACHET / IMD Hazard Severity Contribution
    score += hazardSeverity;

    return score.clamp(0, 100);
  }

  /// Convert numerical score (0 - 100) to Risk Level
  ContextRiskLevel scoreToRiskLevel(int score) {
    if (score >= 80) return ContextRiskLevel.critical;
    if (score >= 60) return ContextRiskLevel.danger;
    if (score >= 30) return ContextRiskLevel.warning;
    return ContextRiskLevel.safe;
  }

  /// Complete Context Evaluation Pipeline
  ContextRiskState evaluateContext({
    required double userLat,
    required double userLon,
    required WeatherData weather,
    required List<HazardData> hazards,
    required bool isSosActive,
    required bool isOnline,
  }) {
    if (isSosActive) {
      return ContextRiskState(
        score: 100,
        level: ContextRiskLevel.sos,
        distanceToNearestHazardKm: 0.0,
        weather: weather,
        sourceMode: isOnline ? 'LIVE' : 'MESH',
        updatedAt: DateTime.now(),
      );
    }

    if (hazards.isEmpty) {
      final baseScore = calculateRiskScore(
        distanceKm: 999.0,
        rainfall: weather.rain,
        windSpeed: weather.windSpeed,
        hazardSeverity: 0,
      );

      return ContextRiskState(
        score: baseScore,
        level: scoreToRiskLevel(baseScore),
        distanceToNearestHazardKm: 999.0,
        weather: weather,
        sourceMode: weather.isCached ? 'CACHED' : (isOnline ? 'LIVE' : 'CACHED'),
        updatedAt: DateTime.now(),
      );
    }

    // Compute distances and find nearest hazard
    HazardData? nearest;
    double minDistanceKm = double.infinity;

    for (var hazard in hazards) {
      final distKm = hazard.distanceKm ??
          LocationService.calculateDistanceKm(
            userLat,
            userLon,
            hazard.latitude,
            hazard.longitude,
          );

      if (distKm < minDistanceKm) {
        minDistanceKm = distKm;
        nearest = hazard.copyWithDistance(distKm);
      }
    }

    final int score = calculateRiskScore(
      distanceKm: minDistanceKm,
      rainfall: weather.rain,
      windSpeed: weather.windSpeed,
      hazardSeverity: nearest?.severity ?? 0,
    );

    final level = scoreToRiskLevel(score);

    return ContextRiskState(
      score: score,
      level: level,
      distanceToNearestHazardKm: minDistanceKm,
      nearestHazard: nearest,
      weather: weather,
      sourceMode: weather.isCached ? 'CACHED' : (isOnline ? 'LIVE' : 'CACHED'),
      updatedAt: DateTime.now(),
    );
  }
}
