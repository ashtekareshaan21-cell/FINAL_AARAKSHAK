import 'dart:async';
import 'package:flutter/foundation.dart';
import '../hazards/hazard_model.dart';
import '../hazards/hazard_repository.dart';
import 'risk_calculator.dart';
import 'risk_state.dart';

class ContextEngine {
  final HazardRepository _hazardRepository;
  RiskState _currentRiskState = RiskState.initial();
  final _riskStateStreamController = StreamController<RiskState>.broadcast();

  ContextEngine({HazardRepository? hazardRepository})
      : _hazardRepository = hazardRepository ?? HazardRepository();

  RiskState get currentRiskState => _currentRiskState;
  Stream<RiskState> get riskStateStream => _riskStateStreamController.stream;

  /// Recalculates unified risk state from location, active hazards, weather, and SOS status.
  Future<RiskState> evaluateContext({
    required double userLat,
    required double userLng,
    required bool isOnline,
    required bool activeSos,
    String? weatherSummary,
  }) async {
    try {
      final hazards = await _hazardRepository.getActiveHazards(
        userLat: userLat,
        userLng: userLng,
        isOnline: isOnline,
      );

      _currentRiskState = RiskCalculator.calculateRiskState(
        userLat: userLat,
        userLng: userLng,
        activeHazards: hazards,
        activeSos: activeSos,
        weatherSummary: weatherSummary,
      );

      _riskStateStreamController.add(_currentRiskState);
      return _currentRiskState;
    } catch (e) {
      debugPrint('ContextEngine evaluation fallback: $e');
      return _currentRiskState;
    }
  }

  void injectMeshObservation(Hazard hazard, double userLat, double userLng, bool activeSos) {
    _hazardRepository.addMeshHazard(hazard);
    evaluateContext(
      userLat: userLat,
      userLng: userLng,
      isOnline: false,
      activeSos: activeSos,
    );
  }

  void dispose() {
    _riskStateStreamController.close();
  }
}
