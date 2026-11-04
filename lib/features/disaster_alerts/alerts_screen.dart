import 'package:flutter/material.dart';
import '../../shared/constants/app_brand.dart';
import '../../core/disaster/disaster_service.dart';
import '../../core/disaster/live_disaster_service.dart';
import '../../core/weather/weather_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // Phase 1: EONET + GDACS + USGS, not EONET alone.
  final DisasterDataService _disasterService = CombinedDisasterService();
  // Phase 0: weather is intentionally not fetched here (see _fetchEvents).

  List<DisasterEvent> _events = [];
  WeatherSnapshot? _weatherSnapshot;
  bool _isLoading = true;

  static const Color emeraldColor = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() { _isLoading = true; });
    final list = await _disasterService.getEvents();
    // Phase 0 safety: do NOT fetch weather for hardcoded Pune
    // coordinates. The weather card stays hidden until Alerts receives
    // the user's real location (Phase 1).
    if (mounted) {
      setState(() {
        _events = list;
        _weatherSnapshot = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusTag = _disasterService.statusTag;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('DISASTER INTELLIGENCE & OFFICIAL ALERTS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _fetchEvents),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Auditable Data Source Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusTag.color.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hub_rounded, color: statusTag.color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ENVIRONMENTAL DATA PROVENANCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white.withOpacity(0.5))),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text('Geofence: Active GPS Sector Target', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: statusTag.color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text(statusTag.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusTag.color)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Live / Cached Weather Snapshot Card
            if (_weatherSnapshot != null) _buildWeatherSnapshotCard(_weatherSnapshot!),

            const SizedBox(height: 16),

            const Text(
              'ACTIVE HAZARD WARNINGS & OFFICIAL FEEDS',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, idx) {
                        final ev = _events[idx];
                        final isCritical = ev.severity == 'CRITICAL';
                        final isLocal = ev.id.startsWith('LOC');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isLocal ? Colors.amber.withOpacity(0.5) : Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isCritical ? Colors.redAccent : Colors.amber).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCritical ? Icons.warning_amber_rounded : Icons.thunderstorm_rounded,
                                  color: isCritical ? Colors.redAccent : Colors.amber,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ev.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isCritical ? Colors.redAccent : Colors.amber).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ev.severity,
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isCritical ? Colors.redAccent : Colors.amber),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Category: ${ev.category} • Source: ${ev.source}',
                                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time_rounded, color: Colors.white.withOpacity(0.4), size: 12),
                                        const SizedBox(width: 4),
                                        Text('Updated ${ev.ageLabel}', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4))),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(color: emeraldColor.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                                          child: Text('● ${ev.freshnessTag}', style: const TextStyle(fontSize: 8, color: emeraldColor, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherSnapshotCard(WeatherSnapshot w) {
    final isLive = w.stateTag == WeatherStateTag.live;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isLive ? emeraldColor : Colors.amber).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.cloud_sync_rounded, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 8),
                  Text('REGIONAL METEOROLOGICAL CONTEXT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLive ? emeraldColor : Colors.amber).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isLive ? '● LIVE (${w.provider})' : '● CACHED / OFFLINE SNAPSHOT',
                  style: TextStyle(color: isLive ? emeraldColor : Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherMetric('Temp', '${w.temperatureC.toStringAsFixed(1)}°C', Icons.thermostat_rounded, Colors.orangeAccent),
              _buildWeatherMetric('Rainfall', '${w.precipitationMm.toStringAsFixed(2)} mm', Icons.water_drop_rounded, Colors.blueAccent),
              _buildWeatherMetric('Humidity', '${w.humidity}%', Icons.water_rounded, Colors.cyanAccent),
              _buildWeatherMetric('Wind', '${w.windKmh.toStringAsFixed(1)} km/h', Icons.air_rounded, Colors.tealAccent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Condition: ${w.condition} • Observed: ${_formatAge(w.observedAt)}',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
      ],
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
