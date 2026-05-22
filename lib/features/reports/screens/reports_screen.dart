import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../profile/services/profile_service.dart';
import '../models/report_models.dart';
import '../providers/report_cache_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(reportFilterStateProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('reports_tab') ?? 'Raporlar', style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryChips(filterState),
          _buildDateFilterBar(filterState),
          if (filterState.activeCategory == 'health') _buildHealthSubChips(filterState),
          Expanded(
            child: _buildReportContent(filterState, currency),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(ReportFilterState filterState) {
    final categories = [
      {'id': 'finance', 'label': '💰 ${context.l10n('finance_card')?.replaceAll(' TAKİBİ', '').replaceAll(' TRACKING', '') ?? 'Finans'}'},
      {'id': 'debt', 'label': '💳 ${context.l10n('debt_card')?.replaceAll(' & ALACAK', '').replaceAll(' & CREDITS', '') ?? 'Borç / Alacak'}'},
      {'id': 'goal', 'label': '🎯 ${context.l10n('goals_card') ?? 'Hedefler'}'},
      {'id': 'health', 'label': '💊 ${context.l10n('health_card')?.replaceAll(' & SPOR', '').replaceAll(' & SPORT', '') ?? 'Sağlık'}'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: categories.map((cat) {
          final isSelected = filterState.activeCategory == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                cat['label']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF38BDF8),
              backgroundColor: const Color(0xFF334155),
              onSelected: (bool selected) {
                if (selected) {
                  ref.read(reportFilterStateProvider.notifier).setActiveCategory(cat['id']!);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateFilterBar(ReportFilterState filterState) {
    final filters = [
      {'id': ReportDateFilter.today, 'label': context.l10n('filter_today') ?? 'Bugün'},
      {'id': ReportDateFilter.week, 'label': context.l10n('filter_week') ?? 'Bu Hafta'},
      {'id': ReportDateFilter.month, 'label': context.l10n('filter_month') ?? 'Bu Ay'},
      {'id': ReportDateFilter.last30, 'label': context.l10n('filter_last_30') ?? 'Son 30 Gün'},
      {'id': ReportDateFilter.custom, 'label': context.l10n('filter_custom') ?? 'Özel Aralık'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: filters.map((f) {
          final filterType = f['id'] as ReportDateFilter;
          final isSelected = filterState.filter == filterType;
          String label = f['label'] as String;

          if (filterType == ReportDateFilter.custom && isSelected && filterState.customStartDate != null && filterState.customEndDate != null) {
            label = "${DateFormat('dd.MM').format(filterState.customStartDate!)} - ${DateFormat('dd.MM').format(filterState.customEndDate!)}";
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              backgroundColor: isSelected ? const Color(0xFF38BDF8).withOpacity(0.15) : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isSelected ? const Color(0xFF38BDF8) : Colors.white12),
              ),
              onPressed: () async {
                if (filterType == ReportDateFilter.custom) {
                  final picked = await showDateRangePicker(
                    context: context,
                    initialDateRange: filterState.customStartDate != null && filterState.customEndDate != null
                        ? DateTimeRange(start: filterState.customStartDate!, end: filterState.customEndDate!)
                        : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF38BDF8),
                            onPrimary: Colors.white,
                            surface: Color(0xFF1E293B),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(reportFilterStateProvider.notifier).setFilter(ReportDateFilter.custom, start: picked.start, end: picked.end);
                  }
                } else {
                  ref.read(reportFilterStateProvider.notifier).setFilter(filterType);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHealthSubChips(ReportFilterState filterState) {
    final subs = [
      {'id': 'water', 'label': '💧 ${context.l10n('water_label') ?? 'Su'}'},
      {'id': 'sport', 'label': '🏃 ${context.l10n('sport_label') ?? 'Spor'}'},
      {'id': 'smoking', 'label': '🚭 ${context.l10n('smoking_card')?.replaceAll(' BIRAKMA', '').replaceAll('QUIT ', '') ?? 'Sigara'}'},
      {'id': 'medicine', 'label': '💊 ${context.l10n('medication_card')?.replaceAll(' TAKİBİ', '') ?? 'İlaç'}'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: subs.map((sub) {
          final isSelected = filterState.activeHealthSub == sub['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                sub['label']!,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF60A5FA),
              backgroundColor: const Color(0xFF1E293B),
              onSelected: (bool selected) {
                if (selected) {
                  ref.read(reportFilterStateProvider.notifier).setActiveHealthSub(sub['id']!);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportContent(ReportFilterState filterState, String currency) {
    switch (filterState.activeCategory) {
      case 'finance':
        return _buildFinanceReport(currency);
      case 'debt':
        return _buildDebtReport(currency);
      case 'goal':
        return _buildGoalReport(currency);
      case 'health':
        return _buildHealthReport(filterState.activeHealthSub, currency);
      default:
        return Center(child: Text(context.l10n('unknown_category') ?? 'Bilinmeyen Kategori'));
    }
  }

  // --- EMPTY STATE BUILDER ---
  Widget _buildEmptyState(String iconEmoji, String title, String description) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(iconEmoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.white54)),
        ],
      ),
    );
  }

  // --- AI SUMMARY CARD ---
  Widget _buildAISummaryCard(String summaryText) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16, bottom: 32),
      color: const Color(0xFF22D3EE),
      opacity: 0.12,
      border: Border.all(color: const Color(0xFF22D3EE).withOpacity(0.3), width: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF22D3EE).withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF22D3EE), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n('ai_insight_title') ?? 'AI Rapor İçgörüsü', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF22D3EE))),
                const SizedBox(height: 6),
                Text(summaryText, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- FINANCE REPORT ---
  Widget _buildFinanceReport(String currency) {
    final asyncData = ref.watch(financialReportCacheProvider);

    return asyncData.when(
      data: (data) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context.l10n('total_income') ?? 'Toplam Gelir', CurrencyFormatter.format(data.totalIncome, context, currency), color: const Color(0xFF34D399), iconEmoji: '📈')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(context.l10n('total_expense') ?? 'Toplam Gider', CurrencyFormatter.format(data.totalExpense, context, currency), color: const Color(0xFFFB7185), iconEmoji: '📉')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context.l10n('net_balance') ?? 'Mevcut Bakiye', CurrencyFormatter.format(data.currentBalance, context, currency), color: const Color(0xFF38BDF8), iconEmoji: '💰')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(context.l10n('savings_rate') ?? 'Tasarruf Oranı', '%${(data.savingsRate * 100).toStringAsFixed(1)}', color: const Color(0xFFA78BFA), iconEmoji: '🛡️')),
                ],
              ),

              if (data.isEmpty)
                _buildEmptyState('📊', context.l10n('no_finance_data') ?? 'Henüz finans verisi bulunmuyor.', context.l10n('no_finance_data_desc') ?? 'Seçilen tarih aralığında herhangi bir gelir veya gider işlemi kaydedilmemiş.')
              else ...[
                const SizedBox(height: 24),
                _buildChartSection(context.l10n('expense_distribution_pie') ?? 'Gider Dağılımı (Pasta Grafik)', _buildPieChart(data.pieChartData)),
                const SizedBox(height: 24),
                _buildChartSection(context.l10n('cash_flow_trend_line') ?? 'Nakit Akış Trendi (Çizgi Grafik)', _buildLineChart(data.lineChartData)),
                const SizedBox(height: 24),
                _buildChartSection(context.l10n('income_expense_comparison') ?? 'Gelir / Gider Karşılaştırması', _buildBarChart(data.barChartData)),
              ],

              _buildAISummaryCard(data.aiSummary),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Hata: $e')),
    );
  }

  // --- DEBT REPORT ---
  Widget _buildDebtReport(String currency) {
    final asyncData = ref.watch(debtReportCacheProvider);

    return asyncData.when(
      data: (data) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context.l10n('active_debts_amount') ?? 'Toplam Borç', CurrencyFormatter.format(data.totalDebt, context, currency), color: const Color(0xFFFB7185), iconEmoji: '💳')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(context.l10n('total_credit') ?? 'Toplam Alacak', CurrencyFormatter.format(data.totalCredit, context, currency), color: const Color(0xFF34D399), iconEmoji: '📥')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context.l10n('collected_amount') ?? 'Tahsil Edilen', CurrencyFormatter.format(data.collectedAmount, context, currency), color: const Color(0xFF38BDF8), iconEmoji: '✅')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(context.l10n('pending_amount') ?? 'Bekleyen', CurrencyFormatter.format(data.pendingAmount, context, currency), color: const Color(0xFFFBBF24), iconEmoji: '⏳')),
                ],
              ),

              if (data.isEmpty)
                _buildEmptyState('📜', context.l10n('no_debt_data') ?? 'Borç/Alacak kaydı bulunmuyor.', context.l10n('no_debt_data_desc') ?? 'Bu dönemde takip edilen herhangi bir borç veya alacak işlemi yok.')
              else ...[
                const SizedBox(height: 24),
                _buildChartSection(context.l10n('debt_credit_distribution') ?? 'Borç / Alacak Dağılımı', _buildPieChart(data.distributionData)),
                const SizedBox(height: 24),
                _buildChartSection(context.l10n('collection_trend') ?? 'Tahsilat Trendi', _buildBarChart(data.collectionTrendData)),
              ],

              _buildAISummaryCard(data.aiSummary),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Hata: $e')),
    );
  }

  // --- GOAL REPORT ---
  Widget _buildGoalReport(String currency) {
    final asyncData = ref.watch(goalReportCacheProvider);

    return asyncData.when(
      data: (data) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context.l10n('active_goals_count') ?? 'Aktif Hedef', '${data.activeGoalsCount}', color: const Color(0xFF38BDF8), iconEmoji: '🎯')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(context.l10n('completed_label') ?? 'Tamamlanan', '${data.completedGoalsCount}', color: const Color(0xFF34D399), iconEmoji: '🏆')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildSummaryCard(context.l10n('completed_rate') ?? 'İlerleme Oranı', '%${(data.overallProgress * 100).toStringAsFixed(0)}', color: const Color(0xFFA78BFA), iconEmoji: '📈')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(context.l10n('total_savings') ?? 'Toplam Birikim', CurrencyFormatter.format(data.totalSavings, context, currency), color: const Color(0xFF60A5FA), iconEmoji: '💎')),
                ],
              ),

              if (data.isEmpty)
                _buildEmptyState('🎯', context.l10n('no_goal_data') ?? 'Kayıtlı hedef bulunmuyor.', context.l10n('no_goal_data_desc') ?? 'Henüz birikim veya harcama hedefi belirlememişsiniz.')
              else ...[
                const SizedBox(height: 24),
                _buildChartSection(context.l10n('goal_progress_status') ?? 'Hedef İlerleme Durumları', _buildBarChart(data.progressCurveData)),
              ],

              _buildAISummaryCard(data.aiSummary),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Hata: $e')),
    );
  }

  // --- HEALTH REPORT ---
  Widget _buildHealthReport(String subCategory, String currency) {
    final asyncData = ref.watch(healthReportCacheProvider);

    return asyncData.when(
      data: (healthData) {
        switch (subCategory) {
          case 'water':
            final data = healthData.water;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('daily_average') ?? 'Günlük Ortalama', '${data.dailyAverage.toStringAsFixed(1)} L', color: const Color(0xFF38BDF8), iconEmoji: '💧')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('total_consumption') ?? 'Toplam Tüketim', '${data.totalWater.toStringAsFixed(1)} L', color: const Color(0xFF60A5FA), iconEmoji: '🚰')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('goal_success') ?? 'Hedef Başarı', '%${(data.goalSuccessRate * 100).toStringAsFixed(0)}', color: const Color(0xFF34D399), iconEmoji: '🎯')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('streak_label') ?? 'Streak', '${data.streak} ${context.l10n('days_label') ?? 'Gün'}', color: const Color(0xFFFBBF24), iconEmoji: '🔥')),
                    ],
                  ),

                  if (data.isEmpty)
                    _buildEmptyState('💧', context.l10n('no_water_data') ?? 'Su kaydı eklenmedi.', context.l10n('no_water_data_desc') ?? 'Bu tarih aralığında su tüketim verisi bulunmuyor.')
                  else ...[
                    const SizedBox(height: 24),
                    _buildChartSection(context.l10n('weekly_consumption_trend') ?? 'Haftalık Tüketim Trendi', _buildBarChart(data.weeklyTrendData)),
                  ],

                  _buildAISummaryCard(data.aiSummary),
                ],
              ),
            );

          case 'sport':
            final data = healthData.sport;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('total_activity') ?? 'Toplam Aktivite', '${data.totalActivities}', color: const Color(0xFF34D399), iconEmoji: '🏃')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('active_days') ?? 'Aktif Gün', '${data.activeDays}', color: const Color(0xFF38BDF8), iconEmoji: '📅')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('total_duration') ?? 'Toplam Süre', '${data.totalDurationMinutes} dk', color: const Color(0xFFA78BFA), iconEmoji: '⏱️')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('success_rate') ?? 'Başarı Oranı', '%${(data.successRate * 100).toStringAsFixed(0)}', color: const Color(0xFF60A5FA), iconEmoji: '⭐')),
                    ],
                  ),

                  if (data.isEmpty)
                    _buildEmptyState('🏃', context.l10n('no_sport_data') ?? 'Spor kaydı bulunmuyor.', context.l10n('no_sport_data_desc') ?? 'Seçilen aralıkta egzersiz aktivitesi kaydedilmemiş.')
                  else ...[
                    const SizedBox(height: 24),
                    _buildChartSection(context.l10n('activity_trend_min') ?? 'Aktivite Trendi (dk)', _buildLineChart(data.activityTrendData)),
                  ],

                  _buildAISummaryCard(data.aiSummary),
                ],
              ),
            );

          case 'smoking':
            final data = healthData.smoking;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('smoked_count') ?? 'İçilen Adet', '${data.smokedCount}', color: const Color(0xFFFB923C), iconEmoji: '🚬')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('reduction_rate') ?? 'Azalma Oranı', '%${(data.reductionRate * 100).toStringAsFixed(0)}', color: const Color(0xFF34D399), iconEmoji: '📉')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('smoke_free_days') ?? 'Sigarasız Gün', '${data.smokeFreeDays}', color: const Color(0xFF38BDF8), iconEmoji: '✨')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('savings_label') ?? 'Tasarruf', CurrencyFormatter.format(data.savings, context, currency), color: const Color(0xFF60A5FA), iconEmoji: '💰')),
                    ],
                  ),

                  if (data.isEmpty)
                    _buildEmptyState('🚭', context.l10n('no_smoking_data') ?? 'Sigara modülü aktif değil.', context.l10n('no_smoking_data_desc') ?? 'Sigara takip verisi bulunamadı.')
                  else ...[
                    const SizedBox(height: 24),
                    _buildChartSection(context.l10n('consumption_curve') ?? 'Tüketim Eğrisi', _buildLineChart(data.reductionCurveData)),
                  ],

                  _buildAISummaryCard(data.aiSummary),
                ],
              ),
            );

          case 'medicine':
            final data = healthData.medicine;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('taken_doses') ?? 'Alınan Doz', '${data.takenCount}', color: const Color(0xFF34D399), iconEmoji: '💊')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('missed_doses') ?? 'Kaçırılan', '${data.missedCount}', color: const Color(0xFFFB7185), iconEmoji: '⚠️')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard(context.l10n('compliance_rate') ?? 'Uyum Oranı', '%${(data.complianceRate * 100).toStringAsFixed(0)}', color: const Color(0xFF38BDF8), iconEmoji: '📈')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard(context.l10n('stock_status') ?? 'Stok Durumu', data.stockStatus, color: const Color(0xFFA78BFA), iconEmoji: '📦')),
                    ],
                  ),

                  if (data.isEmpty)
                    _buildEmptyState('💊', context.l10n('no_med_data') ?? 'İlaç kaydı bulunmuyor.', context.l10n('no_med_data_desc') ?? 'Bu dönemde alınmış veya kaçırılmış ilaç kaydı yok.')
                  else ...[
                    const SizedBox(height: 24),
                    _buildChartSection(context.l10n('med_compliance_chart') ?? 'İlaç Uyum Grafiği', _buildPieChart(data.complianceChartData)),
                  ],

                  _buildAISummaryCard(data.aiSummary),
                ],
              ),
            );

          default:
            return Center(child: Text(context.l10n('unknown_sub_category') ?? 'Bilinmeyen Alt Kategori'));
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Hata: $e')),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildSummaryCard(String title, String value, {required Color color, String? iconEmoji}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54), overflow: TextOverflow.ellipsis)),
              if (iconEmoji != null) Text(iconEmoji, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildChartSection(String title, Widget chart) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 24),
          SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }

  // --- CHARTS BUILDERS ---
  Widget _buildPieChart(List<ChartData> data) {
    if (data.isEmpty) return Center(child: Text(context.l10n('no_chart_data') ?? 'Veri Yok'));
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        sections: data.map((d) {
          return PieChartSectionData(
            color: d.color,
            value: d.value,
            title: context.l10n(d.label.toLowerCase()) ?? d.label,
            radius: 45,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart(List<ChartData> data) {
    if (data.isEmpty) return Center(child: Text(context.l10n('no_chart_data') ?? 'Veri Yok'));
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].value));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(context.l10n(data[index].label.toLowerCase()) ?? data[index].label, style: const TextStyle(fontSize: 9, color: Colors.white54)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF38BDF8),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [const Color(0xFF38BDF8).withOpacity(0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<ChartData> data) {
    if (data.isEmpty) return Center(child: Text(context.l10n('no_chart_data') ?? 'Veri Yok'));
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.fold(0.0, (maxVal, d) => d.value > maxVal ? d.value : maxVal) * 1.2,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(context.l10n(data[index].label.toLowerCase()) ?? data[index].label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[index].value,
                color: data[index].color,
                width: 16,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }
}
