import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/constants/app_brand.dart';

class DisasterEvent {
  final String id;
  final String title;
  final String category;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String source;
  final String severity;
  final String freshnessTag; // LIVE, CACHED, STALE

  DisasterEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.source,
    this.severity = 'ELEVATED',
    this.freshnessTag = 'LIVE',
  });

  String get ageLabel {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

abstract class DisasterDataService {
  Future<List<DisasterEvent>> getEvents();
  SubsystemCapability get statusTag;
}

class NasaEonetDisasterService implements DisasterDataService {
  List<DisasterEvent> _cachedEvents = [];
  bool lastFetchSucceeded = false;

  @override
  SubsystemCapability get statusTag =>
      _cachedEvents.isEmpty ? SubsystemCapability.cached : SubsystemCapability.real;

  @override
  Future<List<DisasterEvent>> getEvents() async {
    try {
      final url = Uri.parse('https://eonet.gsfc.nasa.gov/api/v3/events?limit=20&status=open');
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List eventsList = data['events'] ?? [];
        final results = <DisasterEvent>[];

        // Phase 0 safety: no placeholder disaster is injected above the
        // live EONET events. Only real API events are returned.
        for (var item in eventsList) {
          final categories = item['categories'] as List;
          final categoryName = categories.isNotEmpty ? categories[0]['title'] ?? 'Natural Hazard' : 'Natural Hazard';
          final geometries = item['geometry'] as List;

          if (geometries.isNotEmpty) {
            final coords = geometries[0]['coordinates'] as List;
            final lon = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final dateStr = geometries[0]['date'] as String;

            results.add(DisasterEvent(
              id: item['id'] ?? 'EONET-${results.length}',
              title: item['title'] ?? 'Environmental Event',
              category: categoryName,
              latitude: lat,
              longitude: lon,
              timestamp: DateTime.tryParse(dateStr) ?? DateTime.now(),
              source: 'EONET',
              severity: categoryName.contains('Flood') || categoryName.contains('Storm') ? 'CRITICAL' : 'ELEVATED',
              freshnessTag: 'LIVE',
            ));
          }
        }
        if (results.isNotEmpty) {
          _cachedEvents = results;
          lastFetchSucceeded = true;
          return results;
        }
      }
      lastFetchSucceeded = false;
    } catch (_) {
      lastFetchSucceeded = false;
      // Offline fallback
    }

    // Phase 0 safety: no invented fallback disasters. If the live feed
    // fails, return the last cached live events if any, otherwise nothing.
    // Callers must render an empty / unavailable state, not a fake alert.
    return _cachedEvents;
  }
}
