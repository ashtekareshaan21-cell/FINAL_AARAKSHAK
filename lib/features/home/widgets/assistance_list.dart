import 'package:flutter/material.dart';
import '../../assistance/assistance_model.dart';
import '../../../core/utils/distance_utils.dart';

class AssistanceList extends StatelessWidget {
  final List<AssistancePoint> points;

  const AssistanceList({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No nearby assistance points identified within discovery radius.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
      );
    }

    return Column(
      children: points.take(4).map((point) {
        final icon = _getIconForType(point.type);
        final color = _getColorForType(point.type);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cap: ${point.capacity} • ${point.contact}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  DistanceUtils.formatDistance(point.calculatedDistanceKm),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForType(AssistanceType type) {
    switch (type) {
      case AssistanceType.hospital:
        return Icons.local_hospital_rounded;
      case AssistanceType.shelter:
        return Icons.house_rounded;
      case AssistanceType.reliefCenter:
        return Icons.medical_services_rounded;
      case AssistanceType.ambulance:
        return Icons.airport_shuttle_rounded;
      case AssistanceType.rescueStation:
        return Icons.shield_rounded;
    }
  }

  Color _getColorForType(AssistanceType type) {
    switch (type) {
      case AssistanceType.hospital:
        return Colors.redAccent;
      case AssistanceType.shelter:
        return const Color(0xFF10B981);
      case AssistanceType.reliefCenter:
        return Colors.cyanAccent;
      case AssistanceType.ambulance:
        return Colors.amberAccent;
      case AssistanceType.rescueStation:
        return Colors.purpleAccent;
    }
  }
}
