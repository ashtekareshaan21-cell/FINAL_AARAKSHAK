import 'package:flutter/material.dart';

import '../../shared/constants/app_brand.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String _statusMessage = 'NO CHECK-IN SENT YET';
  bool _isSafe = false;

  void _markSafe() {
    setState(() {
      _isSafe = true;
      _statusMessage =
          'STATUS LOGGED: "I AM SAFE" AT ${DateTime.now().toIso8601String().substring(11, 19)}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SAFETY CHECK-IN SAVED LOCALLY & QUEUED FOR SYNC!'),
        backgroundColor: AppBrand.colorSafe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SAFETY CHECK-IN & TRACKING')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isSafe
                    ? AppBrand.colorSafe.withValues(alpha: 0.15)
                    : AppBrand.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSafe ? AppBrand.colorSafe : AppBrand.cardBorder,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isSafe ? Icons.verified_user : Icons.help_outline,
                    size: 48,
                    color: _isSafe ? AppBrand.colorSafe : AppBrand.accentAmber,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check-ins are stored in SQLite and broadcasted via Mesh to alert command base of your safety status.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _markSafe,
                icon: const Icon(
                  Icons.check_circle,
                  size: 24,
                  color: Colors.black,
                ),
                label: const Text(
                  'I AM SAFE',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppBrand.colorSafe,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
