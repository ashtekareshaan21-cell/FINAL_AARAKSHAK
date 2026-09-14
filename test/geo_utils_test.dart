import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils Tests', () {
    test('Haversine distance calculates accurate distance between known points', () {
      // Pune (18.5204, 73.8567) to Mumbai (19.0760, 72.8777) ~ 120-130 km
      final dist = GeoUtils.haversineDistance(
        lat1: 18.5204,
        lon1: 73.8567,
        lat2: 19.0760,
        lon2: 72.8777,
      );

      expect(dist, greaterThan(115.0));
      expect(dist, lessThan(135.0));
    });

    test('5 km Critical Zone threshold check works correctly', () {
      const centerLat = 18.5204;
      const centerLon = 73.8567;

      // ~2.5 km away point
      const nearLat = 18.5400;
      const nearLon = 73.8567;
      expect(
        GeoUtils.isWithinCriticalZone(
          centerLat: centerLat,
          centerLon: centerLon,
          targetLat: nearLat,
          targetLon: nearLon,
        ),
        isTrue,
      );

      // ~10 km away point
      const farLat = 18.6100;
      const farLon = 73.8567;
      expect(
        GeoUtils.isWithinCriticalZone(
          centerLat: centerLat,
          centerLon: centerLon,
          targetLat: farLat,
          targetLon: farLon,
        ),
        isFalse,
      );
    });

    test('25 km Discovery Zone threshold check works correctly', () {
      const centerLat = 18.5204;
      const centerLon = 73.8567;

      // ~15 km away point (within 25km)
      const midLat = 18.6500;
      const midLon = 73.8567;
      expect(
        GeoUtils.isWithinDiscoveryZone(
          centerLat: centerLat,
          centerLon: centerLon,
          targetLat: midLat,
          targetLon: midLon,
        ),
        isTrue,
      );

      // ~50 km away point (outside 25km)
      const farLat = 18.9500;
      const farLon = 73.8567;
      expect(
        GeoUtils.isWithinDiscoveryZone(
          centerLat: centerLat,
          centerLon: centerLon,
          targetLat: farLat,
          targetLon: farLon,
        ),
        isFalse,
      );
    });
  });
}
