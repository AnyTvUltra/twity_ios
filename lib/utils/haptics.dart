import 'package:flutter/services.dart';

class AppHaptics {
  /// Light haptic feedback for button taps, card presses, and item selections
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium haptic feedback for major actions like starting a game or claiming rewards
  static void medium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Selection haptic for tab switching and toggles
  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Heavy haptic feedback for win celebrations or critical events
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
