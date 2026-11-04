import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';
import 'assistance_model.dart';
import 'assistance_sorter.dart';
import 'overpass_service.dart';

class AssistanceRepository {
  final DatabaseHelper _dbHelper;
  final OverpassService _overpass;

  AssistanceRepository({DatabaseHelper? dbHelper, OverpassService? overpass})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _overpass = overpass ?? OverpassService();

  // Phase 1: fetch verified OSM points for the user's real location,
  // store them, and return them sorted. Call this on a manual refresh
  // or when the location changes significantly — not on every build,
  // because Overpass is a shared public service with rate limits.
  Future<List<AssistancePoint>> refreshFromOverpass({
    required double userLat,
    required double userLng,
  }) async {
    final points = await _overpass.fetchNearby(lat: userLat, lng: userLng);
    for (final point in points) {
      await _savePoint(point);
    }
    return getSortedAssistancePoints(userLat: userLat, userLng: userLng);
  }

  Future<List<AssistancePoint>> getSortedAssistancePoints({
    required double userLat,
    required double userLng,
    AssistanceType? filterType,
  }) async {
    List<AssistancePoint> rawPoints = await _loadAssistancePoints();

    // Phase 0 safety: no invented seed points. If no verified points
    // are stored, return an empty list. Verified points arrive in
    // Phase 1 (OSM Overpass). Until then the UI must show an empty
    // state plus emergency numbers 108 / 112, never invented hospitals.

    return AssistanceSorter.sortAssistancePoints(
      points: rawPoints,
      userLat: userLat,
      userLng: userLng,
      filterType: filterType,
    );
  }

  Future<List<AssistancePoint>> _loadAssistancePoints() async {
    if (kIsWeb) return [];
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('assistance_points');
      return maps.map((m) => AssistancePoint.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePoint(AssistancePoint point) async {
    if (kIsWeb) return;
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'assistance_points',
        point.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

}
