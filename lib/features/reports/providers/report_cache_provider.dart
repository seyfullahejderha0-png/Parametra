import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/locale_provider.dart';
import '../../family/services/family_service.dart';
import '../../finance/services/finance_service.dart';
import '../../debts/services/debt_service.dart';
import '../../goals/services/goal_service.dart';
import '../../health/services/health_service.dart';
import '../../medication/services/medication_service.dart';
import '../../smoking/services/smoking_service.dart';
import '../models/report_models.dart';
import '../services/reports_calculation_service.dart';

class ReportFilterState {
  final ReportDateFilter filter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String activeCategory; // 'finance', 'debt', 'goal', 'health'
  final String activeHealthSub; // 'water', 'sport', 'smoking', 'medicine'

  ReportFilterState({
    this.filter = ReportDateFilter.month,
    this.customStartDate,
    this.customEndDate,
    this.activeCategory = 'finance',
    this.activeHealthSub = 'water',
  });

  ReportFilterState copyWith({
    ReportDateFilter? filter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? activeCategory,
    String? activeHealthSub,
  }) {
    return ReportFilterState(
      filter: filter ?? this.filter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      activeCategory: activeCategory ?? this.activeCategory,
      activeHealthSub: activeHealthSub ?? this.activeHealthSub,
    );
  }
}

class ReportFilterNotifier extends Notifier<ReportFilterState> {
  @override
  ReportFilterState build() => ReportFilterState();

  void setFilter(ReportDateFilter filter, {DateTime? start, DateTime? end}) {
    state = state.copyWith(
      filter: filter,
      customStartDate: start,
      customEndDate: end,
    );
  }

  void setActiveCategory(String category) {
    state = state.copyWith(activeCategory: category);
  }

  void setActiveHealthSub(String sub) {
    state = state.copyWith(activeHealthSub: sub);
  }
}

final reportFilterStateProvider = NotifierProvider<ReportFilterNotifier, ReportFilterState>(() {
  return ReportFilterNotifier();
});

// --- CACHED FUTURE PROVIDERS ---

final financialReportCacheProvider = FutureProvider<FinancialReportData>((ref) {
  ref.watch(localeProvider); // Dil değişiminde önbelleği yenile
  ref.watch(workspaceTypeProvider); // Çalışma alanı değişiminde tetikle
  ref.watch(actionsProvider); // Veri güncellemelerinde tetikle
  ref.watch(categoriesProvider);
  ref.watch(paymentMethodsProvider);

  final calcService = ref.watch(reportsCalculationServiceProvider);
  final filter = ref.watch(reportFilterStateProvider.select((s) => s.filter));
  final start = ref.watch(reportFilterStateProvider.select((s) => s.customStartDate));
  final end = ref.watch(reportFilterStateProvider.select((s) => s.customEndDate));

  return calcService.calculateFinancialReport(filter, start, end);
});

final debtReportCacheProvider = FutureProvider<DebtReportData>((ref) {
  ref.watch(localeProvider); // Dil değişiminde önbelleği yenile
  ref.watch(workspaceTypeProvider); // Çalışma alanı değişiminde tetikle
  ref.watch(debtsStreamProvider); // Veri güncellemelerinde tetikle

  final calcService = ref.watch(reportsCalculationServiceProvider);
  final filter = ref.watch(reportFilterStateProvider.select((s) => s.filter));
  final start = ref.watch(reportFilterStateProvider.select((s) => s.customStartDate));
  final end = ref.watch(reportFilterStateProvider.select((s) => s.customEndDate));

  return calcService.calculateDebtReport(filter, start, end);
});

final goalReportCacheProvider = FutureProvider<GoalReportData>((ref) {
  ref.watch(localeProvider); // Dil değişiminde önbelleği yenile
  ref.watch(workspaceTypeProvider); // Çalışma alanı değişiminde tetikle
  ref.watch(goalsStreamProvider); // Veri güncellemelerinde tetikle

  final calcService = ref.watch(reportsCalculationServiceProvider);
  final filter = ref.watch(reportFilterStateProvider.select((s) => s.filter));
  final start = ref.watch(reportFilterStateProvider.select((s) => s.customStartDate));
  final end = ref.watch(reportFilterStateProvider.select((s) => s.customEndDate));

  return calcService.calculateGoalReport(filter, start, end);
});

final healthReportCacheProvider = FutureProvider<HealthReportData>((ref) {
  ref.watch(localeProvider); // Dil değişiminde önbelleği yenile
  ref.watch(workspaceTypeProvider); // Çalışma alanı değişiminde tetikle
  ref.watch(activitiesStreamProvider); // Veri güncellemelerinde tetikle
  ref.watch(smokingStreamProvider);
  ref.watch(medicationsStreamProvider);
  ref.watch(logTodayStreamProvider);
  ref.watch(waterLogsProvider);

  final calcService = ref.watch(reportsCalculationServiceProvider);
  final filter = ref.watch(reportFilterStateProvider.select((s) => s.filter));
  final start = ref.watch(reportFilterStateProvider.select((s) => s.customStartDate));
  final end = ref.watch(reportFilterStateProvider.select((s) => s.customEndDate));

  return calcService.calculateHealthReport(filter, start, end);
});
