import 'package:flutter/material.dart';

import '../../../core/theme/atmosphere_theme.dart';
import '../../context_engine/risk_state.dart';

class RiskStatusCard extends StatelessWidget {
  final RiskState riskState;

  const RiskStatusCard({super.key, required this.riskState});

  @override
  Widget build(BuildContext context) {
    final palette = AtmosphereTheme.getPaletteForRiskLevel(riskState.level);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.accentColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: palette.glowColor, blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CURRENT SAFETY STATE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: palette.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: palette.statusBadgeColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.accentColor, width: 1),
                ),
                child: Text(
                  palette.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: palette.textColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                riskState.score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: palette.accentColor,
                  height: 1.0,
                ),
              ),
              const Text(
                ' / 100',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'CONFIDENCE',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    (riskState.confidence <= 0 ||
                            riskState.primaryHazard == 'No Active Hazards Nearby' ||
                            riskState.primaryHazard == null)
                        ? '--'
                        : '${(riskState.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: palette.accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  riskState.primaryHazard ?? 'No Active Hazards Nearby',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
