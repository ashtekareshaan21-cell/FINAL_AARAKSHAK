import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/atmosphere_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/constants/app_brand.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isRefreshingAssistance = false;

  Future<void> _handleRefreshAssistance(LocationData location) async {
    if (_isRefreshingAssistance) return;
    setState(() => _isRefreshingAssistance = true);
    try {
      await ref.read(assistanceRepositoryProvider).refreshFromOverpass(
            userLat: location.latitude,
            userLng: location.longitude,
          );
      ref.invalidate(sortedAssistanceProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline Mode: Using cached verified facilities. Connect to internet for live OpenStreetMap Overpass queries.'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingAssistance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskStateAsync = ref.watch(riskStateProvider);
    final location = ref.watch(locationStateProvider);
    final weatherAsync = ref.watch(weatherStateProvider);
    final sortedAssistanceAsync = ref.watch(sortedAssistanceProvider);
    final activeHazardsAsync = ref.watch(activeHazardsProvider);
    final activeSos = ref.watch(sosControllerProvider);
    final simState = ref.watch(simulationProvider);
    final syncStatus = ref.watch(syncStatusMessageProvider).maybeWhen(
      data: (msg) => msg,
      orElse: () => ref.read(syncServiceProvider).syncStatusMessage,
    );

    final RiskState riskState = riskStateAsync.maybeWhen(
      data: (data) => data,
      orElse: () => RiskState.initial(),
    );

    final palette = AtmosphereTheme.getPaletteForRiskLevel(riskState.level);

    // Phase 1: real connectivity from connectivity_plus. While the
    // stream is still loading, fall back to "not online" rather than
    // claiming ONLINE. Simulation never creates an online state.
    final bool isOnline = ref.watch(isOnlineProvider).maybeWhen(
      data: (online) => online && !simState.isSimulationActive,
      orElse: () => false,
    );

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
                        syncStatusMessage: syncStatus,
                        onTriggerSos: () {
                          // Never send a Home SOS from an unconfirmed /
                          // fallback location. An explicit manual pick
                          // counts as confirmed (labelled MANUAL, never
                          // presented as live GPS).
                          if (!location.isConfirmedForUse) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Location not confirmed — GPS on karo ya manual location chuno, phir SOS bhejo.',
                                ),
                                backgroundColor: Colors.amber,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          ref.read(sosControllerProvider.notifier).triggerSos(
                                userLat: location.latitude,
                                userLng: location.longitude,
                              );
                        },
                        onCancelSos: () {
                          ref.read(sosControllerProvider.notifier).cancelSos();
                        },
                      ),

                      const SizedBox(height: 20),

                      // 5. Dynamic Nearby Emergency Assistance Points
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'NEARBY ASSISTANCE (OVERPASS)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isRefreshingAssistance
                                ? null
                                : () => _handleRefreshAssistance(location),
                            icon: _isRefreshingAssistance
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppBrand.accentCyan,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 14, color: AppBrand.accentCyan),
                            label: Text(
                              _isRefreshingAssistance ? 'Refreshing...' : 'Refresh',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppBrand.accentCyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      sortedAssistanceAsync.when(
                        data: (points) => AssistanceList(
                          points: points,
                          isRefreshing: _isRefreshingAssistance,
                          onRefresh: () => _handleRefreshAssistance(location),
                        ),
                        loading: () => Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppBrand.accentCyan),
                              ),
                              SizedBox(width: 10),
                              Text('Loading verified facilities...', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                        error: (_, _) => Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Unable to load assistance points.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 6. Citizen Tools & Dedicated Testing Screen Shortcut
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
    // Phase 0 safety: do not claim ONLINE. This badge only says whether
    // the app is in simulation mode; real connectivity is not asserted
    // here (a real connectivity provider is a Phase 1 follow-up).
    final String netStatusLabel = simState.isSimulationActive
        ? 'SIMULATION: ${simState.networkStatus.name.toUpperCase()}'
        : 'APP ACTIVE';

    final Color netColor = netStatusLabel == 'APP ACTIVE'
        ? const Color(0xFF10B981)
        : Colors.blueAccent;

    final bool isDemoLocation = location.isMockedOrFallback;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.backgroundColor.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: netColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: netColor.withValues(alpha: 0.5)),
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

              const SizedBox(width: 6),

              // Risk Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: palette.statusBadgeColor.withValues(alpha: 0.3),
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
                    Text(
                      palette.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: palette.textColor,
                      ),
                    ),
                  ],
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
                color: isDemoLocation ? Colors.orange.withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDemoLocation ? Colors.orangeAccent.withValues(alpha: 0.5) : const Color(0xFF10B981).withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDemoLocation ? Icons.warning_amber_rounded : Icons.radar_rounded,
                        color: isDemoLocation ? Colors.orangeAccent : const Color(0xFF10B981),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isDemoLocation ? '⚠️ Location Not Confirmed (Tap to set)' : location.label,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDemoLocation ? Colors.orangeAccent : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          location.isManualConfirmed
                              ? 'MANUAL'
                              : isDemoLocation
                                  ? 'TAP TO CONFIRM 📍'
                                  : '📡 STREAMING LIVE',
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
                          isDemoLocation
                              ? 'Tap here to enable Live GPS or pick a manual landmark'
                              : '${location.address} • (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})',
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
