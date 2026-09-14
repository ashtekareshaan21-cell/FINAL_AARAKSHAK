import 'package:flutter/material.dart';
import '../../hazards/hazard_model.dart';
import '../../../core/utils/distance_utils.dart';
import '../../../core/utils/geo_utils.dart';

class ProximityAlert extends StatelessWidget {
  final List<Hazard> hazards;
  final double userLat;
  final double userLng;

  const ProximityAlert({
    super.key,
    required this.hazards,
    required this.userLat,
    required this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    // Filter critical zone hazards (inside 5 km)
    final criticalHazards = hazards.where((h) {
      final dist = GeoUtils.haversineDistance(
        lat1: userLat,
        lon1: userLng,
        lat2: h.latitude,
        lon2: h.longitude,
      );
      return dist <= 5.0;
    }).toList();

    if (criticalHazards.isEmpty) {
      return const SizedBox.shrink();
    }

    final topCritical = criticalHazards.first;
    final distKm = GeoUtils.haversineDistance(
      lat1: userLat,
      lon1: userLng,
      lat2: topCritical.latitude,
      lon2: topCritical.longitude,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66EF4444),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CRITICAL 5 KM ZONE ALERT',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DistanceUtils.formatDistance(distKm),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellowAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hazard "${topCritical.title}" is located within your 5 km emergency radius.',
            style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.3),
          ),
        ],
      ),
    );
  }
}
