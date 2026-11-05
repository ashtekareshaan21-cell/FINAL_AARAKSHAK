import 'dart:math';

import 'package:flutter/material.dart';

import '../../shared/constants/app_brand.dart';
import '../../core/networking/mesh_simulator_engine.dart';
import '../../core/packet/packet_engine.dart';

class MeshSimScreen extends StatefulWidget {
  const MeshSimScreen({super.key});

  @override
  State<MeshSimScreen> createState() => _MeshSimScreenState();
}

class _MeshSimScreenState extends State<MeshSimScreen> {
  final MeshSimulatorEngine _engine = MeshSimulatorEngine();
  bool _isSimulating = false;

  Future<void> _injectTestSOS({bool corrupt = false}) async {
    setState(() {
      _isSimulating = true;
    });

    final packet = EmergencyPacket(
      packetId: Random().nextInt(60000),
      sourceNode: 0x30541989 + Random().nextInt(100),
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      priority: TriagePriority.p0Critical,
      latitude: 18.52043,
      longitude: 73.85674,
      battery: 88,
      adults: 4,
      children: 1,
      payloadText: corrupt ? 'Corrupted Payload' : 'Disaster SOS Test Payload',
    );

    var bytes = PacketEngine.encodePacket(packet);
    if (corrupt) {
      bytes = PacketEngine.corruptByte(bytes, 12);
    }

    await _engine.simulatePacketTransmission(
      packetBytes: bytes,
      startNodeId: 'CITIZEN-01',
    );

    setState(() {
      _isSimulating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _engine.metrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('50-NODE DELAY-TOLERANT MESH SIMULATOR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _engine.resetTopology()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Simulation Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amber.shade900.withValues(alpha: 0.35),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SIMULATION ONLY — NOT REAL MESH HARDWARE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade200,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Top Simulator Metrics Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: AppBrand.cardDark,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricItem(
                    'DELIVERY RATIO',
                    '${metrics.deliveryRatio.toStringAsFixed(1)}%',
                    AppBrand.colorSafe,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricItem(
                    'AVG LATENCY',
                    '${metrics.avgLatencyMs} ms',
                    AppBrand.accentCyan,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricItem(
                    'P95 LATENCY',
                    '${metrics.p95LatencyMs} ms',
                    AppBrand.accentAmber,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricItem(
                    'AVG HOPS',
                    metrics.avgHops.toStringAsFixed(1),
                    Colors.white,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricItem(
                    'CRC FAILURES',
                    '${metrics.crcFailures}',
                    AppBrand.colorCritical,
                  ),
                  const SizedBox(width: 16),
                  _buildMetricItem(
                    'DUPES BLOCKED',
                    '${metrics.duplicatesSuppressed}',
                    AppBrand.colorNeeds,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppBrand.cardBorder),

          // Main View: Graph Visualizer + Hop Log Terminal (Responsive Layout)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 600;

                final graphWidget = Container(
                  color: Colors.black,
                  child: CustomPaint(
                    painter: _TopologyPainter(nodes: _engine.nodes),
                    child: Container(),
                  ),
                );

                final logWidget = Container(
                  color: AppBrand.cardDark,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SIMULATOR CONTROLS & CHAOS ENGINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isSimulating
                                ? null
                                : () => _injectTestSOS(corrupt: false),
                            icon: const Icon(Icons.send, size: 14),
                            label: const Text(
                              'INJECT SOS',
                              style: TextStyle(fontSize: 10),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppBrand.accentCyan,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isSimulating
                                ? null
                                : () => _injectTestSOS(corrupt: true),
                            icon: const Icon(Icons.bug_report, size: 14),
                            label: const Text(
                              'CORRUPT CRC',
                              style: TextStyle(fontSize: 10),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppBrand.colorCritical,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => setState(
                              () =>
                                  _engine.severRegion(!_engine.isRegionSevered),
                            ),
                            icon: const Icon(Icons.flash_off, size: 14),
                            label: Text(
                              _engine.isRegionSevered
                                  ? 'RESTORE SECTOR'
                                  : 'SEVER SECTOR',
                              style: const TextStyle(fontSize: 10),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppBrand.accentAmber,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                setState(() => _engine.runChaosTest()),
                            icon: const Icon(Icons.shuffle, size: 14),
                            label: const Text(
                              'CHAOS TEST',
                              style: TextStyle(fontSize: 10),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppBrand.cardBorder),

                      const Text(
                        'REALTIME PACKET HOP TRACE LOG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppBrand.accentCyan,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Terminal Log Stream
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _engine.hopLog.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No hops logged yet.\nTap "INJECT SOS" or "CHAOS TEST" above to simulate packet propagation.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                            itemCount: _engine.hopLog.length,
                            itemBuilder: (context, idx) {
                              final log = _engine
                                  .hopLog[_engine.hopLog.length - 1 - idx];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Text(
                                  '[${log.timestamp.toIso8601String().substring(11, 19)}] Hop ${log.hopCount} (TTL ${log.ttl}): ${log.description}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: log.isCrcValid
                                        ? (log.description.contains('DELIVERED')
                                              ? AppBrand.colorSafe
                                              : Colors.white70)
                                        : AppBrand.colorCritical,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      Expanded(flex: 3, child: graphWidget),
                      Expanded(flex: 4, child: logWidget),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: graphWidget),
                    Expanded(flex: 2, child: logWidget),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final Map<String, SimNode> nodes;
  _TopologyPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppBrand.cardBorder.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    final paintNode = Paint()..style = PaintingStyle.fill;

    // Convert Geo Lat/Lon to Canvas X/Y
    Offset toOffset(SimNode node) {
      double x = (node.longitude - 73.81) / (73.90 - 73.81) * size.width;
      double y = (18.56 - node.latitude) / (18.56 - 18.48) * size.height;
      return Offset(
        x.clamp(20.0, size.width - 20),
        y.clamp(20.0, size.height - 20),
      );
    }

    final nodeOffsets = <String, Offset>{};
    nodes.forEach((id, node) {
      nodeOffsets[id] = toOffset(node);
    });

    // Draw Edges
    nodes.forEach((id1, n1) {
      if (!n1.isOnline) return;
      nodes.forEach((id2, n2) {
        if (id1 != id2 && n2.isOnline) {
          double dist = sqrt(
            pow(n1.latitude - n2.latitude, 2) +
                pow(n1.longitude - n2.longitude, 2),
          );
          if (dist < 0.035) {
            canvas.drawLine(nodeOffsets[id1]!, nodeOffsets[id2]!, paintLine);
          }
        }
      });
    });

    // Draw Nodes
    nodes.forEach((id, node) {
      final pos = nodeOffsets[id]!;
      Color color;
      double radius = 5.0;

      if (!node.isOnline) {
        color = Colors.grey;
      } else {
        switch (node.type) {
          case SimNodeType.command:
            color = AppBrand.colorCritical;
            radius = 10.0;
            break;
          case SimNodeType.loraBridge:
            color = AppBrand.accentAmber;
            radius = 8.0;
            break;
          case SimNodeType.dataMule:
            color = Colors.purpleAccent;
            radius = 7.0;
            break;
          case SimNodeType.relay:
            color = AppBrand.accentCyan;
            radius = 5.0;
            break;
          case SimNodeType.citizen:
            color = AppBrand.colorSafe;
            radius = 4.0;
            break;
        }
      }

      paintNode.color = color;
      canvas.drawCircle(pos, radius, paintNode);
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
