import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../finance/models/finance_models.dart';
import '../finance/services/finance_service.dart';
import '../debts/models/debt_model.dart';
import '../debts/services/debt_service.dart';
import '../health/models/health_models.dart';
import '../health/services/health_service.dart';
import '../medication/models/medication_model.dart';
import '../medication/services/medication_service.dart';
import '../smoking/models/smoking_model.dart';
import '../smoking/services/smoking_service.dart';
import '../notes/models/note_model.dart';
import '../notes/services/note_service.dart';
import '../goals/models/goal_model.dart';
import '../goals/services/goal_service.dart';
import '../profile/models/module_setting.dart';
import '../profile/services/module_settings_service.dart';

final clockProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

class DashboardSummary {
  final FinanceSummary finance;
  final DebtSummary debts;
  final WaterSummary water;
  final SmokingSummary smoking;
  final MedicationSummary medication;
  final NotesSummary notes;
  final GoalsSummary goals;
  final HealthSummary health;
  final AISummary ai;

  DashboardSummary({
    required this.finance,
    required this.debts,
    required this.water,
    required this.smoking,
    required this.medication,
    required this.notes,
    required this.goals,
    required this.health,
    required this.ai,
  });
}

class FinanceSummary {
  final double todayExpense;
  final double monthlyExpense;
  final double monthlyIncome;
  final double balance;
  final String topCategory;
  final String lastAction;
  final bool isEmpty;

  FinanceSummary({
    required this.todayExpense,
    required this.monthlyExpense,
    required this.monthlyIncome,
    required this.balance,
    required this.topCategory,
    required this.lastAction,
    this.isEmpty = false,
  });
}

class DebtSummary {
  final int upcomingPaymentsCount;
  final double totalDebt;
  final double totalCredit;
  final bool hasTodayCollection;
  final double collectionAmount;
  final bool isEmpty;

  DebtSummary({
    required this.upcomingPaymentsCount,
    required this.totalDebt,
    required this.totalCredit,
    required this.hasTodayCollection,
    required this.collectionAmount,
    this.isEmpty = false,
  });
}

class WaterSummary {
  final double currentAmount;
  final double targetAmount;
  final double percentage;
  final double remainingAmount;
  final bool isEmpty;

  WaterSummary({
    required this.currentAmount,
    required this.targetAmount,
    required this.percentage,
    required this.remainingAmount,
    this.isEmpty = false,
  });
}

class SmokingSummary {
  final Duration quitDuration;
  final double savings;
  final int unsmokedCount;
  final bool isEmpty;

  SmokingSummary({
    required this.quitDuration,
    required this.savings,
    required this.unsmokedCount,
    this.isEmpty = false,
  });
}

class MedicationSummary {
  final int remainingDosesToday;
  final String nextDoseTime;
  final int activeMedicationCount;
  final bool isEmpty;

  MedicationSummary({
    required this.remainingDosesToday,
    required this.nextDoseTime,
    required this.activeMedicationCount,
    this.isEmpty = false,
  });
}

class NotesSummary {
  final int todayNotesCount;
  final int totalNotesCount;
  final String lastNoteTitle;
  final String lastNoteContent;
  final String lastNoteDate;
  final bool isEmpty;

  NotesSummary({
    required this.todayNotesCount,
    required this.totalNotesCount,
    required this.lastNoteTitle,
    required this.lastNoteContent,
    required this.lastNoteDate,
    this.isEmpty = false,
  });
}

class GoalsSummary {
  final double topGoalProgress;
  final double remainingAmount;
  final double dailyRequired;
  final double totalAmount;
  final double currentAmount;
  final bool isEmpty;

  GoalsSummary({
    required this.topGoalProgress,
    required this.remainingAmount,
    required this.dailyRequired,
    required this.totalAmount,
    required this.currentAmount,
    this.isEmpty = false,
  });
}

class HealthSummary {
  final bool isActiveToday;
  final int weeklyActivityCount;
  final int todaySportMinutes;
  final String lastActivityDate;
  final bool isEmpty;

  HealthSummary({
    required this.isActiveToday,
    required this.weeklyActivityCount,
    required this.todaySportMinutes,
    required this.lastActivityDate,
    this.isEmpty = false,
  });
}

