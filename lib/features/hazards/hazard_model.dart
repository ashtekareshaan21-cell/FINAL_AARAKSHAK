enum HazardSource {
  weatherApi,
  disasterApi,
  cachedDb,
  meshObservation,
  responderReport,
  citizenReport,
}

class Hazard {
  final String id;
  final String title;
  final String type; // e.g. Flood, Wildfire, Cyclone, Landslide
  final double severity; // 0.0 (low) to 1.0 (extreme)
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double confidence; // 0.0 to 1.0
  final HazardSource source;
  final String description;
  final bool responderConfirmed;
  final int supportingReports;

  const Hazard({
    required this.id,
    required this.title,
    required this.type,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.confidence,
    required this.source,
    this.description = '',
    this.responderConfirmed = false,
    this.supportingReports = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      'source': source.name,
      'description': description,
      'responderConfirmed': responderConfirmed ? 1 : 0,
      'supportingReports': supportingReports,
    };
  }

  factory Hazard.fromMap(Map<String, dynamic> map) {
    return Hazard(
      id: map['id'] as String,
      title: map['title'] as String,
      type: map['type'] as String,
      severity: (map['severity'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      confidence: (map['confidence'] as num).toDouble(),
      source: HazardSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => HazardSource.cachedDb,
      ),
      description: map['description'] as String? ?? '',
      responderConfirmed: (map['responderConfirmed'] as int?) == 1,
      supportingReports: (map['supportingReports'] as int?) ?? 1,
    );
  }
}
