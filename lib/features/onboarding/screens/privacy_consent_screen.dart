import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../profile/services/profile_service.dart';
import '../../main/screens/main_screen.dart';
import '../../../core/theme/app_colors.dart';

class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  ConsumerState<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  bool _isAccepted = false;
  bool _isLoading = false;

  void _handleAccept() async {
    if (!_isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n('privacy_accept_checkbox'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(profileServiceProvider).acceptPrivacy();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.aiColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.aiColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 80,
                        color: AppColors.aiColor,
                      ),
                    ),
                      const SizedBox(height: 32),
                      Text(
                        context.l10n('privacy_title'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n('privacy_desc'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      _buildPrivacyItem(context, context.l10n('privacy_item_1')),
                      _buildPrivacyItem(context, context.l10n('privacy_item_2')),
                      _buildPrivacyItem(context, context.l10n('privacy_item_3')),
                      _buildPrivacyItem(context, context.l10n('privacy_item_4')),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.l10n('privacy_ai_info'),
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          onChanged: (val) => setState(() => _isAccepted = val ?? false),
                          activeColor: theme.colorScheme.primary,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isAccepted = !_isAccepted),
                            child: Text(
                              context.l10n('privacy_accept_checkbox'),
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.aiColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                context.l10n('privacy_button_accept'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Logic to open privacy policy URL
                      },
                      child: Text(
                        context.l10n('privacy_button_read'),
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
