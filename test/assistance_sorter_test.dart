import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/features/assistance/assistance_model.dart';
import 'package:resqmesh_ai/features/assistance/assistance_sorter.dart';

void main() {
  group('AssistanceSorter Unit Tests', () {
    const userLat = 18.5204;
    const userLng = 73.8567;

    test('Sorts assistance points by Haversine distance ascending', () {
      final farPoint = AssistancePoint(
        id: '1',
        name: 'Far Hospital',
        type: AssistanceType.hospital,
        latitude: userLat + 0.1, // ~11 km
        longitude: userLng + 0.1,
      );

      final nearPoint = AssistancePoint(
        id: '2',
        name: 'Near Shelter',
        type: AssistanceType.shelter,
        latitude: userLat + 0.01, // ~1.1 km
        longitude: userLng + 0.01,
      );

      final sorted = AssistanceSorter.sortAssistancePoints(
        points: [farPoint, nearPoint],
        userLat: userLat,
        userLng: userLng,
      );

      expect(sorted.first.id, equals('2'));
      expect(sorted.last.id, equals('1'));
      expect(sorted.first.calculatedDistanceKm, lessThan(sorted.last.calculatedDistanceKm));
    });

    test('Available facilities rank ahead of unavailable ones', () {
      final nearUnavailable = AssistancePoint(
        id: 'UNAVAIL',
        name: 'Full Shelter',
        type: AssistanceType.shelter,
        latitude: userLat + 0.005,
        longitude: userLng + 0.005,
        isAvailable: false,
      );

      final farAvailable = AssistancePoint(
        id: 'AVAIL',
        name: 'Open Relief Center',
        type: AssistanceType.reliefCenter,
        latitude: userLat + 0.02,
        longitude: userLng + 0.02,
        isAvailable: true,
      );

      final sorted = AssistanceSorter.sortAssistancePoints(
        points: [nearUnavailable, farAvailable],
        userLat: userLat,
        userLng: userLng,
      );

      expect(sorted.first.id, equals('AVAIL'));
    });
  });
}
