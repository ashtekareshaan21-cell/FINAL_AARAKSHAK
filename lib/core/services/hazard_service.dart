import '../models/hazard_data.dart';
import '../constants/app_constants.dart';
import 'hazard_provider.dart';
import 'real_hazard_provider.dart';
import 'location_service.dart';

class HazardService {
  final HazardProvider _provider;

  HazardService({HazardProvider? provider})
      : _provider = provider ?? RealHazardProvider();

  /// Retrieves active hazards around [userLat] & [userLon], computes exact proximity,
  /// filters by configurable monitoring radius (20 km), and sorts by proximity ascending.
  Future<List<HazardData>> getActiveHazards({
    required double userLat,
    required double userLon,
    double monitoringRadiusKm = AppConstants.discoveryRadiusKm,
  }) async {
    // 1. Fetch location-driven hazards from provider
    final rawHazards = await _provider.getHazards(
      latitude: userLat,
      longitude: userLon,
    );

    // 2. Compute distance to user's exact GPS location & filter by monitoring radius
    final filtered = <HazardData>[];

    for (var h in rawHazards) {
      final distKm = LocationService.calculateDistanceKm(
        userLat,
        userLon,
        h.latitude,
        h.longitude,
      );

      if (distKm <= monitoringRadiusKm) {
        filtered.add(h.copyWithDistance(distKm));
      }
    }

    // 3. Sort hazards by proximity ascending
    filtered.sort((a, b) => (a.distanceKm ?? 999.0).compareTo(b.distanceKm ?? 999.0));

    return filtered;
  }
}
