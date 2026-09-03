import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has seen onboarding at least once.
///
/// This flag survives logout but is cleared on a full app-data wipe.
/// The intent: show onboarding once, never again — even after signing out.
class OnboardingStorage {
  OnboardingStorage._();

  static const _key = 'campuz_onboarding_done';

  /// Returns `true` if the user has previously completed onboarding.
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Marks onboarding as completed. Call this when the user taps
  /// "Get Started" on the last onboarding slide.
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Resets the flag — useful only for testing or full data wipes.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
