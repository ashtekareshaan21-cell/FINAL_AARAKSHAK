import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Phase 1 — stable device identity.
//
// The old code generated sourceNode as 0x12345678 + Random().nextInt(999)
// and packetId as Random().nextInt(65000) on every SOS. Two phones (or
// one phone twice) could collide, and the server enforces
// UNIQUE(source_node, packet_id), so a collision is a rejected SOS.
//
// Instead, one random ID is generated once per install and stored on
// disk. sourceNode is derived from it, so it is stable for this install
// and different on every other install. packetId is a persisted,
// monotonic counter for this device, so it never repeats while the
// install lives. A fresh install gets a new device ID, so its counter
// restarting at 1 cannot collide with the old install's packets.
class DeviceIdentity {
  static const String _idFileName = 'aarakshak_device_id.txt';
  static const String _counterFileName = 'aarakshak_packet_counter.txt';
  static String? _cachedId;

  static Future<Directory> _dir() async {
    return await getApplicationDocumentsDirectory();
  }

  static String _newId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;
    if (kIsWeb) {
      // Web has no app documents directory; a session-only ID is the
      // honest fallback, and it is never presented as a stable ID.
      _cachedId = _newId();
      return _cachedId!;
    }
    try {
      final file = File('${(await _dir()).path}/$_idFileName');
      if (await file.exists()) {
        final stored = (await file.readAsString()).trim();
        if (stored.isNotEmpty) {
          _cachedId = stored;
          return stored;
        }
      }
      final id = _newId();
      await file.writeAsString(id);
      _cachedId = id;
      return id;
    } catch (_) {
      _cachedId ??= _newId();
      return _cachedId!;
    }
  }

  // First 8 hex chars of the device ID, as a 32-bit node number.
  static Future<int> getSourceNode() async {
    final id = await getDeviceId();
    return int.parse(id.substring(0, 8), radix: 16);
  }

  // Persisted per-device counter, 1..65000, wrapping only after a full
  // cycle (at which point old packets are long past the server's
  // active window, and the sourceNode is still unique per install).
  static Future<int> nextPacketId() async {
    if (kIsWeb) {
      return (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 65000 + 1;
    }
    try {
      final file = File('${(await _dir()).path}/$_counterFileName');
      var current = 0;
      if (await file.exists()) {
        current = int.tryParse((await file.readAsString()).trim()) ?? 0;
      }
      final next = current >= 65000 ? 1 : current + 1;
      await file.writeAsString('$next');
      return next;
    } catch (_) {
      return (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 65000 + 1;
    }
  }
}