class AISummary {
  final List<String> dailyInsights;
  final String lastSuggestion;
  final int unsmokedCount;
  final double waterPercentage;
  final double balance;
  final bool isEmpty;

  AISummary({
    required this.dailyInsights,
    required this.lastSuggestion,
    required this.unsmokedCount,
    required this.waterPercentage,
    required this.balance,
    this.isEmpty = false,
  });
}

final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final now = ref.watch(clockProvider).value ?? DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfMonth = DateTime(now.year, now.month, 1);

  // --- Finance ---
  final actions = ref.watch(actionsProvider).value ?? [];
  final categories = ref.watch(categoriesProvider).value ?? [];
  final financeData = FinanceData(actions: actions, categories: categories);
  final finance = _calculateFinanceSummary(financeData, startOfToday, startOfMonth);

  // --- Debts ---
  final debtsList = ref.watch(debtsStreamProvider).value ?? [];
  final debts = _calculateDebtSummary(debtsList, startOfToday);

  // --- Water ---
  final waterIntakes = ref.watch(dailyWaterProvider).value ?? [];
  final waterGoal = ref.watch(waterGoalProvider).value ?? 3.0;
  final water = _calculateWaterSummary(waterIntakes, waterGoal);

  // --- Smoking ---
  final smokingAsync = ref.watch(smokingStreamProvider);
  final smokingData = smokingAsync.value;
  final smoking = _calculateSmokingSummary(smokingData, now);

  // --- Medication ---
  final medsList = ref.watch(medicationsStreamProvider).value ?? [];
  final medication = _calculateMedicationSummary(medsList, now);

  // --- Notes ---
  final notesList = ref.watch(notesStreamProvider).value ?? [];
  final notes = _calculateNotesSummary(notesList, startOfToday);

  // --- Goals ---
  final goalsList = ref.watch(goalsStreamProvider).value ?? [];
  final goals = _calculateGoalsSummary(goalsList);

  // --- Health/Activity ---
  final activities = ref.watch(activitiesStreamProvider).value ?? [];
  final health = _calculateHealthSummary(activities, startOfToday);

  // --- AI Summary ---
  final settings = ref.watch(moduleSettingsProvider);
  final ai = _calculateAISummary(finance, debts, water, smoking, settings);

  return DashboardSummary(
    finance: finance,
    debts: debts,
    water: water,
    smoking: smoking,
    medication: medication,
    notes: notes,
    goals: goals,
    health: health,
    ai: ai,
  );
});

