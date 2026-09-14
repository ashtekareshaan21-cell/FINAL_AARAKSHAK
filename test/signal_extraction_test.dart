import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/triage/signal_extraction_service.dart';

void main() {
  group('RuleBasedSignalExtractionService Tests', () {
    final extractor = RuleBasedSignalExtractionService();

    test('Extracts Pune Flood scenario parameters correctly', () async {
      const text = 'Flood water is rising quickly. Four people are trapped. One person is unconscious.';
      final signal = await extractor.extract(text);

      expect(signal.category, equals('Flood'));
      expect(signal.casualties, equals(4));
      expect(signal.medicalStatus, equals('Unconscious'));
      expect(signal.personTrapped, isTrue);
      expect(signal.waterRising, isTrue);
    });

    test('Extracts Structural Collapse scenario parameters correctly', () async {
      const text = 'Building collapse in Mumbai. 2 victims trapped under rubble. Severe injuries.';
      final signal = await extractor.extract(text);

      expect(signal.category, equals('Structural Collapse'));
      expect(signal.casualties, equals(2));
      expect(signal.medicalStatus, equals('Critical'));
      expect(signal.personTrapped, isTrue);
      expect(signal.structuralInstability, isTrue);
    });
  });
}
