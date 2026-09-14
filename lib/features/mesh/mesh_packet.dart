enum PacketType {
  sos,
  hazardReport,
  responderMessage,
  heartbeat,
  ack,
}

enum PacketPriority {
  critical, // 4 - SOS, trapped person
  high,     // 3 - active hazard report
  medium,   // 2 - general hazard info
  low,      // 1 - safe status / heartbeat
}

class MeshPacket {
  final String id;
  final PacketType type;
  final PacketPriority priority;
  final double latitude;
  final double longitude;
  final int battery;
  final DateTime timestamp;
  final int ttl;
  final int hopCount;
  final String payload;
  final bool acknowledged;

  const MeshPacket({
    required this.id,
    required this.type,
    required this.priority,
    required this.latitude,
    required this.longitude,
    required this.battery,
    required this.timestamp,
    this.ttl = 5,
    this.hopCount = 0,
    required this.payload,
    this.acknowledged = false,
  });

  MeshPacket copyWith({
    String? id,
    PacketType? type,
    PacketPriority? priority,
    double? latitude,
    double? longitude,
    int? battery,
    DateTime? timestamp,
    int? ttl,
    int? hopCount,
    String? payload,
    bool? acknowledged,
  }) {
    return MeshPacket(
      id: id ?? this.id,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      battery: battery ?? this.battery,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      payload: payload ?? this.payload,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'priority': priority.name,
      'latitude': latitude,
      'longitude': longitude,
      'battery': battery,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl,
      'hopCount': hopCount,
      'payload': payload,
      'acknowledged': acknowledged ? 1 : 0,
    };
  }

  factory MeshPacket.fromMap(Map<String, dynamic> map) {
    return MeshPacket(
      id: map['id'] as String,
      type: PacketType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PacketType.sos,
      ),
      priority: PacketPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => PacketPriority.medium,
      ),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      battery: (map['battery'] as int?) ?? 100,
      timestamp: DateTime.parse(map['timestamp'] as String),
      ttl: (map['ttl'] as int?) ?? 5,
      hopCount: (map['hopCount'] as int?) ?? 0,
      payload: map['payload'] as String? ?? '',
      acknowledged: (map['acknowledged'] as int?) == 1,
    );
  }
}
