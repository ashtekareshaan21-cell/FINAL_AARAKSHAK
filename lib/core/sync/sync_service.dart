import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/repositories/incident_repository.dart';
import '../transport/transport_adapter.dart';
import '../packet/packet_engine.dart';

class SyncService {
  final IncidentRepository repository;
  final List<TransportAdapter> transports;
  final Connectivity connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool isSyncing = false;
  final void Function(String incidentId, String ackId)? onPacketDelivered;

  SyncService({
    required this.repository,
    required this.transports,
    this.onPacketDelivered,
    Connectivity? connectivity,
  }) : connectivity = connectivity ?? Connectivity() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        // Connectivity restored! Trigger background sync
        syncPendingPackets();
      }
    });
  }

  void start() {
    syncPendingPackets();
  }

  Future<int> syncPendingPackets() async {
    if (isSyncing) return 0;
    isSyncing = true;
    int syncedCount = 0;

    try {
      final pending = await repository.getQueuedIncidents();
      if (pending.isEmpty) {
        isSyncing = false;
        return 0;
      }

      for (final incident in pending) {
        await repository.updateStatus(incident.id, 'SENDING');

        final packetBytes = PacketEngine.hexToPacket(incident.packetHex);
        bool delivered = false;

        // Try primary InternetTransport first, then fall back to Mesh/LoRa
        for (final transport in transports) {
          final bool canAttempt = (transport is InternetTransport)
              ? transport.isConfigured
              : (transport.getStatus() == TransportStatus.connected);

          if (canAttempt) {
            final result = await transport.send(packetBytes);
            if (result.success) {
              await repository.updateStatus(incident.id, 'DELIVERED');
              onPacketDelivered?.call(incident.id, result.ackId ?? '');
              await repository.logPacketEvent(
                sourceNode: incident.sourceNode,
                packetId: incident.packetId,
                eventType: 'DELIVERED',
                nodeId: transport.name,
                details: 'Packet successfully delivered via ${transport.name} (ACK: ${result.ackId})',
              );
              delivered = true;
              syncedCount++;
              break;
            }
          }
        }

        if (!delivered) {
          await repository.updateStatus(incident.id, 'QUEUED');
          await repository.logPacketEvent(
            sourceNode: incident.sourceNode,
            packetId: incident.packetId,
            eventType: 'RETRY_FAILED',
            nodeId: 'LOCAL-SYNC',
            details: 'All transport attempts failed. Retained in offline queue with exponential backoff.',
          );
        }
      }
    } finally {
      isSyncing = false;
    }

    return syncedCount;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
