import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('resqmesh_ai.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite FFI is not supported on web. Using in-memory repository list fallback.');
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createDB(db, newVersion);
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incidents (
        id TEXT PRIMARY KEY,
        source_node INTEGER NOT NULL,
        packet_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        severity_score INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        gps_accuracy REAL DEFAULT 0.0,
        battery INTEGER NOT NULL,
        headcount INTEGER NOT NULL,
        medical_status TEXT NOT NULL,
        description TEXT NOT NULL,
        packet_hex TEXT NOT NULL,
        ttl INTEGER NOT NULL,
        hop_count INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        received_at TEXT,
        client_priority TEXT NOT NULL,
        server_priority TEXT NOT NULL,
        CONSTRAINT unique_sos UNIQUE (source_node, packet_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE packets (
        source_node INTEGER NOT NULL,
        packet_id INTEGER NOT NULL,
        raw_frame TEXT NOT NULL,
        first_seen_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        status TEXT NOT NULL,
        PRIMARY KEY (source_node, packet_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE packet_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_node INTEGER NOT NULL,
        packet_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        node_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        details TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mesh_nodes (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        battery INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        status TEXT NOT NULL,
        signal_quality INTEGER NOT NULL,
        last_seen TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE resources (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        quantity INTEGER NOT NULL,
        status TEXT NOT NULL,
        source TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE checkins (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        status TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE hazards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        severity REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        confidence REAL NOT NULL,
        source TEXT NOT NULL,
        description TEXT,
        responderConfirmed INTEGER NOT NULL DEFAULT 0,
        supportingReports INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE assistance_points (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        capacity INTEGER NOT NULL,
        isAvailable INTEGER NOT NULL DEFAULT 1,
        hazardExposed INTEGER NOT NULL DEFAULT 0,
        contact TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE mesh_outbox (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        priority TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        battery INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        ttl INTEGER NOT NULL,
        hopCount INTEGER NOT NULL,
        payload TEXT NOT NULL,
        acknowledged INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sos_packets (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        batteryPercentage INTEGER NOT NULL,
        emergencyType TEXT NOT NULL,
        medicalNote TEXT NOT NULL,
        status TEXT NOT NULL,
        responderAckMessage TEXT
      )
    ''');
  }

  Future<void> clearAllData() async {
    if (kIsWeb) return;
    final db = await instance.database;
    await db.delete('incidents');
    await db.delete('packets');
    await db.delete('packet_events');
    await db.delete('mesh_nodes');
    await db.delete('resources');
    await db.delete('checkins');
    // Phase 0 safety: previously these four tables were left behind,
    // so "reset" did not actually reset.
    await db.delete('hazards');
    await db.delete('assistance_points');
    await db.delete('mesh_outbox');
    await db.delete('sos_packets');
  }
}
