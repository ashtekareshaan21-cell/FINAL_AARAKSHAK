enum RiskLevel {
  safe,
  warning,
  danger,
  sos,
}

class RiskState {
  final RiskLevel level;
  final double score; // 0.0 to 100.0
  final double nearestHazardKm;
  final String? primaryHazard;
  final double confidence; // 0.0 to 1.0
  final bool activeSos;
  final String weatherSummary;
  final DateTime lastUpdated;

  const RiskState({
    required this.level,
    required this.score,
    required this.nearestHazardKm,
    this.primaryHazard,
    required this.confidence,
    required this.activeSos,
    required this.weatherSummary,
    required this.lastUpdated,
  });

  factory RiskState.initial() {
    // Phase 0 safety: an initial state claims no weather and no
    // confidence — it must never display invented calm weather.
    return RiskState(
      level: RiskLevel.safe,
      score: 0.0,
      nearestHazardKm: 999.0,
      primaryHazard: 'No Active Hazards Nearby',
      confidence: 0.0,
      activeSos: false,
      weatherSummary: 'No data yet',
      lastUpdated: DateTime.now(),
    );
  }

  RiskState copyWith({
    RiskLevel? level,
    double? score,
    double? nearestHazardKm,
    String? primaryHazard,
    double? confidence,
    bool? activeSos,
    String? weatherSummary,
    DateTime? lastUpdated,
  }) {
    return RiskState(
      level: level ?? this.level,
      score: score ?? this.score,
      nearestHazardKm: nearestHazardKm ?? this.nearestHazardKm,
      primaryHazard: primaryHazard ?? this.primaryHazard,
      confidence: confidence ?? this.confidence,
      activeSos: activeSos ?? this.activeSos,
      weatherSummary: weatherSummary ?? this.weatherSummary,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
