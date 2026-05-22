import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/finance_service.dart';
import '../models/finance_models.dart';
import '../../../core/localization/app_localizations.dart';

class PaymentMethodManagementScreen extends ConsumerStatefulWidget {
  const PaymentMethodManagementScreen({super.key});

  @override
  ConsumerState<PaymentMethodManagementScreen> createState() => _PaymentMethodManagementScreenState();
}

class _PaymentMethodManagementScreenState extends ConsumerState<PaymentMethodManagementScreen> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _statementDayController = TextEditingController();
  String _selectedIcon = '💳';
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n('accounts_title')),
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
      body: paymentMethodsAsync.when(
        data: (methods) {
          if (methods.isEmpty) {
            return Center(
              child: Text(
                context.l10n('no_payment_methods'),
                style: const TextStyle(color: Colors.white38),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: methods.length,
            itemBuilder: (context, index) {
              final method = methods[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(method.icon, style: const TextStyle(fontSize: 20)),
                    ),
                    title: Text(method.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.l10n('opening_balance_label')}: ${method.openingBalance.toStringAsFixed(2)} ₺',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        if (method.type == AccountType.credit_card && method.statementDay != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${context.l10n('statement_day_prefix') ?? 'Son Ödeme'}: Her ayın ${method.statementDay}. günü',
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                          onPressed: () => _showAddMethodDialog(context, initialMethod: method),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteMethod(method),
                        ),
                      ],
                    ),
                    onTap: () => _showAddMethodDialog(context, initialMethod: method),
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
        onPressed: () => _showAddMethodDialog(context),
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _deleteMethod(PaymentMethod method) async {
    final confirm = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('delete_account_title'),
      content: context.l10n('delete_account_confirm_msg'),
    );
    if (confirm) {
      await ref.read(financeServiceProvider).deletePaymentMethod(method.id);
      if (mounted) UIHelpers.showSuccessSnackBar(context, context.l10n('account_deleted_msg'));
    }
  }

  void _showAddMethodDialog(BuildContext context, {PaymentMethod? initialMethod}) {
    AccountType selectedType = initialMethod?.type ?? AccountType.bank;

    if (initialMethod != null) {
      _nameController.text = initialMethod.name;
      _openingBalanceController.text = initialMethod.openingBalance.toString();
      _statementDayController.text = initialMethod.statementDay?.toString() ?? '';
      _selectedIcon = initialMethod.icon;
    } else {
      _nameController.clear();
      _openingBalanceController.clear();
      _statementDayController.clear();
      _selectedIcon = '💳';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Text(
            initialMethod != null ? context.l10n('edit_account') : context.l10n('new_payment_method'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${context.l10n('account_type_label')}:', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<AccountType>(
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 9),
                      padding: EdgeInsets.zero,
                    ),
                    segments: [
                      ButtonSegment(value: AccountType.cash, label: Text(context.l10n('account_type_cash')), icon: const Icon(Icons.money, size: 12)),
                      ButtonSegment(value: AccountType.bank, label: Text(context.l10n('account_type_bank')), icon: const Icon(Icons.account_balance, size: 12)),
                      ButtonSegment(value: AccountType.credit_card, label: Text(context.l10n('account_type_credit_card')), icon: const Icon(Icons.credit_card, size: 12)),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (val) => setDialogState(() => selectedType = val.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: context.l10n('payment_method_name'),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _openingBalanceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: selectedType == AccountType.credit_card 
                          ? context.l10n('opening_balance_credit_hint') 
                          : context.l10n('opening_balance_label'),
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (selectedType == AccountType.credit_card) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _statementDayController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: context.l10n('statement_day_label') ?? 'Son Ödeme Günü (Örn: 15)',
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${context.l10n('select_icon_label')}:', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['💳', '💰', '🏦', '📱', '💵', '💸', '🏦', '💼'].map((e) => GestureDetector(
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
              child: Text(context.l10n('cancel').toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: _isSaving ? null : () async {
                if (_nameController.text.isNotEmpty) {
                  setDialogState(() => _isSaving = true);
                  final method = PaymentMethod(
                    id: initialMethod?.id ?? const Uuid().v4(),
                    name: _nameController.text,
                    icon: _selectedIcon,
                    openingBalance: double.tryParse(_openingBalanceController.text) ?? 0,
                    type: selectedType,
                    statementDay: selectedType == AccountType.credit_card ? int.tryParse(_statementDayController.text) : null,
                  );
                  await ref.read(financeServiceProvider).addPaymentMethod(method);
                  _nameController.clear();
                  _openingBalanceController.clear();
                  _statementDayController.clear();
                  if (mounted) {
                    UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                    Navigator.pop(context);
                  }
                  setDialogState(() => _isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: _isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Text(context.l10n('save').toUpperCase(), style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
