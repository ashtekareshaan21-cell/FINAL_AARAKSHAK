import 'package:flutter/material.dart';
import '../../features/context_engine/risk_state.dart';

/// Dynamic Atmosphere Theme model representing visual styling parameters for each Risk Level.
class AtmospherePalette {
  final Color backgroundColor;
  final Color cardColor;
  final Color accentColor;
  final Color textColor;
  final Color glowColor;
  final Color statusBadgeColor;
  final Gradient backgroundGradient;
  final String label;

  const AtmospherePalette({
    required this.backgroundColor,
    required this.cardColor,
    required this.accentColor,
    required this.textColor,
    required this.glowColor,
    required this.statusBadgeColor,
    required this.backgroundGradient,
    required this.label,
  });
}

class AtmosphereTheme {
  static const AtmospherePalette safePalette = AtmospherePalette(
    backgroundColor: Color(0xFF0F172A),
    cardColor: Color(0xFF1E293B),
    accentColor: Color(0xFF10B981), // Emerald Green
    textColor: Colors.white,
    glowColor: Color(0x3310B981),
    statusBadgeColor: Color(0xFF059669),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0F172A), Color(0xFF090D16)],
    ),
    label: 'SAFE',
  );

  static const AtmospherePalette warningPalette = AtmospherePalette(
    backgroundColor: Color(0xFF181510),
    cardColor: Color(0xFF262015),
    accentColor: Color(0xFFF59E0B), // Amber / Yellow
    textColor: Colors.white,
    glowColor: Color(0x44F59E0B),
    statusBadgeColor: Color(0xFFD97706),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF241B0D), Color(0xFF140F08)],
    ),
    label: 'WARNING',
  );

  static const AtmospherePalette dangerPalette = AtmospherePalette(
    backgroundColor: Color(0xFF1A0C0E),
    cardColor: Color(0xFF2E1317),
    accentColor: Color(0xFFEF4444), // Red / Crimson
    textColor: Colors.white,
    glowColor: Color(0x55EF4444),
    statusBadgeColor: Color(0xFFDC2626),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3B1115), Color(0xFF1A0A0C)],
    ),
    label: 'DANGER',
  );

  static const AtmospherePalette sosPalette = AtmospherePalette(
    backgroundColor: Color(0xFF2B0A0D),
    cardColor: Color(0xFF450A0A),
    accentColor: Color(0xFFFF2E4C), // Bright Emergency Red
    textColor: Colors.white,
    glowColor: Color(0x77FF2E4C),
    statusBadgeColor: Color(0xFF991B1B),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF50070B), Color(0xFF200305)],
    ),
    label: 'SOS CRITICAL',
  );

  static AtmospherePalette getPaletteForRiskLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return safePalette;
      case RiskLevel.warning:
        return warningPalette;
      case RiskLevel.danger:
        return dangerPalette;
      case RiskLevel.sos:
        return sosPalette;
    }
  }
}
