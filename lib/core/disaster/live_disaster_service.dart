import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../shared/constants/app_brand.dart';
import 'disaster_service.dart';

// Phase 1 — free, no-key live feeds, added alongside the existing
// NASA EONET feed. Every parser below is defensive: an unexpected
// field, a missing coordinate or a failed request yields no event,
// never an invented one. A feed that fails contributes nothing;
// the combined service still returns the feeds that did succeed,
// and on total failure it returns the last cached live events.

// USGS earthquakes, GeoJSON feed (magnitude 2.5+, past day).
class UsgsEarthquakeService implements DisasterDataService {
  List<DisasterEvent> _cached = [];
  bool lastFetchSucceeded = false;

  @override
  SubsystemCapability get statusTag =>
      _cached.isEmpty ? SubsystemCapability.cached : SubsystemCapability.real;

  @override
  Future<List<DisasterEvent>> getEvents() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.usgsFeedUrl)).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        lastFetchSucceeded = false;
        return _cached;
      }
      final data = json.decode(response.body);
      final features = data['features'] as List? ?? [];
      final results = <DisasterEvent>[];
      for (final f in features) {
        final props = f['properties'] as Map? ?? {};
        final geom = f['geometry'] as Map? ?? {};
        final coords = geom['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;
        final mag = (props['mag'] as num?)?.toDouble();
        final timeMs = props['time'] as num?;
        results.add(DisasterEvent(
          id: (f['id'] as String?) ?? 'USGS-${results.length}',
          title: (props['place'] as String?) ??
              'Earthquake${mag != null ? ' M${mag.toStringAsFixed(1)}' : ''}',
          category: 'Earthquake',
          latitude: (coords[1] as num).toDouble(),
          longitude: (coords[0] as num).toDouble(),
          timestamp: timeMs != null
              ? DateTime.fromMillisecondsSinceEpoch(timeMs.toInt())
              : DateTime.now(),
          source: 'USGS',
          severity: (mag != null && mag >= 6.0) ? 'CRITICAL' : 'ELEVATED',
          freshnessTag: 'LIVE',
        ));
      }
      if (results.isNotEmpty) {
        _cached = results;
        lastFetchSucceeded = true;
      }
    } catch (_) {
      lastFetchSucceeded = false;
      // No invented fallback: keep the last cached live events.
    }
    return _cached;
  }
}

// GDACS global disaster alerts (GeoJSON event list). Field names in
// the GDACS feed have changed before, so every field is read with a
// fallback and an event without a usable location is dropped.
class GdacsDisasterService implements DisasterDataService {
  List<DisasterEvent> _cached = [];
  bool lastFetchSucceeded = false;

  @override
  SubsystemCapability get statusTag =>
      _cached.isEmpty ? SubsystemCapability.cached : SubsystemCapability.real;

  @override
  Future<List<DisasterEvent>> getEvents() async {
    try {
      final response =
          await http.get(Uri.parse(AppConfig.gdacsFeedUrl)).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        lastFetchSucceeded = false;
        return _cached;
      }
      final data = json.decode(response.body);
      // GDACS returns either a GeoJSON FeatureCollection or a plain
      // list under "features"/"events" — accept both shapes.
      final List features;
      if (data is Map && data['features'] is List) {
        features = data['features'] as List;
      } else if (data is Map && data['events'] is List) {
        features = data['events'] as List;
      } else if (data is List) {
        features = data;
      } else {
        lastFetchSucceeded = false;
        return _cached;
      }
      final results = <DisasterEvent>[];
      for (final f in features) {
        final props = (f is Map ? f['properties'] as Map? : null) ?? (f as Map? ?? {});
        final geom = f is Map ? f['geometry'] as Map? : null;
        final coords = geom?['coordinates'] as List?;
        double? lat;
        double? lon;
        if (coords != null && coords.length >= 2) {
          lon = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        } else {
          // Some GDACS rows carry lat/lon as properties instead.
          final pLat = props['latitude'] ?? props['lat'];
          final pLon = props['longitude'] ?? props['lon'];
          if (pLat is num && pLon is num) {
            lat = pLat.toDouble();
            lon = pLon.toDouble();
          }
        }
        if (lat == null || lon == null) continue;
        final eventType = (props['eventtype'] ?? props['eventType'] ?? props['type'] ?? 'Disaster').toString();
        final alertLevel = (props['alertlevel'] ?? props['alertLevel'] ?? '').toString();
        final name = (props['name'] ?? props['title'] ?? props['country'] ?? eventType).toString();
        final dateStr = (props['fromdate'] ?? props['date'] ?? props['pubDate'])?.toString();
        results.add(DisasterEvent(
          id: (props['eventid'] ?? props['id'] ?? 'GDACS-${results.length}').toString(),
          title: '$eventType: $name',
          category: eventType,
          latitude: lat,
          longitude: lon,
          timestamp: dateStr != null ? (DateTime.tryParse(dateStr) ?? DateTime.now()) : DateTime.now(),
          source: 'GDACS',
          severity: alertLevel.toLowerCase().contains('red') ? 'CRITICAL' : 'ELEVATED',
          freshnessTag: 'LIVE',
        ));
      }
      if (results.isNotEmpty) {
        _cached = results;
        lastFetchSucceeded = true;
      }
    } catch (_) {
      lastFetchSucceeded = false;
      // No invented fallback.
    }
    return _cached;
  }
}

// EONET + GDACS + USGS, deduplicated by source+id, newest first.
class CombinedDisasterService implements DisasterDataService {
  final List<DisasterDataService> _services;
  List<DisasterEvent> _cached = [];
  final List<String> _unavailableFeeds = [];
  List<String> get unavailableFeeds => List.unmodifiable(_unavailableFeeds);

  CombinedDisasterService({List<DisasterDataService>? services})
      : _services = services ??
            [
              NasaEonetDisasterService(),
              GdacsDisasterService(),
              UsgsEarthquakeService(),
            ];

  @override
  SubsystemCapability get statusTag =>
      _cached.isEmpty ? SubsystemCapability.cached : SubsystemCapability.real;

  @override
  Future<List<DisasterEvent>> getEvents() async {
    final results = <DisasterEvent>[];
    final seen = <String>{};
    _unavailableFeeds.clear();
    for (final service in _services) {
      final feedName = _getFeedName(service);
      try {
        final events = await service.getEvents();
        final bool failed = (service is UsgsEarthquakeService && !service.lastFetchSucceeded) ||
            (service is GdacsDisasterService && !service.lastFetchSucceeded) ||
            (service is NasaEonetDisasterService && !service.lastFetchSucceeded);
        if (failed && events.isEmpty) {
          _unavailableFeeds.add(feedName);
        }
        for (final event in events) {
          final key = '${event.source}:${event.id}';
          if (seen.add(key)) results.add(event);
        }
      } catch (_) {
        _unavailableFeeds.add(feedName);
      }
    }
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (results.isNotEmpty) _cached = results;
    return _cached;
  }

  String _getFeedName(DisasterDataService s) {
    if (s is NasaEonetDisasterService) return 'EONET';
    if (s is GdacsDisasterService) return 'GDACS';
    if (s is UsgsEarthquakeService) return 'USGS';
    return s.runtimeType.toString();
  }
}
