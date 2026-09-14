import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/packet/packet_engine.dart';
import 'package:resqmesh_ai/core/triage/triage_engine.dart';

void main() {
  group('TriageEngine Scoring & Priority Tests', () {
    test('Unconscious victim triggers P0 Critical priority', () {
      final signal = EmergencySignal(
        category: 'Flood',
        casualties: 4,
        medicalStatus: 'Unconscious',
        personTrapped: true,
        waterRising: true,
        firePresent: false,
        structuralInstability: false,
        requiresEvacuation: true,
        medicalEmergency: true,
        rawDescription: 'Flood water rising, 4 trapped, 1 unconscious',
      );

      final result = TriageEngine.calculate(signal);
      expect(result.priority, equals(TriagePriority.p0Critical));
      expect(result.score, greaterThanOrEqualTo(60));
      expect(result.reasons, contains(predicate<String>((s) => s.contains('Unconscious'))));
    });

    test('Injured without life-threatening flags triggers P1 Medical', () {
      final signal = EmergencySignal(
        category: 'Medical',
        casualties: 1,
        medicalStatus: 'Injured',
        personTrapped: false,
        waterRising: false,
        firePresent: false,
        structuralInstability: false,
        requiresEvacuation: false,
        medicalEmergency: true,
        rawDescription: 'Broken arm from slip',
      );

      final result = TriageEngine.calculate(signal);
      expect(result.priority, equals(TriagePriority.p1Medical));
    });
  });
}