FinanceSummary _calculateFinanceSummary(FinanceData financeData, DateTime today, DateTime month) {
  final actions = financeData.actions.where((a) => a.isPureIncomeExpense).toList();
  if (actions.isEmpty) return FinanceSummary(todayExpense: 0, monthlyExpense: 0, monthlyIncome: 0, balance: 0, topCategory: '', lastAction: '', isEmpty: true);

  double todayExp = 0;
  double monthExp = 0;
  double monthInc = 0;
  Map<String, double> categories = {};

  for (var action in actions) {
    if (action.date.isAfter(today)) {
      if (action.type == FinanceType.expense) {
        todayExp += action.amount;
      }
    }
    if (action.date.isAfter(month)) {
      if (action.type == FinanceType.expense) {
        monthExp += action.amount;
        final category = financeData.categories.firstWhere(
          (c) => c.id == action.categoryId,
          orElse: () => FinanceCategory(id: '', name: 'Diğer', emoji: '📁', type: FinanceType.expense),
        );
        categories[category.name] = (categories[category.name] ?? 0) + action.amount;
      } else {
        monthInc += action.amount;
      }
    }
  }

  String topCategory = '';
  if (categories.isNotEmpty) {
    topCategory = categories.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String last = '';
  if (actions.isNotEmpty) {
    final lastAction = actions.first;
    final lastCat = financeData.categories.firstWhere(
      (c) => c.id == lastAction.categoryId,
      orElse: () => FinanceCategory(id: '', name: 'Diğer', emoji: '📁', type: FinanceType.expense),
    );
    final sign = lastAction.type == FinanceType.income ? '+' : '-';
    last = '${lastCat.name} $sign${lastAction.amount.toStringAsFixed(0)} TL';
  }

  return FinanceSummary(
    todayExpense: todayExp,
    monthlyExpense: monthExp,
    monthlyIncome: monthInc,
    balance: monthInc - monthExp,
    topCategory: topCategory,
    lastAction: last,
  );
}

DebtSummary _calculateDebtSummary(List<Debt> debts, DateTime today) {
  if (debts.isEmpty) return DebtSummary(upcomingPaymentsCount: 0, totalDebt: 0, totalCredit: 0, hasTodayCollection: false, collectionAmount: 0, isEmpty: true);

  int upcoming = 0;
  double totalD = 0;
  double totalC = 0;
  bool todayColl = false;
  double collAmt = 0;

  for (var d in debts) {
    if (d.isPaid) continue;
    
    final isBorc = d.type == DebtType.borc || d.type == DebtType.kredi;
    if (isBorc) {
      totalD += d.remainingAmount * d.exchangeRate;
    } else {
      totalC += d.remainingAmount * d.exchangeRate;
    }

    if (d.dueDate != null) {
      if (d.dueDate!.isBefore(today.add(const Duration(days: 7)))) {
        upcoming++;
      }
      if (d.dueDate!.year == today.year && d.dueDate!.month == today.month && d.dueDate!.day == today.day) {
        if (!isBorc) {
          todayColl = true;
          collAmt += d.remainingAmount * d.exchangeRate;
        }
      }
    }
  }

  return DebtSummary(
    upcomingPaymentsCount: upcoming,
    totalDebt: totalD,
    totalCredit: totalC,
    hasTodayCollection: todayColl,
    collectionAmount: collAmt,
  );
}

WaterSummary _calculateWaterSummary(List<WaterIntake> intakes, double target) {
  final current = intakes.fold(0.0, (sum, item) => sum + item.amount);
  final percentage = (current / target).clamp(0.0, 1.0);
  final remaining = (target - current).clamp(0.0, target);

  return WaterSummary(
    currentAmount: current,
    targetAmount: target,
    percentage: percentage,
    remainingAmount: remaining,
    isEmpty: intakes.isEmpty && current == 0,
  );
}

SmokingSummary _calculateSmokingSummary(SmokingData? data, DateTime now) {
  if (data == null) return SmokingSummary(quitDuration: Duration.zero, savings: 0, unsmokedCount: 0, isEmpty: true);

  final duration = now.difference(data.startDate);
  final totalSeconds = duration.inSeconds.isNegative ? 0 : duration.inSeconds;
  
  final unsmoked = (totalSeconds / (24 * 3600)) * data.dailyQuantity;
  final savings = (unsmoked / 20) * data.packetPrice;

  return SmokingSummary(
    quitDuration: Duration(seconds: totalSeconds),
    savings: savings < 0 ? 0 : savings,
    unsmokedCount: unsmoked < 0 ? 0 : unsmoked.toInt(),
  );
}

MedicationSummary _calculateMedicationSummary(List<Medication> meds, DateTime now) {
  if (meds.isEmpty) return MedicationSummary(remainingDosesToday: 0, nextDoseTime: '', activeMedicationCount: 0, isEmpty: true);

  int activeCount = 0;
  int remainingDoses = 0;
  DateTime? nextDose;

  for (var med in meds) {
    if (med.remainingDays > 0) {
      activeCount++;
      for (var timeStr in med.scheduleTimes) {
        final parts = timeStr.split(':');
        final doseTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
        if (doseTime.isAfter(now)) {
          remainingDoses++;
          if (nextDose == null || doseTime.isBefore(nextDose)) {
            nextDose = doseTime;
          }
        }
      }
    }
  }

  String nextStr = nextDose != null ? '${nextDose.hour.toString().padLeft(2, '0')}:${nextDose.minute.toString().padLeft(2, '0')}' : '';

  return MedicationSummary(
    remainingDosesToday: remainingDoses,
    nextDoseTime: nextStr,
    activeMedicationCount: activeCount,
  );
}

NotesSummary _calculateNotesSummary(List<NoteEntry> notes, DateTime today) {
  if (notes.isEmpty) {
    return NotesSummary(
      todayNotesCount: 0,
      totalNotesCount: 0,
      lastNoteTitle: '',
      lastNoteContent: '',
      lastNoteDate: '',
      isEmpty: true,
    );
  }

  final todayNotes = notes.where((n) => n.date.isAfter(today)).length;
  final last = notes.first;

  return NotesSummary(
    todayNotesCount: todayNotes,
    totalNotesCount: notes.length,
    lastNoteTitle: last.title,
    lastNoteContent: last.content,
    lastNoteDate: DateFormat('dd.MM.yyyy').format(last.date),
  );
}

GoalsSummary _calculateGoalsSummary(List<Goal> goals) {
  if (goals.isEmpty) return GoalsSummary(topGoalProgress: 0, remainingAmount: 0, dailyRequired: 0, totalAmount: 0, currentAmount: 0, isEmpty: true);

  final totalTarget = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  final totalCurrent = goals.fold(0.0, (sum, g) => sum + g.currentAmount);

  final topGoal = goals.reduce((a, b) => a.progress > b.progress ? a : b);
  final remaining = totalTarget - totalCurrent;
  
  double daily = 0;
  if (topGoal.deadline != null) {
    final daysLeft = topGoal.deadline!.difference(DateTime.now()).inDays;
    if (daysLeft > 0) {
      daily = remaining / daysLeft;
    }
  }

  return GoalsSummary(
    topGoalProgress: totalTarget > 0 ? (totalCurrent / totalTarget) : 0.0,
    remainingAmount: remaining,
    dailyRequired: daily,
    totalAmount: totalTarget,
    currentAmount: totalCurrent,
  );
}

HealthSummary _calculateHealthSummary(List<Activity> activities, DateTime today) {
  if (activities.isEmpty) return HealthSummary(isActiveToday: false, weeklyActivityCount: 0, todaySportMinutes: 0, lastActivityDate: '', isEmpty: true);

  bool todayActive = activities.any((a) => a.date.isAfter(today));
  int weeklyCount = activities.where((a) => a.date.isAfter(today.subtract(const Duration(days: 7)))).length;
  int todayMins = activities
      .where((a) => a.date.isAfter(today))
      .fold(0, (sum, a) => sum + a.durationMinutes);
  
  final last = activities.first;
  String dateStr = 'Bugün';
  if (last.date.isBefore(today)) {
    final diff = today.difference(DateTime(last.date.year, last.date.month, last.date.day)).inDays;
    dateStr = diff == 1 ? 'Dün' : '$diff gün önce';
  }

  return HealthSummary(
    isActiveToday: todayActive,
    weeklyActivityCount: weeklyCount,
    todaySportMinutes: todayMins,
    lastActivityDate: dateStr,
  );
}

AISummary _calculateAISummary(FinanceSummary f, DebtSummary d, WaterSummary w, SmokingSummary s, List<ModuleSetting> settings) {
  List<String> insights = [];
  
  bool isVisible(String id) => settings.any((s) => s.id == id && s.isVisible);

  if (isVisible('finance') && f.todayExpense > 0) insights.add('Bugün ${f.todayExpense.toStringAsFixed(0)} TL harcadın');
  if (isVisible('smoking') && !s.isEmpty) insights.add('${s.quitDuration.inDays} gündür sigarasızsın');
  if (isVisible('debts') && d.upcomingPaymentsCount > 0) insights.add('${d.upcomingPaymentsCount} ödeme yaklaşıyor');
  if (isVisible('health') && w.percentage > 0) insights.add('Su hedefinin %${(w.percentage * 100).toInt()} tamam');

  return AISummary(
    dailyInsights: insights,
    lastSuggestion: insights.isNotEmpty ? insights.first : 'Bugün harika görünüyorsun!',
    unsmokedCount: s.unsmokedCount,
    waterPercentage: w.percentage,
    balance: f.balance,
  );
}

class FinanceData {
  final List<FinanceAction> actions;
  final List<FinanceCategory> categories;

  FinanceData({required this.actions, required this.categories});
}
