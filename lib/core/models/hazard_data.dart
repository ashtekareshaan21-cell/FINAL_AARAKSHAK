enum HazardDataState { live, cached, mesh, demo }

enum HazardType {
  flood,
  landslide,
  cyclone,
  lightning,
  thunderstorm,
  earthquake,
  heatwave,
  wildfire,
  tsunami,
  other,
}

extension HazardTypeX on HazardType {
  String get label {
    switch (this) {
      case HazardType.flood:
        return 'FLOOD';
      case HazardType.landslide:
        return 'LANDSLIDE';
      case HazardType.cyclone:
        return 'CYCLONE';
      case HazardType.lightning:
        return 'LIGHTNING';
      case HazardType.thunderstorm:
        return 'THUNDERSTORM';
      case HazardType.earthquake:
        return 'EARTHQUAKE';
      case HazardType.heatwave:
        return 'HEATWAVE';
      case HazardType.wildfire:
        return 'WILDFIRE';
      case HazardType.tsunami:
        return 'TSUNAMI';
      case HazardType.other:
        return 'OTHER';
    }
  }
}

/// Generic, Location-Agnostic Hazard Model
class HazardData {
  final String id;
  final String title;
  final String type;
  final String source;
  final int severity; // Scale 0 - 40 for risk scoring
  final double latitude;
  final double longitude;
  final String description;
  final DateTime timestamp;
  final double? distanceKm;
  final double confidence; // 0.0 to 1.0
  final HazardDataState dataState;

  HazardData({
    required this.id,
    required this.title,
    required this.type,
    required this.source,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.timestamp,
    this.distanceKm,
    this.confidence = 0.85,
    this.dataState = HazardDataState.live,
  });

  HazardData copyWithDistance(double km) {
    return HazardData(
      id: id,
      title: title,
      type: type,
      source: source,
      severity: severity,
      latitude: latitude,
      longitude: longitude,
      description: description,
      timestamp: timestamp,
      distanceKm: km,
      confidence: confidence,
      dataState: dataState,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'source': source,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'distanceKm': distanceKm,
      'confidence': confidence,
      'dataState': dataState.name,
    };
  }

  factory HazardData.fromJson(Map<String, dynamic> json) {
    return HazardData(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      source: json['source'] as String,
      severity: (json['severity'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      distanceKm: json['distanceKm'] != null ? (json['distanceKm'] as num).toDouble() : null,
      confidence: json['confidence'] != null ? (json['confidence'] as num).toDouble() : 0.85,
      dataState: json['dataState'] != null
          ? HazardDataState.values.firstWhere(
              (e) => e.name == json['dataState'],
              orElse: () => HazardDataState.live,
            )
          : HazardDataState.live,
    );
  }
}
