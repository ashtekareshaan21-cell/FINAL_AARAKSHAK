import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../context_engine/context_providers.dart';
import '../location/location_provider.dart';
import '../map/offline_map_widget.dart';
import '../map/nasa_atmosphere_screen.dart';
import '../home/widgets/proximity_alert.dart';
import '../home/widgets/hazard_banner.dart';
import '../home/widgets/location_selector_modal.dart';

class DisasterRadarScreen extends ConsumerWidget {
  const DisasterRadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationStateProvider);
    final activeHazardsAsync = ref.watch(activeHazardsProvider);
    final sortedAssistanceAsync = ref.watch(sortedAssistanceProvider);
    final activeSos = ref.watch(sosControllerProvider);

    final bool isDemoLocation = location.isMockedOrFallback;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.radar_rounded, color: Colors.cyanAccent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'DISASTER RADAR & MAP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
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
            icon: const Icon(Icons.my_location_rounded, color: Colors.cyanAccent),
            tooltip: 'Change Test Sector Location',
            onPressed: () => LocationSelectorModal.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sector Location Header Bar
            InkWell(
              onTap: () => LocationSelectorModal.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: const Color(0xFF1E293B).withOpacity(0.8),
                child: Row(
                  children: [
                    Icon(
                      isDemoLocation ? Icons.science_rounded : Icons.location_on_rounded,
                      color: isDemoLocation ? Colors.orangeAccent : const Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SECTOR: ${location.label} (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDemoLocation ? Colors.orangeAccent : const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDemoLocation ? 'TEST PRESET' : 'GPS LIVE',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ),

            // Scrollable Map & Active Hazard Feed
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 0. NASA Satellite Atmosphere & Animated Winds Launcher Banner
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const NasaAtmosphereScreen()),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B132B)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.12),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.public_rounded, color: Colors.cyanAccent, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NASA SATELLITE & ATMOSPHERE OBSERVATORY',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Live VIIRS Clouds • Animated Wind Stream Vectors • EONET Events',
                                    style: TextStyle(fontSize: 9, color: Colors.cyanAccent),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.cyanAccent, size: 14),
                          ],
                        ),
                      ),
                    ),

                    // 1. Interactive Offline Map
                    activeHazardsAsync.maybeWhen(
                      data: (hazards) => sortedAssistanceAsync.maybeWhen(
                        data: (points) => OfflineMapWidget(
                          userLat: location.latitude,
                          userLng: location.longitude,
                          hazards: hazards,
                          assistancePoints: points,
                          activeSos: activeSos,
                        ),
                        orElse: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
                      ),
                      orElse: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
                    ),

                    const SizedBox(height: 16),

                    // 2. Critical Proximity Warning (Within 5 km)
                    activeHazardsAsync.maybeWhen(
                      data: (hazards) => ProximityAlert(
                        hazards: hazards,
                        userLat: location.latitude,
                        userLng: location.longitude,
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 12),

                    // 3. Geofenced Active Hazard Telemetry (25 km Discovery)
                    const Text(
                      'GEOFENCED ACTIVE HAZARDS (25 KM DISCOVERY)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    activeHazardsAsync.when(
                      data: (hazards) {
                        if (hazards.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF065F46).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '🟢 NO ACTIVE HAZARDS: Your sector is currently clear of severe weather or natural disaster threats.',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: hazards.map((h) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: HazardBanner(
                                hazard: h,
                                userLat: location.latitude,
                                userLng: location.longitude,
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                      error: (_, __) => const Text('Unable to load hazards.', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
