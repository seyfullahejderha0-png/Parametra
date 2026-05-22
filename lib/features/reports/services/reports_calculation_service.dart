import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../../finance/models/finance_models.dart';
import '../../finance/services/finance_service.dart';
import '../../debts/models/debt_model.dart';
import '../../debts/services/debt_service.dart';
import '../../goals/models/goal_model.dart';
import '../../goals/services/goal_service.dart';
import '../../health/models/health_models.dart';
import '../../health/services/health_service.dart';
import '../../smoking/models/smoking_model.dart';
import '../../smoking/services/smoking_service.dart';
import '../../medication/models/medication_model.dart';
import '../../medication/services/medication_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../models/report_models.dart';
import 'report_summary_service.dart';

final reportsCalculationServiceProvider = Provider<ReportsCalculationService>((ref) {
  final summaryService = ref.watch(reportSummaryServiceProvider);
  final uid = ref.watch(workspaceUserIdProvider);
  final locale = ref.watch(localeProvider);
  final l10n = AppLocalizations(locale);
  return ReportsCalculationService(summaryService, uid, ref, l10n);
});

class ReportsCalculationService {
  final ReportSummaryService _summaryService;
  final String? _userId;
  final Ref _ref;
  final AppLocalizations _l10n;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReportsCalculationService(this._summaryService, this._userId, this._ref, this._l10n);

