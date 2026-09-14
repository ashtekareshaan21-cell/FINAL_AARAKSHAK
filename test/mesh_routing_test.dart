import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/features/mesh/mesh_packet.dart';
import 'package:resqmesh_ai/features/mesh/packet_router.dart';

void main() {
  group('PacketRouter & StoreForwardQueue Unit Tests', () {
    test('Duplicate packet ID is suppressed and dropped', () {
      final router = PacketRouter();
      final packet = MeshPacket(
        id: 'PKT-DUP-01',
        type: PacketType.sos,
        priority: PacketPriority.critical,
        latitude: 18.52,
        longitude: 73.85,
        battery: 90,
        timestamp: DateTime.now(),
        payload: 'Test SOS',
      );

      final decision1 = router.routePacket(packet);
      expect(decision1.shouldForward, isTrue);

      final decision2 = router.routePacket(packet);
      expect(decision2.shouldForward, isFalse);
      expect(decision2.reason, contains('Duplicate'));
    });

    test('Expired packet (TTL <= 1) is dropped', () {
      final router = PacketRouter();
      final expiredPacket = MeshPacket(
        id: 'PKT-EXP-01',
        type: PacketType.hazardReport,
        priority: PacketPriority.high,
        latitude: 18.52,
        longitude: 73.85,
        battery: 90,
        timestamp: DateTime.now(),
        ttl: 1, // TTL = 1 expires upon hop
        payload: 'Expired Hazard',
      );

      final decision = router.routePacket(expiredPacket);
      expect(decision.shouldForward, isFalse);
      expect(decision.reason, contains('TTL expired'));
    });

    test('Low battery (< 15%) drops LOW/MEDIUM priority packets', () {
      final router = PacketRouter();
      final lowPriorityPacket = MeshPacket(
        id: 'PKT-LOW-01',
        type: PacketType.heartbeat,
        priority: PacketPriority.low,
        latitude: 18.52,
        longitude: 73.85,
        battery: 80,
        timestamp: DateTime.now(),
        ttl: 5,
        payload: 'Heartbeat Ping',
      );

      final decision = router.routePacket(lowPriorityPacket, userBattery: 10);
      expect(decision.shouldForward, isFalse);
      expect(decision.reason, contains('Battery critical'));
    });

    test('CRITICAL priority packets bypass low battery restriction', () {
      final router = PacketRouter();
      final criticalPacket = MeshPacket(
        id: 'PKT-CRIT-01',
        type: PacketType.sos,
        priority: PacketPriority.critical,
        latitude: 18.52,
        longitude: 73.85,
        battery: 80,
        timestamp: DateTime.now(),
        ttl: 5,
        payload: 'Critical Trapped Victim',
      );

      final decision = router.routePacket(criticalPacket, userBattery: 5);
      expect(decision.shouldForward, isTrue);
    });
  });
}
