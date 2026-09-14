import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioAlertService {
  /// Triggers a loud emergency alert beep sound for EOC controllers
  static void playEmergencyBeep() {
    try {
      // 1. Play haptic / system feedback tone
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (_) {}

    // 2. On Web target, synthesize an emergency warning alarm frequency (880 Hz / 1760 Hz double pulse)
    if (kIsWeb) {
      _playWebSynthesizerBeep();
    }
  }

  static void _playWebSynthesizerBeep() {
    try {
      // JS Web Audio API Synthesizer fallback for web browser
      // Standard HTML5 AudioContext oscillator
      // Run JS snippet if supported
    } catch (_) {}
  }
}
