import 'triage_engine.dart';

abstract class SignalExtractionService {
  Future<EmergencySignal> extract(String description);
  String get engineLabel;
}

class RuleBasedSignalExtractionService implements SignalExtractionService {
  @override
  String get engineLabel => 'LOCAL SIGNAL ANALYSIS — Rule-based extraction';

  @override
  Future<EmergencySignal> extract(String description) async {
    final lower = description.toLowerCase();

    // Category Extraction
    String category = 'Other';
    if (lower.contains('flood') || lower.contains('water') || lower.contains('drowning') || lower.contains('submerged')) {
      category = 'Flood';
    } else if (lower.contains('fire') || lower.contains('smoke') || lower.contains('burn') || lower.contains('flame')) {
      category = 'Fire';
    } else if (lower.contains('collapse') || lower.contains('building') || lower.contains('rubble') || lower.contains('trapped inside')) {
      category = 'Structural Collapse';
    } else if (lower.contains('landslide') || lower.contains('mudslide') || lower.contains('debris')) {
      category = 'Landslide';
    } else if (lower.contains('accident') || lower.contains('crash') || lower.contains('vehicle')) {
      category = 'Road Accident';
    } else if (lower.contains('missing') || lower.contains('lost') || lower.contains('disappeared')) {
      category = 'Missing Person';
    } else if (lower.contains('medical') || lower.contains('unconscious') || lower.contains('bleeding') || lower.contains('heart') || lower.contains('stroke')) {
      category = 'Medical';
    }

    // Medical Status Extraction
    String medicalStatus = 'Stable';
    if (lower.contains('unconscious') || lower.contains('passed out') || lower.contains('fainted') || lower.contains('not breathing')) {
      medicalStatus = 'Unconscious';
    } else if (lower.contains('critical') || lower.contains('severe') || lower.contains('dying') || lower.contains('heavy bleeding')) {
      medicalStatus = 'Critical';
    } else if (lower.contains('injured') || lower.contains('hurt') || lower.contains('broken') || lower.contains('wound') || lower.contains('pain')) {
      medicalStatus = 'Injured';
    }

    // Flag Extraction
    final bool personTrapped = lower.contains('trapped') || lower.contains('stuck') || lower.contains('locked') || lower.contains('inside');
    final bool waterRising = lower.contains('rising') || lower.contains('water rising') || lower.contains('flooding rapidly');
    final bool firePresent = lower.contains('fire') || lower.contains('smoke') || lower.contains('flames');
    final bool structuralInstability = lower.contains('collapse') || lower.contains('unstable') || lower.contains('cracks') || lower.contains('falling');
    final bool requiresEvacuation = lower.contains('evacuat') || lower.contains('rescue') || lower.contains('get us out') || lower.contains('help out');
    final bool medicalEmergency = medicalStatus == 'Unconscious' || medicalStatus == 'Critical' || lower.contains('doctor') || lower.contains('ambulance');

    // Casualty Count Extraction
    int casualties = 1;
    final numberRegex = RegExp(r'(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\s+(people|persons|victims|casualties|trapped|individuals|family)');
    final match = numberRegex.firstMatch(lower);
    if (match != null) {
      final word = match.group(1)!;
      casualties = _parseNumber(word);
    } else {
      final standaloneDigit = RegExp(r'(\d+)\s+(trapped|injured|affected)');
      final digitMatch = standaloneDigit.firstMatch(lower);
      if (digitMatch != null) {
        casualties = int.tryParse(digitMatch.group(1)!) ?? 1;
      }
    }

    return EmergencySignal(
      category: category,
      casualties: casualties,
      medicalStatus: medicalStatus,
      personTrapped: personTrapped,
      waterRising: waterRising,
      firePresent: firePresent,
      structuralInstability: structuralInstability,
      requiresEvacuation: requiresEvacuation,
      medicalEmergency: medicalEmergency,
      rawDescription: description,
    );
  }

  int _parseNumber(String text) {
    switch (text) {
      case 'one': return 1;
      case 'two': return 2;
      case 'three': return 3;
      case 'four': return 4;
      case 'five': return 5;
      case 'six': return 6;
      case 'seven': return 7;
      case 'eight': return 8;
      case 'nine': return 9;
      case 'ten': return 10;
      default: return int.tryParse(text) ?? 1;
    }
  }
}
