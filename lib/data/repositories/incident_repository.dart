import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class IncidentRecord {
  final String id;
  final int sourceNode;
  final int packetId;
  final String category;
  final String priority;
  final int severityScore;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final int battery;
  final int headcount;
  final String medicalStatus;
  final String description;
  final String packetHex;
  final int ttl;
  final int hopCount;
  final String status; // LOCAL, QUEUED, RELAYING, DELIVERED, ACKNOWLEDGED, ASSIGNED, RESOLVED
  final DateTime createdAt;
  final DateTime? receivedAt;
  final String clientPriority;
  final String serverPriority;
  final int trustScore;
  final String assignedUnit;
  final int etaMinutes;
  final String eocNotes;
  final bool humanVerified;

  IncidentRecord({
    required this.id,
    required this.sourceNode,
    required this.packetId,
    required this.category,
    required this.priority,
    required this.severityScore,
    required this.latitude,
    required this.longitude,
    this.gpsAccuracy = 5.0,
    required this.battery,
    required this.headcount,
    required this.medicalStatus,
    required this.description,
    required this.packetHex,
    required this.ttl,
    required this.hopCount,
    required this.status,
    required this.createdAt,
    this.receivedAt,
    required this.clientPriority,
    required this.serverPriority,
    this.trustScore = 94,
    this.assignedUnit = '',
    this.etaMinutes = 0,
    this.eocNotes = '',
    this.humanVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_node': sourceNode,
      'packet_id': packetId,
      'category': category,
      'priority': priority,
      'severity_score': severityScore,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'battery': battery,
      'headcount': headcount,
      'medical_status': medicalStatus,
      'description': description,
      'packet_hex': packetHex,
      'ttl': ttl,
      'hop_count': hopCount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
      'client_priority': clientPriority,
      'server_priority': serverPriority,
    };
  }

  factory IncidentRecord.fromMap(Map<String, dynamic> map) {
    return IncidentRecord(
      id: map['id'],
      sourceNode: map['source_node'],
      packetId: map['packet_id'],
      category: map['category'],
      priority: map['priority'],
      severityScore: map['severity_score'],
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      gpsAccuracy: (map['gps_accuracy'] as num).toDouble(),
      battery: map['battery'],
      headcount: map['headcount'],
      medicalStatus: map['medical_status'],
      description: map['description'],
      packetHex: map['packet_hex'],
      ttl: map['ttl'],
      hopCount: map['hop_count'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      receivedAt: map['received_at'] != null ? DateTime.parse(map['received_at']) : null,
      clientPriority: map['client_priority'],
      serverPriority: map['server_priority'],
      trustScore: map['trust_score'] ?? 94,
      assignedUnit: map['assigned_unit'] ?? '',
      etaMinutes: map['eta_minutes'] ?? 0,
      eocNotes: map['eoc_notes'] ?? '',
      humanVerified: (map['human_verified'] ?? 0) == 1,
    );
  }

  IncidentRecord copyWith({
    String? status,
    String? serverPriority,
    DateTime? receivedAt,
    int? trustScore,
    String? assignedUnit,
    int? etaMinutes,
    String? eocNotes,
    bool? humanVerified,
  }) {
    return IncidentRecord(
      id: id,
      sourceNode: sourceNode,
      packetId: packetId,
      category: category,
      priority: priority,
      severityScore: severityScore,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      battery: battery,
      headcount: headcount,
      medicalStatus: medicalStatus,
      description: description,
      packetHex: packetHex,
      ttl: ttl,
      hopCount: hopCount,
      status: status ?? this.status,
      createdAt: createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      clientPriority: clientPriority,
      serverPriority: serverPriority ?? this.serverPriority,
      trustScore: trustScore ?? this.trustScore,
      assignedUnit: assignedUnit ?? this.assignedUnit,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      eocNotes: eocNotes ?? this.eocNotes,
      humanVerified: humanVerified ?? this.humanVerified,
    );
  }
}

class IncidentRepository {
  static final List<IncidentRecord> _webInMemoryQueue = [
    // Seed an initial incident so Admin EOC is not empty on first launch
    IncidentRecord(
      id: 'INC-7F92A-4B12',
      sourceNode: 0x12345678,
      packetId: 0x4B12,
      category: 'Flood',
      priority: 'P0 — CRITICAL',
      severityScore: 130,
      latitude: 18.52043,
      longitude: 73.85674,
      gpsAccuracy: 8.0,
      battery: 85,
      headcount: 4,
      medicalStatus: 'Unconscious',
      description: 'Flood water rising fast. 4 people trapped inside structure. 1 person unconscious.',
      packetHex: '525351310001123456784B1266D42A1000000000000000000000000000000000',
      ttl: 15,
      hopCount: 2,
      status: 'DELIVERED',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
      receivedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      clientPriority: 'P0 — CRITICAL',
      serverPriority: 'P0 — CRITICAL',
      trustScore: 94,
      assignedUnit: 'NDRF Rescue Unit 04',
      etaMinutes: 18,
      eocNotes: 'Boat squad dispatched with medical team.',
      humanVerified: true,
    ),
  ];

  static final StreamController<List<IncidentRecord>> _streamController =
      StreamController<List<IncidentRecord>>.broadcast();

  static Stream<List<IncidentRecord>> get incidentStream => _streamController.stream;

  void _notifyListeners() {
    _streamController.add(List.unmodifiable(_webInMemoryQueue));
  }

  Future<void> saveIncident(IncidentRecord incident) async {
    int idx = _webInMemoryQueue.indexWhere((i) => i.id == incident.id);
    if (idx >= 0) {
      _webInMemoryQueue[idx] = incident;
    } else {
      _webInMemoryQueue.insert(0, incident);
    }

    if (!kIsWeb) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert(
          'incidents',
          incident.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await logPacketEvent(
          sourceNode: incident.sourceNode,
          packetId: incident.packetId,
          eventType: 'CREATED',
          nodeId: 'LOCAL-DEVICE',
          details: 'Incident saved to local SQLite persistent queue (Status: ${incident.status})',
        );
      } catch (_) {}
    }
    _notifyListeners();
  }

  Future<List<IncidentRecord>> getQueuedIncidents() async {
    return _webInMemoryQueue.where((i) => ['LOCAL', 'QUEUED', 'PENDING', 'SENDING', 'RELAYING'].contains(i.status)).toList();
  }

  Future<List<IncidentRecord>> getAllIncidents() async {
    return List.from(_webInMemoryQueue);
  }

  Future<void> updateStatus(String id, String status) async {
    int idx = _webInMemoryQueue.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      _webInMemoryQueue[idx] = _webInMemoryQueue[idx].copyWith(
        status: status,
        receivedAt: status == 'DELIVERED' || status == 'ACKNOWLEDGED' ? DateTime.now() : _webInMemoryQueue[idx].receivedAt,
      );
    }
    if (!kIsWeb) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'incidents',
          {'status': status},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    }
    _notifyListeners();
  }

  Future<void> assignResponder(String id, String unitName, int etaMinutes, {String notes = ''}) async {
    int idx = _webInMemoryQueue.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      _webInMemoryQueue[idx] = _webInMemoryQueue[idx].copyWith(
        status: 'ASSIGNED',
        assignedUnit: unitName,
        etaMinutes: etaMinutes,
        eocNotes: notes.isNotEmpty ? notes : 'Rescue unit assigned by EOC operator.',
        humanVerified: true,
      );
    }
    if (!kIsWeb) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'incidents',
          {
            'status': 'ASSIGNED',
            'assigned_unit': unitName,
            'eta_minutes': etaMinutes,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (_) {}
    }
    _notifyListeners();
  }

  Future<void> verifyIncident(String id) async {
    int idx = _webInMemoryQueue.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      _webInMemoryQueue[idx] = _webInMemoryQueue[idx].copyWith(
        humanVerified: true,
        trustScore: (_webInMemoryQueue[idx].trustScore + 10).clamp(0, 100),
      );
    }
    _notifyListeners();
  }

  Future<void> logPacketEvent({
    required int sourceNode,
    required int packetId,
    required String eventType,
    required String nodeId,
    required String details,
  }) async {
    if (kIsWeb) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('packet_events', {
        'source_node': sourceNode,
        'packet_id': packetId,
        'event_type': eventType,
        'node_id': nodeId,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details,
      });
    } catch (_) {}
  }

  Future<void> clearAll() async {
    _webInMemoryQueue.clear();
    if (!kIsWeb) {
      try {
        await DatabaseHelper.instance.clearAllData();
      } catch (_) {}
    }
    _notifyListeners();
  }
}
