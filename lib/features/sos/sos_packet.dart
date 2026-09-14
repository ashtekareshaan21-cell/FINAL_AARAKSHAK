enum SosStatus {
  created,
  queued,
  relayed,
  receivedByResponder,
}

class SosPacket {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final int batteryPercentage;
  final String emergencyType; // e.g., Medical, Trapped, Fire, Flood
  final String medicalNote;
  final SosStatus status;
  final String? responderAckMessage;

  const SosPacket({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.batteryPercentage,
    required this.emergencyType,
    required this.medicalNote,
    this.status = SosStatus.created,
    this.responderAckMessage,
  });

  String get statusLabel {
    switch (status) {
      case SosStatus.created:
        return 'SOS CREATED';
      case SosStatus.queued:
        return 'QUEUED IN OUTBOX';
      case SosStatus.relayed:
        return 'RELAYED VIA MESH';
      case SosStatus.receivedByResponder:
        return 'RECEIVED BY RESPONDER';
    }
  }

  SosPacket copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    int? batteryPercentage,
    String? emergencyType,
    String? medicalNote,
    SosStatus? status,
    String? responderAckMessage,
  }) {
    return SosPacket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      emergencyType: emergencyType ?? this.emergencyType,
      medicalNote: medicalNote ?? this.medicalNote,
      status: status ?? this.status,
      responderAckMessage: responderAckMessage ?? this.responderAckMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'batteryPercentage': batteryPercentage,
      'emergencyType': emergencyType,
      'medicalNote': medicalNote,
      'status': status.name,
      'responderAckMessage': responderAckMessage,
    };
  }

  factory SosPacket.fromMap(Map<String, dynamic> map) {
    return SosPacket(
      id: map['id'] as String,
      userId: map['userId'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      batteryPercentage: (map['batteryPercentage'] as int?) ?? 100,
      emergencyType: map['emergencyType'] as String? ?? 'General Emergency',
      medicalNote: map['medicalNote'] as String? ?? '',
      status: SosStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SosStatus.created,
      ),
      responderAckMessage: map['responderAckMessage'] as String?,
    );
  }
}
