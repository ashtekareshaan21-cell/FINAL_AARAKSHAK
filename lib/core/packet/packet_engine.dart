import 'dart:convert';
import 'dart:typed_data';

enum TriagePriority { p0Critical, p1Medical, p2Needs, p3Safe }

class EmergencyPacket {
  final int magicByte;
  final int packetId;
  final int sourceNode;
  final int ttl;
  final int hops;
  final int timestamp;
  final TriagePriority priority;
  final double latitude;
  final double longitude;
  final int battery;
  final int adults;
  final int children;
  final String payloadText;
  final int crc;

  EmergencyPacket({
    this.magicByte = 0x52, // 'R'
    required this.packetId,
    required this.sourceNode,
    this.ttl = 15,
    this.hops = 0,
    required this.timestamp,
    required this.priority,
    required this.latitude,
    required this.longitude,
    required this.battery,
    required this.adults,
    required this.children,
    required this.payloadText,
    this.crc = 0,
  });

  String get logicalIdentity => '$sourceNode:$packetId';

  EmergencyPacket copyWith({
    int? ttl,
    int? hops,
    int? crc,
  }) {
    return EmergencyPacket(
      magicByte: magicByte,
      packetId: packetId,
      sourceNode: sourceNode,
      ttl: ttl ?? this.ttl,
      hops: hops ?? this.hops,
      timestamp: timestamp,
      priority: priority,
      latitude: latitude,
      longitude: longitude,
      battery: battery,
      adults: adults,
      children: children,
      payloadText: payloadText,
      crc: crc ?? this.crc,
    );
  }
}

class PacketEngine {
  static const int packetLength = 48;
  static const int magicByteValue = 0x52; // 'R'

