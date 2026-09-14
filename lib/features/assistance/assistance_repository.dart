import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';
import 'assistance_model.dart';
import 'assistance_sorter.dart';

class AssistanceRepository {
  final DatabaseHelper _dbHelper;

  AssistanceRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<AssistancePoint>> getSortedAssistancePoints({
    required double userLat,
    required double userLng,
    AssistanceType? filterType,
  }) async {
    List<AssistancePoint> rawPoints = await _loadAssistancePoints();

    if (rawPoints.isEmpty) {
      rawPoints = _getSeedAssistancePoints(userLat, userLng);
      for (var p in rawPoints) {
        await _savePoint(p);
      }
    }

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

  List<AssistancePoint> _getSeedAssistancePoints(double userLat, double userLng) {
    String hospName = 'District Emergency Hospital';
    String shelName = 'Regional Disaster Relief Shelter';
    String rescName = 'NDRF Regional Rescue Base';

    if (userLat >= 12.0 && userLat <= 13.5) {
      // Bengaluru
      hospName = 'Bowring Hospital & Disaster Trauma Center';
      shelName = 'Kanteerava Indoor Stadium Relief Shelter';
      rescName = 'NDRF Bengaluru Response Post';
    } else if (userLat >= 18.8 && userLat <= 19.3) {
      // Mumbai
      hospName = 'KEM Disaster Care & Trauma Hospital';
      shelName = 'Brabourne Stadium Relief Shelter';
      rescName = 'NDRF Mumbai Maritime Rescue Base';
    } else if (userLat >= 28.3 && userLat <= 28.9) {
      // Delhi
      hospName = 'AIIMS Emergency Trauma Care Center';
      shelName = 'Jawaharlal Nehru Relief Shelter';
      rescName = 'NDRF Capital Emergency Rescue Post';
    } else if (userLat >= 18.4 && userLat <= 18.7) {
      // Regional Preset (MH Zone)
      hospName = 'Ruby Trauma & Disaster Hospital';
      shelName = 'Municipal Indoor Stadium Relief Shelter';
      rescName = 'NDRF Regional Emergency Rescue Post';
    }

    return [
      AssistancePoint(
        id: 'AST-HOSP-${userLat.toStringAsFixed(2)}-${userLng.toStringAsFixed(2)}',
        name: hospName,
        type: AssistanceType.hospital,
        latitude: userLat + 0.015, // ~2.1 km away
        longitude: userLng + 0.008,
        capacity: 120,
        isAvailable: true,
        hazardExposed: false,
        contact: '+91 20 2616 3399',
      ),
      AssistancePoint(
        id: 'AST-SHEL-${userLat.toStringAsFixed(2)}-${userLng.toStringAsFixed(2)}',
        name: shelName,
        type: AssistanceType.shelter,
        latitude: userLat + 0.024, // ~3.4 km away
        longitude: userLng - 0.012,
        capacity: 450,
        isAvailable: true,
        hazardExposed: false,
        contact: 'Ch. 4 Mesh Radio / 108',
      ),
      AssistancePoint(
        id: 'AST-AMB-${userLat.toStringAsFixed(2)}-${userLng.toStringAsFixed(2)}',
        name: 'Emergency Mobile Ambulance Unit #4',
        type: AssistanceType.ambulance,
        latitude: userLat - 0.032, // ~4.5 km away
        longitude: userLng + 0.020,
        capacity: 4,
        isAvailable: true,
        hazardExposed: false,
        contact: 'VHF-146.520 MHz',
      ),
      AssistancePoint(
        id: 'AST-RESC-${userLat.toStringAsFixed(2)}-${userLng.toStringAsFixed(2)}',
        name: rescName,
        type: AssistanceType.rescueStation,
        latitude: userLat - 0.041, // ~5.8 km away
        longitude: userLng - 0.025,
        capacity: 80,
        isAvailable: true,
        hazardExposed: false,
        contact: 'Aarakshak Gateway Node #12',
      ),
      AssistancePoint(
        id: 'AST-CAMP-${userLat.toStringAsFixed(2)}-${userLng.toStringAsFixed(2)}',
        name: 'Disaster Relief Supplies Center',
        type: AssistanceType.reliefCenter,
        latitude: userLat + 0.055, // ~7.2 km away
        longitude: userLng + 0.040,
        capacity: 300,
        isAvailable: true,
        hazardExposed: false,
        contact: 'Relief Post Alpha',
      ),
    ];
  }
}
