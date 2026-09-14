import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../shared/constants/app_brand.dart';

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

  TransmissionResult({
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
class InternetTransport implements TransportAdapter {
  final String backendUrl;
  TransportStatus _status = TransportStatus.connected;

  InternetTransport({this.backendUrl = 'http://127.0.0.1:8000'});

  @override
  String get name => 'Internet REST API';

  @override
  Future<void> start() async {
    _status = TransportStatus.connected;
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
    try {
      final hex = packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final response = await http.post(
        Uri.parse('$backendUrl/api/v1/telemetry/inject-packet'),
        headers: {'Content-Type': 'application/json'},
        body: '{"raw_hex": "$hex"}',
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return TransmissionResult(
          success: true,
          message: 'Delivered directly to backend server (HTTP ${response.statusCode})',
          hops: 0,
          ackId: 'ACK-REST-200',
        );
      } else {
        return TransmissionResult(
          success: false,
          message: 'Server error HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return TransmissionResult(
        success: false,
        message: 'Internet connection unavailable or backend offline: $e',
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
      message: 'Relayed via Simulated BLE Mesh to ${peer?.name ?? "nearby peer"}',
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
