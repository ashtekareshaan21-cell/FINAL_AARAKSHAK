import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
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

  String _syncStatusMessage = '';
  String get syncStatusMessage => _syncStatusMessage;

  final _syncStatusController = StreamController<String>.broadcast();
  Stream<String> get syncStatusStream => _syncStatusController.stream;

  void updateSyncStatus(String msg) {
    _syncStatusMessage = msg;
    _syncStatusController.add(msg);
  }

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
        updateSyncStatus('Internet restored — syncing pending packets...');
        syncPendingPackets();
      } else {
        updateSyncStatus('No internet — will retry when back online');
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
        await syncRemoteAcks();
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

          if (!canAttempt && transport is InternetTransport && !transport.isConfigured) {
            updateSyncStatus('Server not configured — run with --dart-define');
          }

          if (canAttempt) {
            if (transport is InternetTransport) {
              updateSyncStatus('Contacting server — transmitting 48-byte packet...');
            } else {
              updateSyncStatus('Broadcasting via Offline BLE Mesh to nearby nodes...');
            }
            final result = await transport.send(packetBytes);
            if (result.success) {
              final newStatus = (transport is InternetTransport) ? 'DELIVERED' : 'RELAYED';
              updateSyncStatus(result.message);
              await repository.updateStatus(incident.id, newStatus);
              onPacketDelivered?.call(incident.id, result.ackId ?? '');
              await repository.logPacketEvent(
                sourceNode: incident.sourceNode,
                packetId: incident.packetId,
                eventType: newStatus,
                nodeId: transport.name,
                details: 'Packet successfully transmitted via ${transport.name} (ACK: ${result.ackId})',
              );
              delivered = true;
              syncedCount++;
              break;
            } else {
              updateSyncStatus(result.message);
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
      await syncRemoteAcks();
    } finally {
      isSyncing = false;
    }

    return syncedCount;
  }

  Future<void> syncRemoteAcks() async {
    for (final transport in transports) {
      if (transport is InternetTransport && transport.isConfigured) {
        try {
          final uri = Uri.parse('${transport.backendUrl}/api/v1/packets/active');
          final headers = <String, String>{};
          if (transport.apiToken.isNotEmpty) {
            headers['Authorization'] = 'Bearer ${transport.apiToken}';
          }
          final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            final list = jsonDecode(res.body);
            if (list is List) {
              for (final item in list) {
                if (item is Map) {
                  final id = item['id']?.toString() ?? '';
                  final status = item['status']?.toString() ?? '';
                  if (status == 'ACKNOWLEDGED' && id.isNotEmpty) {
                    await repository.updateStatus(id, 'ACKNOWLEDGED');
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
}
