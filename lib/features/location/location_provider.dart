import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final locationStateProvider = StateNotifierProvider<LocationNotifier, LocationData>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationNotifier(service);
});

class LocationNotifier extends StateNotifier<LocationData> {
  final LocationService _service;
  StreamSubscription<LocationData>? _subscription;

  LocationNotifier(this._service) : super(LocationData.defaultFallback()) {
    init();
  }

  Future<void> init() async {
    _subscription?.cancel();
    _subscription = _service.locationStream.listen((loc) {
      state = loc;
    });

    final loc = await _service.getCurrentLocation();
    state = loc;
  }

  Future<void> refreshLocation() async {
    final loc = await _service.getCurrentLocation();
    state = loc;
  }

  void setSimulatedLocation(double lat, double lng, {String label = 'Custom Coordinates'}) {
    _service.updateSimulatedLocation(lat, lng, label: label);
    state = _service.currentLocation;
  }

  void generateRandomLocation() {
    _service.generateRandomLocation();
    state = _service.currentLocation;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
