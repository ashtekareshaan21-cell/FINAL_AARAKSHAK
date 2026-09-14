import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh_ai/core/packet/packet_engine.dart';

void main() {
  group('48-Byte SOS_FRAME_V1 Packet Engine Tests', () {
    test('Cross-Language Test Vectors Validation', () {
      final file = File('protocol/test_vectors.json');
      expect(file.existsSync(), isTrue);

      final jsonContent = json.decode(file.readAsStringSync());
      final List vectors = jsonContent['test_vectors'];

      for (var vec in vectors) {
        final fields = vec['fields'];
        final String expectedHex = vec['expected_hex'];

        final packet = EmergencyPacket(
          magicByte: fields['magic_byte'],
          packetId: fields['packet_id'],
          sourceNode: fields['source_node'],
          ttl: fields['ttl'],
          hops: fields['hops'],
          timestamp: fields['timestamp'],
          priority: TriagePriority.values[fields['triage_priority']],
          latitude: (fields['latitude'] as num).toDouble(),
          longitude: (fields['longitude'] as num).toDouble(),
          battery: fields['battery'],
          adults: fields['adults'],
          children: fields['children'],
          payloadText: fields['payload_text'],
        );

        final encodedBytes = PacketEngine.encodePacket(packet);
        expect(encodedBytes.length, equals(48), reason: 'Packet MUST be strictly 48 bytes');

        final actualHex = PacketEngine.packetToHex(encodedBytes);
        expect(actualHex, equals(expectedHex), reason: 'Dart encoded hex must match test vector');

        // Test Round Trip Decoding
        final decoded = PacketEngine.decodePacket(encodedBytes);
        expect(decoded.packetId, equals(packet.packetId));
        expect(decoded.sourceNode, equals(packet.sourceNode));
        expect(decoded.priority, equals(packet.priority));
        expect(decoded.battery, equals(packet.battery));
        expect(decoded.adults, equals(packet.adults));
        expect(decoded.children, equals(packet.children));
        expect(decoded.payloadText, equals(packet.payloadText));

        // Test CRC Validation
        expect(PacketEngine.validatePacket(encodedBytes), isTrue);
      }
    });

    test('Single-Byte Corruption Detection', () {
      final packet = EmergencyPacket(
        packetId: 100,
        sourceNode: 0x12345678,
        timestamp: 1725490000,
        priority: TriagePriority.p0Critical,
        latitude: 18.5204,
        longitude: 73.8567,
        battery: 90,
        adults: 2,
        children: 1,
        payloadText: 'Test emergency message',
      );

      final validBytes = PacketEngine.encodePacket(packet);
      expect(PacketEngine.validatePacket(validBytes), isTrue);

      final corruptedBytes = PacketEngine.corruptByte(validBytes, 10);
      expect(PacketEngine.validatePacket(corruptedBytes), isFalse);
    });

    test('Hop Mutation Recalculates CRC', () {
      final packet = EmergencyPacket(
        packetId: 50,
        sourceNode: 0xABCDEF01,
        timestamp: 1725490000,
        ttl: 15,
        hops: 0,
        priority: TriagePriority.p1Medical,
        latitude: 18.5,
        longitude: 73.8,
        battery: 80,
        adults: 1,
        children: 0,
        payloadText: 'Medical assistance',
      );

      final origBytes = PacketEngine.encodePacket(packet);
      final mutatedBytes = PacketEngine.mutateHop(origBytes);

      final decodedMutated = PacketEngine.decodePacket(mutatedBytes);
      expect(decodedMutated.ttl, equals(14));
      expect(decodedMutated.hops, equals(1));
      expect(PacketEngine.validatePacket(mutatedBytes), isTrue);
    });
  });
}