  static int calculateCrc16(Uint8List bytes, [int length = 46]) {
    int crc = 0xFFFF;
    for (int i = 0; i < length; i++) {
      crc ^= (bytes[i] << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }

  static Uint8List encodePacket(EmergencyPacket packet) {
    final buffer = Uint8List(packetLength);
    final bdata = ByteData.view(buffer.buffer);

    // 0x00: Magic Byte (1 byte)
    bdata.setUint8(0, packet.magicByte);

    // 0x01: Packet ID (2 bytes, uint16, BigEndian)
    bdata.setUint16(1, packet.packetId & 0xFFFF, Endian.big);

    // 0x03: Source Node (4 bytes, uint32, BigEndian)
    bdata.setUint32(3, packet.sourceNode & 0xFFFFFFFF, Endian.big);

    // 0x07: Hop Metrics (1 byte: high 4 bits TTL, low 4 bits Hops)
    final ttlBounded = packet.ttl.clamp(0, 15);
    final hopsBounded = packet.hops.clamp(0, 15);
    bdata.setUint8(7, (ttlBounded << 4) | hopsBounded);

    // 0x08: Timestamp (4 bytes, uint32, BigEndian)
    bdata.setUint32(8, packet.timestamp & 0xFFFFFFFF, Endian.big);

    // 0x0C: Triage Priority (1 byte)
    bdata.setUint8(12, packet.priority.index);

    // 0x0D: Latitude (4 bytes, int32 BigEndian, degrees * 10^7)
    final latRaw = (packet.latitude * 1e7).round().clamp(-900000000, 900000000);
    bdata.setInt32(13, latRaw, Endian.big);

    // 0x11: Longitude (4 bytes, int32 BigEndian, degrees * 10^7)
    final lonRaw = (packet.longitude * 1e7).round().clamp(-1800000000, 1800000000);
    bdata.setInt32(17, lonRaw, Endian.big);

    // 0x15: Battery Status (1 byte: 0-100 or 255)
    bdata.setUint8(21, packet.battery.clamp(0, 255));

    // 0x16: Headcount (1 byte: high 4 bits Adults, low 4 bits Children)
    final adultsBounded = packet.adults.clamp(0, 15);
    final childrenBounded = packet.children.clamp(0, 15);
    bdata.setUint8(22, (adultsBounded << 4) | childrenBounded);

    // 0x17: Payload Text (23 bytes UTF-8 safely truncated)
    final payloadBytes = _truncateUtf8(packet.payloadText, 23);
    for (int i = 0; i < 23; i++) {
      buffer[23 + i] = i < payloadBytes.length ? payloadBytes[i] : 0;
    }

    // 0x2E: CRC-16 (2 bytes, BigEndian)
    final calculatedCrc = calculateCrc16(buffer, 46);
    bdata.setUint16(46, calculatedCrc, Endian.big);

    return buffer;
  }

  static EmergencyPacket decodePacket(Uint8List bytes) {
    if (bytes.length != packetLength) {
      throw ArgumentError('Invalid packet length: ${bytes.length} (expected $packetLength)');
    }

    final bdata = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

    final magic = bdata.getUint8(0);
    if (magic != magicByteValue) {
      throw FormatException('Invalid magic byte: 0x${magic.toRadixString(16)} (expected 0x52)');
    }

    final packetId = bdata.getUint16(1, Endian.big);
    final sourceNode = bdata.getUint32(3, Endian.big);

    final hopMetrics = bdata.getUint8(7);
    final ttl = (hopMetrics >> 4) & 0x0F;
    final hops = hopMetrics & 0x0F;

    final timestamp = bdata.getUint32(8, Endian.big);
    final priorityIdx = bdata.getUint8(12).clamp(0, 3);
    final priority = TriagePriority.values[priorityIdx];

    final latRaw = bdata.getInt32(13, Endian.big);
    final lonRaw = bdata.getInt32(17, Endian.big);
    final latitude = latRaw / 1e7;
    final longitude = lonRaw / 1e7;

    final battery = bdata.getUint8(21);
    final headcount = bdata.getUint8(22);
    final adults = (headcount >> 4) & 0x0F;
    final children = headcount & 0x0F;

    final payloadSlice = bytes.sublist(23, 46);
    int nullIdx = payloadSlice.indexOf(0);
    final validPayloadBytes = nullIdx >= 0 ? payloadSlice.sublist(0, nullIdx) : payloadSlice;
    final payloadText = utf8.decode(validPayloadBytes, allowMalformed: true);

    final crc = bdata.getUint16(46, Endian.big);

    return EmergencyPacket(
      magicByte: magic,
      packetId: packetId,
      sourceNode: sourceNode,
      ttl: ttl,
      hops: hops,
      timestamp: timestamp,
      priority: priority,
      latitude: latitude,
      longitude: longitude,
      battery: battery,
      adults: adults,
      children: children,
      payloadText: payloadText,
      crc: crc,
    );
  }

  static bool validatePacket(Uint8List bytes) {
    if (bytes.length != packetLength) return false;
    if (bytes[0] != magicByteValue) return false;

    final bdata = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    final storedCrc = bdata.getUint16(46, Endian.big);
    final calculatedCrc = calculateCrc16(bytes, 46);

    return storedCrc == calculatedCrc;
  }

  static Uint8List mutateHop(Uint8List bytes) {
    if (!validatePacket(bytes)) {
      throw FormatException('Cannot mutate invalid packet');
    }
    final buffer = Uint8List.fromList(bytes);
    final bdata = ByteData.view(buffer.buffer);

    final hopMetrics = bdata.getUint8(7);
    int ttl = (hopMetrics >> 4) & 0x0F;
    int hops = hopMetrics & 0x0F;

    if (ttl > 0) ttl -= 1;
    if (hops < 15) hops += 1;

    bdata.setUint8(7, (ttl << 4) | hops);

    // Recalculate CRC after mutation
    final newCrc = calculateCrc16(buffer, 46);
    bdata.setUint16(46, newCrc, Endian.big);

    return buffer;
  }

  static Uint8List corruptByte(Uint8List bytes, int index) {
    final copy = Uint8List.fromList(bytes);
    final targetIndex = index.clamp(0, packetLength - 1);
    copy[targetIndex] ^= 0xFF; // Flip all bits of the target byte
    return copy;
  }

  static String packetToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List hexToPacket(String hex) {
    final cleanHex = hex.replaceAll(' ', '').replaceAll('\n', '');
    if (cleanHex.length != packetLength * 2) {
      throw ArgumentError('Hex string length must be ${packetLength * 2} chars');
    }
    final result = Uint8List(packetLength);
    for (int i = 0; i < packetLength; i++) {
      result[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static List<int> _truncateUtf8(String str, int maxBytes) {
    final encoded = utf8.encode(str);
    if (encoded.length <= maxBytes) return encoded;

    // Boundary-safe UTF-8 truncation
    int cutIndex = maxBytes;
    while (cutIndex > 0 && (encoded[cutIndex] & 0xC0) == 0x80) {
      cutIndex--;
    }
    return encoded.sublist(0, cutIndex);
  }
}
