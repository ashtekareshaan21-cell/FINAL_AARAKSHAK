import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../location/location_provider.dart';

class LocationPresetItem {
  final String name;
  final double lat;
  final double lng;
  const LocationPresetItem(this.name, this.lat, this.lng);
}

const List<LocationPresetItem> kLocationPresets = [
  LocationPresetItem('📍 [TEST LOCATION] Swargate Sector', 18.52043, 73.85674),
  LocationPresetItem('📍 [TEST LOCATION] Shivajinagar Landmark', 18.5314, 73.8446),
  LocationPresetItem('📍 [TEST LOCATION] CSMT Station', 18.9400, 72.8353),
  LocationPresetItem('📍 [TEST LOCATION] Connaught Place', 28.6315, 77.2167),
  LocationPresetItem('📍 [TEST LOCATION] MG Road Station', 12.9756, 77.6066),
];

class LocationSelectorModal extends ConsumerStatefulWidget {
  const LocationSelectorModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const LocationSelectorModal(),
    );
  }

  @override
  ConsumerState<LocationSelectorModal> createState() => _LocationSelectorModalState();
}

class _LocationSelectorModalState extends ConsumerState<LocationSelectorModal> {
  late TextEditingController _latController;
  late TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    final currentLoc = ref.read(locationStateProvider);
    _latController = TextEditingController(text: currentLoc.latitude.toStringAsFixed(4));
    _lngController = TextEditingController(text: currentLoc.longitude.toStringAsFixed(4));
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = ref.watch(locationStateProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.edit_location_alt_rounded, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'LOCATION FEED & TEST SIMULATOR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const Text(
            'Use real device GPS, or pick a manual location. Manual locations are not live GPS and are flagged as such.',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 16),

          // 1. Real GPS Reset Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(locationStateProvider.notifier).refreshLocation();
                if (context.mounted) {
                  final loc = ref.read(locationStateProvider);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.isMockedOrFallback
                          ? '⚠️ GPS unavailable or permission denied'
                          : '🟢 Real Device GPS Restored: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}'),
                      backgroundColor: loc.isMockedOrFallback ? Colors.amber[800] : const Color(0xFF10B981),
                    ),
                  );
                }
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

          const SizedBox(height: 12),
          // Phase 0 safety: random test-location generation removed.
          // A random sector must never become the app location.

          const SizedBox(height: 16),
          const Text(
            'Preset Regional Landmarks:',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 3. Preset Locations List
          ...kLocationPresets.map((preset) {
            final isSelected = currentLocation.label == preset.name;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.cyan.withOpacity(0.2) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.cyanAccent : Colors.white10,
                ),
              ),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  preset.name,
                  style: TextStyle(
                    color: isSelected ? Colors.cyanAccent : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  '${preset.lat.toStringAsFixed(4)}, ${preset.lng.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent, size: 18)
                    : const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 18),
                onTap: () {
                  ref.read(locationStateProvider.notifier).setManualLocation(
                        preset.lat,
                        preset.lng,
                        label: preset.name,
                      );
                  Navigator.pop(context);
                },
              ),
            );
          }),

          const SizedBox(height: 12),
          const Text(
            'Custom Latitude / Longitude Input:',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 4. Custom Coordinates Inputs
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final lat = double.tryParse(_latController.text);
                  final lng = double.tryParse(_lngController.text);
                  if (lat != null && lng != null) {
                    ref.read(locationStateProvider.notifier).setManualLocation(
                          lat,
                          lng,
                          label: 'Custom (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})',
                        );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
