import 'hazard_model.dart';

abstract class HazardDataSource {
  Future<List<Hazard>> fetchHazards(double userLat, double userLng);
}
