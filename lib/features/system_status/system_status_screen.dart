import 'package:flutter/material.dart';
import '../../shared/constants/app_brand.dart';
import '../../data/repositories/incident_repository.dart';

class SystemStatusScreen extends StatelessWidget {
  const SystemStatusScreen({super.key});

  Future<void> _resetDemo(BuildContext context) async {
    final repo = IncidentRepository();
    await repo.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DEMO RESET COMPLETE: Database cleared & default mesh nodes restored.'),
          backgroundColor: AppBrand.accentCyan,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusList = [
      {'name': 'Flutter App Core', 'cap': SubsystemCapability.real, 'detail': 'Dart 3.13.2 / Flutter 3.47.2'},
      {'name': '48-Byte SOS_FRAME_V1 Engine', 'cap': SubsystemCapability.real, 'detail': 'CRC-16-CCITT Validated'},
      {'name': 'SQLite Database & Queue', 'cap': SubsystemCapability.real, 'detail': 'Persistent Storage Active'},
      {'name': 'Triage & NLP Engine', 'cap': SubsystemCapability.real, 'detail': 'Rule-Based Local Parsing'},
      {'name': 'FastAPI Command REST Server', 'cap': SubsystemCapability.real, 'detail': 'Local HTTP Endpoint Ready'},
      {'name': '50-Node Mesh Simulator', 'cap': SubsystemCapability.simulated, 'detail': 'Virtual BFS Routing Engine'},
      {'name': 'LoRa Narrowband Radio Model', 'cap': SubsystemCapability.simulated, 'detail': 'Virtual SF7 Channel Model'},
      {'name': 'Weather Context Provider', 'cap': SubsystemCapability.cached, 'detail': 'Open-Meteo Offline Cache'},
      {'name': 'NASA EONET Risk Feed', 'cap': SubsystemCapability.cached, 'detail': 'Environmental Event Cache'},
      {'name': 'ESP32 / SX1262 Hardware', 'cap': SubsystemCapability.futureHardware, 'detail': 'Future Transport Phase'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SYSTEM DIAGNOSTICS & STATUS'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SUBSYSTEM DIAGNOSTIC MATRIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 10),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: statusList.length,
              itemBuilder: (context, idx) {
                final item = statusList[idx];
                final cap = item['cap'] as SubsystemCapability;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(item['detail'] as String, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cap.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: cap.color),
                      ),
                      child: Text(cap.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cap.color)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Demo Reset Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _resetDemo(context),
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                label: const Text('RESET DEMO & CLEAR LOCAL DATABASE'),
                style: ElevatedButton.styleFrom(backgroundColor: AppBrand.colorCritical, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
