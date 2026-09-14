import '../../core/utils/geo_utils.dart';
import 'assistance_model.dart';

class AssistanceSorter {
  /// Dynamically sorts assistance points based on Haversine distance, availability, facility type, and hazard exposure.
  static List<AssistancePoint> sortAssistancePoints({
    required List<AssistancePoint> points,
    required double userLat,
    required double userLng,
    AssistanceType? filterType,
  }) {
    List<AssistancePoint> updatedPoints = points.map((p) {
      final double distKm = GeoUtils.haversineDistance(
        lat1: userLat,
        lon1: userLng,
        lat2: p.latitude,
        lon2: p.longitude,
      );
      return p.copyWith(calculatedDistanceKm: distKm);
    }).toList();

    if (filterType != null) {
      updatedPoints = updatedPoints.where((p) => p.type == filterType).toList();
    }

    updatedPoints.sort((a, b) {
      // 1. Available facilities come before unavailable ones
      if (a.isAvailable != b.isAvailable) {
        return a.isAvailable ? -1 : 1;
      }

      // 2. Safe facilities (not exposed to active hazards) come first
      if (a.hazardExposed != b.hazardExposed) {
        return a.hazardExposed ? 1 : -1;
      }

      // 3. Primary distance sort
      return a.calculatedDistanceKm.compareTo(b.calculatedDistanceKm);
    });

    return updatedPoints;
  }
}
