import 'dart:math';
import '../../core/utils/geo_utils.dart';
import '../../core/constants/app_constants.dart';
import '../hazards/hazard_model.dart';
import 'risk_state.dart';

class RiskCalculator {
  /// Evaluates active hazards and active SOS state to produce a unified [RiskState].
  static RiskState calculateRiskState({
    required double userLat,
    required double userLng,
    required List<Hazard> activeHazards,
    required bool activeSos,
    String? weatherSummary,
  }) {
    // Rule 1: Active SOS overrides normal environmental risk
    if (activeSos) {
      return RiskState(
        level: RiskLevel.sos,
        score: 100.0,
        nearestHazardKm: 0.0,
        primaryHazard: 'EMERGENCY SOS ACTIVE',
        confidence: 1.0,
        activeSos: true,
        weatherSummary: weatherSummary ?? 'Emergency SOS Broadcast Active',
        lastUpdated: DateTime.now(),
      );
    }

    if (activeHazards.isEmpty) {
      return RiskState.initial();
    }

    double maxCalculatedScore = 0.0;
    double nearestDistanceKm = 999.0;
    Hazard? topHazard;

    for (var hazard in activeHazards) {
      final double distKm = GeoUtils.haversineDistance(
        lat1: userLat,
        lon1: userLng,
        lat2: hazard.latitude,
        lon2: hazard.longitude,
      );

      if (distKm < nearestDistanceKm) {
        nearestDistanceKm = distKm;
      }

      // Proximity Factor calculation (5km critical zone, 25km discovery limit)
      double proximityFactor = 0.0;
      if (distKm <= AppConstants.criticalZoneKm) {
        // High proximity inside 5km: 1.0 down to 0.75
        proximityFactor = 1.0 - (distKm / AppConstants.criticalZoneKm) * 0.25;
      } else if (distKm <= AppConstants.discoveryRadiusKm) {
        // Linear decay from 5km to 25km: 0.75 down to 0.1
        final double ratio = (distKm - AppConstants.criticalZoneKm) /
            (AppConstants.discoveryRadiusKm - AppConstants.criticalZoneKm);
        proximityFactor = 0.75 * (1.0 - ratio);
      } else {
        proximityFactor = 0.0;
      }

      // Freshness Decay calculation (stale reports have reduced weight)
      final double ageInHours =
          DateTime.now().difference(hazard.timestamp).inMinutes / 60.0;
      final double freshness =
          exp(-ageInHours / AppConstants.staleDecayHours).clamp(0.2, 1.0);

      // Confidence & Source weight
      double sourceWeight = hazard.confidence;
      if (hazard.responderConfirmed) {
        sourceWeight = (sourceWeight * 1.15).clamp(0.0, 1.0);
      }

      // Trend / Direction factor
      double trendFactor = 1.0;

      // Mathematical Risk Score formula
      // Score component = Severity (0-1) * Proximity (0-1) * Freshness (0.2-1) * Confidence (0-1) * 100
      double hazardScore = hazard.severity *
          proximityFactor *
          freshness *
          sourceWeight *
          trendFactor *
          100.0;

      if (hazardScore > maxCalculatedScore) {
        maxCalculatedScore = hazardScore;
        topHazard = hazard;
      }
    }

    maxCalculatedScore = maxCalculatedScore.clamp(0.0, 100.0);

    // Determine Risk Level based on bounds
    RiskLevel level;
    if (maxCalculatedScore >= 80.0) {
      level = RiskLevel.sos; // Critical Environmental Level
    } else if (maxCalculatedScore >= 60.0) {
      level = RiskLevel.danger;
    } else if (maxCalculatedScore >= 30.0) {
      level = RiskLevel.warning;
    } else {
      level = RiskLevel.safe;
    }

    return RiskState(
      level: level,
      score: maxCalculatedScore,
      nearestHazardKm: nearestDistanceKm,
      primaryHazard: topHazard != null
          ? '${topHazard.title} (${nearestDistanceKm.toStringAsFixed(1)} km)'
          : 'No Primary Hazard',
      confidence: topHazard?.confidence ?? 1.0,
      activeSos: false,
      weatherSummary: weatherSummary ?? 'Active Telemetry Monitoring',
      lastUpdated: DateTime.now(),
    );
  }
}
