import 'dart:math';

/// High-performance Geo & Spatial mathematics utilities
class GeoUtils {
  static const double earthRadiusKm = 6371.0;

  /// Calculates Haversine distance between two coordinates in kilometers.
  static double haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Checks if point (lat, lon) is within [radiusKm] of (centerLat, centerLon).
  static bool isWithinRadius({
    required double centerLat,
    required double centerLon,
    required double targetLat,
    required double targetLon,
    required double radiusKm,
  }) {
    return haversineDistance(
          lat1: centerLat,
          lon1: centerLon,
          lat2: targetLat,
          lon2: targetLon,
        ) <=
        radiusKm;
  }

  /// Checks if point is within the 5 km Critical Zone.
  static bool isWithinCriticalZone({
    required double centerLat,
    required double centerLon,
    required double targetLat,
    required double targetLon,
  }) {
    return isWithinRadius(
      centerLat: centerLat,
      centerLon: centerLon,
      targetLat: targetLat,
      targetLon: targetLon,
      radiusKm: 5.0,
    );
  }

  /// Checks if point is within the 25 km Discovery Zone.
  static bool isWithinDiscoveryZone({
    required double centerLat,
    required double centerLon,
    required double targetLat,
    required double targetLon,
  }) {
    return isWithinRadius(
      centerLat: centerLat,
      centerLon: centerLon,
      targetLat: targetLat,
      targetLon: targetLon,
      radiusKm: 25.0,
    );
  }

  /// Calculates bearing from source to destination coordinate in degrees.
  static double calculateBearing({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final double dLon = _toRadians(lon2 - lon1);
    final double y = sin(dLon) * cos(_toRadians(lat2));
    final double x = cos(_toRadians(lat1)) * sin(_toRadians(lat2)) -
        sin(_toRadians(lat1)) * cos(_toRadians(lat2)) * cos(dLon);

    final double brng = atan2(y, x);
    return (_toDegrees(brng) + 360) % 360;
  }

  static double _toRadians(double degree) => degree * pi / 180.0;
  static double _toDegrees(double rad) => rad * 180.0 / pi;
}
