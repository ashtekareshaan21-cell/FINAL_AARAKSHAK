import 'package:flutter/material.dart';
import '../../../core/theme/atmosphere_theme.dart';
import '../../context_engine/risk_state.dart';

class AtmosphereBackground extends StatelessWidget {
  final RiskLevel riskLevel;
  final Widget child;

  const AtmosphereBackground({
    super.key,
    required this.riskLevel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AtmosphereTheme.getPaletteForRiskLevel(riskLevel);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: palette.backgroundGradient,
      ),
      child: Stack(
        children: [
          // Ambient Glow Circle
          Positioned(
            top: -60,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.glowColor,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
