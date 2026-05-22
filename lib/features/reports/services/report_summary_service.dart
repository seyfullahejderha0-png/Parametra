import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';

final reportSummaryServiceProvider = Provider<ReportSummaryService>((ref) {
  final locale = ref.watch(localeProvider);
  final l10n = AppLocalizations(locale);
  return ReportSummaryService(l10n);
});

class ReportSummaryService {
  final AppLocalizations _l10n;

  ReportSummaryService(this._l10n);

  // İleride Gemini AI entegrasyonu için asenkron altyapı
  Future<String> getGeminiSummary(String reportType, Map<String, dynamic> exportData) async {
    // TODO: İleride google_generative_ai paketi ile Gemini API çağrısı yapılacak.
    // Şimdilik kural bazlı (rule-based) özeti dönüyoruz.
    return _generateRuleBasedSummary(reportType, exportData);
  }

  String _generateRuleBasedSummary(String reportType, Map<String, dynamic> data) {
    switch (reportType) {
      case 'finance':
        return getFinanceSummary(
          totalIncome: data['totalIncome'] ?? 0.0,
          totalExpense: data['totalExpense'] ?? 0.0,
          savingsRate: data['savingsRate'] ?? 0.0,
        );
      case 'debt':
        return getDebtSummary(
          totalDebt: data['totalDebt'] ?? 0.0,
          totalCredit: data['totalCredit'] ?? 0.0,
          collectionRate: data['collectedAmount'] != null && data['totalCredit'] != null && data['totalCredit'] > 0 
              ? (data['collectedAmount'] / data['totalCredit']) 
              : 0.0,
        );
      case 'goal':
        return getGoalSummary(
          overallProgress: data['overallProgress'] ?? 0.0,
          activeCount: data['activeGoalsCount'] ?? 0,
        );
      case 'water':
        return getWaterSummary(
          goalSuccessRate: data['goalSuccessRate'] ?? 0.0,
          streak: data['streak'] ?? 0,
        );
      case 'sport':
        return getSportSummary(
          successRate: data['successRate'] ?? 0.0,
          activeDays: data['activeDays'] ?? 0,
        );
      case 'smoking':
        return getSmokingSummary(
          reductionRate: data['reductionRate'] ?? 0.0,
          smokeFreeDays: data['smokeFreeDays'] ?? 0,
        );
      case 'medicine':
        return getMedicineSummary(
          complianceRate: data['complianceRate'] ?? 0.0,
          missedCount: data['missedCount'] ?? 0,
        );
      default:
        return _l10n.translate('summary_general_stable');
    }
  }

  String getFinanceSummary({
    required double totalIncome,
    required double totalExpense,
    required double savingsRate,
  }) {
    if (totalIncome == 0 && totalExpense == 0) {
      return _l10n.translate('summary_finance_no_data');
    }
    if (totalExpense > totalIncome && totalIncome > 0) {
      return _l10n.translate('summary_finance_expense_high');
    }
    if (savingsRate > 0.3) {
      final template = _l10n.translate('summary_finance_savings_great');
      return template.replaceAll('{rate}', (savingsRate * 100).toStringAsFixed(1));
    }
    if (totalExpense > 0) {
      return _l10n.translate('summary_finance_controlled');
    }
    return _l10n.translate('summary_finance_stable');
  }

  String getDebtSummary({
    required double totalDebt,
    required double totalCredit,
    required double collectionRate,
  }) {
    if (totalDebt == 0 && totalCredit == 0) {
      return _l10n.translate('summary_debt_no_data');
    }
    if (collectionRate > 0.7) {
      final template = _l10n.translate('summary_debt_collection_high');
      return template.replaceAll('{rate}', (collectionRate * 100).toStringAsFixed(0));
    }
    if (totalDebt > totalCredit && totalCredit > 0) {
      return _l10n.translate('summary_debt_high');
    }
    return _l10n.translate('summary_debt_stable');
  }

  String getGoalSummary({
    required double overallProgress,
    required int activeCount,
  }) {
    if (activeCount == 0) {
      return _l10n.translate('summary_goal_no_data');
    }
    if (overallProgress > 0.8) {
      return _l10n.translate('summary_goal_almost_there');
    }
    if (overallProgress > 0.4) {
      return _l10n.translate('summary_goal_steady');
    }
    return _l10n.translate('summary_goal_slow');
  }

  String getWaterSummary({
    required double goalSuccessRate,
    required int streak,
  }) {
    if (goalSuccessRate == 0) {
      return _l10n.translate('summary_water_no_data');
    }
    if (streak > 3) {
      final template = _l10n.translate('summary_water_streak');
      return template.replaceAll('{streak}', streak.toString());
    }
    if (goalSuccessRate > 0.7) {
      return _l10n.translate('summary_water_close');
    }
    return _l10n.translate('summary_water_low');
  }

  String getSportSummary({
    required double successRate,
    required int activeDays,
  }) {
    if (activeDays == 0) {
      return _l10n.translate('summary_sport_no_data');
    }
    if (successRate > 0.7) {
      return _l10n.translate('summary_sport_great');
    }
    return _l10n.translate('summary_sport_low');
  }

  String getSmokingSummary({
    required double reductionRate,
    required int smokeFreeDays,
  }) {
    if (smokeFreeDays > 0) {
      final template = _l10n.translate('summary_smoking_smoke_free');
      return template.replaceAll('{days}', smokeFreeDays.toString());
    }
    if (reductionRate > 0) {
      final template = _l10n.translate('summary_smoking_reduction');
      return template.replaceAll('{rate}', (reductionRate * 100).toStringAsFixed(0));
    }
    return _l10n.translate('summary_smoking_struggle');
  }

  String getMedicineSummary({
    required double complianceRate,
    required int missedCount,
  }) {
    if (complianceRate == 0 && missedCount == 0) {
      return _l10n.translate('summary_med_no_data');
    }
    if (complianceRate > 0.9) {
      final template = _l10n.translate('summary_med_excellent');
      return template.replaceAll('{rate}', (complianceRate * 100).toStringAsFixed(0));
    }
    if (missedCount > 0 || complianceRate < 0.5) {
      return _l10n.translate('summary_med_missed');
    }
    return _l10n.translate('summary_med_regular');
  }
}
