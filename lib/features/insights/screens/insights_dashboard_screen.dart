import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/insights_service.dart';
import '../../gamification/services/gamification_service.dart';
import '../../ai_assistant/services/proactive_ai_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/privacy_provider.dart';

class InsightsDashboardScreen extends ConsumerWidget {
  const InsightsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final progressAsync = ref.watch(userProgressStreamProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isPrivacy = ref.watch(privacyProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.scaffoldBackgroundColor, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: () => ref.read(privacyProvider.notifier).toggle(),
                  icon: Icon(
                    isPrivacy ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: Text(
                  l10n.translate('analysis_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
                background: _buildHeader(progressAsync, ref, theme, l10n),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildAIMessage(ref, theme, l10n),
                    insightsAsync.when(
                      data: (insights) => Column(
                        children: insights.map((i) => _buildInsightCard(i, theme, isPrivacy)).toList(),
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, s) => Center(child: Text("${l10n.translate('error_label') ?? 'Hata'}: $e")),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<UserProgress> progressAsync, WidgetRef ref, ThemeData theme, AppLocalizations l10n) {
    return progressAsync.when(
      data: (progress) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.primaryColor, width: 2),
              boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 20)],
            ),
            child: Text(
              "${progress.level}",
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('level_label'), 
            style: TextStyle(color: theme.primaryColor.withOpacity(0.8), letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 4),
          Text("${progress.points} ${l10n.translate('points_label')}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => ref.read(proactiveAIServiceProvider).generateMorningBriefing(),
            icon: Icon(Icons.auto_awesome, size: 14, color: theme.primaryColor),
            label: Text(l10n.translate('ai_daily_summary_btn'), style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(120, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildAIMessage(WidgetRef ref, ThemeData theme, AppLocalizations l10n) {
    final aiMessage = ref.watch(proactiveAIMessageProvider);
    if (aiMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24, top: 16),
      child: GlassCard(
        opacity: 0.15,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.translate('ai_partner_message'), style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Colors.white30),
                    onPressed: () => ref.read(proactiveAIMessageProvider.notifier).setMessage(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                aiMessage,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(InsightModel insight, ThemeData theme, bool isPrivacy) {
    bool isFinancial = insight.title.contains('Tasarruf') || 
                       insight.title.contains('Bütçe') || 
                       insight.title.contains('Borç') ||
                       insight.title.contains('Savings') ||
                       insight.title.contains('Budget') ||
                       insight.title.contains('Debt');

    String displayDesc = isPrivacy && isFinancial ? '*****' : insight.description;
    String displayValue = isPrivacy && isFinancial ? '*****' : "%${(insight.value * 100).toInt()}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: insight.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(insight.icon, color: insight.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insight.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(displayDesc, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(displayValue, style: TextStyle(color: insight.color, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: insight.value,
                  backgroundColor: Colors.white10,
                  color: insight.color,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
