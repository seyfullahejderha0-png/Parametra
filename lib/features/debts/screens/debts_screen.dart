import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/glass_card.dart';
import '../widgets/debt_report_widget.dart';
import '../services/debt_service.dart';
import '../models/debt_model.dart';
import 'add_debt_screen.dart';
import 'debt_detail_screen.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/services/subscription_service.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../finance/services/finance_service.dart';
import '../../finance/models/finance_models.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('debt');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'debt',
          title: context.l10n('debt_intro_title'),
          description: context.l10n('debt_intro_desc'),
          imagePath: 'assets/images/onboarding_debt.png',
          themeColor: AppColors.debtColor,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final profileAsync = ref.watch(userProfileProvider);
    
    // Sadece kullanıcının seçtiği para birimini kullan
    final baseCurrency = profileAsync.value?.preferredCurrency ?? 'TRY';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n('debts_credits')),
          bottom: TabBar(
            indicatorColor: Colors.orangeAccent,
            tabs: [
              Tab(text: context.l10n('debts_loans_tab')),
              Tab(text: context.l10n('receivables_tab')),
            ],
          ),
        ),
        body: SafeArea(
          child: debtsAsync.when(
            data: (debts) {
              return Column(
                children: [
                  DebtReportWidget(debts: debts, currencyCode: baseCurrency),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDebtList(debts, [DebtType.borc, DebtType.kredi, DebtType.credit_card], context),
                        _buildDebtList(debts, [DebtType.alacak], context),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('debts');
            if (!canAdd && mounted) {
              UIHelpers.showErrorSnackBar(context, context.l10n('form_error_msg'));
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
              return;
            }
            if (mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddDebtScreen()));
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildDebtList(List<Debt> allDebts, List<DebtType> types, BuildContext context) {
    final filteredDebts = allDebts.where((d) => types.contains(d.type)).toList();
    final Map<String, List<Debt>> groupedByParent = {};
    final List<Debt> displayList = [];

    for (var d in filteredDebts) {
      if (d.parentId == null) {
        displayList.add(d);
      } else {
        if (!groupedByParent.containsKey(d.parentId)) {
          groupedByParent[d.parentId!] = [];
          displayList.add(d);
        }
        groupedByParent[d.parentId!]!.add(d);
      }
    }

    if (displayList.isEmpty) {
      return Center(child: Text(context.l10n('no_records_yet')));
    }

    return ListView.builder(
      itemCount: displayList.length,
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemBuilder: (context, index) {
        final representative = displayList[index];
        if (representative.parentId == null) {
          return _buildDebtItem(context, ref, representative);
        } else {
          final installments = groupedByParent[representative.parentId!]!;
          return _buildGroupedDebtItem(context, ref, installments);
        }
      }
    );
  }

  Widget _buildGroupedDebtItem(BuildContext context, WidgetRef ref, List<Debt> installments) {
    final representative = installments.first;
    final currency = representative.currency;
    final isBorc = representative.type == DebtType.borc || representative.type == DebtType.kredi;
    
    double totalAmount = 0;
    double totalPaid = 0;
    int paidCount = 0;
    
    for (var d in installments) {
      totalAmount += d.amount;
      totalPaid += d.paidAmount;
      if (d.isPaid) paidCount++;
    }
    
    final remaining = totalAmount - totalPaid;
    final allPaid = paidCount == installments.length;

    DateTime? firstDate;
    DateTime? lastDate;
    if (installments.isNotEmpty) {
      final sortedDates = installments.map((d) => d.dueDate).where((d) => d != null).cast<DateTime>().toList();
      if (sortedDates.isNotEmpty) {
        sortedDates.sort();
        firstDate = sortedDates.first;
        lastDate = sortedDates.last;
      }
    }

    return Opacity(
      opacity: allPaid ? 0.6 : 1.0,
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => DebtDetailScreen(parentId: representative.parentId!))
          ),
          leading: CircleAvatar(
            backgroundColor: isBorc ? Colors.redAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
            child: Icon(
              (representative.type == DebtType.kredi || representative.type == DebtType.credit_card) ? Icons.credit_card : (isBorc ? Icons.arrow_outward : Icons.arrow_downward),
              color: isBorc ? Colors.redAccent : Colors.blueAccent,
            ),
          ),
          title: Text(
            representative.personName,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${CurrencyFormatter.format(remaining, context, currency)} (${context.l10n('remaining_label')})', style: const TextStyle(fontSize: 12)),
              if (firstDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 11, color: Colors.orangeAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${context.l10n('first_installment_date') ?? 'İlk Taksit'}: ${DateFormat('dd.MM.yyyy').format(firstDate)}',
                          style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (lastDate != null && firstDate != lastDate)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 11, color: Colors.orangeAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${context.l10n('last_installment_date') ?? 'Son Taksit'}: ${DateFormat('dd.MM.yyyy').format(lastDate)}',
                          style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Text(
                    context.l10n('installments_paid_label')
                      .replaceFirst('{paid}', paidCount.toString())
                      .replaceFirst('{total}', installments.length.toString()),
                    style: TextStyle(fontSize: 11, color: allPaid ? Colors.greenAccent : Colors.white60),
                  ),
                  if (allPaid) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                  ],
                ],
              ),
            ],
          ),
          trailing: SizedBox(
            width: 70, // Fixed width for trailing to prevent overflow
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmDeleteGrouped(context, ref, representative.parentId!),
                ),
                const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteGrouped(BuildContext context, WidgetRef ref, String parentId) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('delete_all_installments'),
      content: context.l10n('delete_all_installments_msg'),
      confirmText: context.l10n('delete_all_btn'),
    );

    if (confirmed) {
      await ref.read(debtServiceProvider).deleteGroupedDebts(parentId);
      if (context.mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('all_installments_deleted'));
      }
    }
  }

  Widget _buildDebtItem(BuildContext context, WidgetRef ref, Debt debt) {
    final isBorc = debt.type == DebtType.borc || debt.type == DebtType.kredi;
    final currency = debt.currency; // Use the currency of the debt

    return Opacity(
      opacity: debt.isPaid ? 0.5 : 1.0,
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: () => _showDebtDetails(context, ref, debt, currency),
          leading: CircleAvatar(
            backgroundColor: isBorc ? Colors.redAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
            child: Icon(
              (debt.type == DebtType.kredi || debt.type == DebtType.credit_card) ? Icons.credit_card : (isBorc ? Icons.arrow_outward : Icons.arrow_downward),
              color: isBorc ? Colors.redAccent : Colors.blueAccent,
            ),
          ),
          title: Text(
            debt.personName,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${CurrencyFormatter.format(debt.remainingAmount, context, currency)} (${context.l10n('remaining_label')})', style: const TextStyle(fontSize: 12)),
              if (debt.dueDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(debt.type == DebtType.alacak ? Icons.event_available : Icons.event_busy, size: 11, color: debt.type == DebtType.alacak ? Colors.greenAccent : Colors.orangeAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          debt.type == DebtType.credit_card 
                            ? '${context.l10n('statement_day_prefix') ?? 'Son Ödeme'}: Her ayın ${debt.dueDate!.day}. günü'
                            : '${debt.type == DebtType.alacak ? (context.l10n('collection_due_date') ?? 'Tahsilat Vadesi') : (context.l10n('payment_due_date') ?? context.l10n('due_date_label') ?? 'Ödeme Vadesi')}: ${DateFormat('dd.MM.yyyy').format(debt.dueDate!)}',
                          style: TextStyle(fontSize: 11, color: debt.type == DebtType.alacak ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (debt.paidAmount > 0)
                Text(
                  '${context.l10n('paid_label')}: ${CurrencyFormatter.format(debt.paidAmount, context, currency)}',
                  style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(debt.isPaid ? Icons.check_circle : Icons.payment, color: debt.isPaid ? Colors.greenAccent : Colors.blueAccent),
            onPressed: debt.isPaid ? null : () => _showPaymentDialog(context, ref, debt, currency),
          ),
        ),
      ),
    );
  }

  void _showDebtDetails(BuildContext context, WidgetRef ref, Debt debt, String currency) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        title: Text(debt.personName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(context.l10n('type_label'), debt.type == DebtType.credit_card ? context.l10n('account_type_credit_card') : (debt.type == DebtType.kredi ? context.l10n('loan_label') : (debt.type == DebtType.borc ? context.l10n('debt_label') : context.l10n('receivable_label')))),
            _detailRow(context.l10n('total_amount_label'), CurrencyFormatter.format(debt.amount, context, currency)),
            _detailRow(context.l10n('paid_amount_label'), CurrencyFormatter.format(debt.paidAmount, context, currency)),
            _detailRow(context.l10n('remaining_amount_label'), CurrencyFormatter.format(debt.remainingAmount, context, currency)),
            if (debt.exchangeRate != 1.0) ...[
              _detailRow(context.l10n('rate_label'), debt.exchangeRate.toString()),
            ],
            if (debt.totalInstallments > 1)
              _detailRow(context.l10n('installment_label'), '${debt.currentInstallment} / ${debt.totalInstallments}'),
            if (debt.dueDate != null)
              _detailRow(context.l10n('due_date_label'), DateFormat('dd.MM.yyyy').format(debt.dueDate!)),
            _detailRow(context.l10n('status_label'), debt.isPaid ? context.l10n('fully_paid') : context.l10n('waiting_payment')),
          ],
        ),
        actions: [
          if (debt.type != DebtType.credit_card)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, debt.id);
              },
              child: Text(context.l10n('delete_label'), style: const TextStyle(color: Colors.redAccent)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
          if (!debt.isPaid && debt.type != DebtType.credit_card)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showPaymentDialog(context, ref, debt, currency);
              },
              child: Text(debt.type == DebtType.alacak ? context.l10n('collect_btn') : context.l10n('make_payment_btn')),
            ),
          if (debt.type == DebtType.credit_card)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                context.l10n('credit_card_sync_msg'), 
                style: TextStyle(fontSize: 10, color: Colors.orangeAccent.withOpacity(0.7), fontStyle: FontStyle.italic)
              ),
            ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, Debt debt, String currency) {
    final controller = TextEditingController(text: debt.remainingAmount.toString());
    String? localPaymentMethodId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.1))),
            title: Text(debt.type == DebtType.alacak ? context.l10n('enter_collection') : context.l10n('enter_payment')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${context.l10n('remaining_amount_label')}: ${CurrencyFormatter.format(debt.remainingAmount, context, currency)}'),
                const SizedBox(height: 16),
                // ÖDEME ARACI SEÇİMİ
                ref.watch(paymentMethodsWithBalanceProvider).when(
                  data: (methods) {
                    if (methods.isNotEmpty) {
                      if (localPaymentMethodId == null || !methods.any((m) => m.id == localPaymentMethodId)) {
                        localPaymentMethodId = methods.first.id;
                      }
                    }
                    return DropdownButtonFormField<String>(
                      value: localPaymentMethodId,
                      dropdownColor: AppColors.surface,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n('payment_method_label'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: methods.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(
                          '${m.icon} ${m.name} (${CurrencyFormatter.format(m.currentBalance ?? 0, context, debt.currency)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => localPaymentMethodId = val),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${context.l10n('amount_to_pay_label')} (${debt.currency})',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final payAmount = double.tryParse(controller.text) ?? 0;
                  if (payAmount <= 0 || payAmount > debt.remainingAmount || localPaymentMethodId == null) {
                    UIHelpers.showErrorSnackBar(context, localPaymentMethodId == null ? context.l10n('select_payment_method') : context.l10n('invalid_amount_msg'));
                    return;
                  }

                  final updatedDebt = debt.copyWith(
                    paidAmount: debt.paidAmount + payAmount,
                    isPaid: (debt.paidAmount + payAmount) >= debt.amount - 0.01, // Küçük bir pay bırakalım
                  );

                  await ref.read(debtServiceProvider).updateDebt(updatedDebt);
                  
                  // FİNANS ENTEGRASYONU
                  final isCollection = debt.type == DebtType.alacak; // Alacak tahsilatı -> Gelir
                  await ref.read(financeServiceProvider).addFinanceAction(FinanceAction(
                    id: Uuid().v4(),
                    categoryId: isCollection ? 'cat_other_in' : 'cat_other_ex',
                    paymentMethodId: localPaymentMethodId!,
                    amount: payAmount,
                    date: DateTime.now(),
                    description: '${context.l10n(isCollection ? 'enter_collection' : 'enter_payment')}: ${debt.personName}',
                    type: isCollection ? FinanceType.income : FinanceType.expense,
                  ));

                  if (context.mounted) {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                    UIHelpers.showSuccessSnackBar(context, context.l10n('payment_recorded_msg').replaceFirst('{amount}', CurrencyFormatter.format(payAmount, context, currency)));
                  }
                },
                child: Text(context.l10n('save')),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('reset_confirm_title'),
      content: context.l10n('delete_all_installments_msg'),
    );

    if (confirmed) {
      await ref.read(debtServiceProvider).deleteDebt(id);
      if (context.mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('record_deleted_msg'));
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
