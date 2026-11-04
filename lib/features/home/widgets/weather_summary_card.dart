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
    final bool isUnavailable =
        weather.stateTag == WeatherStateTag.unavailable;

    final Color badgeColor = isLive
        ? const Color(0xFF10B981)
        : isUnavailable
            ? Colors.grey
            : Colors.amber;
    final String statusLabel = isLive
        ? '● LIVE TELEMETRY'
        : isUnavailable
            ? '● DATA UNAVAILABLE'
            : '● OFFLINE CACHED (${_formatAge(weather.observedAt)})';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Icon(
                      isLive ? Icons.wb_sunny_rounded : Icons.cloud_off_rounded,
                      color: badgeColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'WEATHER TELEMETRY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Colors.white70,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
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
            'Source: ${weather.provider} • Observed at ${_formatTime(weather.observedAt)}',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
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
