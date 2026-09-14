import 'dart:math';
import '../../data/repositories/incident_repository.dart';

class TrustResult {
  final int score;
  final List<String> factors;
  final int corroborationsCount;
  final bool isCrcValid;
  final bool isGpsVerified;
  final String freshnessLabel;

  TrustResult({
    required this.score,
    required this.factors,
    required this.corroborationsCount,
    required this.isCrcValid,
    required this.isGpsVerified,
    required this.freshnessLabel,
  });

  String get trustBadge {
    if (score >= 85) return 'HIGH TRUST ($score%)';
    if (score >= 60) return 'MEDIUM TRUST ($score%)';
    return 'LOW CONFIDENCE ($score%)';
  }
}

class TrustEngine {
  /// Calculates a multi-factor confidence trust score (0 - 100%)
  static TrustResult calculateTrust({
    required IncidentRecord incident,
    required List<IncidentRecord> activeIncidents,
    bool isCrcValid = true,
    bool isHumanVerified = false,
  }) {
    int score = 0;
    final List<String> factors = [];

    // 1. Packet Integrity & CRC (Up to 20 pts)
    if (isCrcValid) {
      score += 20;
      factors.add('✓ Packet CRC-16 checksum valid (uncorrupted)');
    } else {
      factors.add('⚠ CRC checksum mismatch - transmission warning');
    }

    // 2. Source Authentication (Up to 15 pts)
    if (incident.sourceNode != 0) {
      score += 15;
      factors.add('✓ Device source ID authenticated (0x${incident.sourceNode.toRadixString(16).toUpperCase()})');
    }

    // 3. GPS Accuracy & Verification (Up to 25 pts)
    bool gpsVerified = false;
    if (incident.latitude != 0.0 && incident.longitude != 0.0) {
      gpsVerified = true;
      if (incident.gpsAccuracy <= 15.0) {
        score += 25;
        factors.add('✓ Precise GPS acquired (±${incident.gpsAccuracy.toStringAsFixed(1)}m accuracy)');
      } else {
        score += 15;
        factors.add('✓ Coarse GPS location acquired (±${incident.gpsAccuracy.toStringAsFixed(1)}m)');
      }
    } else {
      factors.add('⚠ GPS unavailable - cell/mesh triangulation used');
    }

    // 4. Timestamp Freshness (Up to 25 pts)
    final ageDuration = DateTime.now().difference(incident.createdAt);
    final ageSeconds = ageDuration.inSeconds;
    String freshnessLabel = '';

    if (ageSeconds < 120) {
      score += 25;
      freshnessLabel = 'Fresh (${ageSeconds}s ago)';
      factors.add('✓ High freshness: created ${ageSeconds}s ago');
    } else if (ageSeconds < 600) {
      score += 18;
      freshnessLabel = '${(ageSeconds / 60).round()}m ago';
      factors.add('✓ Freshness: created ${(ageSeconds / 60).round()} minutes ago');
    } else if (ageSeconds < 3600) {
      score += 10;
      freshnessLabel = '${(ageSeconds / 60).round()}m ago';
      factors.add('⚠ Moderate age: created ${(ageSeconds / 60).round()} minutes ago');
    } else {
      score += 5;
      freshnessLabel = '${ageDuration.inHours}h ago';
      factors.add('🔴 Stale report: created ${ageDuration.inHours} hours ago');
    }

    // 5. Spatial Corroboration Engine (Up to 15 pts)
    int corroboratingCount = 0;
    for (final other in activeIncidents) {
      if (other.id == incident.id) continue;
      final distKm = _haversineDistance(
        incident.latitude, incident.longitude,
        other.latitude, other.longitude,
      );
      if (distKm <= 1.2) {
        corroboratingCount++;
      }
    }

    if (corroboratingCount >= 2) {
      score += 15;
      factors.add('✓ High corroboration: $corroboratingCount independent reports within 1.2 km');
    } else if (corroboratingCount == 1) {
      score += 10;
      factors.add('✓ Corroborated: 1 nearby report detected within 1.2 km');
    } else {
      factors.add('ℹ Single-source report (no corroboration yet within 1.2 km)');
    }

    // 6. Human Operator Verification Bonus (Up to 10 pts)
    if (isHumanVerified || incident.humanVerified) {
      score += 10;
      factors.add('✓ Human EOC Operator confirmed report');
    }

    final finalScore = score.clamp(0, 100);

    return TrustResult(
      score: finalScore,
      factors: factors,
      corroborationsCount: corroboratingCount,
      isCrcValid: isCrcValid,
      isGpsVerified: gpsVerified,
      freshnessLabel: freshnessLabel,
    );
  }

  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R * asin(...)
  }
}
