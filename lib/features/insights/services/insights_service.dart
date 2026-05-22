import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../finance/services/finance_service.dart';
import '../../finance/models/finance_models.dart';
import '../../health/services/health_service.dart';
import '../../smoking/services/smoking_service.dart';
import '../../gamification/services/gamification_service.dart';
import '../../debts/services/debt_service.dart';
import '../../debts/models/debt_model.dart';
import '../../goals/services/goal_service.dart';
import '../../medication/services/medication_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class InsightModel {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double value;

  InsightModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.value = 0.5,
  });
}

final insightsProvider = FutureProvider<List<InsightModel>>((ref) async {
  final locale = ref.watch(localeProvider);
  final l10n = AppLocalizations(locale);

  // Verileri dinleyelim
  final financeActions = ref.watch(actionsProvider).value ?? [];
  final waterIntakes = ref.watch(dailyWaterProvider).value ?? [];
  final smokingData = ref.watch(smokingStreamProvider).value;
  final debts = ref.watch(debtsStreamProvider).value ?? [];
  final goals = ref.watch(goalsStreamProvider).value ?? [];
  final medications = ref.watch(medicationsStreamProvider).value ?? [];
  final budgetLimit = ref.watch(budgetLimitProvider).value;
  final medLogs = ref.watch(logTodayStreamProvider).value ?? [];

  List<InsightModel> insights = [];

  // 1. İlaç Takibi Analizi
  if (medications.isNotEmpty) {
    final activeMeds = medications.where((m) => m.isActiveToday).toList();
    if (activeMeds.isNotEmpty) {
      int totalScheduledToday = activeMeds.fold(0, (sum, m) => sum + m.timesPerDay);
      int takenToday = medLogs.length;
      
      // Zamanı geçen ama alınmayan doz kontrolü
      int missedDoses = 0;
      final now = DateTime.now();
      for (var med in activeMeds) {
        for (var time in med.scheduleTimes) {
          final timeParts = time.split(':');
          final scheduleTime = DateTime(now.year, now.month, now.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
          final isTaken = medLogs.any((l) => l.medicationId == med.id && l.scheduledTime == time);
          if (!isTaken && now.isAfter(scheduleTime)) {
            missedDoses++;
          }
        }
      }

      double healthProgress = totalScheduledToday > 0 
          ? (takenToday / totalScheduledToday).clamp(0.0, 1.0) 
          : 1.0;

      // Ceza Uygula: Eğer kaçırılan doz varsa puanı ciddi şekilde düşür
      if (missedDoses > 0) {
        healthProgress = (healthProgress * 0.5).clamp(0.0, 1.0); // %50 ceza
      }

      String desc = takenToday >= totalScheduledToday 
          ? l10n.translate('insight_treatment_desc_done') 
          : l10n.translate('insight_treatment_desc_partial')
              .replaceFirst('{taken}', takenToday.toString())
              .replaceFirst('{total}', totalScheduledToday.toString());

      if (missedDoses > 0) {
        desc = "$desc - ${l10n.translate('missed_label')}: $missedDoses";
      }

      insights.add(InsightModel(
        title: l10n.translate('insight_treatment_title'),
        description: desc,
        icon: missedDoses > 0 ? Icons.error_outline : Icons.medical_services,
        color: missedDoses > 0 ? Colors.redAccent : Colors.pinkAccent,
        value: healthProgress,
      ));
    }
  }

  final profile = ref.watch(userProfileProvider).value;
  final currency = profile?.preferredCurrency ?? 'TRY';
  final localeCode = locale.languageCode == 'tr' ? 'tr_TR' : 'en_US';
  final formatter = NumberFormat.currency(locale: localeCode, symbol: CurrencyFormatter.getSymbol(currency), decimalDigits: 0);

  // 2. Finansal Disiplin
  double totalExpense = financeActions
      .where((a) => a.type == FinanceType.expense && a.isPureIncomeExpense)
      .fold(0.0, (sum, a) => sum + a.amount);
  double totalGoalSavings = financeActions
      .where((a) => a.categoryId == 'cat_goal_savings')
      .fold(0.0, (sum, a) => sum + a.amount);
  double totalIncome = financeActions
      .where((a) => a.type == FinanceType.income && a.isPureIncomeExpense)
      .fold(0.0, (sum, a) => sum + a.amount);
  
  if (budgetLimit != null && budgetLimit > 0) {
    double usage = (totalExpense / budgetLimit).clamp(0.0, 1.0);
    insights.add(InsightModel(
      title: l10n.translate('insight_budget_title'),
      description: usage > 0.9 
          ? l10n.translate('insight_budget_desc_danger') 
          : l10n.translate('insight_budget_desc_ok'),
      icon: Icons.account_balance_wallet,
      color: usage > 0.9 ? Colors.redAccent : Colors.greenAccent,
      value: (1.0 - usage).clamp(0.0, 1.0),
    ));
  } else if (totalIncome > 0) {
    double netSavings = (totalIncome - totalExpense);
    double savingsRate = (netSavings / totalIncome).clamp(0.0, 1.0);
    
    String desc = savingsRate > 0.2 
        ? l10n.translate('insight_savings_desc_high') 
        : l10n.translate('insight_savings_desc_low');

    insights.add(InsightModel(
      title: l10n.translate('insight_savings_title'),
      description: desc,
      icon: Icons.pie_chart,
      color: Colors.tealAccent,
      value: savingsRate,
    ));
  }

  // 3. Borç / Alacak Dengesi
  if (debts.isNotEmpty) {
    final unpaidDebts = debts.where((d) => !d.isPaid && d.type != DebtType.alacak).toList();
    final unpaidReceivables = debts.where((d) => !d.isPaid && d.type == DebtType.alacak).toList();
    
    double totalDebtVal = unpaidDebts.fold(0.0, (sum, d) => sum + d.amount);
    double totalReceivableVal = unpaidReceivables.fold(0.0, (sum, d) => sum + d.amount);
    
    double debtBalance = 1.0;
    if (totalDebtVal + totalReceivableVal > 0) {
      debtBalance = (totalReceivableVal / (totalDebtVal + totalReceivableVal)).clamp(0.0, 1.0);
    }

    insights.add(InsightModel(
      title: l10n.translate('insight_debt_balance_title'),
      description: totalDebtVal == 0 
          ? l10n.translate('insight_debt_no_debt') 
          : l10n.translate('insight_debt_balance_desc').replaceFirst('{percent}', (debtBalance * 100).toInt().toString()),
      icon: Icons.handshake,
      color: debtBalance > 0.5 ? Colors.orangeAccent : Colors.redAccent,
      value: debtBalance,
    ));
  }

  // 4. Sigara Bırakma Analizi
  if (smokingData != null) {
    final days = DateTime.now().difference(smokingData.startDate).inDays;
    insights.add(InsightModel(
      title: l10n.translate('insight_smoking_title'),
      description: days > 0 
          ? l10n.translate('insight_smoking_desc_days').replaceFirst('{days}', days.toString()) 
          : l10n.translate('insight_smoking_desc_start'),
      icon: Icons.smoke_free,
      color: Colors.purpleAccent,
      value: (days / 30.0).clamp(0.0, 1.0),
    ));
  }

  // 5. Hedef İlerlemesi
  if (goals.isNotEmpty) {
    double totalProgress = goals.fold(0.0, (sum, g) => sum + (g.currentAmount / g.targetAmount));
    double avgProgress = totalProgress / goals.length;
    
    double totalTargetAmount = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    double totalCurrentAmount = goals.fold(0.0, (sum, g) => sum + g.currentAmount);

    String formattedSaved = formatter.format(totalCurrentAmount);
    String formattedTarget = formatter.format(totalTargetAmount);
    int percent = (avgProgress * 100).toInt();

    String desc = '';
    if (totalCurrentAmount > 0) {
      desc = l10n.translate('insight_savings_desc_goals').replaceFirst('{amount}', "$formattedSaved / $formattedTarget (%$percent)");
    } else {
      desc = l10n.translate('insight_goals_desc')
          .replaceFirst('{count}', goals.length.toString())
          .replaceFirst('{percent}', percent.toString());
    }

    insights.add(InsightModel(
      title: l10n.translate('insight_goals_title'),
      description: desc,
      icon: Icons.track_changes,
      color: Colors.blueAccent,
      value: avgProgress.clamp(0.0, 1.0),
    ));
  }
  // 6. Sağlık (Su)
  final waterGoal = ref.watch(waterGoalProvider).value ?? 3.0;
  if (waterIntakes.isNotEmpty) {
    double totalWater = waterIntakes.fold(0.0, (sum, a) => sum + a.amount);
    insights.add(InsightModel(
      title: l10n.translate('insight_water_title'),
      description: totalWater < waterGoal 
          ? l10n.translate('insight_water_desc_low') 
          : l10n.translate('insight_water_desc_done'),
      icon: Icons.water_drop,
      color: Colors.cyanAccent,
      value: (totalWater / waterGoal).clamp(0.0, 1.0),
    ));
  }

  // 7. Hoş Geldin
  if (insights.isEmpty) {
    insights.add(InsightModel(
      title: l10n.translate('insight_welcome_title'),
      description: l10n.translate('insight_welcome_desc'),
      icon: Icons.auto_awesome,
      color: Colors.amberAccent,
      value: 1.0,
    ));
  }

  return insights;
});
