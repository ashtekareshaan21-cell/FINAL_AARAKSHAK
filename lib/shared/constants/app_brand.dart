import 'package:flutter/material.dart';

class AppBrand {
  static const String name = 'Aarakshak';
  static const String tagline =
      'Emergency communication that survives unreliable networks.';
  static const String version = '1.0.0-PROTOTYPE';
  static const String protocolVersion = 'SOS_FRAME_V1';

  // Semantic Emergency Colors
  static const Color colorCritical = Color(0xFFEF4444); // P0 Red
  static const Color colorMedical = Color(0xFFF97316);  // P1 Orange
  static const Color colorNeeds = Color(0xFF3B82F6);    // P2 Blue
  static const Color colorSafe = Color(0xFF10B981);     // P3 Green
  static const Color colorNeutral = Color(0xFF6B7280);  // Gray

  // Dark Theme Accents
  static const Color bgDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color cardBorder = Color(0xFF334155);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentAmber = Color(0xFFF59E0B);
}

enum SubsystemCapability {
  real,
  simulated,
  cached,
  futureHardware,
  unavailable,
}

extension SubsystemCapabilityX on SubsystemCapability {
  String get label {
    switch (this) {
      case SubsystemCapability.real:
        return 'REAL';
      case SubsystemCapability.simulated:
        return 'SIMULATED';
      case SubsystemCapability.cached:
        return 'CACHED';
      case SubsystemCapability.futureHardware:
        return 'FUTURE HARDWARE';
      case SubsystemCapability.unavailable:
        return 'UNAVAILABLE';
    }
  }

  Color get color {
    switch (this) {
      case SubsystemCapability.real:
        return const Color(0xFF10B981); // Green
      case SubsystemCapability.simulated:
        return const Color(0xFF3B82F6); // Blue
      case SubsystemCapability.cached:
        return const Color(0xFFF59E0B); // Amber
      case SubsystemCapability.futureHardware:
        return const Color(0xFF8B5CF6); // Purple
      case SubsystemCapability.unavailable:
        return const Color(0xFF6B7280); // Gray
    }
  }
}
