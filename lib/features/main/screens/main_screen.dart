import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../onboarding/screens/privacy_consent_screen.dart';
import '../../insights/screens/insights_dashboard_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../../core/utils/ui_helpers.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ReportsScreen(),
    const InsightsDashboardScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPrivacy();
      _checkProfileSetup();
      ref.read(profileServiceProvider).recordUserActivity();
    });
  }

  Future<void> _checkPrivacy() async {
    final profile = await ref.read(profileServiceProvider).getProfile().first;
    if (profile != null && !profile.hasAcceptedPrivacy) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PrivacyConsentScreen()),
      );
    }
  }

  void _checkProfileSetup() async {
    // Profil verisini bir kez kontrol et
    final profile = await ref.read(profileServiceProvider).getProfile().first;
    
    if (profile == null || profile.firstName.isEmpty) {
      if (!mounted) return;
      
      final firstNameController = TextEditingController();
      final lastNameController = TextEditingController();
      bool isSubmitting = false;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setBottomSheetState) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 32,
              bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n('welcome_emoji'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n('profile_setup_desc'),
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: firstNameController,
                  enabled: !isSubmitting,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: context.l10n('first_name'),
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  enabled: !isSubmitting,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: context.l10n('last_name'),
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final firstName = firstNameController.text.trim();
                          if (firstName.isEmpty) {
                            UIHelpers.showErrorSnackBar(context, 'Lütfen adınızı girin.');
                            return;
                          }

                          setBottomSheetState(() {
                            isSubmitting = true;
                          });

                          try {
                            await ref.read(profileServiceProvider).updateProfile(
                              firstName: firstName,
                              lastName: lastNameController.text.trim(),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              UIHelpers.showSuccessSnackBar(context, 'Profiliniz başarıyla oluşturuldu!');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setBottomSheetState(() {
                                isSubmitting = false;
                              });
                              UIHelpers.showErrorSnackBar(context, 'Hata oluştu: ${e.toString()}');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.aiColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          context.l10n('let_start'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.aiColor,
          unselectedItemColor: Colors.white24,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view_rounded),
              label: context.l10n('modules_tab'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.bar_chart_rounded),
              label: context.l10n('reports_tab') ?? 'Raporlar',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_outlined),
              label: context.l10n('analysis_tab') ?? 'Analiz',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              label: context.l10n('profile'),
            ),
          ],
        ),
      ),
    );
  }
}
