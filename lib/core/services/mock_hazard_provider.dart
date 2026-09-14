import '../models/hazard_data.dart';
import 'hazard_provider.dart';

class MockHazardProvider implements HazardProvider {
  @override
  Future<List<HazardData>> getHazards({
    required double latitude,
    required double longitude,
  }) async {
    // Generates location-relative test hazards around ANY user GPS coordinates
    return [
      HazardData(
        id: 'DEMO-FLOOD-${latitude.toStringAsFixed(2)}-${longitude.toStringAsFixed(2)}',
        title: 'Demo Urban Flood Risk',
        type: HazardType.flood.label,
        source: 'DEMO / TEST FEED',
        severity: 26,
        latitude: latitude + 0.03, // Relative offset (~3.5 km away)
        longitude: longitude + 0.02,
        description: 'Simulated urban inundation for testing proximity and risk calculation.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        confidence: 0.80,
        dataState: HazardDataState.demo,
      ),
      HazardData(
        id: 'DEMO-SLIDE-${latitude.toStringAsFixed(2)}-${longitude.toStringAsFixed(2)}',
        title: 'Demo Landslide Watch',
        type: HazardType.landslide.label,
        source: 'DEMO / TEST FEED',
        severity: 18,
        latitude: latitude + 0.12, // Relative offset (~14 km away)
        longitude: longitude - 0.08,
        description: 'Simulated hill slope instability for testing monitoring radius limits.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        confidence: 0.75,
        dataState: HazardDataState.demo,
      ),
    ];
  }
}
