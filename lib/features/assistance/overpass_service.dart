import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'assistance_model.dart';

// Phase 1 — real assistance points from OpenStreetMap Overpass
// (free, no key), replacing the Phase 0 empty state. Rules from the
// audit, enforced here:
// - Only points OSM actually returns, with a real name, are used.
//   A point without a name is dropped, never given an invented name.
// - Capacity comes from the OSM "capacity" tag only. If OSM has no
//   capacity, the point's capacity is 0, which the UI renders as
//   "Capacity: Unknown" — never a guessed 50/120/450.
// - Contact comes from OSM phone tags only. If none, contact is
//   empty and the UI shows 108 / 112.
// - Availability is not claimed: OSM does not say whether a hospital
//   is currently accepting patients, so isAvailable stays false
//   unless OSM explicitly says otherwise (it does not).
class OverpassService {
  final http.Client _client;

  OverpassService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<AssistancePoint>> fetchNearby({
    required double lat,
    required double lng,
    int radiusMeters = 10000,
  }) async {
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="hospital"](around:$radiusMeters,$lat,$lng);
  way["amenity"="hospital"](around:$radiusMeters,$lat,$lng);
  node["emergency"="shelter"](around:$radiusMeters,$lat,$lng);
  way["emergency"="shelter"](around:$radiusMeters,$lat,$lng);
  node["amenity"="clinic"](around:$radiusMeters,$lat,$lng);
);
out center 50;
''';
    final response = await _client
        .post(
          Uri.parse(AppConfig.overpassUrl),
          headers: {'User-Agent': 'AarakshakEmergencyPlatform/1.0 (contact@aarakshak.internal)'},
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return [];
    final data = json.decode(response.body);
    final elements = data['elements'] as List? ?? [];
    final points = <AssistancePoint>[];
    for (final el in elements) {
      final tags = el['tags'] as Map? ?? {};
      final name = (tags['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      double? plat;
      double? plon;
      if (el['lat'] is num && el['lon'] is num) {
        plat = (el['lat'] as num).toDouble();
        plon = (el['lon'] as num).toDouble();
      } else if (el['center'] is Map) {
        final center = el['center'] as Map;
        if (center['lat'] is num && center['lon'] is num) {
          plat = (center['lat'] as num).toDouble();
          plon = (center['lon'] as num).toDouble();
        }
      }
      if (plat == null || plon == null) continue;
      final amenity = (tags['amenity'] as String?) ?? '';
      final type = amenity == 'hospital'
          ? AssistanceType.hospital
          : amenity == 'clinic'
              ? AssistanceType.hospital
              : AssistanceType.shelter;
      final capacity = int.tryParse((tags['capacity'] as String?) ?? '') ?? 0;
      final contact = ((tags['phone'] ?? tags['contact:phone'] ?? '') as String).trim();
      points.add(AssistancePoint(
        id: 'OSM-${el['type']}-${el['id']}',
        name: name,
        type: type,
        latitude: plat,
        longitude: plon,
        capacity: capacity,
        isAvailable: false,
        hazardExposed: false,
        contact: contact,
      ));
    }
    return points;
  }
}
