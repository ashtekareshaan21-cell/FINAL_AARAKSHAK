import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/features/context_engine/risk_calculator.dart';
import 'package:resqmesh_ai/features/context_engine/risk_state.dart';
import 'package:resqmesh_ai/features/hazards/hazard_model.dart';

void main() {
  group('RiskCalculator Unit Tests', () {
    const userLat = 18.5204;
    const userLng = 73.8567;

    test('Empty hazards list yields RiskLevel.safe', () {
      final state = RiskCalculator.calculateRiskState(
        userLat: userLat,
        userLng: userLng,
        activeHazards: [],
        activeSos: false,
      );

      expect(state.level, RiskLevel.safe);
      expect(state.score, equals(0.0));
    });

    test('Active SOS forces absolute RiskLevel.sos override and score 100', () {
      final state = RiskCalculator.calculateRiskState(
        userLat: userLat,
        userLng: userLng,
        activeHazards: [],
        activeSos: true,
      );

      expect(state.level, RiskLevel.sos);
      expect(state.score, equals(100.0));
      expect(state.activeSos, isTrue);
    });

    test('Severe hazard in 5km critical zone triggers RiskLevel.danger or sos', () {
      final hazard = Hazard(
        id: 'HAZ-CRIT-1',
        title: 'Flash Flood Surge',
        type: 'Flood',
        severity: 0.90,
        latitude: userLat + 0.01, // ~1.1 km away
        longitude: userLng + 0.005,
        timestamp: DateTime.now(),
        confidence: 0.90,
        source: HazardSource.disasterApi,
        responderConfirmed: true,
      );

      final state = RiskCalculator.calculateRiskState(
        userLat: userLat,
        userLng: userLng,
        activeHazards: [hazard],
        activeSos: false,
      );

      expect(state.score, greaterThan(70.0));
      expect(
        state.level == RiskLevel.danger || state.level == RiskLevel.sos,
        isTrue,
      );
    });

    test('Stale hazard score decays compared to fresh hazard', () {
      final freshHazard = Hazard(
        id: 'HAZ-FRESH',
        title: 'Fresh Wildfire',
        type: 'Wildfire',
        severity: 0.80,
        latitude: userLat + 0.02,
        longitude: userLng + 0.02,
        timestamp: DateTime.now(),
        confidence: 0.80,
        source: HazardSource.citizenReport,
      );

      final staleHazard = Hazard(
        id: 'HAZ-STALE',
        title: 'Stale Wildfire',
        type: 'Wildfire',
        severity: 0.80,
        latitude: userLat + 0.02,
        longitude: userLng + 0.02,
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        confidence: 0.80,
        source: HazardSource.citizenReport,
      );

      final freshState = RiskCalculator.calculateRiskState(
        userLat: userLat,
        userLng: userLng,
        activeHazards: [freshHazard],
        activeSos: false,
      );

      final staleState = RiskCalculator.calculateRiskState(
        userLat: userLat,
        userLng: userLng,
        activeHazards: [staleHazard],
        activeSos: false,
      );

      expect(freshState.score, greaterThan(staleState.score));
    });
  });
}
