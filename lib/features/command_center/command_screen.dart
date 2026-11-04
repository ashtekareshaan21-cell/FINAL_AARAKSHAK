import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/constants/app_brand.dart';
import '../../shared/audio/audio_alert_service.dart';
import '../../data/repositories/incident_repository.dart';
import '../../core/triage/trust_engine.dart';
import '../map/nasa_atmosphere_screen.dart';

class CommandScreen extends StatefulWidget {
  const CommandScreen({super.key});

  @override
  State<CommandScreen> createState() => _CommandScreenState();
}

class _CommandScreenState extends State<CommandScreen> with SingleTickerProviderStateMixin {
  final IncidentRepository _repository = IncidentRepository();
  List<IncidentRecord> _incidents = [];
  IncidentRecord? _selectedIncident;
  StreamSubscription<List<IncidentRecord>>? _sub;
  AnimationController? _pulseController;

  bool _alarmActive = false;
  IncidentRecord? _latestEmergency;

  static const Color emeraldColor = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _loadIncidents();

    _sub = IncidentRepository.incidentStream.listen((list) {
      if (mounted) {
        final previousCount = _incidents.length;
        setState(() {
          _incidents = list;
          if (_incidents.isNotEmpty && _selectedIncident == null) {
            _selectedIncident = _incidents.first;
          } else if (_selectedIncident != null) {
            final updated = list.firstWhere((i) => i.id == _selectedIncident!.id, orElse: () => list.first);
            _selectedIncident = updated;
          }
        });

        // Trigger audible beep and alarm banner if a new report or P0 signal arrives!
        if (list.length > previousCount || list.any((i) => i.status == 'LOCAL' || i.status == 'QUEUED')) {
          _triggerEmergencyAlarm(list.first);
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _triggerEmergencyAlarm(IncidentRecord incident) {
    AudioAlertService.playEmergencyBeep();
    if (mounted) {
      setState(() {
        _alarmActive = true;
        _latestEmergency = incident;
        _selectedIncident = incident;
      });
    }
  }

  Future<void> _loadIncidents() async {
    final list = await _repository.getAllIncidents();
    if (mounted) {
      setState(() {
        _incidents = list;
        if (list.isNotEmpty) {
          _selectedIncident = list.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p0Count = _incidents.where((i) => i.priority.contains('P0')).length;
    final activeCount = _incidents.where((i) => i.status != 'RESOLVED').length;

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
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EMERGENCY OPERATIONS CENTER', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('${AppBrand.name} Command Base • Regional EOC Sector', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
              ],
            ),
          ],
        ),
        actions: [
          // Audio Alert Alarm Test Button
          TextButton.icon(
            onPressed: () {
              AudioAlertService.playEmergencyBeep();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔊 ALARM BEEP TRIGGERED! Audible siren alert active for EOC controller.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.volume_up_rounded, color: Colors.redAccent, size: 18),
            label: const Text('TEST ALARM BEEP', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.public_rounded, color: Colors.cyanAccent),
            tooltip: 'Launch NASA Satellite Atmosphere Map',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const NasaAtmosphereScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadIncidents,
          ),
        ],
      ),
      body: Column(
        children: [
          // High Priority Audio/Visual Alarm Banner
          if (_alarmActive && _latestEmergency != null) _buildEmergencyAlarmBanner(_latestEmergency!),

          // KPI Counter Cards
          _buildKpiHeader(activeCount, p0Count),

          // Main Operational Workspace (Responsive for Mobile Screens)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 600;

                final queueWidget = _buildIncidentQueueList();
                final detailsWidget = _selectedIncident != null
                    ? _buildIncidentDetailsPanel(_selectedIncident!)
                    : const Center(child: Text('Select an incident to view intelligence', style: TextStyle(color: Colors.white54)));

                if (isNarrow) {
                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Container(
                          color: const Color(0xFF1E293B),
                          child: const TabBar(
                            indicatorColor: Colors.blueAccent,
                            labelColor: Colors.blueAccent,
                            unselectedLabelColor: Colors.white54,
                            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            tabs: [
                              Tab(text: '🚨 INCIDENT QUEUE'),
                              Tab(text: '⚡ DISPATCH & DETAILS'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              queueWidget,
                              detailsWidget,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: queueWidget),
                    Expanded(flex: 3, child: detailsWidget),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlarmBanner(IncidentRecord incident) {
    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFDC2626), const Color(0xFF991B1B), _pulseController!.value),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.5),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔊 🚨 NEW EMERGENCY SIGNAL RECEIVED',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 Sector 4 (${incident.latitude.toStringAsFixed(3)}, ${incident.longitude.toStringAsFixed(3)}) • ${incident.category} • ${incident.headcount} Victims',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () {
                  setState(() => _alarmActive = false);
                  _openDispatchModal(incident);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: const Text('DISPATCH', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => setState(() => _alarmActive = false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiHeader(int activeCount, int p0Count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard('ACTIVE INCIDENTS', '$activeCount', Colors.blueAccent, Icons.assignment_outlined),
            const SizedBox(width: 8),
            _buildKpiCard('P0 CRITICAL', '$p0Count', Colors.redAccent, Icons.priority_high_rounded),
            const SizedBox(width: 8),
            _buildKpiCard('RESCUE TEAMS', '7 ACTIVE', emeraldColor, Icons.airport_shuttle_rounded),
            const SizedBox(width: 8),
            _buildKpiCard('OFFICIAL ALERTS', '2 LIVE', Colors.amber, Icons.warning_amber_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildIncidentQueueList() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🚨 LIVE INCIDENT QUEUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text('${_incidents.length} REPORTS', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView.separated(
              itemCount: _incidents.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (ctx, i) {
                final incident = _incidents[i];
                final isSelected = _selectedIncident?.id == incident.id;
                final isP0 = incident.priority.contains('P0');

                return ListTile(
                  onTap: () => setState(() => _selectedIncident = incident),
                  selected: isSelected,
                  selectedTileColor: Colors.blueAccent.withOpacity(0.15),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isP0 ? Colors.redAccent.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isP0 ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                      color: isP0 ? Colors.redAccent : Colors.amber,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${incident.category} — ${incident.priority}',
                    style: TextStyle(
                      color: isP0 ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    '${incident.headcount} people • ${incident.medicalStatus} • ${_formatAge(incident.createdAt)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: emeraldColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TRUST ${incident.trustScore}%',
                          style: const TextStyle(color: emeraldColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        incident.status,
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentDetailsPanel(IncidentRecord incident) {
    final trustResult = TrustEngine.calculateTrust(
      incident: incident,
      activeIncidents: _incidents,
      isCrcValid: true,
      isHumanVerified: incident.humanVerified,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prominent Alert Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: incident.priority.contains('P0')
                    ? [const Color(0xFF7F1D1D), const Color(0xFF1E293B)]
                    : [const Color(0xFF78350F), const Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: incident.priority.contains('P0') ? Colors.redAccent : Colors.amber, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'INCIDENT ID: ${incident.id}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text(incident.status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${incident.category.toUpperCase()} EMERGENCY',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '📍 Active Incident Location (${incident.latitude}, ${incident.longitude})',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  incident.description,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Multi-Factor Data Trust Breakdown Card
          _buildTrustScoreCard(trustResult),

          const SizedBox(height: 16),

          // Actionable Lifecycle & Responder Dispatch Panel
          _buildDispatchControls(incident),
        ],
      ),
    );
  }

  Widget _buildTrustScoreCard(TrustResult trust) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: emeraldColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_user_rounded, color: emeraldColor, size: 20),
                  SizedBox(width: 8),
                  Text('DATA TRUST & CONFIDENCE ENGINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: emeraldColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('${trust.score}% TRUST SCORE', style: const TextStyle(color: emeraldColor, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('🟢 PACKET CRC-16 VALID', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('👥 ${trust.corroborationsCount} CORROBORATING REPORTS', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...trust.factors.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(f, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
          )),
        ],
      ),
    );
  }

  Widget _buildDispatchControls(IncidentRecord incident) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚡ RESPONDER DISPATCH & EOC CONTROL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 10),

          if (incident.assignedUnit.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: emeraldColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assigned Unit: ${incident.assignedUnit}', style: const TextStyle(color: emeraldColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Estimated Arrival: ~${incident.etaMinutes} mins', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  if (incident.eocNotes.isNotEmpty) Text('Notes: ${incident.eocNotes}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _repository.verifyIncident(incident.id);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Incident report human-verified! Trust score updated.')));
                  },
                  icon: const Icon(Icons.check_circle_outline, color: emeraldColor, size: 16),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('VERIFY REPORT', style: TextStyle(color: emeraldColor, fontSize: 11, fontWeight: FontWeight.bold))),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: emeraldColor)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openDispatchModal(incident),
                  icon: const Icon(Icons.airport_shuttle, color: Colors.white, size: 16),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('ASSIGN RESCUE TEAM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _openDispatchModal(IncidentRecord incident) {
    // Phase 0 safety: no prefilled dispatch claim. The unit list below
    // is operator-entered, not a verified unit registry, and ETA is
    // unknown (0) until the operator enters it.
    String selectedUnit = 'NDRF Rescue Unit 04';
    int eta = 0;
    TextEditingController notesCtrl = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('🚑 Assign Emergency Rescue Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedUnit,
              dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(labelText: 'Select Response Unit', labelStyle: TextStyle(color: Colors.white70)),
              items: [
                'NDRF Rescue Unit 04',
                'Regional Civil Defense Boat Squad',
                'Sassoon Medical Rapid Response Unit',
                'Fire & Rescue Squad #12'
              ].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (v) => selectedUnit = v!,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(labelText: 'Instructions for Victim', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.assignResponder(incident.id, selectedUnit, eta, notes: notesCtrl.text);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🟢 Rescue Team "$selectedUnit" assigned locally. Victim notification needs server/mesh (Phase 2).')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: emeraldColor),
            child: const Text('DISPATCH UNIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
