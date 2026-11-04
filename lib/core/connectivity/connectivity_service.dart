import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

// Phase 1 — real connectivity, replacing the old Home rule
// "online = simulation is off". connectivity_plus reports the network
// interface, not the simulation state. A wifi/mobile result is not proof
// that the internet works (captive portals exist), so callers must
// still treat a failed API call as offline — but an explicit "none"
// result is a real offline signal, and that is what the badge uses.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none),
      );
}
