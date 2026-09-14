import '../packet/packet_engine.dart';

class EmergencySignal {
  final String category;
  final int casualties;
  final String medicalStatus; // Stable, Injured, Critical, Unconscious, Unknown
  final bool personTrapped;
  final bool waterRising;
  final bool firePresent;
  final bool structuralInstability;
  final bool requiresEvacuation;
  final bool medicalEmergency;
  final String rawDescription;

  EmergencySignal({
    required this.category,
    required this.casualties,
    required this.medicalStatus,
    required this.personTrapped,
    required this.waterRising,
    required this.firePresent,
    required this.structuralInstability,
    required this.requiresEvacuation,
    required this.medicalEmergency,
    required this.rawDescription,
  });
}

class TriageResult {
  final TriagePriority priority;
  final int score;
  final List<String> reasons;
  final String disclaimer;

  TriageResult({
    required this.priority,
    required this.score,
    required this.reasons,
    this.disclaimer =
        'PROTOTYPE DECISION SUPPORT - NOT OFFICIAL MEDICAL TRIAGE - RESPONDER JUDGMENT TAKES PRECEDENCE',
  });

  String get priorityLabel {
    switch (priority) {
      case TriagePriority.p0Critical:
        return 'P0 — CRITICAL';
      case TriagePriority.p1Medical:
        return 'P1 — MEDICAL';
      case TriagePriority.p2Needs:
        return 'P2 — NEEDS / SUPPLIES';
      case TriagePriority.p3Safe:
        return 'P3 — SAFE / ROUTINE';
    }
  }
}

class TriageEngine {
  static TriageResult calculate(EmergencySignal signal) {
    int score = 0;
    final List<String> reasons = [];

    // Scoring Rules
    if (signal.medicalStatus.toUpperCase() == 'UNCONSCIOUS') {
      score += 50;
      reasons.add('Unconscious victim detected (+50)');
    } else if (signal.medicalStatus.toUpperCase() == 'CRITICAL') {
      score += 35;
      reasons.add('Critical medical condition (+35)');
    } else if (signal.medicalStatus.toUpperCase() == 'INJURED') {
      score += 20;
      reasons.add('Injured personnel (+20)');
    }

    if (signal.personTrapped) {
      score += 25;
      reasons.add('Victims trapped inside structure (+25)');
    }

    if (signal.firePresent) {
      score += 25;
      reasons.add('Active fire hazard present (+25)');
    }

    if (signal.structuralInstability) {
      score += 25;
      reasons.add('Structural collapse or instability (+25)');
    }

    if (signal.waterRising) {
      score += 20;
      reasons.add('Rapidly rising water levels (+20)');
    }

    if (signal.casualties > 1) {
      final multiBonus = (signal.casualties * 5).clamp(5, 30);
      score += multiBonus;
      reasons.add('Multiple affected individuals: ${signal.casualties} (+$multiBonus)');
    }

    if (signal.requiresEvacuation) {
      score += 10;
      reasons.add('Immediate evacuation required (+10)');
    }

    if (signal.medicalEmergency) {
      score += 15;
      reasons.add('Medical emergency flagged (+15)');
    }

    // Priority Determination
    TriagePriority priority;
    if (signal.medicalStatus.toUpperCase() == 'UNCONSCIOUS' ||
        (signal.personTrapped && (signal.firePresent || signal.structuralInstability || signal.waterRising)) ||
        score >= 60) {
      priority = TriagePriority.p0Critical;
    } else if (signal.medicalStatus.toUpperCase() == 'CRITICAL' ||
        signal.medicalStatus.toUpperCase() == 'INJURED' ||
        signal.medicalEmergency ||
        score >= 35) {
      priority = TriagePriority.p1Medical;
    } else if (signal.requiresEvacuation || score >= 15) {
      priority = TriagePriority.p2Needs;
    } else {
      priority = TriagePriority.p3Safe;
    }

    return TriageResult(
      priority: priority,
      score: score,
      reasons: reasons.isEmpty ? ['Standard emergency report logged'] : reasons,
    );
  }
}
