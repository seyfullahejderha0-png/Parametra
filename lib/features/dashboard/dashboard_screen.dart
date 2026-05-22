import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../finance/screens/finance_screen.dart';
import '../debts/screens/debts_screen.dart';
import '../goals/screens/goals_screen.dart';
import '../smoking/screens/smoking_screen.dart';
import '../notes/screens/note_screen.dart';
import '../ai_assistant/screens/ai_assistant_screen.dart';
import '../health/screens/health_screen.dart';
import '../medication/screens/medication_screen.dart';
import '../subscription/models/subscription_model.dart';
import '../subscription/screens/subscription_screen.dart';
import '../subscription/services/subscription_service.dart';
import '../profile/services/module_settings_service.dart';
import '../dashboard/dashboard_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';
import '../life_timeline/screens/life_timeline_screen.dart';

import '../profile/services/profile_service.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/providers/privacy_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final settings = ref.watch(moduleSettingsProvider);
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';

    bool isVisible(String id) => settings.any((s) => s.id == id && s.isVisible);

    final isPrivacy = ref.watch(privacyProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            actions: [
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())),
                icon: ref.watch(subscriptionStreamProvider).when(
                  data: (sub) => Icon(
                    Icons.workspace_premium, 
                    color: sub.hasPremium ? Colors.amber : themeMode.textSecondary.withOpacity(0.5),
                  ),
                  loading: () => Icon(Icons.workspace_premium, color: themeMode.textSecondary.withOpacity(0.3)),
                  error: (_, __) => Icon(Icons.workspace_premium, color: themeMode.textSecondary.withOpacity(0.3)),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(privacyProvider.notifier).toggle(),
                icon: Icon(
                  isPrivacy ? Icons.visibility_off : Icons.visibility,
                  color: themeMode.textSecondary,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                context.l10n('dashboard_title'), 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18,
                  color: themeMode.textPrimary,
                )
              ),
              background: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [themeMode.primary.withOpacity(0.2), Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildSubscriptionStatus(context, ref, themeMode),
          ),
          SliverToBoxAdapter(
            child: _buildLifeTimelineCard(context, themeMode),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              delegate: SliverChildListDelegate([
                if (isVisible('finance')) _buildFinanceCard(context, summary.finance, currency, themeMode, isPrivacy),
                if (isVisible('debts')) _buildDebtCard(context, summary.debts, currency, themeMode, isPrivacy),
                if (isVisible('notes')) _buildNoteCard(context, summary.notes, themeMode),
                if (isVisible('smoking')) _buildSmokingCard(context, summary.smoking, currency, themeMode, isPrivacy),
                if (isVisible('health')) _buildHealthCard(context, summary.health, summary.water, themeMode),
                if (isVisible('medication')) _buildMedicationCard(context, summary.medication, themeMode),
                if (isVisible('goals')) _buildGoalCard(context, summary.goals, currency, themeMode, isPrivacy),
                if (isVisible('ai')) _buildAICard(context, ref, summary.ai, themeMode),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard(BuildContext context, FinanceSummary s, String currency, AppThemeMode themeMode, bool isPrivacy) {
    final balanceColor = s.balance >= 0 ? Colors.greenAccent : Colors.redAccent;
    final balanceSign = s.balance >= 0 ? '+' : '';
    final formattedBalance = isPrivacy ? '*****' : '$balanceSign${CurrencyFormatter.format(s.balance.abs(), context, currency)}';
    
    return _buildBaseCard(
      context,
      title: context.l10n('finance_card'),
      icon: Icons.account_balance_wallet,
      color: themeMode.financeColor,
      screen: const FinanceScreen(),
      isEmpty: s.isEmpty,
      emptyLabel: context.l10n('no_data'),
      badge: s.isEmpty ? null : formattedBalance,
      badgeColor: balanceColor,
      data: [
        if (s.monthlyIncome > 0) '${context.l10n('income_label')}: ${isPrivacy ? '*****' : '+${CurrencyFormatter.format(s.monthlyIncome, context, currency)}'}',
        if (s.monthlyExpense > 0) '${context.l10n('expense_label')}: ${isPrivacy ? '*****' : '-${CurrencyFormatter.format(s.monthlyExpense, context, currency)}'}',
        if (s.topCategory.isNotEmpty) '${context.l10n('top_label')}: ${s.topCategory}',
      ],
    );
  }

  Widget _buildDebtCard(BuildContext context, DebtSummary s, String currency, AppThemeMode themeMode, bool isPrivacy) {
    return _buildBaseCard(
      context,
      title: context.l10n('debt_card'),
      icon: Icons.handshake,
      color: themeMode.debtColor,
      screen: const DebtsScreen(),
      isEmpty: s.isEmpty,
      emptyLabel: context.l10n('no_data'),
      badge: s.upcomingPaymentsCount > 0 ? '${s.upcomingPaymentsCount} ${context.l10n('items_count_label')}' : null,
      data: [
        if (s.totalDebt > 0) '${context.l10n('debt_label')}: ${isPrivacy ? '*****' : CurrencyFormatter.format(s.totalDebt, context, currency)}',
        if (s.totalCredit > 0) '${context.l10n('credit_label')}: ${isPrivacy ? '*****' : CurrencyFormatter.format(s.totalCredit, context, currency)}',
        if (s.hasTodayCollection) '${context.l10n('today_label')}',
      ],
    );
  }

  Widget _buildNoteCard(BuildContext context, NotesSummary s, AppThemeMode themeMode) {
    return _buildBaseCard(
      context,
      title: context.l10n('notes_card'),
      icon: Icons.edit_note,
      color: themeMode.noteColor,
      screen: const NoteScreen(),
      isEmpty: s.isEmpty,
      emptyLabel: context.l10n('no_data'),
      badge: s.totalNotesCount > 0 ? context.l10n('total_notes_label').replaceFirst('{count}', s.totalNotesCount.toString()) : null,
      data: [
        if (s.lastNoteDate.isNotEmpty) '📅 ${s.lastNoteDate}',
      ],
      isSpecial: true,
    );
  }

  Widget _buildSmokingCard(BuildContext context, SmokingSummary s, String currency, AppThemeMode themeMode, bool isPrivacy) {
    return _buildBaseCard(
      context,
      title: context.l10n('smoking_card'),
      icon: Icons.smoke_free,
      color: themeMode.smokingColor,
      screen: const SmokingScreen(),
      isEmpty: s.isEmpty,
      emptyLabel: '🚭',
      badge: !s.isEmpty ? '${s.quitDuration.inDays} ${context.l10n('days_label')}' : null,
      data: [
        if (!s.isEmpty) '${context.l10n('savings_label')}: ${isPrivacy ? '*****' : CurrencyFormatter.format(s.savings, context, currency)}',
        if (!s.isEmpty) '${context.l10n('unsmoked_label')}: ${s.unsmokedCount}',
      ],
    );
  }

  Widget _buildHealthCard(BuildContext context, HealthSummary s, WaterSummary w, AppThemeMode themeMode) {
    return _buildBaseCard(
      context,
      title: context.l10n('health_card'),
      icon: Icons.favorite,
      color: themeMode.healthColor,
      screen: const HealthScreen(),
      isEmpty: s.isEmpty && w.isEmpty,
      emptyLabel: '💪',
      badge: w.percentage > 0 ? '%${(w.percentage * 100).toInt()} ${context.l10n('water_label')}' : (s.isActiveToday ? context.l10n('active_label') : null),
      data: [
        if (!w.isEmpty) '💧 ${w.currentAmount.toStringAsFixed(1)}L / ${w.targetAmount.toStringAsFixed(1)}L',
        if (s.todaySportMinutes > 0) '🏃: ${s.todaySportMinutes} ${context.l10n('minutes')}',
      ],
    );
  }

  Widget _buildMedicationCard(BuildContext context, MedicationSummary s, AppThemeMode themeMode) {
    return _buildBaseCard(
      context,
      title: context.l10n('medication_card'),
      icon: Icons.medication,
      color: themeMode.medicationColor,
      screen: const MedicationScreen(),
      isEmpty: s.isEmpty,
      emptyLabel: '💊',
      badge: s.remainingDosesToday > 0 ? '${s.remainingDosesToday} ${context.l10n('doses_label')}' : null,
      data: [
        if (s.nextDoseTime.isNotEmpty) '🕒 ${context.l10n('next_dose_label')}: ${s.nextDoseTime}',
        if (s.activeMedicationCount > 0) '💊 ${s.activeMedicationCount} ${context.l10n('active_label')}',
      ],
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalsSummary s, String currency, AppThemeMode themeMode, bool isPrivacy) {
    return _buildBaseCard(
      context,
      title: context.l10n('goals_card'),
      icon: Icons.track_changes,
      color: themeMode.goalsColor,
      screen: const GoalsScreen(),
      isEmpty: s.isEmpty,
      emptyLabel: '🎯',
      badge: !s.isEmpty ? '%${(s.topGoalProgress * 100).toInt()}' : null,
      data: [
        if (!s.isEmpty) '${context.l10n('target_amount_label')}: ${isPrivacy ? '*****' : CurrencyFormatter.format(s.totalAmount, context, currency)}',
        if (!s.isEmpty) '${context.l10n('current_savings_label')}: ${isPrivacy ? '*****' : CurrencyFormatter.format(s.currentAmount, context, currency)}',
      ],
    );
  }

  Widget _buildSubscriptionStatus(BuildContext context, WidgetRef ref, AppThemeMode themeMode) {
    final subAsync = ref.watch(subscriptionStreamProvider);
    return subAsync.when(
      data: (sub) {
        if (sub.type == SubscriptionType.trial && sub.isActive) {
          final days = sub.remainingTrialDays;
          if (days > 4) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade700, Colors.orange.shade800],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n('trial_ending_soon'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(context.l10n('days_remaining').replaceFirst('{days}', days.toString()), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())),
                  style: TextButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                  child: Text(context.l10n('view')),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAICard(BuildContext context, WidgetRef ref, AISummary s, AppThemeMode themeMode) {
    final subAsync = ref.watch(subscriptionStreamProvider);
    final hasAI = subAsync.value?.hasAI ?? false;
    final aiColor = themeMode.primary;

    return InkWell(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => hasAI ? const AIAssistantScreen() : const SubscriptionScreen()
        )
      ),
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: themeMode.surface,
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  aiColor.withOpacity(hasAI ? 0.15 : 0.05), 
                  themeMode.surface
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: aiColor.withOpacity(hasAI ? 0.4 : 0.1), 
                width: 1.5
              ),
              boxShadow: [
                BoxShadow(color: aiColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n('ai_assistant_card'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: aiColor, letterSpacing: 0.5)),
                    Icon(hasAI ? Icons.psychology : Icons.lock_outline, color: aiColor, size: 24),
                  ],
                ),
                const Spacer(),
                Text(
                  _getSocialAnalysisMessage(context, s, hasAI),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.w500, 
                    color: hasAI ? themeMode.textPrimary : themeMode.textSecondary.withOpacity(0.4), 
                    fontStyle: FontStyle.italic
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: aiColor.withOpacity(hasAI ? 1.0 : 0.3), 
                    borderRadius: BorderRadius.circular(2)
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSocialAnalysisMessage(BuildContext context, AISummary s, bool hasAI) {
    if (!hasAI) return context.l10n('ai_assistant_hint');

    // Simüle edilmiş sosyal analiz mantığı
    if (s.unsmokedCount > 50) {
      return "🚭 ${context.l10n('social_smoke_top').replaceFirst('{percent}', '5')}";
    } else if (s.waterPercentage > 0.8) {
      return "💧 ${context.l10n('social_water_top').replaceFirst('{percent}', '10')}";
    } else if (s.balance > 5000) {
      return "💰 ${context.l10n('social_finance_top').replaceFirst('{percent}', '15')}";
    }

    return context.l10n('ai_assistant_hint');
  }

  Widget _buildBaseCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget screen,
    required bool isEmpty,
    required String emptyLabel,
    String? badge,
    Color? badgeColor,
    required List<String> data,
    bool isSpecial = false,
  }) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final textSecondary = theme.textTheme.bodyMedium?.color ?? Colors.white70;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color, letterSpacing: 0.8))),
                Icon(icon, color: color.withOpacity(0.8), size: 18),
              ],
            ),
            const SizedBox(height: 12),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (badgeColor ?? color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (badgeColor ?? color).withOpacity(0.3)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor ?? color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Spacer(),
            if (isEmpty)
              Text(emptyLabel, style: TextStyle(color: textSecondary.withOpacity(0.4), fontSize: 11, fontStyle: FontStyle.italic))
            else
              ...data.map((text) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSpecial ? 12 : 10,
                    color: isSpecial ? textPrimary : textSecondary,
                    fontWeight: isSpecial ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildLifeTimelineCard(BuildContext context, AppThemeMode themeMode) {
    final cardColor = themeMode.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: themeMode.surface,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            cardColor.withOpacity(0.12),
            themeMode.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: cardColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LifeTimelineScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Icon container with beautiful circular gradient
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      '🕒',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n('life_timeline_title'),
                          style: TextStyle(
                            color: themeMode.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n('life_timeline_card_desc'),
                          style: TextStyle(
                            color: themeMode.textSecondary,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chevron icon
                  Icon(
                    Icons.chevron_right,
                    color: themeMode.textSecondary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
