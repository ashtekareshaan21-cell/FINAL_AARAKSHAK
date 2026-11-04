import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../location/location_provider.dart';
import '../hazards/hazard_repository.dart';
import '../hazards/hazard_model.dart';
import '../assistance/assistance_repository.dart';
import '../assistance/assistance_model.dart';
import '../mesh/mesh_service.dart';
import '../sos/sos_controller.dart';
import '../sos/sos_packet.dart';
import 'context_engine.dart';
import 'risk_state.dart';

import '../../core/weather/weather_service.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/sync/sync_service.dart';
import '../../core/sync/eoc_websocket_client.dart';
import '../../core/transport/transport_adapter.dart';
import '../../data/repositories/incident_repository.dart';

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return MockableWeatherService();
});

// Phase 1: real connectivity (connectivity_plus), not "simulation off".
// The Home badge uses this; simulation only suppresses the live badge
// wording, it never creates an online state by itself.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

final weatherStateProvider = FutureProvider<WeatherSnapshot>((ref) async {
  final location = ref.watch(locationStateProvider);
  final service = ref.watch(weatherServiceProvider);
  return await service.getWeather(latitude: location.latitude, longitude: location.longitude);
});

final hazardRepositoryProvider = Provider<HazardRepository>((ref) {
  return HazardRepository();
});

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return IncidentRepository();
});

final internetTransportProvider = Provider<InternetTransport>((ref) {
  return InternetTransport();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.watch(incidentRepositoryProvider);
  final transport = ref.watch(internetTransportProvider);
  return SyncService(
    repository: repository,
    transports: [transport],
  );
});

final eocWsClientProvider = Provider<EocWebSocketClient>((ref) {
  final client = EocWebSocketClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final meshServiceProvider = Provider<MeshService>((ref) {
  final service = MeshService();
  ref.onDispose(() => service.dispose());
  return service;
});

final sosControllerProvider = StateNotifierProvider<SosNotifier, SosPacket?>((ref) {
  final meshService = ref.watch(meshServiceProvider);
  final incidentRepository = ref.watch(incidentRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  final wsClient = ref.watch(eocWsClientProvider);

  final controller = SosController(
    meshService: meshService,
    incidentRepository: incidentRepository,
    syncService: syncService,
    wsClient: wsClient,
  );
  ref.onDispose(() => controller.dispose());
  return SosNotifier(controller);
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
  final weatherAsync = ref.watch(weatherStateProvider);

  final String weatherSummary = weatherAsync.maybeWhen(
    data: (w) => w.stateTag == WeatherStateTag.unavailable
        ? 'Weather unavailable'
        : '${w.condition} • ${w.temperatureC.toStringAsFixed(1)}°C • Wind ${w.windKmh.toStringAsFixed(1)} km/h • Rain ${w.precipitationMm.toStringAsFixed(1)} mm',
    orElse: () => 'Weather unavailable',
  );

  // Phase 0 safety: simulation risk overrides are removed from the
  // production Home flow. Simulation lives only in Mesh Lab.
  // Also, an unconfirmed (mocked/fallback) location must not produce
  // a risk score for a place the user is not actually in — unless an
  // SOS is active, in which case the SOS state itself is the risk.
  final bool activeSos = sosState != null;
  // Manual-confirmed locations are usable for risk: only the
  // unconfirmed placeholder fallback is excluded.
  if (!location.isConfirmedForUse && !activeSos) {
    return RiskState(
      level: RiskLevel.safe,
      score: 0.0,
      nearestHazardKm: 999.0,
      primaryHazard: 'Location not confirmed — risk cannot be calculated',
      confidence: 0.0,
      activeSos: false,
      weatherSummary: weatherSummary,
      lastUpdated: DateTime.now(),
    );
  }

  return await engine.evaluateContext(
    userLat: location.latitude,
    userLng: location.longitude,
    isOnline: true,
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

  // Phase 0 safety: simulation must not suppress the live hazard API
  // in production. Simulated hazards stay in Mesh Lab only.
  return await repo.getActiveHazards(
    userLat: location.latitude,
    userLng: location.longitude,
    isOnline: true,
  );
});
