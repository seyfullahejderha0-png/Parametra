import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/goal_model.dart';
import '../services/goal_service.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../finance/services/finance_service.dart';
import '../../finance/models/finance_models.dart';
import '../../../core/localization/app_localizations.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();
  DateTime? _deadline;
  String? _selectedPaymentMethodId;
  bool _isBalanceEffect = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  void _saveGoal() async {
    final title = _titleController.text;
    final target = double.tryParse(_targetController.text.replaceAll(',', '.'));
    final current = double.tryParse(_currentController.text.replaceAll(',', '.')) ?? 0;

    if (title.isEmpty || target == null || target <= 0) {
      UIHelpers.showErrorSnackBar(context, context.l10n('enter_title_content_msg'));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Bakiye Kontrolü (Eğer başlangıç birikimi varsa ve bakiye etkiliyse)
      if (current > 0 && _selectedPaymentMethodId != null && _isBalanceEffect) {
        final methods = ref.read(paymentMethodsWithBalanceProvider).value ?? [];
        final method = methods.firstWhere((m) => m.id == _selectedPaymentMethodId);
        
        // Sadece kredi kartı değilse kontrol et
        if (method.type != AccountType.credit_card) {
          if ((method.currentBalance ?? 0) < current) {
            setState(() => _isSaving = false);
            UIHelpers.showErrorSnackBar(context, context.l10n('insufficient_balance'));
            return;
          }
        }
      }

      final goalId = Uuid().v4();
      final newGoal = Goal(
        id: goalId,
        title: title,
        targetAmount: target,
        currentAmount: current,
        deadline: _deadline,
        category: context.l10n('general_category'),
      );

      await ref.read(goalServiceProvider).addGoal(newGoal);

      // FİNANS ENTEGRASYONU (Başlangıç birikimi varsa kaydet)
      if (current > 0 && _selectedPaymentMethodId != null && _isBalanceEffect) {
        await ref.read(financeServiceProvider).addFinanceAction(FinanceAction(
          id: Uuid().v4(),
          categoryId: 'cat_goal_savings',
          paymentMethodId: _selectedPaymentMethodId!,
          amount: current,
          date: DateTime.now(),
          description: '${context.l10n('add_new_goal_title')}: $title',
          type: FinanceType.expense,
          isBalanceEffect: true,
        ));
      }
      if (mounted) {
        FocusScope.of(context).unfocus();
        UIHelpers.showSuccessSnackBar(context, context.l10n('goal_updated_msg'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';
    final symbol = CurrencyFormatter.getSymbol(currency);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('add_new_goal_title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.l10n('goal_name_label'),
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${context.l10n('target_amount_label')} ($symbol)',
                  prefixIcon: const Icon(Icons.track_changes),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _currentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${context.l10n('current_savings_label')} ($symbol)',
                  prefixIcon: const Icon(Icons.savings_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              // ÖDEME ARACI SEÇİMİ
              ref.watch(paymentMethodsWithBalanceProvider).when(
                data: (methods) {
                  if (methods.isNotEmpty && _selectedPaymentMethodId == null) {
                    _selectedPaymentMethodId = methods.first.id;
                  }
                  return DropdownButtonFormField<String>(
                    value: _selectedPaymentMethodId,
                    dropdownColor: const Color(0xFF1E293B),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.l10n('payment_method_label'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: methods.map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(
                        '${m.icon} ${m.name} (${CurrencyFormatter.format(m.currentBalance ?? 0, context, 'TRY')})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedPaymentMethodId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(_deadline == null 
                  ? context.l10n('goal_date_not_selected') 
                  : context.l10n('goal_date_label').replaceFirst('{date}', DateFormat('dd.MM.yyyy').format(_deadline!))),
                leading: const Icon(Icons.calendar_month),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.white10),
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (date != null) setState(() => _deadline = date);
                },
              ),
              const SizedBox(height: 16),
              // Para Hareketi Yapma Toggle
              Row(
                children: [
                  Checkbox(
                    value: !(_isBalanceEffect),
                    onChanged: (val) => setState(() => _isBalanceEffect = !(val ?? false)),
                  ),
                  Text(context.l10n('no_movement_label'), style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveGoal,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(context.l10n('create_goal_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
