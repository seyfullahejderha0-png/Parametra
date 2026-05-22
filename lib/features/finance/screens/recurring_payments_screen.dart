import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/recurring_payment_model.dart';
import '../services/finance_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../profile/services/profile_service.dart';

class RecurringPaymentsScreen extends ConsumerStatefulWidget {
  const RecurringPaymentsScreen({super.key});

  @override
  ConsumerState<RecurringPaymentsScreen> createState() => _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends ConsumerState<RecurringPaymentsScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  RecurringPeriod _selectedPeriod = RecurringPeriod.monthly;
  String _selectedIcon = '📺';

  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(recurringPaymentsProvider);
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).value;
    final currencySymbol = CurrencyFormatter.getSymbol(profile?.preferredCurrency ?? 'TRY');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n('subscriptions_title')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: recurringAsync.when(
        data: (payments) {
          if (payments.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              final daysLeft = payment.nextPaymentDate.difference(DateTime.now()).inDays;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(payment.icon ?? '💳', style: const TextStyle(fontSize: 24)),
                    ),
                    title: Text(payment.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${payment.amount} $currencySymbol / ${payment.period == RecurringPeriod.monthly ? context.l10n('monthly') : context.l10n('yearly')}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.l10n('next_payment_label')}: ${DateFormat('dd MMM').format(payment.nextPaymentDate)}',
                          style: TextStyle(
                            color: daysLeft <= 3 ? Colors.orangeAccent : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (daysLeft >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: daysLeft <= 3 ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.l10n('days_left_label').replaceFirst('{days}', daysLeft.toString()),
                              style: TextStyle(
                                color: daysLeft <= 3 ? Colors.orangeAccent : Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteSubscription(payment),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.subscriptions_outlined, size: 80, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            context.l10n('no_subscriptions'),
            style: const TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddDialog(context),
            child: Text(context.l10n('add_first_subscription')),
          ),
        ],
      ),
    );
  }

  void _deleteSubscription(RecurringPayment payment) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('delete_subscription_title'),
      content: context.l10n('delete_subscription_confirm_msg'),
    );
    if (confirmed) {
      await ref.read(financeServiceProvider).deleteRecurringPayment(payment.id);
      if (mounted) UIHelpers.showSuccessSnackBar(context, context.l10n('subscription_deleted_msg'));
    }
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Text(context.l10n('add_first_subscription'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: context.l10n('subscription_name'),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                      hintText: context.l10n('subscription_name_hint'),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: context.l10n('recurring_amount'),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                      hintText: context.l10n('amount_hint'),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n('recurring_period_label'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            DropdownButton<RecurringPeriod>(
                              value: _selectedPeriod,
                              dropdownColor: const Color(0xFF1E293B),
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: RecurringPeriod.values.map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p == RecurringPeriod.monthly ? context.l10n('monthly') : context.l10n('yearly'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                              )).toList(),
                              onChanged: (v) => setDialogState(() => _selectedPeriod = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n('recurring_start_date_label'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setDialogState(() => _selectedDate = d);
                              },
                              child: Text(DateFormat('dd MMM').format(_selectedDate), style: const TextStyle(color: Colors.blueAccent, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${context.l10n('select_icon_label')}:', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['📺', '🎵', '🎮', '💡', '🛡️', '📦', '🏢', '☁️'].map((e) => GestureDetector(
                      onTap: () => setDialogState(() => _selectedIcon = e),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _selectedIcon == e ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          border: Border.all(color: _selectedIcon == e ? Colors.blue : Colors.white10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(context.l10n('cancel').toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12))
            ),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty && _amountController.text.isNotEmpty) {
                  final newPayment = RecurringPayment(
                    id: const Uuid().v4(),
                    name: _nameController.text,
                    amount: double.tryParse(_amountController.text) ?? 0,
                    currency: ref.read(userProfileProvider).value?.preferredCurrency ?? 'TRY',
                    period: _selectedPeriod,
                    nextPaymentDate: _selectedDate,
                    categoryId: 'subscription',
                    icon: _selectedIcon,
                  );
                  await ref.read(financeServiceProvider).addRecurringPayment(newPayment);
                  _nameController.clear();
                  _amountController.clear();
                  if (mounted) {
                    UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(context.l10n('save').toUpperCase(), style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
