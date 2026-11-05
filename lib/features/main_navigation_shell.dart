import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'disaster_radar/disaster_radar_screen.dart';
import 'command_center/command_screen.dart';
import 'disaster_alerts/alerts_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    DisasterRadarScreen(),
    CommandScreen(),
    AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF1E293B),
          selectedItemColor: _getSelectedColor(_currentIndex),
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_rounded),
              activeIcon: Icon(Icons.shield_rounded, size: 24),
              label: 'Safety Hub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.radar_rounded),
              activeIcon: Icon(Icons.radar_rounded, size: 24),
              label: 'Radar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_rounded),
              activeIcon: Icon(Icons.admin_panel_settings_rounded, size: 24),
              label: 'EOC Command',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.feed_rounded),
              activeIcon: Icon(Icons.feed_rounded, size: 24),
              label: 'Live Alerts',
            ),
          ],
        ),
      ),
    );
  }

  Color _getSelectedColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF10B981); // Emerald
      case 1:
        return Colors.cyanAccent;
      case 2:
        return Colors.blueAccent;
      case 3:
        return Colors.amberAccent;
      default:
        return const Color(0xFF10B981);
    }
  }
}
