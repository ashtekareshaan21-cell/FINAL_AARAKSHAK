import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/main_navigation_shell.dart';
import '../features/home/home_screen.dart';
import '../features/victim/victim_screen.dart';
import '../features/command_center/command_screen.dart';
import '../features/mesh_simulator/mesh_sim_screen.dart';
import '../features/packet_inspector/packet_inspector_screen.dart';
import '../features/disaster_radar/disaster_radar_screen.dart';
import '../features/mesh_lab/mesh_lab_screen.dart';
import '../features/disaster_alerts/alerts_screen.dart';
import '../features/resources/resources_screen.dart';
import '../features/tracking/tracking_screen.dart';
import '../features/system_status/system_status_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MainNavigationShell(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/radar',
      builder: (context, state) => const DisasterRadarScreen(),
    ),
    GoRoute(
      path: '/mesh-lab',
      builder: (context, state) => const MeshLabScreen(),
    ),
    GoRoute(
      path: '/victim',
      builder: (context, state) => const VictimScreen(),
    ),
    GoRoute(
      path: '/command',
      builder: (context, state) => const CommandScreen(),
    ),
    GoRoute(
      path: '/mesh-sim',
      builder: (context, state) => const MeshSimScreen(),
    ),
    GoRoute(
      path: '/packet',
      builder: (context, state) => const PacketInspectorScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertsScreen(),
    ),
    GoRoute(
      path: '/resources',
      builder: (context, state) => const ResourcesScreen(),
    ),
    GoRoute(
      path: '/tracking',
      builder: (context, state) => const TrackingScreen(),
    ),
    GoRoute(
      path: '/system',
      builder: (context, state) => const SystemStatusScreen(),
    ),
  ],
);

