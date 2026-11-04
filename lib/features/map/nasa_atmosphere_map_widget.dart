import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/weather/nasa_atmosphere_service.dart';
import '../../core/disaster/disaster_service.dart';
import 'widgets/animated_wind_vector_painter.dart';

class NasaAtmosphereMapWidget extends StatefulWidget {
  final double centerLat;
  final double centerLng;
  final NasaGibsLayerType activeLayer;
  final DateTime selectedDate;
  final double cloudOpacity;
  final bool showWindParticles;
  final bool showWindVectors;
  final bool showCloudOverlay;
  final bool showEonetEvents;
  final double mapHeight;
  final MapController? mapController;
  final Function(AtmosphericTelemetry)? onTelemetryUpdated;
  final Function(DisasterEvent)? onEventSelected;

  const NasaAtmosphereMapWidget({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.activeLayer = NasaGibsLayerType.viirsTrueColor,
    required this.selectedDate,
    this.cloudOpacity = 0.8,
    this.showWindParticles = true,
    this.showWindVectors = true,
    this.showCloudOverlay = true,
    this.showEonetEvents = true,
    this.mapHeight = 450,
    this.mapController,
    this.onTelemetryUpdated,
    this.onEventSelected,
  });

  @override
  State<NasaAtmosphereMapWidget> createState() => _NasaAtmosphereMapWidgetState();
}

class _NasaAtmosphereMapWidgetState extends State<NasaAtmosphereMapWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<WindParticle> _particles;
  AtmosphericTelemetry? _telemetry;
  List<DisasterEvent> _eonetEvents = [];
  bool _isLoadingEonet = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initParticles();
    _loadAtmosphericData();
    _loadEonetEvents();
  }

  void _initParticles() {
    final rand = math.Random();
    _particles = List.generate(45, (i) {
      return WindParticle(
        x: rand.nextDouble() * 400,
        y: rand.nextDouble() * 400,
        speed: 1.2 + rand.nextDouble() * 2.8,
        life: rand.nextDouble() * 2.0,
        maxLife: 2.0 + rand.nextDouble() * 2.0,
        size: 1.5 + rand.nextDouble() * 1.5,
      );
    });
  }

  @override
  void didUpdateWidget(covariant NasaAtmosphereMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.centerLat != widget.centerLat || oldWidget.centerLng != widget.centerLng) {
      _loadAtmosphericData();
    }
  }

  Future<void> _loadAtmosphericData() async {
    final telemetry = await NasaAtmosphereService.fetchAtmosphericTelemetry(
      latitude: widget.centerLat,
      longitude: widget.centerLng,
    );
    if (mounted) {
      setState(() => _telemetry = telemetry);
      if (telemetry != null) {
        widget.onTelemetryUpdated?.call(telemetry);
      }
    }
  }

  Future<void> _loadEonetEvents() async {
    setState(() => _isLoadingEonet = true);
    final service = NasaEonetDisasterService();
    final events = await service.getEvents();
    if (mounted) {
      setState(() {
        _eonetEvents = events;
        _isLoadingEonet = false;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.centerLat, widget.centerLng);
    final tileUrl = NasaAtmosphereService.getGibsTileUrl(
      layerType: widget.activeLayer,
      date: widget.selectedDate,
    );

    final isDarkBase = widget.activeLayer == NasaGibsLayerType.darkTactical;

    return Container(
      height: widget.mapHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // 1. FlutterMap with NASA GIBS Tile Layer
            FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 7.5,
                minZoom: 3,
                maxZoom: 14,
              ),
              children: [
                // Base Dark Tile Layer (if using NASA GIBS transparent layers)
                if (!isDarkBase)
                  TileLayer(
                    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.resqmesh.ai',
                  ),

                // Primary NASA GIBS Satellite / Radar Tile Layer
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.resqmesh.ai',
                  tileBuilder: (context, tileWidget, tile) {
                    if (isDarkBase) return tileWidget;
                    return Opacity(
                      opacity: widget.cloudOpacity.clamp(0.2, 1.0),
                      child: tileWidget,
                    );
                  },
                ),

                // Proximity Radar Circles
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: 25000, // 25 km
                      useRadiusInMeter: true,
                      color: Colors.cyanAccent.withOpacity(0.06),
                      borderColor: Colors.cyanAccent.withOpacity(0.6),
                      borderStrokeWidth: 1.5,
                    ),
                    CircleMarker(
                      point: center,
                      radius: 75000, // 75 km regional storm radius
                      useRadiusInMeter: true,
                      color: Colors.orange.withOpacity(0.03),
                      borderColor: Colors.orangeAccent.withOpacity(0.4),
                      borderStrokeWidth: 1.0,
                    ),
                  ],
                ),

                // NASA EONET Active Severe Weather Event Markers
                if (widget.showEonetEvents)
                  MarkerLayer(
                    markers: _eonetEvents.map((event) {
                      final isCritical = event.severity == 'CRITICAL';
                      return Marker(
                        point: LatLng(event.latitude, event.longitude),
                        width: 38,
                        height: 38,
                        child: GestureDetector(
                          onTap: () => widget.onEventSelected?.call(event),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCritical ? const Color(0xFFFF2E4C) : Colors.orangeAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: isCritical ? const Color(0xFFFF2E4C) : Colors.orangeAccent,
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getEventIcon(event.category),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                // User / Target GPS Center Marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFF10B981), blurRadius: 12, spreadRadius: 3),
                          ],
                        ),
                        child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. Animated Wind Particle Streamlines Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: AnimatedWindVectorPainter(
                        animationValue: _animController.value,
                        windSpeedKmh: _telemetry?.windSpeedKmh ?? 22.0,
                        windBearingDegrees: _telemetry?.windBearingDegrees ?? 145.0,
                        cloudCoveragePercent: _telemetry?.cloudCoveragePercent ?? 65,
                        cloudOpacity: widget.cloudOpacity,
                        showWindParticles: widget.showWindParticles,
                        showWindVectors: widget.showWindVectors,
                        showCloudOverlay: widget.showCloudOverlay,
                        particles: _particles,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. Top NASA Observatory Header Overlay
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Active Layer Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.cyanAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          NasaAtmosphereService.layers[widget.activeLayer]!.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Wind Telemetry Quick Pill
                  if (_telemetry != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.air_rounded, color: Colors.tealAccent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${_telemetry!.windSpeedKmh.toStringAsFixed(1)} km/h ${_telemetry!.windCardinal}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.tealAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Loading Spinner for EONET events
            if (_isLoadingEonet)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getEventIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('storm') || cat.contains('cyclone') || cat.contains('hurricane')) {
      return Icons.cyclone_rounded;
    }
    if (cat.contains('wildfire') || cat.contains('fire')) {
      return Icons.local_fire_department_rounded;
    }
    if (cat.contains('flood') || cat.contains('water')) {
      return Icons.flood_rounded;
    }
    if (cat.contains('volcano')) {
      return Icons.volcano_rounded;
    }
    return Icons.warning_amber_rounded;
  }
}
