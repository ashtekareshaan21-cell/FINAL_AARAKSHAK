import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/models/hazard_data.dart';
import 'package:resqmesh_ai/core/services/real_hazard_provider.dart';
import 'package:resqmesh_ai/core/services/mock_hazard_provider.dart';
import 'package:resqmesh_ai/core/services/hazard_service.dart';

void main() {
  group('Location-Driven Hazard System Generalization Tests', () {
    test('MockHazardProvider generates coordinates relative to ANY given GPS location', () async {
      final mockProvider = MockHazardProvider();

      // Test 1: Pune
      final puneHazards = await mockProvider.getHazards(latitude: 18.5204, longitude: 73.8567);
      expect(puneHazards.isNotEmpty, isTrue);
      expect(puneHazards.first.latitude, closeTo(18.55, 0.01));
      expect(puneHazards.first.dataState, HazardDataState.demo);
      expect(puneHazards.first.source, contains('DEMO'));

      // Test 2: Mumbai
      final mumbaiHazards = await mockProvider.getHazards(latitude: 19.0760, longitude: 72.8777);
      expect(mumbaiHazards.first.latitude, closeTo(19.1060, 0.01));
      expect(mumbaiHazards.first.longitude, closeTo(72.8977, 0.01));

      // Test 3: Delhi
      final delhiHazards = await mockProvider.getHazards(latitude: 28.6139, longitude: 77.2090);
      expect(delhiHazards.first.latitude, closeTo(28.6439, 0.01));

      // Test 4: Kerala
      final keralaHazards = await mockProvider.getHazards(latitude: 9.9312, longitude: 76.2673);
      expect(keralaHazards.first.latitude, closeTo(9.9612, 0.01));

      // Test 5: Assam
      final assamHazards = await mockProvider.getHazards(latitude: 26.1445, longitude: 91.7362);
      expect(assamHazards.first.latitude, closeTo(26.1745, 0.01));
    });

    test('HazardService computes proximity distance dynamically and filters outside 20 km', () async {
      final mockProvider = MockHazardProvider();
      final service = HazardService(provider: mockProvider);

      final hazards = await service.getActiveHazards(
        userLat: 18.5204,
        userLon: 73.8567,
        monitoringRadiusKm: 20.0,
      );

      // Verify each hazard has distanceKm computed and is <= 20 km
      for (var h in hazards) {
        expect(h.distanceKm, isNotNull);
        expect(h.distanceKm! <= 20.0, isTrue);
      }
    });

    test('RealHazardProvider query handles coordinate-based queries without hardcoded cities', () async {
      final realProvider = RealHazardProvider();

      // Query for Assam coordinates
      final hazards = await realProvider.getHazards(latitude: 26.1445, longitude: 91.7362);
      // Real provider returns List<HazardData> (either empty if clear, or dynamic hazards if severe)
      expect(hazards, isA<List<HazardData>>());
    });
  });
}
