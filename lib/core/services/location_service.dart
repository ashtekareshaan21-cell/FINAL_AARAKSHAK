import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Default fallback demo coordinates
  static const double defaultLat = 18.5204;
  static const double defaultLon = 73.8567;

  /// Calculate distance between two coordinates in Kilometers using Geolocator
  static double calculateDistanceKm(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    try {
      final double distanceInMeters = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );
      return distanceInMeters / 1000.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Get current user position with fallback to default coordinates
  Future<Map<String, double>> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {'latitude': defaultLat, 'longitude': defaultLon};
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'latitude': defaultLat, 'longitude': defaultLon};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {'latitude': defaultLat, 'longitude': defaultLon};
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (_) {
      return {'latitude': defaultLat, 'longitude': defaultLon};
    }
  }
}
