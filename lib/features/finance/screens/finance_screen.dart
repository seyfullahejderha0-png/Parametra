import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/finance_service.dart';
import '../models/finance_models.dart';
import 'add_transaction_screen.dart';
import 'transfer_screen.dart';
import 'category_management_screen.dart';
import 'payment_method_management_screen.dart';
import 'recurring_payments_screen.dart';
import '../models/recurring_payment_model.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/services/subscription_service.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../profile/services/profile_service.dart';
import '../models/budget_model.dart';
import '../services/budget_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/privacy_provider.dart';
import '../../reports/models/report_models.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportDateFilter _transactionFilter = ReportDateFilter.month;
  DateTime? _transactionCustomStart;
  DateTime? _transactionCustomEnd;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('finance');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'finance',
          title: context.l10n('finance_intro_title'),
          description: context.l10n('finance_intro_desc'),
          imagePath: 'assets/images/onboarding_finance.png',
          themeColor: AppColors.financeColor,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionsAsync = ref.watch(actionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';
    final isPrivacy = ref.watch(privacyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('finance_mgmt')),
        actions: [
          IconButton(
            onPressed: () => ref.read(privacyProvider.notifier).toggle(),
            icon: Icon(
              isPrivacy ? Icons.visibility_off : Icons.visibility,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
          indicatorColor: Colors.blueAccent,
          tabs: [
            Tab(text: context.l10n('report'), icon: const Icon(Icons.pie_chart, size: 20)),
            Tab(text: context.l10n('income_expense_tab') ?? 'Gelir / Gider', icon: const Icon(Icons.swap_vert, size: 20)),
            Tab(text: context.l10n('transactions_tab'), icon: const Icon(Icons.list, size: 20)),
            Tab(text: context.l10n('budgets_tab') ?? 'Bütçeler', icon: const Icon(Icons.account_balance_wallet_outlined, size: 20)),
            Tab(text: context.l10n('management'), icon: const Icon(Icons.settings, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportTab(actionsAsync, categoriesAsync, paymentMethodsAsync, currency, isPrivacy),
          _buildIncomeExpenseTab(actionsAsync, categoriesAsync, currency, isPrivacy),
          _buildTransactionsTab(actionsAsync, categoriesAsync, currency, isPrivacy),
          _buildBudgetsTab(actionsAsync, categoriesAsync, currency, isPrivacy),
          _buildManagementTab(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: const Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('finance');
                    if (!canAdd && mounted) {
                      final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
                      if (isAnonymous) {
                        await UIHelpers.showGuestLimitDialog(
                          context: context,
                          title: Localizations.localeOf(context).languageCode == 'tr'
                              ? 'Verilerini Yedekle 🚀'
                              : 'Backup Your Data 🚀',
                          description: Localizations.localeOf(context).languageCode == 'tr'
                              ? 'Misafir modunda 3 işlem limitine ulaştın. Girdiğin finans hareketlerini kaybetmemek ve sınırsız devam etmek için hesabını şimdi kaydet!'
                              : 'You reached the limit of 3 entries as a guest. Save your account now to keep your financial records and unlock unlimited access!',
                        );
                        return;
                      }
                      UIHelpers.showErrorSnackBar(context, context.l10n('premium_needed_msg'));
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                      return;
                    }
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n('new_transaction_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('finance');
                    if (!canAdd && mounted) {
                      final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
                      if (isAnonymous) {
                        await UIHelpers.showGuestLimitDialog(
                          context: context,
                          title: Localizations.localeOf(context).languageCode == 'tr'
                              ? 'Verilerini Yedekle 🚀'
                              : 'Backup Your Data 🚀',
                          description: Localizations.localeOf(context).languageCode == 'tr'
                              ? 'Misafir modunda 3 işlem limitine ulaştın. Girdiğin finans hareketlerini kaybetmemek ve sınırsız devam etmek için hesabını şimdi kaydet!'
                              : 'You reached the limit of 3 entries as a guest. Save your account now to keep your financial records and unlock unlimited access!',
                        );
                        return;
                      }
                      UIHelpers.showErrorSnackBar(context, context.l10n('premium_needed_msg'));
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                      return;
                    }
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TransferScreen()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(context.l10n('transfer_btn') ?? 'Transfer Yap', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTab(
    AsyncValue<List<FinanceAction>> actionsAsync,
    AsyncValue<List<FinanceCategory>> categoriesAsync,
    AsyncValue<List<PaymentMethod>> paymentMethodsAsync,
    String currency,
    bool isPrivacy,
  ) {
    return actionsAsync.when(
      data: (actions) {
        return paymentMethodsAsync.when(
          data: (methods) {
            final expenseActions = actions.where((a) => a.type == FinanceType.expense && a.isBalanceEffect && a.isPureIncomeExpense).toList();
            final incomeActions = actions.where((a) => a.type == FinanceType.income && a.isBalanceEffect && a.isPureIncomeExpense).toList();
            
            final wealthExpenses = methods.where((m) => m.type == AccountType.credit_card).map((m) => m.id).toList();
            final filteredExpenseActions = expenseActions.where((a) => !wealthExpenses.contains(a.paymentMethodId)).toList();
            final filteredIncomeActions = incomeActions.where((a) => !wealthExpenses.contains(a.paymentMethodId)).toList();

            double totalExpense = filteredExpenseActions.fold(0.0, (sum, item) => sum + item.amount);
            double totalIncome = filteredIncomeActions.fold(0.0, (sum, item) => sum + item.amount);
            
            double totalOpening = methods
                .where((m) => m.type != AccountType.credit_card)
                .fold(0.0, (sum, item) => sum + item.openingBalance);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecurringSummary(),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: _buildBalanceSummary(totalIncome, totalExpense, totalOpening, currency, isPrivacy),
                  ),
                  const SizedBox(height: 24),
                  Text(context.l10n('income_expense_trend'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildTrendBarChart(actions, currency, isPrivacy),
                  const SizedBox(height: 24),
                  if (expenseActions.isNotEmpty) _buildExpensePieChart(expenseActions, categoriesAsync, currency, isPrivacy),
                  const SizedBox(height: 24),
                  _buildPaymentMethodBalances(actions, methods, currency, isPrivacy),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
    );
  }

  Widget _buildTrendBarChart(List<FinanceAction> actions, String currency, bool isPrivacy) {
    Map<int, double> monthlyIncomes = {};
    Map<int, double> monthlyExpenses = {};
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();

    for (var action in actions) {
      final diffMonths = (now.year - action.date.year) * 12 + now.month - action.date.month;
      if (diffMonths < 5 && action.isBalanceEffect && action.isPureIncomeExpense) {
        if (action.type == FinanceType.income) {
          monthlyIncomes[diffMonths] = (monthlyIncomes[diffMonths] ?? 0) + action.amount;
        } else {
          monthlyExpenses[diffMonths] = (monthlyExpenses[diffMonths] ?? 0) + action.amount;
        }
      }
    }

    double maxVal = 0;
    for (var val in monthlyIncomes.values) { if (val > maxVal) maxVal = val; }
    for (var val in monthlyExpenses.values) { if (val > maxVal) maxVal = val; }
    maxVal = (maxVal * 1.2).clamp(1000, double.infinity);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey.withOpacity(0.8),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    isPrivacy ? '*****' : CurrencyFormatter.format(rod.toY, context, currency),
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index > 4) return const SizedBox();
                    final monthDate = DateTime(now.year, now.month - index);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(DateFormat('MMM', locale).format(monthDate), style: const TextStyle(fontSize: 10, color: Colors.white54)),
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
            barGroups: List.generate(5, (index) {
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: monthlyIncomes[index] ?? 0,
                    width: 10,
                    gradient: const LinearGradient(colors: [Colors.greenAccent, Color(0xFF10B981)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                  ),
                  BarChartRodData(
                    toY: monthlyExpenses[index] ?? 0,
                    width: 10,
                    gradient: const LinearGradient(colors: [Colors.redAccent, Color(0xFFEF4444)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                  ),
                ],
              );
            }).reversed.toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSummary(double income, double expense, double totalOpening, String currency, bool isPrivacy) {
    final balance = (income + totalOpening) - expense;
    return Row(
      children: [
        Expanded(child: _balanceItem(context.l10n('income_label'), income, Colors.greenAccent, currency, isPrivacy)),
        Container(width: 1, height: 30, color: Colors.white10),
        Expanded(child: _balanceItem(context.l10n('expense_label'), expense, Colors.redAccent, currency, isPrivacy)),
        Container(width: 1, height: 30, color: Colors.white10),
        Expanded(child: _balanceItem(context.l10n('balance_label'), balance, Colors.blueAccent, currency, isPrivacy)),
      ],
    );
  }

  Widget _balanceItem(String label, double amount, Color color, String currency, bool isPrivacy) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 4),
        Text(
          isPrivacy ? '*****' : CurrencyFormatter.format(amount, context, currency),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildExpensePieChart(List<FinanceAction> actions, AsyncValue<List<FinanceCategory>> categoriesAsync, String currency, bool isPrivacy) {
    return categoriesAsync.when(
      data: (categories) {
        Map<String, double> categoryTotals = {};
        for (var action in actions) {
          final cat = categories.firstWhere((c) => c.id == action.categoryId, orElse: () => FinanceCategory(id: '', name: context.l10n('other_category'), emoji: '❓', type: FinanceType.expense));
          categoryTotals[cat.name] = (categoryTotals[cat.name] ?? 0) + action.amount;
        }

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(context.l10n('expense_distribution'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 30,
                    sections: categoryTotals.entries.map((e) {
                      final color = Colors.primaries[categoryTotals.keys.toList().indexOf(e.key) % Colors.primaries.length];
                      return PieChartSectionData(
                        value: e.value,
                        title: '',
                        color: color,
                        radius: 40,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...categoryTotals.entries.map((e) {
                final percentage = (e.value / actions.fold(0.0, (sum, a) => sum + a.amount) * 100).toStringAsFixed(1);
                final color = Colors.primaries[categoryTotals.keys.toList().indexOf(e.key) % Colors.primaries.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                      Text('%$percentage', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text(isPrivacy ? '*****' : CurrencyFormatter.format(e.value, context, currency), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, s) => Text(context.l10n('chart_error')),
    );
  }

  Widget _buildPaymentMethodBalances(List<FinanceAction> actions, List<PaymentMethod> methods, String currency, bool isPrivacy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n('accounts_balance') ?? 'Hesap Bakiyeleri', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...methods.map((method) {
          double methodBalance = method.openingBalance;
          for (var action in actions) {
            if (action.paymentMethodId == method.id && action.isBalanceEffect) {
              methodBalance += (action.type == FinanceType.income ? action.amount : -action.amount);
            }
          }
          final isCreditCard = method.type == AccountType.credit_card;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text(method.icon)),
              title: Text(method.name),
              subtitle: isCreditCard ? Text(context.l10n('account_type_credit_card'), style: const TextStyle(fontSize: 10, color: Colors.orangeAccent)) : null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPrivacy ? '*****' : CurrencyFormatter.format(methodBalance, context, currency), 
                    style: TextStyle(
                      color: isCreditCard ? Colors.orangeAccent : (methodBalance >= 0 ? Colors.greenAccent : Colors.redAccent), 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  if (isCreditCard) 
                    Text(context.l10n('card_debt_label') ?? 'Kart Borcu/Harcaması', style: const TextStyle(fontSize: 9, color: Colors.white54)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  bool _isWithinTransactionFilter(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_transactionFilter) {
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
        if (_transactionCustomStart == null || _transactionCustomEnd == null) return true;
        final start = DateTime(_transactionCustomStart!.year, _transactionCustomStart!.month, _transactionCustomStart!.day);
        final end = DateTime(_transactionCustomEnd!.year, _transactionCustomEnd!.month, _transactionCustomEnd!.day, 23, 59, 59);
        return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
               (date.isBefore(end) || date.isAtSameMomentAs(end));
    }
  }

  Widget _buildTransactionDateFilterBar() {
    final filters = [
      {'id': ReportDateFilter.today, 'label': context.l10n('filter_today') ?? 'Bugün'},
      {'id': ReportDateFilter.week, 'label': context.l10n('filter_week') ?? 'Bu Hafta'},
      {'id': ReportDateFilter.month, 'label': context.l10n('filter_month') ?? 'Bu Ay'},
      {'id': ReportDateFilter.last30, 'label': context.l10n('filter_last_30') ?? 'Son 30 Gün'},
      {'id': ReportDateFilter.custom, 'label': context.l10n('filter_custom') ?? 'Özel Aralık'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((f) {
          final filterType = f['id'] as ReportDateFilter;
          final isSelected = _transactionFilter == filterType;
          String label = f['label'] as String;

          if (filterType == ReportDateFilter.custom && isSelected && _transactionCustomStart != null && _transactionCustomEnd != null) {
            label = "${DateFormat('dd.MM').format(_transactionCustomStart!)} - ${DateFormat('dd.MM').format(_transactionCustomEnd!)}";
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
                    initialDateRange: _transactionCustomStart != null && _transactionCustomEnd != null
                        ? DateTimeRange(start: _transactionCustomStart!, end: _transactionCustomEnd!)
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
                    setState(() {
                      _transactionFilter = ReportDateFilter.custom;
                      _transactionCustomStart = picked.start;
                      _transactionCustomEnd = picked.end;
                    });
                  }
                } else {
                  setState(() {
                    _transactionFilter = filterType;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIncomeExpenseTab(AsyncValue<List<FinanceAction>> actionsAsync, AsyncValue<List<FinanceCategory>> categoriesAsync, String currency, bool isPrivacy) {
    return actionsAsync.when(
      data: (allActions) {
        final actions = allActions.where((a) => _isWithinTransactionFilter(a.date) && a.isPureIncomeExpense).toList();
        final locale = Localizations.localeOf(context).toString();

        return Column(
          children: [
            _buildTransactionDateFilterBar(),
            Expanded(
              child: actions.isEmpty
                  ? Center(child: Text(context.l10n('no_data')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: actions.length,
                      itemBuilder: (context, index) {
                        final action = actions[index];
                        return categoriesAsync.when(
                          data: (categories) {
                            final cat = categories.firstWhere((c) => c.id == action.categoryId, orElse: () => FinanceCategory(id: '', name: context.l10n('other_category'), emoji: '❓', type: FinanceType.expense));
                            return Card(
                              child: ListTile(
                                leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                                title: Text(action.description.isEmpty ? cat.name : action.description),
                                subtitle: Text(DateFormat('dd.MM.yyyy HH:mm', locale).format(action.date)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isPrivacy ? '*****' : '${action.type == FinanceType.income ? "+" : "-"}${CurrencyFormatter.format(action.amount, context, currency)}',
                                        style: TextStyle(
                                          color: action.type == FinanceType.income ? Colors.greenAccent : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAction: action)),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                      onPressed: () => _confirmDelete(context, ref, action.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, s) => Text('${context.l10n('error_label')}: $e'),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
    );
  }

  Widget _buildTransactionsTab(AsyncValue<List<FinanceAction>> actionsAsync, AsyncValue<List<FinanceCategory>> categoriesAsync, String currency, bool isPrivacy) {
    return actionsAsync.when(
      data: (allActions) {
        final actions = allActions.where((a) => _isWithinTransactionFilter(a.date) && !a.isPureIncomeExpense).toList();
        final locale = Localizations.localeOf(context).toString();

        return Column(
          children: [
            _buildTransactionDateFilterBar(),
            Expanded(
              child: actions.isEmpty
                  ? Center(child: Text(context.l10n('no_data')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: actions.length,
                      itemBuilder: (context, index) {
                        final action = actions[index];
                        return categoriesAsync.when(
                          data: (categories) {
                            final cat = categories.firstWhere((c) => c.id == action.categoryId, orElse: () => FinanceCategory(id: '', name: context.l10n('other_category'), emoji: '❓', type: FinanceType.expense));
                            return Card(
                              child: ListTile(
                                leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                                title: Text(action.description.isEmpty ? cat.name : action.description),
                                subtitle: Text(DateFormat('dd.MM.yyyy HH:mm', locale).format(action.date)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isPrivacy ? '*****' : '${action.type == FinanceType.income ? "+" : "-"}${CurrencyFormatter.format(action.amount, context, currency)}',
                                        style: TextStyle(
                                          color: action.type == FinanceType.income ? Colors.greenAccent : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => AddTransactionScreen(initialAction: action)),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                                      onPressed: () => _confirmDelete(context, ref, action.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, s) => Text('${context.l10n('error_label')}: $e'),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String actionId) async {
    final actions = ref.read(actionsProvider).value ?? [];
    final methods = ref.read(paymentMethodsProvider).value ?? [];
    final actionToDelete = actions.firstWhere((a) => a.id == actionId);

    if (actionToDelete.type == FinanceType.income && actionToDelete.isBalanceEffect) {
      final method = methods.firstWhere((m) => m.id == actionToDelete.paymentMethodId);
      if (method.type != AccountType.credit_card) {
        double currentBalance = method.openingBalance;
        for (var action in actions) {
          if (action.paymentMethodId == method.id && action.isBalanceEffect) {
            currentBalance += (action.type == FinanceType.income ? action.amount : -action.amount);
          }
        }
        if (currentBalance - actionToDelete.amount < 0) {
          UIHelpers.showErrorSnackBar(context, context.l10n('insufficient_balance_delete') ?? 'Bu geliri silemezsiniz, hesap bakiyesi eksiye düşüyor!');
          return;
        }
      }
    }

    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('confirm_delete'),
      content: context.l10n('confirm_delete_msg'),
    );

    if (confirmed) {
      await ref.read(financeServiceProvider).deleteAction(actionId);
      if (context.mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('transaction_deleted_msg'));
      }
    }
  }

  DateTime _selectedMonth = DateTime.now();

  Widget _buildBudgetsTab(
    AsyncValue<List<FinanceAction>> actionsAsync,
    AsyncValue<List<FinanceCategory>> categoriesAsync,
    String currency,
    bool isPrivacy,
  ) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    final locale = Localizations.localeOf(context).toString();
    final displayMonth = DateFormat('MMMM yyyy', locale).format(_selectedMonth);

    return categoriesAsync.when(
      data: (categories) => budgetsAsync.when(
        data: (budgets) => actionsAsync.when(
          data: (actions) {
            final expenseCategories = categories.where((c) => c.type == FinanceType.expense).toList();
            
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.white.withOpacity(0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
                      ),
                      Text(
                        displayMonth.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        context.l10n('monthly_budgets_desc') ?? 'Kategori bazlı aylık bütçelerini buradan yönetebilirsin.',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ...expenseCategories.map((cat) {
                        final budget = budgets.firstWhere(
                          (b) => b.categoryId == cat.id && b.month == monthStr, 
                          orElse: () => Budget(id: '', categoryId: cat.id, limitAmount: 0, month: monthStr, createdAt: DateTime.now())
                        );
                        final currentSpend = actions
                            .where((a) => a.categoryId == cat.id && DateFormat('yyyy-MM').format(a.date) == monthStr && a.type == FinanceType.expense)
                            .fold(0.0, (sum, a) => sum + a.amount);
                        
                        final hasBudget = budget.limitAmount > 0;
                        final progress = hasBudget ? (currentSpend / budget.limitAmount).clamp(0.0, 1.0) : 0.0;
                        final color = progress > 0.9 ? Colors.redAccent : (progress > 0.7 ? Colors.orangeAccent : Colors.greenAccent);

                        return InkWell(
                          onTap: () => _showBudgetDialog(cat, hasBudget ? budget : null, currency, monthStr),
                          borderRadius: BorderRadius.circular(16),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                                          const SizedBox(width: 12),
                                          Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Icon(
                                        hasBudget ? Icons.edit : Icons.add_circle_outline, 
                                        color: Colors.blueAccent.withOpacity(0.5), 
                                        size: 18
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (hasBudget) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isPrivacy ? '***** / *****' : '${CurrencyFormatter.format(currentSpend, context, currency)} / ${CurrencyFormatter.format(budget.limitAmount, context, currency)}',
                                          style: TextStyle(
                                            fontSize: 12, 
                                            color: currentSpend > budget.limitAmount ? Colors.redAccent : Colors.white70,
                                            fontWeight: currentSpend > budget.limitAmount ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        Text(
                                          '%${(progress * 100).toInt()}', 
                                          style: TextStyle(
                                            fontSize: 12, 
                                            color: currentSpend > budget.limitAmount ? Colors.red : color, 
                                            fontWeight: FontWeight.bold
                                          )
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.white10,
                                        color: currentSpend > budget.limitAmount ? Colors.red : color,
                                        minHeight: 8,
                                      ),
                                    ),
                                    if (currentSpend > budget.limitAmount)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          context.l10n('budget_exceeded') ?? 'Bütçe aşıldı!',
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ] else 
                                    Text(
                                      context.l10n('tap_to_set_budget') ?? 'Bütçe girilmedi. Tanımlamak için dokun.', 
                                      style: const TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic)
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Text('Error: $e'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('Error: $e'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }

  void _showBudgetDialog(FinanceCategory category, Budget? existingBudget, String currency, String monthStr) {
    final controller = TextEditingController(text: existingBudget?.limitAmount.toStringAsFixed(0) ?? '');
    final symbol = CurrencyFormatter.getSymbol(currency);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${category.emoji} ${category.name} ${context.l10n('budget_label') ?? 'Bütçesi'}', style: const TextStyle(fontSize: 18, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('MMMM yyyy', Localizations.localeOf(context).toString()).format(DateFormat('yyyy-MM').parse(monthStr))} ayı için limit belirleyin.',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.l10n('limit_amount') ?? 'Limit Tutarı',
                labelStyle: const TextStyle(color: Colors.white70),
                suffixText: symbol,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              final budget = Budget(
                id: existingBudget?.id.isNotEmpty == true ? existingBudget!.id : const Uuid().v4(),
                categoryId: category.id,
                limitAmount: amount,
                month: monthStr,
                createdAt: DateTime.now(),
              );
              await ref.read(budgetServiceProvider).setBudget(budget);
              if (mounted) Navigator.pop(context);
            },
            child: Text(context.l10n('save')),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _managementTile(
          context.l10n('manage_expense_cats'),
          '',
          Icons.shopping_cart_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoryManagementScreen(type: FinanceType.expense))),
        ),
        _managementTile(
          context.l10n('manage_income_cats'),
          '',
          Icons.payments_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoryManagementScreen(type: FinanceType.income))),
        ),
        _managementTile(
          context.l10n('manage_accounts') ?? 'Hesaplarımı Yönet',
          '',
          Icons.account_balance_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentMethodManagementScreen())),
        ),
        _managementTile(
          context.l10n('manage_subscriptions'),
          '',
          Icons.subscriptions_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RecurringPaymentsScreen())),
        ),
      ],
    );
  }

  Widget _buildRecurringSummary() {
    final isPrivacy = ref.watch(privacyProvider);
    final recurringAsync = ref.watch(recurringPaymentsProvider);
    return recurringAsync.when(
      data: (payments) {
        if (payments.isEmpty) return const SizedBox.shrink();
        final sorted = List<RecurringPayment>.from(payments)
          ..sort((a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate));
        final next = sorted.first;
        final daysLeft = next.nextPaymentDate.difference(DateTime.now()).inDays;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RecurringPaymentsScreen())),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(next.icon ?? '📺', style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n('upcoming_payment') ?? 'Yaklaşan Ödeme', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(next.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$daysLeft ${context.l10n('days_label')}', style: TextStyle(color: daysLeft <= 3 ? Colors.orangeAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
                      Text(isPrivacy ? '*****' : '${next.amount} ₺', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _managementTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.blueAccent),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)) : null,
          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        ),
      ),
    );
  }
}
