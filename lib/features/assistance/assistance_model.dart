enum AssistanceType {
  hospital,
  shelter,
  reliefCenter,
  ambulance,
  rescueStation,
}

class AssistancePoint {
  final String id;
  final String name;
  final AssistanceType type;
  final double latitude;
  final double longitude;
  final int capacity;
  final bool isAvailable;
  final bool hazardExposed;
  final String contact;
  final double calculatedDistanceKm;

  const AssistancePoint({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.capacity = 50,
    this.isAvailable = true,
    this.hazardExposed = false,
    this.contact = '',
    this.calculatedDistanceKm = 0.0,
  });

  AssistancePoint copyWith({
    String? id,
    String? name,
    AssistanceType? type,
    double? latitude,
    double? longitude,
    int? capacity,
    bool? isAvailable,
    bool? hazardExposed,
    String? contact,
    double? calculatedDistanceKm,
  }) {
    return AssistancePoint(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacity: capacity ?? this.capacity,
      isAvailable: isAvailable ?? this.isAvailable,
      hazardExposed: hazardExposed ?? this.hazardExposed,
      contact: contact ?? this.contact,
      calculatedDistanceKm: calculatedDistanceKm ?? this.calculatedDistanceKm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'isAvailable': isAvailable ? 1 : 0,
      'hazardExposed': hazardExposed ? 1 : 0,
      'contact': contact,
    };
  }

  factory AssistancePoint.fromMap(Map<String, dynamic> map) {
    return AssistancePoint(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AssistanceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AssistanceType.shelter,
      ),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      capacity: (map['capacity'] as int?) ?? 50,
      isAvailable: (map['isAvailable'] as int?) == 1,
      hazardExposed: (map['hazardExposed'] as int?) == 1,
      contact: map['contact'] as String? ?? '',
    );
  }
}