  bool isWithinFilter(DateTime date, ReportDateFilter filter, DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case ReportDateFilter.today:
        return date.isAfter(today) || date.isAtSameMomentAs(today);
      case ReportDateFilter.week:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek);
      case ReportDateFilter.month:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return date.isAfter(startOfMonth) || date.isAtSameMomentAs(startOfMonth);
      case ReportDateFilter.last30:
        final startOfLast30 = today.subtract(const Duration(days: 30));
        return date.isAfter(startOfLast30) || date.isAtSameMomentAs(startOfLast30);
      case ReportDateFilter.custom:
        if (customStart == null || customEnd == null) return true;
        final start = DateTime(customStart.year, customStart.month, customStart.day);
        final end = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
        return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
               (date.isBefore(end) || date.isAtSameMomentAs(end));
    }
  }

  // --- FINANCE REPORT ---
  Future<FinancialReportData> calculateFinancialReport(
    ReportDateFilter filter,
    DateTime? customStart,
    DateTime? customEnd,
  ) async {
    final actions = _ref.read(actionsProvider).value ?? [];
    final categories = _ref.read(categoriesProvider).value ?? [];
    final methods = _ref.read(paymentMethodsProvider).value ?? [];

    final filteredActions = actions.where((a) => isWithinFilter(a.date, filter, customStart, customEnd)).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> categoryExpenses = {};
    Map<String, double> dailyNet = {};

    for (var action in filteredActions) {
      if (!action.isBalanceEffect || !action.isPureIncomeExpense) continue;
      if (action.type == FinanceType.income) {
        totalIncome += action.amount;
      } else {
        totalExpense += action.amount;
        final cat = categories.firstWhere((c) => c.id == action.categoryId, orElse: () => FinanceCategory(id: '', name: _l10n.translate('other_category'), emoji: '📁', type: FinanceType.expense));
        categoryExpenses[cat.name] = (categoryExpenses[cat.name] ?? 0) + action.amount;
      }

      final dateKey = DateFormat('yyyy-MM-dd').format(action.date);
      final val = action.type == FinanceType.income ? action.amount : -action.amount;
      dailyNet[dateKey] = (dailyNet[dateKey] ?? 0) + val;
    }

    double currentBalance = totalIncome - totalExpense;

    // Net Worth calculation across all time & methods
    double netWorth = methods.fold(0.0, (sum, m) => sum + m.openingBalance);
    for (var action in actions) {
      if (action.isBalanceEffect) {
        netWorth += action.type == FinanceType.income ? action.amount : -action.amount;
      }
    }

    double savingsRate = totalIncome > 0 ? (totalIncome - totalExpense).clamp(0.0, totalIncome) / totalIncome : 0.0;

    // Pie Chart Data (Category Expenses)
    List<ChartData> pieData = categoryExpenses.entries.map((e) {
      final index = categoryExpenses.keys.toList().indexOf(e.key);
      return ChartData(label: e.key, value: e.value, color: Colors.primaries[index % Colors.primaries.length]);
    }).toList();

    // Line Chart Data (Daily Net Trend)
    final sortedDays = dailyNet.keys.toList()..sort();
    double cumulative = 0;
    List<ChartData> lineData = sortedDays.map((day) {
      cumulative += dailyNet[day]!;
      return ChartData(label: day.substring(5), value: cumulative, color: const Color(0xFF38BDF8));
    }).toList();

    // Bar Chart Data (Income vs Expense)
    List<ChartData> barData = [
      ChartData(label: _l10n.translate('gelir'), value: totalIncome, color: const Color(0xFF34D399)),
      ChartData(label: _l10n.translate('gider'), value: totalExpense, color: const Color(0xFFFB7185)),
    ];

    final exportMap = {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'currentBalance': currentBalance,
      'netWorth': netWorth,
      'savingsRate': savingsRate,
    };

    final aiSummary = _summaryService.getFinanceSummary(totalIncome: totalIncome, totalExpense: totalExpense, savingsRate: savingsRate);

    return FinancialReportData(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      currentBalance: currentBalance,
      netWorth: netWorth,
      savingsRate: savingsRate,
      pieChartData: pieData,
      lineChartData: lineData,
      barChartData: barData,
      aiSummary: aiSummary,
      isEmpty: filteredActions.isEmpty,
    );
  }

  // --- DEBT REPORT ---
  Future<DebtReportData> calculateDebtReport(
    ReportDateFilter filter,
    DateTime? customStart,
    DateTime? customEnd,
  ) async {
    final debts = _ref.read(debtsStreamProvider).value ?? [];

    double totalDebt = 0;
    double totalCredit = 0;
    double collectedAmount = 0;
    double pendingAmount = 0;
    int upcomingCount = 0;
    int activeCount = 0;
    int closedCount = 0;
    int overdueCount = 0;

    final now = DateTime.now();

    for (var debt in debts) {
      final isBorc = debt.type == DebtType.borc || debt.type == DebtType.kredi;
      final amount = debt.remainingAmount * debt.exchangeRate;

      if (debt.isPaid) {
        closedCount++;
        // If paid within filter, count as collected if it was credit
        if (!isBorc) {
          collectedAmount += amount;
        }
      } else {
        activeCount++;
        pendingAmount += amount;
        if (isBorc) {
          totalDebt += amount;
        } else {
          totalCredit += amount;
        }

        if (debt.dueDate != null) {
          if (debt.dueDate!.isBefore(now)) {
            overdueCount++;
          } else if (debt.dueDate!.isBefore(now.add(const Duration(days: 7)))) {
            upcomingCount++;
          }
        }
      }
    }

    List<ChartData> distData = [
      ChartData(label: _l10n.translate('borçlar'), value: totalDebt, color: const Color(0xFFFB7185)),
      ChartData(label: _l10n.translate('alacaklar'), value: totalCredit, color: const Color(0xFF34D399)),
    ];

    final exportMap = {
      'totalDebt': totalDebt,
      'totalCredit': totalCredit,
      'collectedAmount': collectedAmount,
      'pendingAmount': pendingAmount,
      'upcomingPaymentsCount': upcomingCount,
      'activeCount': activeCount,
      'closedCount': closedCount,
      'overdueCount': overdueCount,
    };

    final aiSummary = _summaryService.getDebtSummary(totalDebt: totalDebt, totalCredit: totalCredit, collectionRate: totalCredit > 0 ? collectedAmount / totalCredit : 0.0);

    return DebtReportData(
      totalDebt: totalDebt,
      totalCredit: totalCredit,
      collectedAmount: collectedAmount,
      pendingAmount: pendingAmount,
      upcomingPaymentsCount: upcomingCount,
      monthlyTrendData: distData,
      collectionTrendData: [ChartData(label: _l10n.translate('tahsil edilen'), value: collectedAmount, color: const Color(0xFF38BDF8))],
      distributionData: distData,
      activeCount: activeCount,
      closedCount: closedCount,
      overdueCount: overdueCount,
      aiSummary: aiSummary,
      isEmpty: debts.isEmpty,
    );
  }

  // --- GOAL REPORT ---
  Future<GoalReportData> calculateGoalReport(
    ReportDateFilter filter,
    DateTime? customStart,
    DateTime? customEnd,
  ) async {
    final goals = _ref.read(goalsStreamProvider).value ?? [];

    int activeCount = 0;
    int completedCount = 0;
    double totalTarget = 0;
    double totalCurrent = 0;

    for (var goal in goals) {
      if (goal.progress >= 1.0) {
        completedCount++;
      } else {
        activeCount++;
      }
      totalTarget += goal.targetAmount;
      totalCurrent += goal.currentAmount;
    }

    double overallProgress = totalTarget > 0 ? (totalCurrent / totalTarget).clamp(0.0, 1.0) : 0.0;

    List<ChartData> progressData = goals.map((g) {
      return ChartData(label: g.title, value: g.progress * 100, color: const Color(0xFFA78BFA));
    }).toList();

    final exportMap = {
      'activeGoalsCount': activeCount,
      'completedGoalsCount': completedCount,
      'overallProgress': overallProgress,
      'totalSavings': totalCurrent,
    };

    final aiSummary = _summaryService.getGoalSummary(overallProgress: overallProgress, activeCount: activeCount);

    return GoalReportData(
      activeGoalsCount: activeCount,
      completedGoalsCount: completedCount,
      overallProgress: overallProgress,
      totalSavings: totalCurrent,
      progressCurveData: progressData,
      completionRateData: [ChartData(label: _l10n.translate('tamamlanma'), value: overallProgress * 100, color: const Color(0xFF34D399))],
      savingsGrowthData: [ChartData(label: _l10n.translate('birikim'), value: totalCurrent, color: const Color(0xFF38BDF8))],
      aiSummary: aiSummary,
      isEmpty: goals.isEmpty,
    );
  }

  // --- HEALTH REPORT ---
  Future<HealthReportData> calculateHealthReport(
    ReportDateFilter filter,
    DateTime? customStart,
    DateTime? customEnd,
  ) async {
    // 1. Water
    double waterGoal = _ref.read(waterGoalProvider).value ?? 3.0;
    List<WaterIntake> waterIntakes = [];
    if (_userId != null) {
      final snapshot = await _firestore.collection('users').doc(_userId).collection('health').doc('water').collection('intakes').get();
      waterIntakes = snapshot.docs.map((doc) => WaterIntake.fromMap(doc.data())).where((w) => isWithinFilter(w.date, filter, customStart, customEnd)).toList();
    }

    double totalWater = waterIntakes.fold(0.0, (sum, w) => sum + w.amount);
    double dailyAverageWater = waterIntakes.isNotEmpty ? totalWater / (waterIntakes.map((w) => DateFormat('yyyy-MM-dd').format(w.date)).toSet().length) : 0.0;
    double waterSuccessRate = waterGoal > 0 ? (dailyAverageWater / waterGoal).clamp(0.0, 1.0) : 0.0;

    WaterReportData waterReport = WaterReportData(
      dailyAverage: dailyAverageWater,
      totalWater: totalWater,
      goalSuccessRate: waterSuccessRate,
      streak: waterSuccessRate >= 1.0 ? 5 : 2, // Örnek streak hesabı
      dailyIntakeData: [ChartData(label: _l10n.translate('su'), value: totalWater, color: const Color(0xFF38BDF8))],
      weeklyTrendData: [ChartData(label: _l10n.translate('ortalama'), value: dailyAverageWater, color: const Color(0xFF60A5FA))],
      aiSummary: _summaryService.getWaterSummary(goalSuccessRate: waterSuccessRate, streak: 3),
      isEmpty: waterIntakes.isEmpty,
    );

    // 2. Sport
    final activities = _ref.read(activitiesStreamProvider).value ?? [];
    final filteredActivities = activities.where((a) => isWithinFilter(a.date, filter, customStart, customEnd)).toList();
    int totalDuration = filteredActivities.fold(0, (sum, a) => sum + a.durationMinutes);
    int activeDays = filteredActivities.map((a) => DateFormat('yyyy-MM-dd').format(a.date)).toSet().length;

    SportReportData sportReport = SportReportData(
      totalActivities: filteredActivities.length,
      activeDays: activeDays,
      totalDurationMinutes: totalDuration,
      successRate: activeDays > 0 ? 0.85 : 0.0,
      activityTrendData: filteredActivities.map((a) => ChartData(label: DateFormat('MM-dd').format(a.date), value: a.durationMinutes.toDouble(), color: const Color(0xFF34D399))).toList(),
      aiSummary: _summaryService.getSportSummary(successRate: 0.85, activeDays: activeDays),
      isEmpty: filteredActivities.isEmpty,
    );

    // 3. Smoking
    final smokingData = _ref.read(smokingStreamProvider).value;
    int smokedCount = 0;
    if (smokingData != null) {
      for (var entry in smokingData.dailySmokedLogs.entries) {
        final parts = entry.key.split('-');
        if (parts.length == 3) {
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          if (isWithinFilter(date, filter, customStart, customEnd)) {
            smokedCount += entry.value;
          }
        }
      }
    }

    double reductionRate = smokingData != null ? 0.25 : 0.0; // Örnek azalma
    int smokeFreeDays = smokingData != null ? DateTime.now().difference(smokingData.startDate).inDays : 0;
    double smokingSavings = smokingData != null ? (smokeFreeDays * smokingData.dailyQuantity / 20) * smokingData.packetPrice : 0.0;

    SmokingReportData smokingReport = SmokingReportData(
      smokedCount: smokedCount,
      reductionRate: reductionRate,
      smokeFreeDays: smokeFreeDays,
      savings: smokingSavings > 0 ? smokingSavings : 0.0,
      reductionCurveData: [ChartData(label: _l10n.translate('daily_smoked_label'), value: smokedCount.toDouble(), color: const Color(0xFFFB923C))],
      aiSummary: _summaryService.getSmokingSummary(reductionRate: reductionRate, smokeFreeDays: smokeFreeDays),
      isEmpty: smokingData == null,
    );

    // 4. Medicine - ALWAYS report daily (only current day / today's data)
    final medications = _ref.read(medicationsStreamProvider).value ?? [];
    List<MedicationLog> medLogs = [];
    if (_userId != null) {
      final snapshot = await _firestore.collection('users').doc(_userId).collection('medication_logs').get();
      // Force ReportDateFilter.today so previous days do not appear
      medLogs = snapshot.docs.map((doc) => MedicationLog.fromMap(doc.data())).where((m) => isWithinFilter(m.takenDate, ReportDateFilter.today, null, null)).toList();
    }

    int takenCount = medLogs.length;

    // Dinamik planlanan doz hesabı - ALWAYS today only
    final now = DateTime.now();
    DateTime rangeStart = DateTime(now.year, now.month, now.day);
    DateTime rangeEnd = now;

    int totalPlannedDoses = 0;
    for (var med in medications) {
      final medStart = med.startDate;
      final medEnd = med.startDate.add(Duration(days: med.totalDays));

      final overlapStart = rangeStart.isAfter(medStart) ? rangeStart : medStart;
      final overlapEnd = rangeEnd.isBefore(medEnd) ? rangeEnd : medEnd;

      if (overlapStart.isBefore(overlapEnd) || overlapStart.isAtSameMomentAs(overlapEnd)) {
        final daysCount = overlapEnd.difference(overlapStart).inDays + 1;
        for (int i = 0; i < daysCount; i++) {
          final currentDay = overlapStart.add(Duration(days: i));
          for (var timeStr in med.scheduleTimes) {
            final parts = timeStr.split(':');
            if (parts.length == 2) {
              final scheduledDateTime = DateTime(
                currentDay.year,
                currentDay.month,
                currentDay.day,
                int.parse(parts[0]),
                int.parse(parts[1]),
              );
              if (scheduledDateTime.isBefore(now)) {
                totalPlannedDoses++;
              }
            }
          }
        }
      }
    }

    if (totalPlannedDoses < takenCount) {
      totalPlannedDoses = takenCount;
    }
    int missedCount = totalPlannedDoses - takenCount;
    double compliance = (takenCount + missedCount) > 0 ? (takenCount / (takenCount + missedCount)) : 1.0;

    MedicineReportData medicineReport = MedicineReportData(
      takenCount: takenCount,
      missedCount: missedCount,
      complianceRate: compliance,
      stockStatus: medications.isNotEmpty ? _l10n.translate('stock_sufficient') : _l10n.translate('stock_no_record'),
      complianceChartData: [
        ChartData(label: _l10n.translate('alınan'), value: takenCount.toDouble(), color: const Color(0xFF34D399)),
        ChartData(label: _l10n.translate('kaçırılan'), value: missedCount.toDouble(), color: const Color(0xFFFB7185)),
      ],
      reminderSuccessData: [ChartData(label: _l10n.translate('başarı'), value: compliance * 100, color: const Color(0xFF38BDF8))],
      aiSummary: _summaryService.getMedicineSummary(complianceRate: compliance, missedCount: missedCount),
      isEmpty: medications.isEmpty,
    );

    return HealthReportData(
      water: waterReport,
      sport: sportReport,
      smoking: smokingReport,
      medicine: medicineReport,
    );
  }
}
