import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../shared/constants/app_brand.dart';
import '../config/app_config.dart';

class Peer {
  final String id;
  final String name;
  final String transportType;
  final double signalQuality; // 0.0 to 1.0

  Peer({
    required this.id,
    required this.name,
    required this.transportType,
    required this.signalQuality,
  });
}

enum TransportStatus { disconnected, connecting, connected, degraded, error }

class TransportCapabilities {
  final bool supportsDiscovery;
  final bool supportsReceive;
  final bool supportsBackground;
  final bool supportsAcknowledgement;
  final bool supportsBroadcast;
  final int maximumPayload;
  final SubsystemCapability capabilityTag;

  TransportCapabilities({
    required this.supportsDiscovery,
    required this.supportsReceive,
    required this.supportsBackground,
    required this.supportsAcknowledgement,
    required this.supportsBroadcast,
    required this.maximumPayload,
    required this.capabilityTag,
  });
}

class TransmissionResult {
  final bool success;
  final String message;
  final int hops;
  final String? ackId;

  const TransmissionResult({
    required this.success,
    required this.message,
    this.hops = 0,
    this.ackId,
  });
}

abstract class TransportAdapter {
  Future<TransmissionResult> send(Uint8List packet, [Peer? peer]);
  Future<List<Peer>> discoverPeers();
  TransportStatus getStatus();
  TransportCapabilities getCapabilities();
  Future<void> start();
  Future<void> stop();
  String get name;
}

// 1. Internet Transport
//
// Phase 1: the backend URL comes from AppConfig (build-time
// --dart-define). There is deliberately no localhost default: on a
// phone, 127.0.0.1 is the phone itself. If no server is configured,
// this transport reports disconnected and send() fails honestly
// instead of pretending a delivery happened.
class InternetTransport implements TransportAdapter {
  final String backendUrl;
  final String apiToken;
  TransportStatus _status = TransportStatus.disconnected;

  InternetTransport({String? backendUrl, String? apiToken})
      : backendUrl = backendUrl ?? AppConfig.serverBaseUrl,
        apiToken = apiToken ?? AppConfig.apiToken;

  bool get isConfigured =>
      backendUrl.isNotEmpty &&
      (backendUrl.startsWith('https://') || backendUrl.startsWith('http://'));

  @override
  String get name => 'Internet REST API';

  @override
  Future<void> start() async {
    // Never claim "connected" on start — that is only true after a
    // successful send() to the configured server.
    _status = TransportStatus.disconnected;
  }

  @override
  Future<void> stop() async {
    _status = TransportStatus.disconnected;
  }

  @override
  TransportStatus getStatus() => _status;

  @override
  TransportCapabilities getCapabilities() => TransportCapabilities(
        supportsDiscovery: false,
        supportsReceive: true,
        supportsBackground: true,
        supportsAcknowledgement: true,
        supportsBroadcast: false,
        maximumPayload: 4096,
        capabilityTag: SubsystemCapability.real,
      );

  @override
  Future<List<Peer>> discoverPeers() async => [];

  @override
  Future<TransmissionResult> send(Uint8List packet, [Peer? peer]) async {
    if (!isConfigured) {
      _status = TransportStatus.disconnected;
      return const TransmissionResult(
        success: false,
        message: 'Server not configured — run with --dart-define',
      );
    }
    try {
      final hex = packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (apiToken.isNotEmpty) headers['Authorization'] = 'Bearer $apiToken';
      final response = await http.post(
        Uri.parse('$backendUrl/api/v1/telemetry/inject-packet'),
        headers: headers,
        body: '{"raw_hex": "$hex"}',
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 409) {
        _status = TransportStatus.connected;
        String? ackToken;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['ack_token'] != null) {
            ackToken = decoded['ack_token'].toString();
          }
        } catch (_) {}
        return TransmissionResult(
          success: true,
          message: response.statusCode == 409
              ? 'Packet already ingested by backend server (HTTP 409)'
              : 'Delivered directly to backend server (HTTP ${response.statusCode})',
          hops: 0,
          ackId: ackToken ?? 'ACK-REST-${response.statusCode}',
        );
      } else if (response.statusCode == 401) {
        _status = TransportStatus.error;
        return const TransmissionResult(
          success: false,
          message: 'Server rejected the packet (check token)',
        );
      } else {
        _status = TransportStatus.error;
        return TransmissionResult(
          success: false,
          message: 'Server error HTTP ${response.statusCode} — will retry automatically',
        );
      }
    } on TimeoutException {
      _status = TransportStatus.error;
      return const TransmissionResult(
        success: false,
        message: 'Waiting for server — first request can take up to 60s',
      );
    } catch (e) {
      _status = TransportStatus.error;
      return const TransmissionResult(
        success: false,
        message: 'No internet — will retry when back online',
      );
    }
  }
}

