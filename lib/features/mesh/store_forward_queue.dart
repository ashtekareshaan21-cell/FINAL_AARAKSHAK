import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';
import 'mesh_packet.dart';

class StoreForwardQueue {
  final DatabaseHelper _dbHelper;
  final Set<String> _seenPacketIds = {};
  final List<MeshPacket> _memoryQueue = [];

  StoreForwardQueue({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  List<MeshPacket> get pendingPackets => List.unmodifiable(_memoryQueue);
  int get queueLength => _memoryQueue.length;

  /// Checks if packet has already been processed or routed (duplicate suppression)
  bool isDuplicate(String packetId) {
    return _seenPacketIds.contains(packetId);
  }

  /// Adds packet to queue with priority ordering and TTL validation
  Future<bool> enqueuePacket(MeshPacket packet) async {
    if (isDuplicate(packet.id)) {
      debugPrint('Duplicate packet ${packet.id} suppressed.');
      return false;
    }

    if (packet.ttl <= 0) {
      debugPrint('Expired packet ${packet.id} dropped (TTL=0).');
      return false;
    }

    _seenPacketIds.add(packet.id);
    _memoryQueue.add(packet);

    // Sort queue by priority (CRITICAL first) then timestamp
    _sortQueue();
    await _persistPacket(packet);
    return true;
  }

  /// Dequeues highest priority pending packet
  MeshPacket? dequeueNextPacket() {
    if (_memoryQueue.isEmpty) return null;
    return _memoryQueue.removeAt(0);
  }

  /// Marks packet as acknowledged when ACK is received from responder or gateway
  Future<void> acknowledgePacket(String packetId) async {
    final index = _memoryQueue.indexWhere((p) => p.id == packetId);
    if (index != -1) {
      _memoryQueue[index] = _memoryQueue[index].copyWith(acknowledged: true);
      await _persistPacket(_memoryQueue[index]);
    }
  }

  void _sortQueue() {
    _memoryQueue.sort((a, b) {
      final pA = _getPriorityValue(a.priority);
      final pB = _getPriorityValue(b.priority);
      if (pA != pB) {
        return pB.compareTo(pA); // Higher priority value first
      }
      return a.timestamp.compareTo(b.timestamp); // Earlier timestamp first
    });
  }

  int _getPriorityValue(PacketPriority priority) {
    switch (priority) {
      case PacketPriority.critical:
        return 4;
      case PacketPriority.high:
        return 3;
      case PacketPriority.medium:
        return 2;
      case PacketPriority.low:
        return 1;
    }
  }

  Future<void> _persistPacket(MeshPacket packet) async {
    if (kIsWeb) return;
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'mesh_outbox',
        packet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
