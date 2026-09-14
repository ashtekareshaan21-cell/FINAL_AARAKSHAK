import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../context_engine/risk_state.dart';
import '../hazards/hazard_model.dart';

enum NetworkStatus {
  online,
  meshConnected,
  offline,
}

class SimulationState {
  final bool isSimulationActive;
  final NetworkStatus networkStatus;
  final RiskLevel? overrideRiskLevel;
  final List<Hazard> simulatedHazards;

  const SimulationState({
    this.isSimulationActive = false,
    this.networkStatus = NetworkStatus.online,
    this.overrideRiskLevel,
    this.simulatedHazards = const [],
  });

  SimulationState copyWith({
    bool? isSimulationActive,
    NetworkStatus? networkStatus,
    RiskLevel? overrideRiskLevel,
    List<Hazard>? simulatedHazards,
  }) {
    return SimulationState(
      isSimulationActive: isSimulationActive ?? this.isSimulationActive,
      networkStatus: networkStatus ?? this.networkStatus,
      overrideRiskLevel: overrideRiskLevel,
      simulatedHazards: simulatedHazards ?? this.simulatedHazards,
    );
  }
}

class SimulationController extends StateNotifier<SimulationState> {
  SimulationController() : super(const SimulationState());

  void setNetworkStatus(NetworkStatus status) {
    state = state.copyWith(
      isSimulationActive: true,
      networkStatus: status,
    );
  }

  void setRiskLevelOverride(RiskLevel level) {
    state = SimulationState(
      isSimulationActive: true,
      networkStatus: state.networkStatus,
      overrideRiskLevel: level,
      simulatedHazards: state.simulatedHazards,
    );
  }

  void triggerApproachingHazard(double userLat, double userLng) {
    final hazard = Hazard(
      id: 'SIM-FLOOD-${DateTime.now().millisecondsSinceEpoch}',
      title: 'CRITICAL: Approaching Flash Flood Surge',
      type: 'Flood',
      severity: 0.95,
      latitude: userLat + 0.012, // ~1.5 km away inside 5km critical zone
      longitude: userLng + 0.008,
      timestamp: DateTime.now(),
      confidence: 0.94,
      source: HazardSource.responderReport,
      description: 'Dams overflowing. Immediate evacuation advisory for sector 4.',
      responderConfirmed: true,
      supportingReports: 42,
    );

    state = state.copyWith(
      isSimulationActive: true,
      simulatedHazards: [...state.simulatedHazards, hazard],
    );
  }

  void resetSimulation() {
    state = const SimulationState();
  }
}

final simulationProvider = StateNotifierProvider<SimulationController, SimulationState>((ref) {
  return SimulationController();
});
