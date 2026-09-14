import '../models/hazard_data.dart';

/// Clean abstraction interface for hazard providers (Real vs Mock)
abstract class HazardProvider {
  Future<List<HazardData>> getHazards({
    required double latitude,
    required double longitude,
  });
}
