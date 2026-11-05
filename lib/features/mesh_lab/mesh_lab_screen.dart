import 'package:flutter/material.dart';
import '../mesh_simulator/mesh_sim_screen.dart';
import '../packet_inspector/packet_inspector_screen.dart';
import '../home/widgets/simulation_control_panel.dart';

class MeshLabScreen extends StatefulWidget {
  const MeshLabScreen({super.key});

  @override
  State<MeshLabScreen> createState() => _MeshLabScreenState();
}

class _MeshLabScreenState extends State<MeshLabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.bolt_rounded, color: Colors.purpleAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'TECHNICAL MESH LAB',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white54,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          labelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.hub_rounded, size: 18), text: '50-NODE MESH'),
            Tab(icon: Icon(Icons.memory_rounded, size: 18), text: 'HEX INSPECTOR'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'CHAOS LAB'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Mesh Topology & Simulator
          const MeshSimScreen(showAppBar: false),

          // 2. 48-Byte Hex Frame Inspector
          const PacketInspectorScreen(showAppBar: false),

          // 3. Chaos Controls Panel
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'SIMULATION ONLY — NOT REAL MESH • CHAOS TEST CONTROLS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 12),
                SimulationControlPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
