import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';
import '../mesh/mesh_packet.dart';
import '../mesh/mesh_service.dart';
import 'sos_packet.dart';

class SosController {
  final MeshService _meshService;
  final DatabaseHelper _dbHelper;

  SosPacket? _activeSos;
  final _sosStreamController = StreamController<SosPacket?>.broadcast();

  SosController({
    MeshService? meshService,
    DatabaseHelper? dbHelper,
  })  : _meshService = meshService ?? MeshService(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  SosPacket? get activeSos => _activeSos;
  bool get isSosActive => _activeSos != null;
  Stream<SosPacket?> get sosStream => _sosStreamController.stream;

  /// Triggers a One-Tap Emergency SOS broadcast
  Future<SosPacket> triggerSos({
    required double userLat,
    required double userLng,
    int batteryLevel = 100,
    String emergencyType = 'General Emergency / Disaster Help Needed',
    String medicalNote = 'No immediate medical note provided',
  }) async {
    final String sosId = 'SOS-${DateTime.now().millisecondsSinceEpoch}';

    final packet = SosPacket(
      id: sosId,
      userId: 'USER-LOCAL-NODE-01',
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

    // Transition to QUEUED status
    await Future.delayed(const Duration(milliseconds: 300));
    _activeSos = _activeSos?.copyWith(status: SosStatus.queued);
    _sosStreamController.add(_activeSos);
    await _saveSosPacket(_activeSos!);

    // Package into MeshPacket with CRITICAL priority
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

    // Route packet into Store & Forward Mesh outbox
    await _meshService.sendPacket(meshPacket, battery: batteryLevel);

    // Transition to RELAYED status
    await Future.delayed(const Duration(milliseconds: 600));
    _activeSos = _activeSos?.copyWith(status: SosStatus.relayed);
    _sosStreamController.add(_activeSos);
    await _saveSosPacket(_activeSos!);

    return _activeSos!;
  }

  /// Simulates/processes incoming ACK from an EOC responder node
  Future<void> receiveResponderAck(String sosId, String responderMsg) async {
    if (_activeSos != null && _activeSos!.id == sosId) {
      _activeSos = _activeSos!.copyWith(
        status: SosStatus.receivedByResponder,
        responderAckMessage: responderMsg,
      );
      _sosStreamController.add(_activeSos);
      await _saveSosPacket(_activeSos!);
      await _meshService.router.queue.acknowledgePacket(sosId);
    }
  }

  /// Cancels/resolves active SOS
  Future<void> cancelSos() async {
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
    _sosStreamController.close();
  }
}
