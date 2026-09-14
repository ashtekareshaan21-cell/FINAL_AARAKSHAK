import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/atmosphere_theme.dart';
import '../../core/constants/app_constants.dart';
import '../context_engine/context_providers.dart';
import '../context_engine/risk_state.dart';
import '../simulation/simulation_controller.dart';
import '../location/location_provider.dart';

import 'widgets/atmosphere_background.dart';
import 'widgets/risk_status_card.dart';
import 'widgets/proximity_alert.dart';
import 'widgets/assistance_list.dart';
import 'widgets/emergency_action_panel.dart';
import 'widgets/location_selector_modal.dart';
import 'widgets/weather_summary_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskStateAsync = ref.watch(riskStateProvider);
    final location = ref.watch(locationStateProvider);
    final weatherAsync = ref.watch(weatherStateProvider);
    final sortedAssistanceAsync = ref.watch(sortedAssistanceProvider);
    final activeHazardsAsync = ref.watch(activeHazardsProvider);
    final activeSos = ref.watch(sosControllerProvider);
    final simState = ref.watch(simulationProvider);

    final RiskState riskState = riskStateAsync.maybeWhen(
      data: (data) => data,
      orElse: () => RiskState.initial(),
    );

    final palette = AtmosphereTheme.getPaletteForRiskLevel(riskState.level);

    final bool isOnline = simState.isSimulationActive
        ? simState.networkStatus == NetworkStatus.online
        : true;

    return Scaffold(
      backgroundColor: palette.backgroundColor,
      body: AtmosphereBackground(
        riskLevel: riskState.level,
        child: SafeArea(
          child: Column(
            children: [
              // Header Bar with Location Selector Trigger
              _buildHeader(context, ref, location, riskState, simState, palette),

              // Scrollable Citizen Safety Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Current Risk Status Banner
                      RiskStatusCard(riskState: riskState),

                      const SizedBox(height: 14),

                      // 2. Live / Cached Weather Telemetry Card
                      weatherAsync.maybeWhen(
                        data: (weather) => WeatherSummaryCard(
                          weather: weather,
                          isOnline: isOnline,
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 14),

                      // 3. Proximity Warning Alert (Within 5 km)
                      activeHazardsAsync.maybeWhen(
                        data: (hazards) => ProximityAlert(
                          hazards: hazards,
                          userLat: location.latitude,
                          userLng: location.longitude,
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),

                      // 4. Hero Emergency Action Panel ([ SEND SOS ] Button)
                      EmergencyActionPanel(
                        activeSos: activeSos,
                        onTriggerSos: () {
                          ref.read(sosControllerProvider.notifier).triggerSos(
                                userLat: location.latitude,
                                userLng: location.longitude,
                              );
                        },
                        onCancelSos: () {
                          ref.read(sosControllerProvider.notifier).cancelSos();
                        },
                        onSimulateResponderAck: (sosId, msg) {
                          ref.read(sosControllerProvider.notifier).receiveResponderAck(sosId, msg);
                        },
                      ),

                      const SizedBox(height: 20),

                      // 5. Dynamic Nearby Emergency Assistance Points
                      const Text(
                        'NEARBY ASSISTANCE (DYNAMICALLY SORTED)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      sortedAssistanceAsync.when(
                        data: (points) => AssistanceList(points: points),
                        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                        error: (_, __) => const Text('Unable to load assistance points.', style: TextStyle(color: Colors.redAccent)),
                      ),

                      const SizedBox(height: 20),

                      // 6. Citizen Tools & Dedicated Testing Screen Shortcut
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emergency_share_rounded, color: Colors.redAccent, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DEDICATED CITIZEN TEST MODE',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Text(
                                    'Access isolated high-contrast SOS beacon tester.',
                                    style: TextStyle(fontSize: 10, color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => context.push('/victim'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text('OPEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header Bar with Interactive Location Selector
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    location,
    RiskState riskState,
    SimulationState simState,
    AtmospherePalette palette,
  ) {
    final String netStatusLabel = simState.isSimulationActive
        ? simState.networkStatus.name.toUpperCase()
        : 'ONLINE';

    final Color netColor = netStatusLabel == 'ONLINE'
        ? const Color(0xFF10B981)
        : netStatusLabel == 'MESHCONNECTED' || netStatusLabel == 'MESH ONLY'
            ? Colors.blueAccent
            : Colors.amber;

    final bool isDemoLocation = location.isMockedOrFallback;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.backgroundColor.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.redAccent, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  AppConstants.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Connectivity Status Badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: netColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: netColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    netStatusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Risk Status Badge
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.statusBadgeColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.accentColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          palette.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: palette.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Interactive Location Feed Bar
          InkWell(
            onTap: () => LocationSelectorModal.show(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDemoLocation ? Colors.orange.withOpacity(0.15) : const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDemoLocation ? Colors.orangeAccent.withOpacity(0.5) : const Color(0xFF10B981).withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDemoLocation ? Icons.science_rounded : Icons.radar_rounded,
                        color: isDemoLocation ? Colors.orangeAccent : const Color(0xFF10B981),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDemoLocation ? Colors.orangeAccent : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDemoLocation ? Colors.orangeAccent : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDemoLocation ? 'DEMO / TEST' : '📡 STREAMING LIVE',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${location.address} • (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
