import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/triage/trust_engine.dart';
import 'package:resqmesh_ai/data/repositories/incident_repository.dart';

void main() {
  group('TrustEngine Unit Tests', () {
    test('Calculates high trust for fresh, GPS-verified, CRC-valid report with corroboration', () {
      final incident = IncidentRecord(
        id: 'INC-TEST-01',
        sourceNode: 0x12345678,
        packetId: 100,
        category: 'Flood',
        priority: 'P0 — CRITICAL',
        severityScore: 130,
        latitude: 18.52043,
        longitude: 73.85674,
        gpsAccuracy: 8.0,
        battery: 90,
        headcount: 4,
        medicalStatus: 'Unconscious',
        description: 'Test flood',
        packetHex: '52535131000112345678000000000000',
        ttl: 15,
        hopCount: 0,
        status: 'LOCAL',
        createdAt: DateTime.now(),
        clientPriority: 'P0',
        serverPriority: 'P0',
      );

      final otherIncident = IncidentRecord(
        id: 'INC-TEST-02',
        sourceNode: 0x87654321,
        packetId: 101,
        category: 'Flood',
        priority: 'P0 — CRITICAL',
        severityScore: 120,
        latitude: 18.52100, // Nearby within 600m
        longitude: 73.85700,
        gpsAccuracy: 10.0,
        battery: 80,
        headcount: 2,
        medicalStatus: 'Injured',
        description: 'Nearby flood',
        packetHex: '52535131000187654321000000000000',
        ttl: 15,
        hopCount: 0,
        status: 'DELIVERED',
        createdAt: DateTime.now(),
        clientPriority: 'P0',
        serverPriority: 'P0',
      );

      final result = TrustEngine.calculateTrust(
        incident: incident,
        activeIncidents: [incident, otherIncident],
        isCrcValid: true,
        isHumanVerified: true,
      );

      expect(result.score, greaterThanOrEqualTo(85));
      expect(result.isCrcValid, isTrue);
      expect(result.isGpsVerified, isTrue);
      expect(result.corroborationsCount, equals(1));
    });
  });
}
