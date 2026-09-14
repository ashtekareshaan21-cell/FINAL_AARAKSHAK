import 'package:flutter/material.dart';
import '../../hazards/hazard_model.dart';
import '../../../core/utils/distance_utils.dart';
import '../../../core/utils/geo_utils.dart';

class HazardBanner extends StatelessWidget {
  final Hazard hazard;
  final double userLat;
  final double userLng;

  const HazardBanner({
    super.key,
    required this.hazard,
    required this.userLat,
    required this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    final double distKm = GeoUtils.haversineDistance(
      lat1: userLat,
      lon1: userLng,
      lat2: hazard.latitude,
      lon2: hazard.longitude,
    );

    final bool isCriticalZone = distKm <= 5.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCriticalZone
            ? const Color(0xFF450A0A)
            : const Color(0xFF262015),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCriticalZone ? Colors.redAccent : Colors.amber,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCriticalZone
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: isCriticalZone ? Colors.redAccent : Colors.amber,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        hazard.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCriticalZone ? Colors.redAccent : Colors.amber,
                        ),
                        softWrap: true,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isCriticalZone ? Colors.red : Colors.amber).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        DistanceUtils.formatDistance(distKm),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCriticalZone ? Colors.redAccent : Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hazard.description.isNotEmpty
                      ? hazard.description
                      : 'Active hazard reported near coordinates.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.3,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Confidence: ${(hazard.confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Source: ${hazard.source.name}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}
