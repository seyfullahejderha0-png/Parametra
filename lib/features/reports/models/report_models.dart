import 'package:flutter/material.dart';

enum ReportDateFilter {
  today,
  week,
  month,
  last30,
  custom,
}

class ChartData {
  final String label;
  final double value;
  final Color color;

  ChartData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class SummaryCardData {
  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final String? iconEmoji;

  SummaryCardData({
    required this.title,
    required this.value,
    this.subtitle,
    required this.color,
    this.iconEmoji,
  });
}

class FinancialReportData {
  final double totalIncome;
  final double totalExpense;
  final double currentBalance;
  final double netWorth;
  final double savingsRate;
  final List<ChartData> pieChartData;
  final List<ChartData> lineChartData;
  final List<ChartData> barChartData;
  final String aiSummary;
  final bool isEmpty;

  FinancialReportData({
    required this.totalIncome,
    required this.totalExpense,
    required this.currentBalance,
    required this.netWorth,
    required this.savingsRate,
    required this.pieChartData,
    required this.lineChartData,
    required this.barChartData,
    required this.aiSummary,
    this.isEmpty = false,
  });

  // Export hazırlığı (İleride PDF/Excel/CSV için)
  Map<String, dynamic> toExportMap() => {
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
    'currentBalance': currentBalance,
    'netWorth': netWorth,
    'savingsRate': savingsRate,
    'aiSummary': aiSummary,
  };
}

class DebtReportData {
  final double totalDebt;
  final double totalCredit;
  final double collectedAmount;
  final double pendingAmount;
  final int upcomingPaymentsCount;
  final List<ChartData> monthlyTrendData;
  final List<ChartData> collectionTrendData;
  final List<ChartData> distributionData;
  final int activeCount;
  final int closedCount;
  final int overdueCount;
  final String aiSummary;
  final bool isEmpty;

  DebtReportData({
    required this.totalDebt,
    required this.totalCredit,
    required this.collectedAmount,
    required this.pendingAmount,
    required this.upcomingPaymentsCount,
    required this.monthlyTrendData,
    required this.collectionTrendData,
    required this.distributionData,
    required this.activeCount,
    required this.closedCount,
    required this.overdueCount,
    required this.aiSummary,
    this.isEmpty = false,
  });

  Map<String, dynamic> toExportMap() => {
    'totalDebt': totalDebt,
    'totalCredit': totalCredit,
    'collectedAmount': collectedAmount,
    'pendingAmount': pendingAmount,
    'upcomingPaymentsCount': upcomingPaymentsCount,
    'activeCount': activeCount,
    'closedCount': closedCount,
    'overdueCount': overdueCount,
    'aiSummary': aiSummary,
  };
}

class GoalReportData {
  final int activeGoalsCount;
  final int completedGoalsCount;
  final double overallProgress;
  final double totalSavings;
  final List<ChartData> progressCurveData;
  final List<ChartData> completionRateData;
  final List<ChartData> savingsGrowthData;
  final String aiSummary;
  final bool isEmpty;

  GoalReportData({
    required this.activeGoalsCount,
    required this.completedGoalsCount,
    required this.overallProgress,
    required this.totalSavings,
    required this.progressCurveData,
    required this.completionRateData,
    required this.savingsGrowthData,
    required this.aiSummary,
    this.isEmpty = false,
  });

  Map<String, dynamic> toExportMap() => {
    'activeGoalsCount': activeGoalsCount,
    'completedGoalsCount': completedGoalsCount,
    'overallProgress': overallProgress,
    'totalSavings': totalSavings,
    'aiSummary': aiSummary,
  };
}

class WaterReportData {
  final double dailyAverage;
  final double totalWater;
  final double goalSuccessRate;
  final int streak;
  final List<ChartData> dailyIntakeData;
  final List<ChartData> weeklyTrendData;
  final String aiSummary;
  final bool isEmpty;

  WaterReportData({
    required this.dailyAverage,
    required this.totalWater,
    required this.goalSuccessRate,
    required this.streak,
    required this.dailyIntakeData,
    required this.weeklyTrendData,
    required this.aiSummary,
    this.isEmpty = false,
  });

  Map<String, dynamic> toExportMap() => {
    'dailyAverage': dailyAverage,
    'totalWater': totalWater,
    'goalSuccessRate': goalSuccessRate,
    'streak': streak,
    'aiSummary': aiSummary,
  };
}

class SportReportData {
  final int totalActivities;
  final int activeDays;
  final int totalDurationMinutes;
  final double successRate;
  final List<ChartData> activityTrendData;
  final String aiSummary;
  final bool isEmpty;

  SportReportData({
    required this.totalActivities,
    required this.activeDays,
    required this.totalDurationMinutes,
    required this.successRate,
    required this.activityTrendData,
    required this.aiSummary,
    this.isEmpty = false,
  });

  Map<String, dynamic> toExportMap() => {
    'totalActivities': totalActivities,
    'activeDays': activeDays,
    'totalDurationMinutes': totalDurationMinutes,
    'successRate': successRate,
    'aiSummary': aiSummary,
  };
}

class SmokingReportData {
  final int smokedCount;
  final double reductionRate;
  final int smokeFreeDays;
  final double savings;
  final List<ChartData> reductionCurveData;
  final String aiSummary;
  final bool isEmpty;

  SmokingReportData({
    required this.smokedCount,
    required this.reductionRate,
    required this.smokeFreeDays,
    required this.savings,
    required this.reductionCurveData,
    required this.aiSummary,
    this.isEmpty = false,
  });

  Map<String, dynamic> toExportMap() => {
    'smokedCount': smokedCount,
    'reductionRate': reductionRate,
    'smokeFreeDays': smokeFreeDays,
    'savings': savings,
    'aiSummary': aiSummary,
  };
}

class MedicineReportData {
  final int takenCount;
  final int missedCount;
  final double complianceRate;
  final String stockStatus;
  final List<ChartData> complianceChartData;
  final List<ChartData> reminderSuccessData;
  final String aiSummary;
  final bool isEmpty;

  MedicineReportData({
    required this.takenCount,
    required this.missedCount,
    required this.complianceRate,
    required this.stockStatus,
    required this.complianceChartData,
    required this.reminderSuccessData,
    required this.aiSummary,
    this.isEmpty = false,
  });

  Map<String, dynamic> toExportMap() => {
    'takenCount': takenCount,
    'missedCount': missedCount,
    'complianceRate': complianceRate,
    'stockStatus': stockStatus,
    'aiSummary': aiSummary,
  };
}

class HealthReportData {
  final WaterReportData water;
  final SportReportData sport;
  final SmokingReportData smoking;
  final MedicineReportData medicine;

  HealthReportData({
    required this.water,
    required this.sport,
    required this.smoking,
    required this.medicine,
  });

  Map<String, dynamic> toExportMap() => {
    'water': water.toExportMap(),
    'sport': sport.toExportMap(),
    'smoking': smoking.toExportMap(),
    'medicine': medicine.toExportMap(),
  };
}
