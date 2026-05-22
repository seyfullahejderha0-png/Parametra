import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    final faqs = [
      {'q': l10n.translate('faq_finance_q'), 'a': l10n.translate('faq_finance_a')},
      {'q': l10n.translate('faq_debt_q'), 'a': l10n.translate('faq_debt_a')},
      {'q': l10n.translate('faq_smoking_q'), 'a': l10n.translate('faq_smoking_a')},
      {'q': l10n.translate('faq_medication_q'), 'a': l10n.translate('faq_medication_a')},
      {'q': l10n.translate('faq_water_q'), 'a': l10n.translate('faq_water_a')},
      {'q': l10n.translate('faq_goal_q'), 'a': l10n.translate('faq_goal_a')},
      {'q': l10n.translate('faq_notes_q'), 'a': l10n.translate('faq_notes_a')},
      {'q': l10n.translate('faq_ai_q'), 'a': l10n.translate('faq_ai_a')},
      {'q': l10n.translate('faq_security_q'), 'a': l10n.translate('faq_security_a')},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('faq_title')),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: faqs.length,
          itemBuilder: (context, index) {
            return Card(
              color: AppColors.surface.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(
                  faqs[index]['q']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                iconColor: AppColors.aiColor,
                collapsedIconColor: Colors.white54,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      faqs[index]['a']!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
