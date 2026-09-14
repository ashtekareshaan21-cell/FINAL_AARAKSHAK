import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';
import '../../core/utils/geo_utils.dart';
import 'hazard_model.dart';
import 'hazard_data_source.dart';
import 'hazard_api_service.dart';

class HazardRepository {
  final HazardDataSource _apiSource;
  final DatabaseHelper _dbHelper;

  List<Hazard> _meshHazards = [];
  List<Hazard> _simulatedHazards = [];

  HazardRepository({
    HazardDataSource? apiSource,
    DatabaseHelper? dbHelper,
  })  : _apiSource = apiSource ?? HazardApiService(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Retrieves hazards within discovery radius, merging API, cached DB, mesh, and simulated reports.
  Future<List<Hazard>> getActiveHazards({
    required double userLat,
    required double userLng,
    double radiusKm = 25.0,
    bool isOnline = true,
  }) async {
    Map<String, Hazard> hazardMap = {};

    // 1. Cached SQLite hazards
    final cached = await _getCachedHazards();
    for (var h in cached) {
      // Ignore stale seed hazards older than 2 hours
      if (h.id.startsWith('SEED-') && DateTime.now().difference(h.timestamp).inHours >= 2) {
        continue;
      }
      hazardMap[h.id] = h;
    }

    // 2. Fetch live API hazards if online
    if (isOnline) {
      try {
        final apiHazards = await _apiSource.fetchHazards(userLat, userLng);
        if (apiHazards.isEmpty) {
          // Live API confirmed no active severe weather or natural disasters in this sector.
          // Clear legacy SEED hazards so we don't falsely display DANGER when sector is clear.
          hazardMap.removeWhere((id, h) => id.startsWith('SEED-'));
        } else {
          for (var h in apiHazards) {
            hazardMap[h.id] = h;
            await _saveHazardToCache(h);
          }
        }
      } catch (e) {
        debugPrint('API hazard fetch failed, relying on cache/mesh: $e');
      }
    }

    // 3. Merge Mesh observations
    for (var h in _meshHazards) {
      hazardMap[h.id] = h;
    }

    // 4. Merge Simulated hazards
    for (var h in _simulatedHazards) {
      hazardMap[h.id] = h;
    }

    // 5. Filter strictly within [radiusKm] (default 25 km Discovery radius)
    final allHazards = hazardMap.values.where((h) {
      final dist = GeoUtils.haversineDistance(
        lat1: userLat,
        lon1: userLng,
        lat2: h.latitude,
        lon2: h.longitude,
      );
      return dist <= radiusKm;
    }).toList();

    return allHazards;
  }

  void addMeshHazard(Hazard hazard) {
    _meshHazards.removeWhere((h) => h.id == hazard.id);
    _meshHazards.add(hazard);
  }

  void setSimulatedHazards(List<Hazard> hazards) {
    _simulatedHazards = hazards;
  }

  void clearSimulatedHazards() {
    _simulatedHazards.clear();
  }

  Future<List<Hazard>> _getCachedHazards() async {
    if (kIsWeb) return [];
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('hazards');
      return maps.map((m) => Hazard.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveHazardToCache(Hazard hazard) async {
    if (kIsWeb) return;
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'hazards',
        hazard.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
