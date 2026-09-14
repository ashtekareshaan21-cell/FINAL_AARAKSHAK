/// Utilities for human-friendly distance formatting
class DistanceUtils {
  /// Format distance in km or meters nicely for UI
  static String formatDistance(double km) {
    if (km < 1.0) {
      final int meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}
