import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingServiceProvider = Provider((ref) => OnboardingService());

class OnboardingService {
  static const String _prefix = 'onboarding_';

  Future<bool> shouldShowIntro(String moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_prefix$moduleId') ?? false);
  }

  Future<void> markAsShown(String moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$moduleId', true);
  }

  Future<void> resetIntro(String moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$moduleId', false);
  }
}
