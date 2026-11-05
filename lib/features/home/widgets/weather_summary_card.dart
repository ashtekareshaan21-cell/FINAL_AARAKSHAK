import 'package:flutter/material.dart';
import '../../../core/weather/weather_service.dart';

class WeatherSummaryCard extends StatelessWidget {
  final WeatherSnapshot weather;
  final bool isOnline;

  const WeatherSummaryCard({
    super.key,
    required this.weather,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLive = isOnline && weather.stateTag == WeatherStateTag.live;
    final bool isUnavailable = weather.stateTag == WeatherStateTag.unavailable;

    final Color badgeBg = isLive
        ? const Color(0xFF065F46)
        : isUnavailable
            ? const Color(0xFF1E293B)
            : const Color(0xFF78350F);

    final Color badgeBorder = isLive
        ? const Color(0xFF10B981)
        : isUnavailable
            ? const Color(0xFF475569)
            : const Color(0xFFF59E0B);

    final Color badgeText = isLive
        ? const Color(0xFF34D399)
        : isUnavailable
            ? const Color(0xFF94A3B8)
            : const Color(0xFFFBBF24);

    final IconData badgeIcon = isLive
        ? Icons.sensors_rounded
        : isUnavailable
            ? Icons.cloud_off_rounded
            : Icons.history_rounded;

    final String badgeLabel = isLive
        ? 'LIVE TELEMETRY'
        : isUnavailable
            ? 'DATA UNAVAILABLE'
            : 'OFFLINE CACHED';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeBorder.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Bar: Unmistakable Badge + Observed At Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeText),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: badgeText,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Observed: ${_formatTime(weather.observedAt)}${!isLive && !isUnavailable ? ' (${_formatAge(weather.observedAt)})' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Condition Header
          Text(
            weather.condition,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            'Source: ${weather.provider}',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),

          const SizedBox(height: 12),

          // Metrics Grid Row — unavailable snapshots show '--', never
          // invented numbers.
          Row(
            children: [
              _buildMetric('Temp', isUnavailable ? '--' : '${weather.temperatureC.toStringAsFixed(1)}°C', Icons.thermostat_rounded, Colors.orangeAccent),
              _buildMetric('Rainfall', isUnavailable ? '--' : '${weather.precipitationMm.toStringAsFixed(1)} mm/h', Icons.water_drop_rounded, Colors.blueAccent),
              _buildMetric('Humidity', isUnavailable ? '--' : '${weather.humidity}%', Icons.water_rounded, Colors.cyanAccent),
              _buildMetric('Wind', isUnavailable ? '--' : '${weather.windKmh.toStringAsFixed(1)} km/h', Icons.air_rounded, Colors.tealAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatAge(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
