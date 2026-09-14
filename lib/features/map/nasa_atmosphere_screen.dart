import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../location/location_provider.dart';
import '../../core/weather/nasa_atmosphere_service.dart';
import '../../core/disaster/disaster_service.dart';
import 'nasa_atmosphere_map_widget.dart';
import '../home/widgets/location_selector_modal.dart';

class NasaAtmosphereScreen extends ConsumerStatefulWidget {
  const NasaAtmosphereScreen({super.key});

  @override
  ConsumerState<NasaAtmosphereScreen> createState() => _NasaAtmosphereScreenState();
}

class _NasaAtmosphereScreenState extends ConsumerState<NasaAtmosphereScreen> {
  late MapController _mapController;
  NasaGibsLayerType _activeLayer = NasaGibsLayerType.viirsTrueColor;
  DateTime _selectedDate = DateTime.now();
  double _cloudOpacity = 0.85;
  bool _showWindParticles = true;
  bool _showWindVectors = true;
  bool _showCloudOverlay = true;
  bool _showEonetEvents = true;

  AtmosphericTelemetry? _currentTelemetry;
  DisasterEvent? _selectedEvent;
  double _customLat = 18.5204;
  double _customLng = 73.8567;
  bool _hasCustomCenter = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _panToLocation(double lat, double lng) {
    setState(() {
      _customLat = lat;
      _customLng = lng;
      _hasCustomCenter = true;
    });
    _mapController.move(LatLng(lat, lng), 9.0);
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationStateProvider);
    final centerLat = _hasCustomCenter ? _customLat : location.latitude;
    final centerLng = _hasCustomCenter ? _customLng : location.longitude;