// 2. Simulated BLE Transport
class SimulatedBleTransport implements TransportAdapter {
  bool _active = true;

  @override
  String get name => 'Simulated BLE Mesh';

  @override
  Future<void> start() async { _active = true; }

  @override
  Future<void> stop() async { _active = false; }

  @override
  TransportStatus getStatus() => _active ? TransportStatus.connected : TransportStatus.disconnected;

  @override
  TransportCapabilities getCapabilities() => TransportCapabilities(
        supportsDiscovery: true,
        supportsReceive: true,
        supportsBackground: false,
        supportsAcknowledgement: true,
        supportsBroadcast: true,
        maximumPayload: 512,
        capabilityTag: SubsystemCapability.simulated,
      );

  @override
  Future<List<Peer>> discoverPeers() async {
    return [
      Peer(id: 'BLE-NODE-01', name: 'Rescue Phone Alpha', transportType: 'BLE', signalQuality: 0.85),
      Peer(id: 'BLE-NODE-02', name: 'Volunteer Device', transportType: 'BLE', signalQuality: 0.62),
    ];
  }

  @override
  Future<TransmissionResult> send(Uint8List packet, [Peer? peer]) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return TransmissionResult(
      success: true,
      message: 'Relayed via Offline BLE Mesh to ${peer?.name ?? "nearby peer (1 hop)"} • Stored in DTN Outbox',
      hops: 1,
      ackId: 'ACK-BLE-${Random().nextInt(9999)}',
    );
  }
}

// 3. Simulated LoRa Radio Transport
class SimulatedLoRaTransport implements TransportAdapter {
  bool _active = true;
  double lossRate = 0.05; // 5% simulated packet loss

  @override
  String get name => 'Simulated LoRa Radio (868 MHz)';

  @override
  Future<void> start() async { _active = true; }

  @override
  Future<void> stop() async { _active = false; }

  @override
  TransportStatus getStatus() => _active ? TransportStatus.connected : TransportStatus.disconnected;

  @override
  TransportCapabilities getCapabilities() => TransportCapabilities(
        supportsDiscovery: false,
        supportsReceive: true,
        supportsBackground: true,
        supportsAcknowledgement: false,
        supportsBroadcast: true,
        maximumPayload: 256,
        capabilityTag: SubsystemCapability.simulated,
      );

  @override
  Future<List<Peer>> discoverPeers() async => [
        Peer(id: 'LORA-GW-01', name: 'LoRa Gateway Station', transportType: 'LoRa', signalQuality: 0.95),
      ];

  @override
  Future<TransmissionResult> send(Uint8List packet, [Peer? peer]) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (Random().nextDouble() < lossRate) {
      return TransmissionResult(
        success: false,
        message: 'Simulated LoRa channel collision / packet loss',
      );
    }
    return TransmissionResult(
      success: true,
      message: 'Transmitted over Simulated LoRa narrow-band channel (SF7 / 125kHz)',
      hops: 2,
      ackId: 'ACK-LORA-${Random().nextInt(9999)}',
    );
  }
}
