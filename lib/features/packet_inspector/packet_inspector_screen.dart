import 'package:flutter/material.dart';
import '../../shared/constants/app_brand.dart';
import '../../core/packet/packet_engine.dart';

class PacketInspectorScreen extends StatefulWidget {
  const PacketInspectorScreen({super.key});

  @override
  State<PacketInspectorScreen> createState() => _PacketInspectorScreenState();
}

class _PacketInspectorScreenState extends State<PacketInspectorScreen> {
  final TextEditingController _hexController = TextEditingController();
  EmergencyPacket? _decodedPacket;
  bool _isCrcValid = false;
  int _corruptedIndex = -1;
  String _currentHex = '';

  @override
  void initState() {
    super.initState();
    _encodeSamplePacket();
  }

  void _encodeSamplePacket() {
    final sample = EmergencyPacket(
      packetId: 1,
      sourceNode: 0x12345678,
      ttl: 15,
      hops: 0,
      timestamp: 1725490176,
      priority: TriagePriority.p0Critical,
      latitude: 18.52043,
      longitude: 73.85674,
      battery: 85,
      adults: 4,
      children: 1,
      payloadText: 'Flood water rising fast',
    );

    final bytes = PacketEngine.encodePacket(sample);
    _updatePacketState(bytes);
  }

  void _updatePacketState(dynamic bytes) {
    final hex = PacketEngine.packetToHex(bytes);
    final valid = PacketEngine.validatePacket(bytes);
    EmergencyPacket? decoded;
    try {
      decoded = PacketEngine.decodePacket(bytes);
    } catch (_) {}

    setState(() {
      _currentHex = hex;
      _hexController.text = hex;
      _isCrcValid = valid;
      _decodedPacket = decoded;
    });
  }

  void _corruptByte() {
    final origBytes = PacketEngine.hexToPacket(_currentHex);
    final targetIdx = _corruptedIndex >= 0 ? (_corruptedIndex + 1) % 48 : 12;
    final corrupted = PacketEngine.corruptByte(origBytes, targetIdx);
    setState(() { _corruptedIndex = targetIdx; });
    _updatePacketState(corrupted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TECHNICAL PACKET INSPECTOR (SOS_FRAME_V1)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isCrcValid ? AppBrand.colorSafe.withOpacity(0.15) : AppBrand.colorCritical.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isCrcValid ? AppBrand.colorSafe : AppBrand.colorCritical),
              ),
              child: Row(
                children: [
                  Icon(_isCrcValid ? Icons.check_circle_outline : Icons.error_outline,
                      size: 32, color: _isCrcValid ? AppBrand.colorSafe : AppBrand.colorCritical),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCrcValid ? 'CHECKSUM VALID (CRC-16 MATCH)' : 'CHECKSUM INVALID — PACKET REJECTED!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _isCrcValid ? AppBrand.colorSafe : AppBrand.colorCritical,
                          ),
                        ),
                        Text(
                          _isCrcValid
                              ? 'CRC-16-CCITT integrity verification passed over all 46 payload bytes.'
                              : 'Bit corruption detected! Final 2-byte CRC checksum does not match decoded bytes.',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Controls Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _encodeSamplePacket,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('GENERATE CANONICAL FRAME'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppBrand.cardDark, foregroundColor: AppBrand.accentCyan),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _corruptByte,
                    icon: const Icon(Icons.flash_on, size: 16),
                    label: const Text('CORRUPT 1 BYTE'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppBrand.colorCritical, foregroundColor: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Hex Bytes Viewer
            const Text('RAW 48-BYTE HEXADECIMAL FRAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppBrand.cardBorder)),
              child: SelectableText(
                _currentHex.replaceAllMapped(RegExp(r".{2}"), (match) => "${match.group(0)} "),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 15, color: AppBrand.accentCyan, letterSpacing: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            // Decoded Fields Inspection Table
            if (_decodedPacket != null) ...[
              const Text('DECODED FIELD BREAKDOWN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70)),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: AppBrand.cardBorder, width: 1),
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2.0),
                  2: FlexColumnWidth(2.5),
                },
                children: [
                  _buildRow('Byte Offset', 'Field Name', 'Decoded Value', isHeader: true),
                  _buildRow('0x00 [1 B]', 'MAGIC_BYTE', '0x${_decodedPacket!.magicByte.toRadixString(16).toUpperCase()} ("R")'),
                  _buildRow('0x01 [2 B]', 'PACKET_ID', '${_decodedPacket!.packetId} (0x${_decodedPacket!.packetId.toRadixString(16)})'),
                  _buildRow('0x03 [4 B]', 'SOURCE_NODE', '0x${_decodedPacket!.sourceNode.toRadixString(16).toUpperCase()}'),
                  _buildRow('0x07 [1 B]', 'HOP_METRICS', 'TTL: ${_decodedPacket!.ttl} | Hops: ${_decodedPacket!.hops}'),
                  _buildRow('0x08 [4 B]', 'TIMESTAMP', '${_decodedPacket!.timestamp} (UTC Seconds)'),
                  _buildRow('0x0C [1 B]', 'TRIAGE_PRIORITY', '${_decodedPacket!.priority}'),
                  _buildRow('0x0D [4 B]', 'LATITUDE', '${_decodedPacket!.latitude} °'),
                  _buildRow('0x11 [4 B]', 'LONGITUDE', '${_decodedPacket!.longitude} °'),
                  _buildRow('0x15 [1 B]', 'BATTERY', '${_decodedPacket!.battery} %'),
                  _buildRow('0x16 [1 B]', 'HEADCOUNT', 'Adults: ${_decodedPacket!.adults} | Children: ${_decodedPacket!.children}'),
                  _buildRow('0x17 [23 B]', 'PAYLOAD_TEXT', '"${_decodedPacket!.payloadText}"'),
                  _buildRow('0x2E [2 B]', 'CRC-16-CCITT', '0x${_decodedPacket!.crc.toRadixString(16).toUpperCase()} [${_isCrcValid ? "VALID" : "INVALID"}]'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  TableRow _buildRow(String offset, String name, String val, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(color: isHeader ? AppBrand.cardDark : Colors.transparent),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(offset, style: TextStyle(fontSize: 10, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, color: AppBrand.accentCyan)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(name, style: TextStyle(fontSize: 10, fontWeight: isHeader ? FontWeight.bold : FontWeight.w600, color: Colors.white)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(val, style: TextStyle(fontSize: 10, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, color: Colors.white70)),
        ),
      ],
    );
  }
}
