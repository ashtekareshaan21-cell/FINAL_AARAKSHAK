import 'weather_data.dart';
import 'hazard_data.dart';

enum ContextRiskLevel { safe, warning, danger, critical, sos }

extension ContextRiskLevelX on ContextRiskLevel {
  String get label {
    switch (this) {
      case ContextRiskLevel.safe:
        return 'SAFE';
      case ContextRiskLevel.warning:
        return 'WARNING';
      case ContextRiskLevel.danger:
        return 'DANGER';
      case ContextRiskLevel.critical:
        return 'CRITICAL';
      case ContextRiskLevel.sos:
        return 'ACTIVE SOS';
    }
  }

  String get subtitle {
    switch (this) {
      case ContextRiskLevel.safe:
        return 'Low Hazard Proximity • Normal Telemetry';
      case ContextRiskLevel.warning:
        return 'Moderate Risk • Monitor Regional Alerts';
      case ContextRiskLevel.danger:
        return 'Elevated Threat • Active Disaster Proximity';
      case ContextRiskLevel.critical:
        return 'Extreme Risk • Immediate Evacuation Recommended';
      case ContextRiskLevel.sos:
        return 'Emergency SOS Triggered • Mesh Packet Queued';
    }
  }
}

/// Dynamic Risk State model produced by ContextEngine
class ContextRiskState {
  final int score; // 0 - 100
  final ContextRiskLevel level;
  final double distanceToNearestHazardKm;
  final HazardData? nearestHazard;
  final WeatherData? weather;
  final String sourceMode; // "LIVE", "CACHED", "MESH"
  final DateTime updatedAt;

  ContextRiskState({
    required this.score,
    required this.level,
    required this.distanceToNearestHazardKm,
    this.nearestHazard,
    this.weather,
    required this.sourceMode,
    required this.updatedAt,
  });

  factory ContextRiskState.initial() {
    return ContextRiskState(
      score: 15,
      level: ContextRiskLevel.safe,
      distanceToNearestHazardKm: 999.0,
      sourceMode: 'CACHED',
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level.name,
      'distanceToNearestHazardKm': distanceToNearestHazardKm,
      'nearestHazard': nearestHazard?.toJson(),
      'weather': weather?.toJson(),
      'sourceMode': sourceMode,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
