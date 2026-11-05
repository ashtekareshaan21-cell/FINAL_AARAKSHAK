import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/constants/app_brand.dart';
import '../../core/disaster/disaster_service.dart';
import '../../core/disaster/live_disaster_service.dart';
import '../../core/weather/weather_service.dart';
import '../../core/services/location_service.dart' as distance_utils;
import '../location/location_provider.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  // Phase 1: EONET + GDACS + USGS live combined disaster feeds
  final CombinedDisasterService _disasterService = CombinedDisasterService();

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
    if (mounted) {
      setState(() {
        _events = list;
        _weatherSnapshot = null;
        _isLoading = false;
      });
    }
  }

  bool _hasCoordinates(DisasterEvent ev) {
    if (ev.latitude == 0.0 && ev.longitude == 0.0) return false;
    if (ev.latitude < -90.0 || ev.latitude > 90.0) return false;
    if (ev.longitude < -180.0 || ev.longitude > 180.0) return false;
    return true;
  }

  double? _computeDistance(DisasterEvent ev, LocationData location) {
    if (!location.isConfirmedForUse) return null;
    if (!_hasCoordinates(ev)) return null;
    return distance_utils.LocationService.calculateDistanceKm(
      location.latitude,
      location.longitude,
      ev.latitude,
      ev.longitude,
    );
  }

  String _formatDistance(double? distKm, bool isLocationConfirmed) {
    if (!isLocationConfirmed || distKm == null) return '--';
    if (distKm < 1.0) return 'Nearby';
    if (distKm < 10.0) return '${distKm.toStringAsFixed(1)} km away';
    return '${distKm.round()} km away';
  }

  List<DisasterEvent> _getSortedEvents(LocationData location) {
    final list = List<DisasterEvent>.from(_events);
    if (!location.isConfirmedForUse) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    }

    list.sort((a, b) {
      final aHasCoord = _hasCoordinates(a);
      final bHasCoord = _hasCoordinates(b);

      if (aHasCoord && !bHasCoord) return -1;
      if (!aHasCoord && bHasCoord) return 1;
      if (!aHasCoord && !bHasCoord) return b.timestamp.compareTo(a.timestamp);

      final distA = distance_utils.LocationService.calculateDistanceKm(
        location.latitude,
        location.longitude,
        a.latitude,
        a.longitude,
      );
      final distB = distance_utils.LocationService.calculateDistanceKm(
        location.latitude,
        location.longitude,
        b.latitude,
        b.longitude,
      );

      final cmp = distA.compareTo(distB);
      if (cmp != 0) return cmp;
      return b.timestamp.compareTo(a.timestamp);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationStateProvider);
    final bool isLocationConfirmed = location.isConfirmedForUse;
    final statusTag = _disasterService.statusTag;
    final sortedEvents = _getSortedEvents(location);
    final unavailableFeeds = _disasterService.unavailableFeeds;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.feed_rounded, color: Colors.amberAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'LIVE DISASTER ALERTS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
            ),
          ],
        ),
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
                border: Border.all(color: statusTag.color.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hub_rounded, color: statusTag.color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OFFICIAL FEEDS PROVENANCE (EONET • GDACS • USGS)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isLocationConfirmed ? 'Sector: ${location.label}' : 'Sector: Location Not Confirmed',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: statusTag.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
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

            const SizedBox(height: 12),

            // Honest Feed Warning Banner (if any feed is unreachable)
            if (unavailableFeeds.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live feed unavailable: ${unavailableFeeds.join(', ')} (showing remaining feeds)',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Unconfirmed Location Hint Line
            if (!isLocationConfirmed) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.location_off_rounded, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confirm your location to see distances',
                        style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Live / Cached Weather Snapshot Card (if available)
            if (_weatherSnapshot != null) _buildWeatherSnapshotCard(_weatherSnapshot!),

            const SizedBox(height: 6),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ACTIVE HAZARD WARNINGS & OFFICIAL FEEDS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                  ),
                ),
                if (isLocationConfirmed && sortedEvents.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Nearest First',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: AppBrand.accentCyan),
                          SizedBox(height: 12),
                          Text(
                            'Loading live disaster feeds (EONET, GDACS, USGS)...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : sortedEvents.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shield_outlined, size: 48, color: Colors.white38),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Active Official Disaster Warnings',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Verified global feeds report no active hazard advisories for this sector. For life emergencies, call 108 / 112.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.white60),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: _fetchEvents,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Refresh Feeds'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppBrand.accentCyan,
                                    side: const BorderSide(color: AppBrand.accentCyan),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: sortedEvents.length,
                          itemBuilder: (context, idx) {
                            final ev = sortedEvents[idx];
                            final isCritical = ev.severity == 'CRITICAL';
                            final distKm = _computeDistance(ev, location);
                            final distanceText = _formatDistance(distKm, isLocationConfirmed);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCritical
                                      ? Colors.redAccent.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isCritical ? Colors.redAccent : Colors.amber).withValues(alpha: 0.15),
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ev.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (isCritical ? Colors.redAccent : Colors.amber).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                ev.severity,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCritical ? Colors.redAccent : Colors.amber,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            // Real source badge (EONET / GDACS / USGS)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                ev.source,
                                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Distance badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.near_me_rounded, size: 10, color: Colors.amberAccent),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    distanceText,
                                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '• ${ev.category}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, color: Colors.white.withValues(alpha: 0.4), size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Updated ${ev.ageLabel}',
                                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: emeraldColor.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                '● ${ev.freshnessTag}',
                                                style: const TextStyle(fontSize: 8, color: emeraldColor, fontWeight: FontWeight.bold),
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
        border: Border.all(color: (isLive ? emeraldColor : Colors.amber).withValues(alpha: 0.4)),
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
                  color: (isLive ? emeraldColor : Colors.amber).withValues(alpha: 0.2),
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontStyle: FontStyle.italic),
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
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9)),
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
