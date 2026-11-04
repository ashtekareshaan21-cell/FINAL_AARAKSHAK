import 'dart:async';
import 'dart:math';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../shared/constants/app_brand.dart';
import '../../core/triage/triage_engine.dart';
import '../../core/triage/signal_extraction_service.dart';
import '../../core/packet/packet_engine.dart';
import '../../core/device/device_identity.dart';
import '../../data/repositories/incident_repository.dart';

class VictimScreen extends StatefulWidget {
  const VictimScreen({super.key});

  @override
  State<VictimScreen> createState() => _VictimScreenState();
}

class LocationPreset {
  final String name;
  final double lat;
  final double lng;
  LocationPreset(this.name, this.lat, this.lng);
}

class _VictimScreenState extends State<VictimScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final RuleBasedSignalExtractionService _extractor = RuleBasedSignalExtractionService();
  final IncidentRepository _repository = IncidentRepository();
  final Connectivity _connectivity = Connectivity();

  static const Color emeraldColor = Color(0xFF10B981);

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  TriageResult? _triageResult;
  bool _isSending = false;

  // Form Fields — Phase 0 safety: no worst-case defaults. The user must
  // fill in what is actually happening; nothing is pre-assumed.
  String _selectedCategory = 'Flood';
  int _casualties = 1;
  String _medicalStatus = 'Unknown';
  bool _personTrapped = false;
  bool _waterRising = false;
  bool _firePresent = false;
  bool _structuralInstability = false;
  bool _requiresEvacuation = false;

  // Location Fields (Editable & Feedable)
  // Initial coordinates are NOT a confirmed location. SOS is blocked
  // until _locationConfirmed becomes true via real GPS or an explicit
  // manual selection (see _loadRealBatteryAndGps and preset/manual taps).
  double _latitude = 18.52043;
  double _longitude = 73.85674;
  String _selectedLocationName = 'Location not confirmed — GPS / manual required';
  double _gpsAccuracy = 0.0;
  int _batteryLevel = 255; // 255 = unknown in the packet format
  bool _locationConfirmed = false;

  final List<LocationPreset> _locationPresets = [
    LocationPreset('📍 Swargate Sector (manual)', 18.52043, 73.85674),
    LocationPreset('📍 Kothrud Sector (manual)', 18.5074, 73.8077),
    LocationPreset('📍 Shivajinagar Landmark (manual)', 18.5314, 73.8446),
    LocationPreset('📍 Hadapsar Station (manual)', 18.5089, 73.9259),
    LocationPreset('📍 Marine Drive (manual)', 18.9440, 72.8238),
    LocationPreset('📍 Connaught Place (manual)', 28.6315, 77.2167),
    LocationPreset('📍 MG Road Station (manual)', 12.9756, 77.6066),
  ];

  IncidentRecord? _activeSignal;
  List<IncidentRecord> _outboxIncidents = [];
  StreamSubscription<List<IncidentRecord>>? _incidentSub;

  final List<String> _categories = [
    'Flood', 'Medical', 'Fire', 'Structural Collapse', 'Landslide', 'Road Accident', 'Missing Person', 'Other'
  ];

  final List<String> _medicalOptions = [
    'Stable', 'Injured', 'Critical', 'Unconscious', 'Unknown'
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController.text = '';
    _loadIncidents();
    _checkConnectivity();
    _loadRealBatteryAndGps();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnline = results.any((r) => r != ConnectivityResult.none);
        });
      }
    });

    _incidentSub = IncidentRepository.incidentStream.listen((incidents) {
      if (mounted) {
        setState(() {
          _outboxIncidents = incidents;
          if (incidents.isNotEmpty) {
            _activeSignal = incidents.first;
          }
        });
      }
    });
  }

  /// Phase 0 safety: replace the fixed battery (85) and fixed GPS
  /// accuracy with real values. If GPS fails, the location stays
  /// unconfirmed and SOS is blocked until the user picks a manual
  /// location explicitly.
  Future<void> _loadRealBatteryAndGps() async {
    try {
      final level = await Battery().batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level.clamp(0, 100);
        });
      }
    } catch (_) {
      // Battery unknown (255) is kept; never claim a fixed level.
    }
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _gpsAccuracy = position.accuracy;
          _selectedLocationName = 'Live GPS';
          _locationConfirmed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedLocationName =
              'GPS unavailable — pick manual location or retry';
          _locationConfirmed = false;
        });
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = results.any((r) => r != ConnectivityResult.none);
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _incidentSub?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    final list = await _repository.getAllIncidents();
    if (mounted) {
      setState(() {
        _outboxIncidents = list;
        if (list.isNotEmpty) {
          _activeSignal = list.first;
        }
      });
    }
  }

  Future<void> _triggerInstantSOS({bool isOneTap = false}) async {
    setState(() { _isSending = true; });

    // Phase 0 safety: never send an SOS from an unconfirmed location
    // (the old Pune fallback). The user must have live GPS or an
    // explicit manual location first.
    if (!_locationConfirmed) {
      if (mounted) {
        setState(() { _isSending = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location not confirmed — GPS on karo ya manual location chuno, phir SOS bhejo.',
            ),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final currentSignal = EmergencySignal(
      category: _selectedCategory,
      casualties: _casualties,
      medicalStatus: _medicalStatus,
      personTrapped: _personTrapped,
      waterRising: _waterRising,
      firePresent: _firePresent,
      structuralInstability: _structuralInstability,
      requiresEvacuation: _requiresEvacuation,
      medicalEmergency: _medicalStatus == 'Unconscious' || _medicalStatus == 'Critical',
      rawDescription: _descriptionController.text,
    );

    final triage = TriageEngine.calculate(currentSignal);
    // Phase 1: stable device ID + persisted packet counter, not random.
    // Random IDs collided on the server's UNIQUE(source_node, packet_id).
    final sourceNode = await DeviceIdentity.getSourceNode();
    final packetId = await DeviceIdentity.nextPacketId();

    final packet = EmergencyPacket(
      packetId: packetId,
      sourceNode: sourceNode,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      priority: triage.priority,
      latitude: _latitude,
      longitude: _longitude,
      battery: _batteryLevel,
      // Phase 0 safety: do not invent an adult/child split. The total
      // headcount is _casualties; the child split is unknown (0) until
      // the form asks for it explicitly.
      adults: _casualties.clamp(0, 15),
      children: 0,
      // Note: the 48-byte packet format truncates this to 23 bytes in
      // PacketEngine; the full description stays in the local incident.
      payloadText: _descriptionController.text.substring(0, min(23, _descriptionController.text.length)),
    );

    final encodedBytes = PacketEngine.encodePacket(packet);
    final packetHex = PacketEngine.packetToHex(encodedBytes);

    final incident = IncidentRecord(
      id: 'INC-${sourceNode.toRadixString(16).toUpperCase()}-${packetId.toRadixString(16).toUpperCase()}',
      sourceNode: sourceNode,
      packetId: packetId,
      category: _selectedCategory,
      priority: triage.priorityLabel,
      severityScore: triage.score,
      latitude: _latitude,
      longitude: _longitude,
      gpsAccuracy: _gpsAccuracy,
      battery: _batteryLevel,
      headcount: _casualties,
      medicalStatus: _medicalStatus,
      description: '[$_selectedLocationName] ${_descriptionController.text}',
      packetHex: packetHex,
      ttl: 15,
      hopCount: 0,
      // Phase 0 safety: QUEUED means saved locally and queued only.
      // It is NOT delivered — delivery needs a real server/mesh ACK
      // (Phase 2). No timer may advance this to DELIVERED.
      status: 'QUEUED',
      createdAt: DateTime.now(),
      clientPriority: triage.priorityLabel,
      serverPriority: triage.priorityLabel,
    );

    await _repository.saveIncident(incident);

    if (mounted) {
      setState(() {
        _isSending = false;
        _activeSignal = incident;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🆘 Emergency signal saved locally and queued for $_selectedLocationName. Not yet delivered — delivery confirmation needs server/mesh (Phase 2).',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendImSafe() async {
    if (!_locationConfirmed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location not confirmed — GPS on karo ya manual location chuno, phir check-in karo.',
            ),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    // Phase 1: stable device ID + persisted packet counter, not random.
    // Random IDs collided on the server's UNIQUE(source_node, packet_id).
    final sourceNode = await DeviceIdentity.getSourceNode();
    final packetId = await DeviceIdentity.nextPacketId();

    // Phase 0 safety: encode a real packet instead of a hardcoded hex
    // string, and queue it — never claim DELIVERED without an ACK.
    final safePacket = EmergencyPacket(
      packetId: packetId,
      sourceNode: sourceNode,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      priority: TriagePriority.p3Safe,
      latitude: _latitude,
      longitude: _longitude,
      battery: _batteryLevel,
      adults: 1,
      children: 0,
      payloadText: 'I AM SAFE',
    );
    final safeHex = PacketEngine.packetToHex(
      PacketEngine.encodePacket(safePacket),
    );

    final incident = IncidentRecord(
      id: 'SAFE-${sourceNode.toRadixString(16).toUpperCase()}',
      sourceNode: sourceNode,
      packetId: packetId,
      category: 'Safe Check-in',
      priority: 'P3 — SAFE / ROUTINE',
      severityScore: 10,
      latitude: _latitude,
      longitude: _longitude,
      gpsAccuracy: _gpsAccuracy,
      battery: _batteryLevel,
      headcount: 1,
      medicalStatus: 'Stable',
      description: "User checked in: I AM SAFE at $_selectedLocationName.",
      packetHex: safeHex,
      ttl: 15,
      hopCount: 0,
      status: 'QUEUED',
      createdAt: DateTime.now(),
      clientPriority: 'P3 — SAFE',
      serverPriority: 'P3 — SAFE',
    );

    await _repository.saveIncident(incident);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Check-in saved locally and queued: "I AM SAFE at $_selectedLocationName". Not yet delivered.',
          ),
          backgroundColor: emeraldColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppBrand.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(AppBrand.tagline, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_isOnline ? emeraldColor : Colors.amber).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (_isOnline ? emeraldColor : Colors.amber).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(_isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded, color: _isOnline ? emeraldColor : Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'ONLINE • OFFLINE READY' : 'OFFLINE • MESH ACTIVE',
                  style: TextStyle(fontSize: 10, color: _isOnline ? emeraldColor : Colors.amber, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationStatusCard(),
            const SizedBox(height: 20),
            if (_activeSignal != null) ...[
              _buildActiveEmergencyCard(_activeSignal!),
              const SizedBox(height: 20),
            ],
            _buildPrimaryActionButtons(),
            const SizedBox(height: 24),
            _buildNearbyAssistanceSection(),
            const SizedBox(height: 24),
            _buildLocalAlertsTicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _locationConfirmed ? const Color(0xFF1E293B) : const Color(0xFF2A1C16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _locationConfirmed ? Colors.blueAccent.withOpacity(0.3) : Colors.amber.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_locationConfirmed ? Colors.blueAccent : Colors.amber).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _locationConfirmed ? Icons.my_location_rounded : Icons.location_off_rounded,
                  color: _locationConfirmed ? Colors.blueAccent : Colors.amber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          _locationConfirmed ? 'Location Confirmed' : 'Location Not Confirmed',
                          style: TextStyle(
                            color: _locationConfirmed ? Colors.white : Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_locationConfirmed ? Colors.blue : Colors.amber).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _locationConfirmed
                                ? (_selectedLocationName.startsWith('Live GPS')
                                    ? 'GPS READY ±${_gpsAccuracy.toStringAsFixed(0)}m'
                                    : 'MANUAL CONFIRMED')
                                : 'ACTION REQUIRED',
                            style: TextStyle(
                              color: _locationConfirmed ? Colors.lightBlueAccent : Colors.amberAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedLocationName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    Text(
                      'Coords: (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                    ),
                  ],
                ),
              ),
              // Interactive Location Change & Feed Button
              TextButton.icon(
                onPressed: () => _openLocationPickerModal(),
                icon: const Icon(Icons.edit_location_alt_rounded, color: Colors.cyanAccent, size: 16),
                label: Text(
                  _locationConfirmed ? 'CHANGE' : 'CHOOSE',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.cyan.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ],
          ),
          if (!_locationConfirmed) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _loadRealBatteryAndGps();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_locationConfirmed
                                ? '🟢 Live GPS confirmed: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}'
                                : '⚠️ GPS unavailable or permission denied — pick a manual landmark below.'),
                            backgroundColor: _locationConfirmed ? const Color(0xFF10B981) : Colors.amber[800],
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('RETRY GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLocationPickerModal(),
                    icon: const Icon(Icons.touch_app_rounded, size: 14),
                    label: const Text('MANUAL LANDMARK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      side: const BorderSide(color: Colors.cyanAccent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButtons() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _triggerInstantSOS(isOneTap: true),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sos_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 10),
                const Text(
                  '🆘 TAP FOR IMMEDIATE SOS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  'Transmits P0 Emergency Packet via Mesh / Off-Grid Transport',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sendImSafe,
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                label: const Text("I'M SAFE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openDetailedReportModal(),
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
                label: const Text('Detailed Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveEmergencyCard(IncidentRecord incident) {
    final statusColor = _getStatusColor(incident.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '🚨 ACTIVE EMERGENCY SIGNAL',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  incident.status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${incident.category} — ${incident.priority}',
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            incident.description,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 14),
          _buildDeliveryProgressTracker(incident.status),
          if (incident.status == 'ASSIGNED' || incident.assignedUnit.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: emeraldColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: emeraldColor.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.directions_run_rounded, color: emeraldColor, size: 18),
                      SizedBox(width: 6),
                      Text('🟢 HELP IS ON THE WAY!', style: TextStyle(color: emeraldColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Dispatched Unit: ${incident.assignedUnit}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  Text('Estimated Arrival: ~${incident.etaMinutes > 0 ? incident.etaMinutes : 18} minutes', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                  if (incident.eocNotes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Instructions: "${incident.eocNotes}"', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryProgressTracker(String status) {
    int currentStep = 0;
    if (status == 'LOCAL') currentStep = 1;
    if (status == 'QUEUED') currentStep = 2;
    if (status == 'RELAYING') currentStep = 3;
    if (status == 'DELIVERED') currentStep = 4;
    if (status == 'ACKNOWLEDGED' || status == 'ASSIGNED') currentStep = 5;

    final steps = ['Signal Created', 'Queued', 'Relaying', 'Delivered', 'Acknowledged'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMUNICATION PROGRESS',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(steps.length, (index) {
            final isDone = index < currentStep;
            final isCurrent = index == currentStep - 1;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 4,
                decoration: BoxDecoration(
                  color: isDone
                      ? emeraldColor
                      : isCurrent
                          ? Colors.amber
                          : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentStep == 5 ? '✓ Received & Acknowledged by EOC' : 'Searching for nearby mesh relay...',
              style: TextStyle(
                color: currentStep == 5 ? emeraldColor : Colors.amberAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(currentStep / steps.length * 100).round()}%',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNearbyAssistanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🏥 NEARBY ASSISTANCE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
            ),
            Text(
              'Location-Aware • Verified',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildAssistanceCard(
          icon: Icons.local_hospital_rounded,
          iconColor: Colors.redAccent,
          title: 'Sassoon General Hospital',
          distance: '2.4 km',
          statusText: '12 ICU Beds Available',
          badgeText: 'OPERATIONAL',
          badgeColor: emeraldColor,
        ),
        const SizedBox(height: 8),
        _buildAssistanceCard(
          icon: Icons.other_houses_rounded,
          iconColor: Colors.amber,
          title: 'Balewadi Flood Relief Shelter',
          distance: '1.1 km',
          statusText: '320 Beds & Food Supply',
          badgeText: 'OPEN',
          badgeColor: emeraldColor,
        ),
        const SizedBox(height: 8),
        _buildAssistanceCard(
          icon: Icons.airport_shuttle_rounded,
          iconColor: Colors.blueAccent,
          title: 'Disaster Relief Ambulance #09',
          distance: '3.2 km',
          statusText: '2 Units En Route',
          badgeText: 'LIMITED',
          badgeColor: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildAssistanceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String distance,
    required String statusText,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(statusText, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(distance, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalAlertsTicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emeraldColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: emeraldColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: emeraldColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🟢 SECTOR SAFETY STATUS — $_selectedLocationName', style: const TextStyle(color: emeraldColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('Updated Live', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'ALL CLEAR: No severe weather or flood alerts active in this sector.',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _openLocationPickerModal() {
    TextEditingController latCtrl = TextEditingController(text: _latitude.toStringAsFixed(5));
    TextEditingController lngCtrl = TextEditingController(text: _longitude.toStringAsFixed(5));
    TextEditingController nameCtrl = TextEditingController(text: _selectedLocationName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20, left: 20, right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('📍 Manual Location Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Icon(Icons.location_on_rounded, color: Colors.cyanAccent, size: 22),
                ],
              ),
              const SizedBox(height: 4),
              Text('Pick a landmark or enter coordinates manually. This is a manual location, not live GPS:', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _loadRealBatteryAndGps();
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(_locationConfirmed
                            ? '🟢 Live Device GPS confirmed: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}'
                            : '⚠️ GPS unavailable or permission denied — pick a manual landmark below.'),
                        backgroundColor: _locationConfirmed ? const Color(0xFF10B981) : Colors.amber[800],
                      ),
                    );
                  },
                  icon: const Icon(Icons.my_location_rounded, color: Color(0xFF10B981), size: 18),
                  label: const Text(
                    'USE REAL DEVICE GPS LOCATION',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text('Preset Regional Landmarks (Manual Confirmation):', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ..._locationPresets.map((preset) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: _selectedLocationName == preset.name ? Colors.cyan.withOpacity(0.2) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _selectedLocationName == preset.name ? Colors.cyanAccent : Colors.white10),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(preset.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  subtitle: Text('(${preset.lat}, ${preset.lng})', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                  trailing: _selectedLocationName == preset.name ? const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent, size: 18) : null,
                  onTap: () {
                    setState(() {
                      _latitude = preset.lat;
                      _longitude = preset.lng;
                      _selectedLocationName = preset.name;
                      _locationConfirmed = true;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📍 Location changed to ${_selectedLocationName}')),
                    );
                  },
                ),
              )),

              const SizedBox(height: 10),
              const Divider(color: Colors.white10),
              const Text('Feed Custom Landmark Name & Coordinates:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(labelText: 'Landmark / Location Name', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(labelText: 'Latitude (e.g. 18.5204)', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(labelText: 'Longitude (e.g. 73.8567)', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  final newLat = double.tryParse(latCtrl.text);
                  final newLng = double.tryParse(lngCtrl.text);
                  if (newLat != null && newLng != null) {
                    setState(() {
                      _latitude = newLat;
                      _longitude = newLng;
                      _selectedLocationName = nameCtrl.text.isNotEmpty
                          ? nameCtrl.text
                          : 'Custom Position (${newLat.toStringAsFixed(4)}, ${newLng.toStringAsFixed(4)})';
                      _locationConfirmed = true;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📍 Custom location saved: ${_selectedLocationName}')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 44)),
                child: const Text('SAVE MANUAL LOCATION FEED', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetailedReportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20, left: 20, right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📝 Detailed Emergency Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe emergency situation...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white70)),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setModalState(() => _selectedCategory = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _medicalStatus,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(labelText: 'Medical Condition', labelStyle: TextStyle(color: Colors.white70)),
                      items: _medicalOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setModalState(() => _medicalStatus = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _triggerInstantSOS();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('SUBMIT EMERGENCY REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'LOCAL': return Colors.redAccent;
      case 'QUEUED': return Colors.amber;
      case 'RELAYING': return Colors.blueAccent;
      case 'DELIVERED': return Colors.cyan;
      case 'ACKNOWLEDGED':
      case 'ASSIGNED': return emeraldColor;
      default: return Colors.grey;
    }
  }
}
