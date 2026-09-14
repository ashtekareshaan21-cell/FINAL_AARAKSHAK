import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import '../packet/packet_engine.dart';

enum SimNodeType { citizen, relay, loraBridge, dataMule, command }

class SimNode {
  final String id;
  final String label;
  final SimNodeType type;
  double latitude;
  double longitude;
  int battery;
  bool isOnline;
  int queueDepth;
  int signalQuality; // 0-100%
  DateTime lastSeen;

  SimNode({
    required this.id,
    required this.label,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.battery = 95,
    this.isOnline = true,
    this.queueDepth = 0,
    this.signalQuality = 90,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  SimNode copyWith({
    bool? isOnline,
    int? battery,
    int? queueDepth,
    int? signalQuality,
    double? latitude,
    double? longitude,
  }) {
    return SimNode(
      id: id,
      label: label,
      type: type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      battery: battery ?? this.battery,
      isOnline: isOnline ?? this.isOnline,
      queueDepth: queueDepth ?? this.queueDepth,
      signalQuality: signalQuality ?? this.signalQuality,
      lastSeen: DateTime.now(),
    );
  }
}

class SimHopEvent {
  final String packetId;
  final String fromNodeId;
  final String toNodeId;
  final int hopCount;
  final int ttl;
  final String description;
  final DateTime timestamp;
  final bool isCrcValid;

  SimHopEvent({
    required this.packetId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.hopCount,
    required this.ttl,
    required this.description,
    DateTime? timestamp,
    this.isCrcValid = true,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SimMetrics {
  int totalInjected = 0;
  int totalDelivered = 0;
  int totalFailed = 0;
  int duplicatesSuppressed = 0;
  int crcFailures = 0;
  int ttlExpirations = 0;
  int totalHopsTraversed = 0;
  List<int> latenciesMs = [];

  double get deliveryRatio => totalInjected == 0 ? 100.0 : (totalDelivered / totalInjected) * 100;
  double get avgHops => totalDelivered == 0 ? 0.0 : totalHopsTraversed / totalDelivered;
  int get avgLatencyMs => latenciesMs.isEmpty ? 0 : (latenciesMs.reduce((a, b) => a + b) / latenciesMs.length).round();
  int get p95LatencyMs {
    if (latenciesMs.isEmpty) return 0;
    final sorted = List<int>.from(latenciesMs)..sort();
    int idx = (sorted.length * 0.95).floor().clamp(0, sorted.length - 1);
    return sorted[idx];
  }
}

class MeshSimulatorEngine {
  final Map<String, SimNode> nodes = {};
  final List<SimHopEvent> hopLog = [];
  final SimMetrics metrics = SimMetrics();
  final Set<String> seenPacketKeys = {};

  bool isInternetEnabled = true;
  bool isVirtualLoraEnabled = true;
  bool isRegionSevered = false;
  int randomSeed = 20260908;
  Random _random = Random(20260908);

  MeshSimulatorEngine() {
    resetTopology();
  }

  void setRandomSeed(int seed) {
    randomSeed = seed;
    _random = Random(seed);
    resetTopology();
  }

  void resetTopology() {
    nodes.clear();
    hopLog.clear();
    seenPacketKeys.clear();
    metrics.totalInjected = 0;
    metrics.totalDelivered = 0;
    metrics.totalFailed = 0;
    metrics.duplicatesSuppressed = 0;
    metrics.crcFailures = 0;
    metrics.ttlExpirations = 0;
    metrics.totalHopsTraversed = 0;
    metrics.latenciesMs.clear();
    isRegionSevered = false;
    isInternetEnabled = true;
    isVirtualLoraEnabled = true;

    // 1 Command Center (Center Base)
    nodes['CMD-01'] = SimNode(
      id: 'CMD-01',
      label: 'EOC Main Base',
      type: SimNodeType.command,
      latitude: 18.5204,
      longitude: 73.8567,
    );

    // 4 LoRa Bridges
    final bridgeCoords = [
      [18.525, 73.850],
      [18.515, 73.860],
      [18.530, 73.865],
      [18.510, 73.845],
    ];
    for (int i = 0; i < 4; i++) {
      final id = 'LORA-0${i + 1}';
      nodes[id] = SimNode(
        id: id,
        label: 'LoRa Gateway 0${i + 1}',
        type: SimNodeType.loraBridge,
        latitude: bridgeCoords[i][0],
        longitude: bridgeCoords[i][1],
      );
    }

    // 2 Data Mules
    nodes['MULE-01'] = SimNode(
      id: 'MULE-01',
      label: 'Rescue Mule Patrol 1',
      type: SimNodeType.dataMule,
      latitude: 18.535,
      longitude: 73.840,
    );
    nodes['MULE-02'] = SimNode(
      id: 'MULE-02',
      label: 'Rescue Mule Drone',
      type: SimNodeType.dataMule,
      latitude: 18.505,
      longitude: 73.870,
    );

    // 20 Relay Nodes
    for (int i = 1; i <= 20; i++) {
      final id = 'RELAY-${i.toString().padLeft(2, '0')}';
      final latOffset = (_random.nextDouble() - 0.5) * 0.06;
      final lonOffset = (_random.nextDouble() - 0.5) * 0.06;
      nodes[id] = SimNode(
        id: id,
        label: 'Relay $i',
        type: SimNodeType.relay,
        latitude: 18.5204 + latOffset,
        longitude: 73.8567 + lonOffset,
        battery: 70 + _random.nextInt(30),
      );
    }

    // 23 Citizen Nodes (Total = 1 + 4 + 2 + 20 + 23 = 50 Nodes)
    for (int i = 1; i <= 23; i++) {
      final id = 'CITIZEN-${i.toString().padLeft(2, '0')}';
      final latOffset = (_random.nextDouble() - 0.5) * 0.08;
      final lonOffset = (_random.nextDouble() - 0.5) * 0.08;
      nodes[id] = SimNode(
        id: id,
        label: 'Citizen SOS Device $i',
        type: SimNodeType.citizen,
        latitude: 18.5204 + latOffset,
        longitude: 73.8567 + lonOffset,
        battery: 50 + _random.nextInt(50),
      );
    }
  }

  void toggleNodeStatus(String nodeId) {
    if (nodes.containsKey(nodeId)) {
      final node = nodes[nodeId]!;
      nodes[nodeId] = node.copyWith(isOnline: !node.isOnline);
    }
  }

  void severRegion(bool sever) {
    isRegionSevered = sever;
    // Turn off 40% of relays in north-west sector when severed
    nodes.forEach((id, node) {
      if (node.type == SimNodeType.relay && node.latitude > 18.5204 && node.longitude < 73.8567) {
        nodes[id] = node.copyWith(isOnline: !sever);
      }
    });
  }

  Future<SimMetrics> simulatePacketTransmission({
    required Uint8List packetBytes,
    required String startNodeId,
  }) async {
    metrics.totalInjected += 1;
    final startTime = DateTime.now();

    // Check CRC
    if (!PacketEngine.validatePacket(packetBytes)) {
      metrics.crcFailures += 1;
      hopLog.add(SimHopEvent(
        packetId: 'CORRUPTED',
        fromNodeId: startNodeId,
        toNodeId: 'NONE',
        hopCount: 0,
        ttl: 0,
        description: 'Packet CRC validation failed at local ingress. Transmission rejected.',
        isCrcValid: false,
      ));
      metrics.totalFailed += 1;
      return metrics;
    }

    final packet = PacketEngine.decodePacket(packetBytes);
    final packetKey = packet.logicalIdentity;

    // Deduplication check
    if (seenPacketKeys.contains(packetKey)) {
      metrics.duplicatesSuppressed += 1;
      hopLog.add(SimHopEvent(
        packetId: packetKey,
        fromNodeId: startNodeId,
        toNodeId: 'NONE',
        hopCount: packet.hops,
        ttl: packet.ttl,
        description: 'Duplicate packet key $packetKey suppressed at ingress.',
      ));
      return metrics;
    }
    seenPacketKeys.add(packetKey);

    // Run BFS path discovery from startNodeId to CMD-01
    final path = _findShortestPath(startNodeId, 'CMD-01');

    if (path.isEmpty) {
      // Check if Data Mule can pick up packet
      final mule = nodes['MULE-01'];
      if (mule != null && mule.isOnline) {
        hopLog.add(SimHopEvent(
          packetId: packetKey,
          fromNodeId: startNodeId,
          toNodeId: 'MULE-01',
          hopCount: packet.hops + 1,
          ttl: packet.ttl - 1,
          description: 'No active direct mesh path. Packet transferred to Rescue Data Mule for DTN storage.',
        ));
        await Future.delayed(const Duration(milliseconds: 600));
        hopLog.add(SimHopEvent(
          packetId: packetKey,
          fromNodeId: 'MULE-01',
          toNodeId: 'CMD-01',
          hopCount: packet.hops + 2,
          ttl: packet.ttl - 2,
          description: 'Data Mule arrived at Command Base. Custody delivery completed.',
        ));
        metrics.totalDelivered += 1;
        metrics.totalHopsTraversed += packet.hops + 2;
        metrics.latenciesMs.add(DateTime.now().difference(startTime).inMilliseconds + 600);
        return metrics;
      }

      metrics.totalFailed += 1;
      hopLog.add(SimHopEvent(
        packetId: packetKey,
        fromNodeId: startNodeId,
        toNodeId: 'NONE',
        hopCount: packet.hops,
        ttl: packet.ttl,
        description: 'NETWORK PARTITION: No viable path or mule available. Packet queued locally.',
      ));
      return metrics;
    }

    // Traverse Path Step by Step
    int currentHops = packet.hops;
    int currentTtl = packet.ttl;

    for (int i = 0; i < path.length - 1; i++) {
      final fromNode = path[i];
      final toNode = path[i + 1];

      if (currentTtl <= 0) {
        metrics.ttlExpirations += 1;
        metrics.totalFailed += 1;
        hopLog.add(SimHopEvent(
          packetId: packetKey,
          fromNodeId: fromNode,
          toNodeId: toNode,
          hopCount: currentHops,
          ttl: 0,
          description: 'TTL expired (TTL=0) during hop relay to $toNode.',
        ));
        return metrics;
      }

      currentHops += 1;
      currentTtl -= 1;

      // Update Node queue depth
      if (nodes.containsKey(fromNode)) {
        nodes[fromNode] = nodes[fromNode]!.copyWith(queueDepth: nodes[fromNode]!.queueDepth + 1);
      }

      hopLog.add(SimHopEvent(
        packetId: packetKey,
        fromNodeId: fromNode,
        toNodeId: toNode,
        hopCount: currentHops,
        ttl: currentTtl,
        description: 'Packet relayed from $fromNode to $toNode (Hop $currentHops, TTL $currentTtl).',
      ));
    }

    metrics.totalDelivered += 1;
    metrics.totalHopsTraversed += currentHops;
    metrics.latenciesMs.add(DateTime.now().difference(startTime).inMilliseconds);

    return metrics;
  }

  List<String> _findShortestPath(String startId, String targetId) {
    if (!nodes.containsKey(startId) || !nodes.containsKey(targetId)) return [];
    if (!nodes[startId]!.isOnline || !nodes[targetId]!.isOnline) return [];

    final queue = <List<String>>[
      [startId]
    ];
    final visited = <String>{startId};

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;

      if (current == targetId) return path;

      for (final neighbor in _getNeighbors(current)) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          final newPath = List<String>.from(path)..add(neighbor);
          queue.add(newPath);
        }
      }
    }
    return [];
  }

  List<String> _getNeighbors(String nodeId) {
    if (!nodes.containsKey(nodeId)) return [];
    final current = nodes[nodeId]!;
    if (!current.isOnline) return [];

    final neighbors = <String>[];
    nodes.forEach((id, other) {
      if (id != nodeId && other.isOnline) {
        // Distance calculation
        double dist = sqrt(pow(current.latitude - other.latitude, 2) + pow(current.longitude - other.longitude, 2));
        if (dist < 0.035) { // Range threshold
          neighbors.add(id);
        }
      }
    });
    return neighbors;
  }

  void runChaosTest() {
    for (int i = 0; i < 5; i++) {
      final keys = nodes.keys.toList();
      final randomNode = keys[_random.nextInt(keys.length)];
      if (nodes[randomNode]!.type != SimNodeType.command) {
        toggleNodeStatus(randomNode);
      }
    }
  }
}
