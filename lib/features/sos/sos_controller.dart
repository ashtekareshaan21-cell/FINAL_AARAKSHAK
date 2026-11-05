import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/device/device_identity.dart';
import '../../core/packet/packet_engine.dart';
import '../../core/sync/eoc_websocket_client.dart';
import '../../core/sync/sync_service.dart';
import '../../data/database/database_helper.dart';
import '../../data/repositories/incident_repository.dart';
import '../mesh/mesh_packet.dart';
import '../mesh/mesh_service.dart';
import 'sos_packet.dart';

class SosController {
  final MeshService _meshService;
  final DatabaseHelper _dbHelper;
  final IncidentRepository _incidentRepository;
  final SyncService? syncService;
  final EocWebSocketClient? wsClient;

  SosPacket? _activeSos;
  final _sosStreamController = StreamController<SosPacket?>.broadcast();
  StreamSubscription? _incidentSub;
  StreamSubscription? _ackSub;

  SosController({
    MeshService? meshService,
    DatabaseHelper? dbHelper,
    IncidentRepository? incidentRepository,
    this.syncService,
    this.wsClient,
  })  : _meshService = meshService ?? MeshService(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _incidentRepository = incidentRepository ?? IncidentRepository() {
    _restoreActiveSos();
    _initListeners();
  }

  SosPacket? get activeSos => _activeSos;
  bool get isSosActive => _activeSos != null;
  Stream<SosPacket?> get sosStream => _sosStreamController.stream;

  void _initListeners() {
    // 1. Listen for Incident updates (e.g., SyncService advances status to DELIVERED)
    _incidentSub = IncidentRepository.incidentStream.listen((incidents) {
      if (_activeSos != null) {
        for (final inc in incidents) {
          if (_matchesSosPacket(_activeSos!, inc.id)) {
            if ((inc.status == 'DELIVERED' || inc.status == 'RELAYED') &&
                _activeSos!.status == SosStatus.queued) {
              _activeSos = _activeSos!.copyWith(status: SosStatus.relayed);
              _sosStreamController.add(_activeSos);
              _saveSosPacket(_activeSos!);
            } else if ((inc.status == 'ACKNOWLEDGED' || inc.status == 'ASSIGNED') &&
                _activeSos!.status != SosStatus.receivedByResponder) {
              _activeSos = _activeSos!.copyWith(
                status: SosStatus.receivedByResponder,
                responderAckMessage: inc.eocNotes.isNotEmpty ? inc.eocNotes : 'ACKNOWLEDGED BY EOC',
              );
              _sosStreamController.add(_activeSos);
              _saveSosPacket(_activeSos!);
            }
          }
        }
      }
    });

    // 2. Listen for genuine EOC acknowledgements over WebSocket
    _ackSub = wsClient?.ackStream.listen((event) {
      if (_activeSos != null) {
        if (_matchesSosPacket(_activeSos!, event.incidentId) ||
            _matchesToken(_activeSos!, event.ackToken)) {
          receiveResponderAck(_activeSos!.id, event.message);
        }
      }
    });
  }

  bool _matchesSosPacket(SosPacket sos, String incidentId) {
    if (incidentId.isEmpty) return false;
    if (sos.id == incidentId) return true;
    if (incidentId.contains(sos.id) || sos.id.contains(incidentId)) return true;
    return false;
  }

  bool _matchesToken(SosPacket sos, String ackToken) {
    if (ackToken.isEmpty) return false;
    if (ackToken == 'ACK-${sos.id}' || ackToken.contains(sos.id)) return true;
    return false;
  }

  Future<void> _restoreActiveSos() async {
    if (kIsWeb) return;
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'sos_packets',
        where: "status != 'cancelled'",
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final restored = SosPacket.fromMap(rows.first);
        _activeSos = restored;
        _sosStreamController.add(_activeSos);
      }
    } catch (_) {}
  }

  /// Triggers a One-Tap Emergency SOS broadcast
  Future<SosPacket> triggerSos({
    required double userLat,
    required double userLng,
    int batteryLevel = 100,
    String emergencyType = 'General Emergency / Disaster Help Needed',
    String medicalNote = 'No immediate medical note provided',
  }) async {
    // Generate stable sourceNode and monotonic packetId from DeviceIdentity
    final sourceNode = await DeviceIdentity.getSourceNode();
    final packetId = await DeviceIdentity.nextPacketId();
    final String sosId =
        'INC-${sourceNode.toRadixString(16).toUpperCase().padLeft(8, '0')}-${packetId.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    final packet = SosPacket(
      id: sosId,
      userId: 'USER-${sourceNode.toRadixString(16).toUpperCase()}',
      latitude: userLat,
      longitude: userLng,
      timestamp: DateTime.now(),
      batteryPercentage: batteryLevel,
      emergencyType: emergencyType,
      medicalNote: medicalNote,
      status: SosStatus.created,
    );

    _activeSos = packet;
    _sosStreamController.add(_activeSos);
    await _saveSosPacket(packet);

    // Stop at QUEUED locally until real server relay confirmation
    _activeSos = _activeSos?.copyWith(status: SosStatus.queued);
    _sosStreamController.add(_activeSos);
    await _saveSosPacket(_activeSos!);

    // Encode standard 48-byte CRC-16 frame for telemetry server ingest
    final emergencyPacket = EmergencyPacket(
      packetId: packetId,
      sourceNode: sourceNode,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      priority: TriagePriority.p0Critical,
      latitude: userLat,
      longitude: userLng,
      battery: batteryLevel,
      adults: 1,
      children: 0,
      payloadText: emergencyType.length > 23 ? emergencyType.substring(0, 23) : emergencyType,
    );
    final encodedBytes = PacketEngine.encodePacket(emergencyPacket);
    final packetHex = PacketEngine.packetToHex(encodedBytes);

    // Unified Queue: save to IncidentRepository (same queue SyncService drains)
    final incident = IncidentRecord(
      id: sosId,
      sourceNode: sourceNode,
      packetId: packetId,
      category: 'SOS Emergency',
      priority: 'P0_CRITICAL',
      severityScore: 100,
      latitude: userLat,
      longitude: userLng,
      battery: batteryLevel,
      headcount: 1,
      medicalStatus: medicalNote.isNotEmpty ? medicalNote : 'SOS Triggered',
      description: '$emergencyType | Note: $medicalNote',
      packetHex: packetHex,
      ttl: 15,
      hopCount: 0,
      status: 'QUEUED',
      createdAt: DateTime.now(),
      clientPriority: 'P0_CRITICAL',
      serverPriority: 'P0_CRITICAL',
    );
    await _incidentRepository.saveIncident(incident);

    // Package into MeshPacket with CRITICAL priority and place in local outbox
    final meshPacket = MeshPacket(
      id: sosId,
      type: PacketType.sos,
      priority: PacketPriority.critical,
      latitude: userLat,
      longitude: userLng,
      battery: batteryLevel,
      timestamp: DateTime.now(),
      ttl: 5,
      hopCount: 0,
      payload: '$emergencyType | Note: $medicalNote',
    );
    await _meshService.sendPacket(meshPacket, battery: batteryLevel);

    // Trigger sync attempt immediately if connected
    syncService?.syncPendingPackets();

    return _activeSos!;
  }

  /// Processes an incoming ACK from an EOC responder node.
  /// Phase 0 safety: call this ONLY with a real ACK (Phase 2 server /
  /// mesh confirmation). There is no simulated-ACK caller left in the app.
  Future<void> receiveResponderAck(String sosId, String responderMsg) async {
    if (_activeSos != null &&
        (_activeSos!.id == sosId ||
         'ACK-${_activeSos!.id}' == sosId ||
         _matchesSosPacket(_activeSos!, sosId))) {
      _activeSos = _activeSos!.copyWith(
        status: SosStatus.receivedByResponder,
        responderAckMessage: responderMsg,
      );
      _sosStreamController.add(_activeSos);
      await _saveSosPacket(_activeSos!);
      await _meshService.router.queue.acknowledgePacket(_activeSos!.id);
      await _incidentRepository.updateStatus(_activeSos!.id, 'ACKNOWLEDGED');
    }
  }

  /// Cancels/resolves active SOS. The cancelled packet is persisted as
  /// CANCELLED so it does not linger as an active SOS in the local DB.
  Future<void> cancelSos() async {
    if (_activeSos != null) {
      final cancelledId = _activeSos!.id;
      await _saveSosPacket(
        _activeSos!.copyWith(status: SosStatus.cancelled),
      );
      await _incidentRepository.updateStatus(cancelledId, 'CANCELLED');
    }
    _activeSos = null;
    _sosStreamController.add(null);
  }

  Future<void> _saveSosPacket(SosPacket packet) async {
    if (kIsWeb) return;
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'sos_packets',
        packet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  void dispose() {
    _incidentSub?.cancel();
    _ackSub?.cancel();
    _sosStreamController.close();
  }
}
