/// Core system constants for Aarakshak
class AppConstants {
  static const String appName = 'Aarakshak';
  static const String appTagline = 'Infrastructure-Independent Disaster Awareness';

  // Proximity Engine Thresholds (in Kilometers)
  static const double discoveryRadiusKm = 25.0; // 25 km Discovery radius
  static const double criticalZoneKm = 5.0;     // 5 km Critical risk zone

  // Risk Score Bounds (0 - 100)
  static const double scoreSafeMax = 29.0;
  static const double scoreWarningMax = 59.0;
  static const double scoreDangerMax = 79.0;
  static const double scoreCriticalMax = 100.0;

  // Stale Hazard Decay
  static const int staleDecayHours = 6; // Hours after which hazard weight decays by half

  // Mesh Network Defaults
  static const int defaultTtl = 5;
  static const int maxHopCount = 10;
  static const int maxOutboxQueueSize = 250;
}