    return Scaffold(
      backgroundColor: const Color(0xFF070D1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.cyanAccent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.public_rounded, color: Colors.cyanAccent, size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'NASA ATMOSPHERE OBSERVATORY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              'GIBS Satellite Tiles • Dynamic Wind Particles • EONET Events',
              style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.cyanAccent),
            tooltip: 'Atmospheric Layers & Controls',
            onPressed: () => _showLayerControlsModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: Colors.cyanAccent),
            tooltip: 'Change Sector Location',
            onPressed: () => LocationSelectorModal.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Telemetry Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF0F172A).withOpacity(0.9),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'NASA GIBS LIVE LINK',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                  const Spacer(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSectorChip('GPS Location', location.latitude, location.longitude),
                        const SizedBox(width: 6),
                        _buildSectorChip('Primary Sector', 18.5204, 73.8567),
                        const SizedBox(width: 6),
                        _buildSectorChip('Mumbai Bay', 18.9667, 72.8333),
                        const SizedBox(width: 6),
                        _buildSectorChip('Bay of Bengal', 15.0000, 88.0000),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Map Viewport
            Expanded(
              child: Stack(
                children: [
                  NasaAtmosphereMapWidget(
                    centerLat: centerLat,
                    centerLng: centerLng,
                    activeLayer: _activeLayer,
                    selectedDate: _selectedDate,
                    cloudOpacity: _cloudOpacity,
                    showWindParticles: _showWindParticles,
                    showWindVectors: _showWindVectors,
                    showCloudOverlay: _showCloudOverlay,
                    showEonetEvents: _showEonetEvents,
                    mapHeight: double.infinity,
                    mapController: _mapController,
                    onTelemetryUpdated: (t) => setState(() => _currentTelemetry = t),
                    onEventSelected: (e) {
                      setState(() => _selectedEvent = e);
                      _showEventDetailsModal(context, e);
                    },
                  ),

                  // Floating Quick Layer Picker Button (Bottom Right)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'fab_layers',
                          backgroundColor: const Color(0xFF0F172A),
                          child: const Icon(Icons.layers_rounded, color: Colors.cyanAccent),
                          onPressed: () => _showLayerControlsModal(context),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'fab_wind',
                          backgroundColor: const Color(0xFF0F172A),
                          child: Icon(
                            _showWindParticles ? Icons.air_rounded : Icons.air_outlined,
                            color: _showWindParticles ? Colors.tealAccent : Colors.white38,
                          ),
                          onPressed: () {
                            setState(() => _showWindParticles = !_showWindParticles);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Telemetry Metrics HUD Bar
            if (_currentTelemetry != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Colors.cyanAccent.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    _buildHudMetric('WIND SPEED', '${_currentTelemetry!.windSpeedKmh.toStringAsFixed(1)} km/h', Icons.air_rounded, Colors.tealAccent),
                    _buildHudMetric('DIRECTION', '${_currentTelemetry!.windCardinal} (${_currentTelemetry!.windBearingDegrees.toInt()}°)', Icons.explore_rounded, Colors.cyanAccent),
                    _buildHudMetric('CLOUD COVER', '${_currentTelemetry!.cloudCoveragePercent}%', Icons.cloud_rounded, Colors.blueAccent),
                    _buildHudMetric('PRESSURE', '${_currentTelemetry!.barometricPressureHpa.toInt()} hPa', Icons.speed_rounded, Colors.orangeAccent),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorChip(String label, double lat, double lng) {
    final isSelected = (_customLat - lat).abs() < 0.01 && (_customLng - lng).abs() < 0.01;
    return InkWell(
      onTap: () => _panToLocation(lat, lng),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.cyanAccent : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildHudMetric(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showLayerControlsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.layers_rounded, color: Colors.cyanAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'NASA GIBS SATELLITE LAYERS',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),

                    // GIBS Tile Layer Selection
                    ...NasaAtmosphereService.layers.entries.map((entry) {
                      final meta = entry.value;
                      final isSelected = _activeLayer == meta.type;
                      return RadioListTile<NasaGibsLayerType>(
                        value: meta.type,
                        groupValue: _activeLayer,
                        activeColor: Colors.cyanAccent,
                        title: Text(meta.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Text(meta.description, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _activeLayer = val);
                            setModalState(() {});
                          }
                        },
                      );
                    }).toList(),

                    const SizedBox(height: 12),
                    const Text('ATMOSPHERIC OVERLAYS & SIMULATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      value: _showWindParticles,
                      activeColor: Colors.tealAccent,
                      title: const Text('Animated Wind Stream Particles', style: TextStyle(fontSize: 12, color: Colors.white)),
                      subtitle: const Text('Flowing vector particle field across map canvas', style: TextStyle(fontSize: 10, color: Colors.white54)),
                      onChanged: (val) {
                        setState(() => _showWindParticles = val);
                        setModalState(() {});
                      },
                    ),

                    SwitchListTile(
                      value: _showWindVectors,
                      activeColor: Colors.cyanAccent,
                      title: const Text('Wind Direction Arrow Grid', style: TextStyle(fontSize: 12, color: Colors.white)),
                      subtitle: const Text('Grid nodes displaying wind velocity & direction', style: TextStyle(fontSize: 10, color: Colors.white54)),
                      onChanged: (val) {
                        setState(() => _showWindVectors = val);
                        setModalState(() {});
                      },
                    ),

                    SwitchListTile(
                      value: _showEonetEvents,
                      activeColor: const Color(0xFFFF2E4C),
                      title: const Text('NASA EONET Disaster Pins', style: TextStyle(fontSize: 12, color: Colors.white)),
                      subtitle: const Text('Live tropical cyclones, wildfires, and floods', style: TextStyle(fontSize: 10, color: Colors.white54)),
                      onChanged: (val) {
                        setState(() => _showEonetEvents = val);
                        setModalState(() {});
                      },
                    ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Cloud Layer Opacity', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        Expanded(
                          child: Slider(
                            value: _cloudOpacity,
                            min: 0.1,
                            max: 1.0,
                            activeColor: Colors.cyanAccent,
                            onChanged: (val) {
                              setState(() => _cloudOpacity = val);
                              setModalState(() {});
                            },
                          ),
                        ),
                        Text('${(_cloudOpacity * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEventDetailsModal(BuildContext context, DisasterEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: event.severity == 'CRITICAL' ? const Color(0xFFFF2E4C) : Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('${event.category} • ${event.source}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildEventMetric('Latitude', event.latitude.toStringAsFixed(4)),
                    _buildEventMetric('Longitude', event.longitude.toStringAsFixed(4)),
                    _buildEventMetric('Reported', event.ageLabel),
                    _buildEventMetric('Severity', event.severity),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.center_focus_strong_rounded),
                label: const Text('PAN MAP TO EVENT CENTER', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  _panToLocation(event.latitude, event.longitude);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
