import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../hazards/hazard_model.dart';
import '../assistance/assistance_model.dart';
import '../sos/sos_packet.dart';

class OfflineMapWidget extends StatelessWidget {
  final double userLat;
  final double userLng;
  final List<Hazard> hazards;
  final List<AssistancePoint> assistancePoints;
  final SosPacket? activeSos;

  const OfflineMapWidget({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.hazards,
    required this.assistancePoints,
    this.activeSos,
  });

  @override
  Widget build(BuildContext context) {
    final userCenter = LatLng(userLat, userLng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FlutterMap(
          options: MapOptions(initialCenter: userCenter, initialZoom: 12.5),
          children: [
            // Tile layer with offline grid fallback styling
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.resqmesh.ai',
              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,
                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,
                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
                  child: tileWidget,
                );
              },
            ),

            // Proximity Zones (5km Critical Red Circle & 25km Amber Discovery Circle)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: userCenter,
                  radius: 5000, // 5 km
                  useRadiusInMeter: true,
                  color: Colors.red.withValues(alpha: 0.15),
                  borderColor: Colors.redAccent,
                  borderStrokeWidth: 1.5,
                ),
                CircleMarker(
                  point: userCenter,
                  radius: 25000, // 25 km
                  useRadiusInMeter: true,
                  color: Colors.amber.withValues(alpha: 0.05),
                  borderColor: Colors.amber.withValues(alpha: 0.6),
                  borderStrokeWidth: 1.0,
                ),
              ],
            ),

            // Markers Layer (User GPS, Hazards, Assistance Points, Active SOS)
            MarkerLayer(
              markers: [
                // User Marker
                Marker(
                  point: userCenter,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.blue,
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),

                // Hazard Markers
                ...hazards.map((h) {
                  final isCritical = h.severity >= 0.8;
                  return Marker(
                    point: LatLng(h.latitude, h.longitude),
                    width: 30,
                    height: 30,
                    child: Tooltip(
                      message:
                          '${h.title} (${(h.severity * 100).toInt()}% severity)',
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCritical ? Colors.redAccent : Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Icon(
                          isCritical
                              ? Icons.warning_rounded
                              : Icons.report_problem_rounded,
                          color: Colors.black,
                          size: 16,
                        ),
                      ),
                    ),
                  );
                }),

                // Assistance Point Markers
                ...assistancePoints.map((p) {
                  return Marker(
                    point: LatLng(p.latitude, p.longitude),
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  );
                }),

                // Active SOS Marker
                if (activeSos != null)
                  Marker(
                    point: LatLng(activeSos!.latitude, activeSos!.longitude),
                    width: 42,
                    height: 42,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2E4C),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFFF2E4C),
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emergency_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
