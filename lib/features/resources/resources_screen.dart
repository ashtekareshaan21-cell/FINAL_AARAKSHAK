import 'package:flutter/material.dart';
import '../../shared/constants/app_brand.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final resources = [
      {'name': 'Regional Disaster Relief Camp #1', 'type': 'Shelter & Food', 'qty': '500 Beds', 'status': 'AVAILABLE'},
      {'name': 'District Emergency Hospital Ward', 'type': 'Medical / Trauma', 'qty': '12 ICU Beds', 'status': 'LIMITED'},
      {'name': 'NDRF Battalion Supply Depot', 'type': 'Clean Water & Rations', 'qty': '2,000 Kits', 'status': 'AVAILABLE'},
      {'name': 'Civil Defense Boat Squad Alpha', 'type': 'Rescue Boats', 'qty': '4 Inflatables', 'status': 'DEPLOYED'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('EMERGENCY RESOURCES & DIRECTORY'),
      ),
      body: resources.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No Resources Listed',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Regional disaster relief caches and NDRF supplies will appear here once connected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: resources.length,
              itemBuilder: (context, idx) {
                final res = resources[idx];
                final isAvailable = res['status'] == 'AVAILABLE';
                final isLimited = res['status'] == 'LIMITED';
                final badgeColor = isAvailable
                    ? AppBrand.colorSafe
                    : isLimited
                        ? AppBrand.accentAmber
                        : AppBrand.accentCyan;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppBrand.cardBorder,
                      child: Icon(Icons.inventory_2, color: AppBrand.accentCyan, size: 20),
                    ),
                    title: Text(res['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Type: ${res['type']!} • Quantity: ${res['qty']!}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        res['status']!,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
