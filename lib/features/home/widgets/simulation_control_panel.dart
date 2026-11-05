import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../simulation/simulation_controller.dart';
import '../../context_engine/risk_state.dart';
import '../../location/location_provider.dart';

class SimulationControlPanel extends ConsumerWidget {
  const SimulationControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simState = ref.watch(simulationProvider);
    final simNotifier = ref.read(simulationProvider.notifier);
    final location = ref.watch(locationStateProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CONTROLLED DEMO / SIMULATION MODE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (simState.isSimulationActive) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => simNotifier.resetSimulation(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Reset Live',
                    style: TextStyle(fontSize: 10, color: Colors.redAccent),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 1. Toggle Network Mode
          const Text(
            'Connectivity Simulation',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildChoiceChip(
                label: 'ONLINE',
                isSelected: simState.networkStatus == NetworkStatus.online,
                onSelected: () =>
                    simNotifier.setNetworkStatus(NetworkStatus.online),
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'MESH ONLY',
                isSelected:
                    simState.networkStatus == NetworkStatus.meshConnected,
                onSelected: () =>
                    simNotifier.setNetworkStatus(NetworkStatus.meshConnected),
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 8),
              _buildChoiceChip(
                label: 'OFFLINE',
                isSelected: simState.networkStatus == NetworkStatus.offline,
                onSelected: () =>
                    simNotifier.setNetworkStatus(NetworkStatus.offline),
                color: Colors.amberAccent,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Toggle Risk Level Override
          const Text(
            'Force Risk State Atmosphere',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: RiskLevel.values.map((level) {
              final isSelected = simState.overrideRiskLevel == level;
              final color = level == RiskLevel.safe
                  ? const Color(0xFF10B981)
                  : level == RiskLevel.warning
                  ? Colors.amber
                  : level == RiskLevel.danger
                  ? Colors.orangeAccent
                  : Colors.redAccent;

              return _buildChoiceChip(
                label: level.name.toUpperCase(),
                isSelected: isSelected,
                onSelected: () => simNotifier.setRiskLevelOverride(level),
                color: color,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 3. Trigger Hazard Approaching Event
          ElevatedButton.icon(
            onPressed: () => simNotifier.triggerApproachingHazard(
              location.latitude,
              location.longitude,
            ),
            icon: const Icon(Icons.thunderstorm_rounded, size: 16),
            label: const Text(
              'Simulate Approaching Hazard (< 5 km)',
              style: TextStyle(fontSize: 11),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.amberAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required Color color,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? color : Colors.white70,
          ),
        ),
      ),
    );
  }
}
