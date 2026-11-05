import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/sync/eoc_websocket_client.dart';
import 'core/sync/sync_service.dart';
import 'core/transport/transport_adapter.dart';
import 'data/repositories/incident_repository.dart';
import 'features/context_engine/context_providers.dart';
import 'shared/constants/app_brand.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for Desktop and Web Fallback
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Phase 2: Start sync and WebSocket client once at startup
  final incidentRepository = IncidentRepository();
  final internetTransport = InternetTransport();
  await internetTransport.start();

  final syncService = SyncService(
    repository: incidentRepository,
    transports: [internetTransport],
  );
  syncService.start();

  final eocWsClient = EocWebSocketClient();
  eocWsClient.connect();

  runApp(
    ProviderScope(
      overrides: [
        incidentRepositoryProvider.overrideWithValue(incidentRepository),
        internetTransportProvider.overrideWithValue(internetTransport),
        syncServiceProvider.overrideWithValue(syncService),
        eocWsClientProvider.overrideWithValue(eocWsClient),
      ],
      child: const ResQMeshApp(),
    ),
  );
}

class ResQMeshApp extends StatelessWidget {
  const ResQMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
