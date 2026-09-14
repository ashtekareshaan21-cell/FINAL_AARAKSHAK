import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../location/location_provider.dart';
import '../hazards/hazard_repository.dart';
import '../hazards/hazard_model.dart';
import '../assistance/assistance_repository.dart';
import '../assistance/assistance_model.dart';
import '../mesh/mesh_service.dart';
import '../sos/sos_controller.dart';
import '../sos/sos_packet.dart';
import '../simulation/simulation_controller.dart';
import 'context_engine.dart';
import 'risk_state.dart';

import '../../core/weather/weather_service.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return MockableWeatherService();
});

final weatherStateProvider = FutureProvider<WeatherSnapshot>((ref) async {
  final location = ref.watch(locationStateProvider);
  final service = ref.watch(weatherServiceProvider);
  return await service.getWeather(latitude: location.latitude, longitude: location.longitude);
});

final hazardRepositoryProvider = Provider<HazardRepository>((ref) {
  return HazardRepository();
});

final meshServiceProvider = Provider<MeshService>((ref) {
  final service = MeshService();
  ref.onDispose(() => service.dispose());
  return service;
});

final sosControllerProvider = StateNotifierProvider<SosNotifier, SosPacket?>((ref) {
  final meshService = ref.watch(meshServiceProvider);
  return SosNotifier(SosController(meshService: meshService));
});

class SosNotifier extends StateNotifier<SosPacket?> {
  final SosController _controller;

  SosNotifier(this._controller) : super(null) {
    _controller.sosStream.listen((packet) {
      state = packet;
    });
  }

  SosController get controller => _controller;

  Future<SosPacket> triggerSos({
    required double userLat,
    required double userLng,
    int batteryLevel = 100,
    String emergencyType = 'General Emergency / Disaster Help Needed',
    String medicalNote = 'No immediate medical note provided',
  }) async {
    final packet = await _controller.triggerSos(
      userLat: userLat,
      userLng: userLng,
      batteryLevel: batteryLevel,
      emergencyType: emergencyType,
      medicalNote: medicalNote,
    );
    state = packet;
    return packet;
  }

  Future<void> receiveResponderAck(String sosId, String responderMsg) async {
    await _controller.receiveResponderAck(sosId, responderMsg);
    state = _controller.activeSos;
  }

  Future<void> cancelSos() async {
    await _controller.cancelSos();
    state = null;
  }
}

final assistanceRepositoryProvider = Provider<AssistanceRepository>((ref) {
  return AssistanceRepository();
});

final contextEngineProvider = Provider<ContextEngine>((ref) {
  final repo = ref.watch(hazardRepositoryProvider);
  final engine = ContextEngine(hazardRepository: repo);
  ref.onDispose(() => engine.dispose());
  return engine;
});

final riskStateProvider = FutureProvider<RiskState>((ref) async {
  final location = ref.watch(locationStateProvider);
  final engine = ref.watch(contextEngineProvider);
  final sosState = ref.watch(sosControllerProvider);
  final simState = ref.watch(simulationProvider);
  final weatherAsync = ref.watch(weatherStateProvider);

  final String weatherSummary = weatherAsync.maybeWhen(
    data: (w) => '${w.condition} • ${w.temperatureC.toStringAsFixed(1)}°C • Wind ${w.windKmh.toStringAsFixed(1)} km/h • Rain ${w.precipitationMm.toStringAsFixed(1)} mm',
    orElse: () => 'Active Telemetry Monitoring',
  );

  // Simulation Risk Level override check
  if (simState.isSimulationActive && simState.overrideRiskLevel != null) {
    return RiskState(
      level: simState.overrideRiskLevel!,
      score: simState.overrideRiskLevel == RiskLevel.safe
          ? 15.0
          : simState.overrideRiskLevel == RiskLevel.warning
              ? 45.0
              : simState.overrideRiskLevel == RiskLevel.danger
                  ? 72.0
                  : 100.0,
      nearestHazardKm: simState.overrideRiskLevel == RiskLevel.safe ? 18.0 : 3.2,
      primaryHazard: 'SIMULATED RISK OVERRIDE (${simState.overrideRiskLevel!.name.toUpperCase()})',
      confidence: 0.95,
      activeSos: simState.overrideRiskLevel == RiskLevel.sos,
      weatherSummary: weatherSummary,
      lastUpdated: DateTime.now(),
    );
  }

  final bool isOnline = simState.isSimulationActive
      ? simState.networkStatus == NetworkStatus.online
      : true;

  final bool activeSos = sosState != null;

  return await engine.evaluateContext(
    userLat: location.latitude,
    userLng: location.longitude,
    isOnline: isOnline,
    activeSos: activeSos,
    weatherSummary: weatherSummary,
  );
});

final sortedAssistanceProvider = FutureProvider<List<AssistancePoint>>((ref) async {
  final location = ref.watch(locationStateProvider);
  final repo = ref.watch(assistanceRepositoryProvider);

  return await repo.getSortedAssistancePoints(
    userLat: location.latitude,
    userLng: location.longitude,
  );
});

final activeHazardsProvider = FutureProvider<List<Hazard>>((ref) async {
  final location = ref.watch(locationStateProvider);
  final repo = ref.watch(hazardRepositoryProvider);
  final simState = ref.watch(simulationProvider);

  final isOnline = simState.isSimulationActive
      ? simState.networkStatus == NetworkStatus.online
      : true;

  return await repo.getActiveHazards(
    userLat: location.latitude,
    userLng: location.longitude,
    isOnline: isOnline,
  );
});
