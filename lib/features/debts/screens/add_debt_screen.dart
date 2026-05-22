import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/debt_model.dart';
import '../services/debt_service.dart';
import '../../profile/services/profile_service.dart';
import '../../finance/services/finance_service.dart';
import '../../finance/models/finance_models.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({super.key});

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController(text: '1.0');
  final _installmentsController = TextEditingController(text: '1');
  
  DebtType _selectedType = DebtType.borc;
  String _selectedCurrency = 'TRY';
  String? _selectedPaymentMethodId;
  bool _isBalanceEffect = true;
  DateTime _startDate = DateTime.now();
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  void _saveDebt() async {
    final person = _personController.text;
    final cleanAmount = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(cleanAmount);
    final rate = double.tryParse(_rateController.text) ?? 1.0;
    final installments = int.tryParse(_installmentsController.text) ?? 1;

    if (person.isEmpty || amount == null || amount <= 0 || _selectedPaymentMethodId == null) {
      UIHelpers.showErrorSnackBar(context, _selectedPaymentMethodId == null ? context.l10n('select_payment_method') : context.l10n('enter_person_amount_msg'));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isExpense = _selectedType == DebtType.alacak; // Alacak -> Ben para veriyorum -> Gider
      
      // Bakiye Kontrolü (Sadece para veriyorsak ve bakiye etkiliyse)
      if (isExpense && _isBalanceEffect && _selectedPaymentMethodId != null) {
        final actions = ref.read(actionsProvider).value ?? [];
        final methods = ref.read(paymentMethodsProvider).value ?? [];
        final method = methods.firstWhere((m) => m.id == _selectedPaymentMethodId);
        
        // Kredi kartı değilse kontrol et
        if (method.type != AccountType.credit_card) {
          double currentBalance = method.openingBalance;
          for (var action in actions) {
            if (action.paymentMethodId == method.id && action.isBalanceEffect) {
              currentBalance += (action.type == FinanceType.income ? action.amount : -action.amount);
            }
          }

          if (currentBalance < amount) {
            setState(() => _isSaving = false);
            UIHelpers.showErrorSnackBar(context, context.l10n('insufficient_balance'));
            return;
          }
        }
      }

      final parentId = Uuid().v4();

      for (int i = 0; i < installments; i++) {
        final installmentDate = DateTime(_startDate.year, _startDate.month + i, _startDate.day);
        
        final newDebt = Debt(
          id: Uuid().v4(),
          personName: person,
          amount: amount / installments,
          currency: _selectedCurrency,
          exchangeRate: rate,
          date: DateTime.now(),
          dueDate: installments > 1 ? installmentDate : _dueDate,
          type: _selectedType,
          totalInstallments: installments,
          currentInstallment: i + 1,
          parentId: installments > 1 ? parentId : null,
          paymentMethodId: _selectedPaymentMethodId, // Save the selected bank
          isBalanceEffect: _isBalanceEffect,
        );

        await ref.read(debtServiceProvider).addDebt(newDebt);
      }

      // FİNANS ENTEGRASYONU
      if (_isBalanceEffect) {
        final financeService = ref.read(financeServiceProvider);
        final isExpense = _selectedType == DebtType.alacak; // Alacak -> Ben para veriyorum -> Gider
        
        String categoryId;
        if (_selectedType == DebtType.kredi) {
          categoryId = 'cat_loan_received';
        } else {
          categoryId = isExpense ? 'cat_other_ex' : 'cat_other_in';
        }
        
        await financeService.addFinanceAction(FinanceAction(
          id: Uuid().v4(),
          categoryId: categoryId,
          paymentMethodId: _selectedPaymentMethodId!,
          amount: amount,
          date: DateTime.now(),
          description: '${context.l10n(isExpense ? 'debt_given' : 'debt_taken')}: $person',
          type: isExpense ? FinanceType.expense : FinanceType.income,
          isBalanceEffect: true,
        ));
      }

      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('debt_loan_save_success'));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final preferredCurrency = profile?.preferredCurrency ?? 'TRY';
    final currencySymbol = CurrencyFormatter.getSymbol(preferredCurrency);
    final isTr = Localizations.localeOf(context).languageCode == 'tr';    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.l10n('add_new_debt_loan'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<DebtType>(
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          selectedBackgroundColor: Colors.blueAccent,
                          selectedForegroundColor: Colors.white,
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        segments: [
                          ButtonSegment(value: DebtType.borc, label: Text(context.l10n('debt_label'), style: const TextStyle(fontSize: 12)), icon: const Icon(Icons.arrow_outward, size: 16)),
                          ButtonSegment(value: DebtType.alacak, label: Text(context.l10n('receivable_label'), style: const TextStyle(fontSize: 12)), icon: const Icon(Icons.arrow_downward, size: 16)),
                          ButtonSegment(value: DebtType.kredi, label: Text(context.l10n('loan_label'), style: const TextStyle(fontSize: 12)), icon: const Icon(Icons.credit_card, size: 16)),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (val) => setState(() {
                          _selectedType = val.first;
                        }),
                      ),
                      const SizedBox(height: 24),
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
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: context.l10n('payment_method_label'),
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.blueAccent),
                            ),
                            items: methods.map((m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                '${m.icon} ${m.name} (${CurrencyFormatter.format(m.currentBalance ?? 0, context, preferredCurrency)})', 
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedPaymentMethodId = val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _personController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _selectedType == DebtType.kredi ? context.l10n('loan_institution_label') : context.l10n('person_institution_label'),
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: context.l10n('total_amount_label'),
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                prefixIcon: const Icon(Icons.monetization_on_outlined, color: Colors.blueAccent),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                              items: ['TRY', 'USD', 'EUR', 'GBP'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                              onChanged: (val) => setState(() => _selectedCurrency = val!),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedCurrency != preferredCurrency) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _rateController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '${context.l10n('exchange_rate_label')} (1 $_selectedCurrency = ? $currencySymbol)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.currency_exchange, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                      if (_selectedType == DebtType.kredi) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _installmentsController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.l10n('installment_count_label'),
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.format_list_numbered, color: Colors.blueAccent),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(primary: Colors.blueAccent, onPrimary: Colors.white, surface: Color(0xFF1E293B), onSurface: Colors.white),
                                dialogBackgroundColor: const Color(0xFF0F172A),
                              ),
                              child: child!,
                            ),
                          );
                          if (date != null) {
                            setState(() {
                              if (_selectedType == DebtType.kredi) _startDate = date;
                              else _dueDate = date;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_selectedType == DebtType.kredi ? context.l10n('first_installment_date') : context.l10n('due_date_label'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(DateFormat('dd.MM.yyyy').format(_selectedType == DebtType.kredi ? _startDate : (_dueDate ?? DateTime.now())), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white24),
                            ],
                          ),
                        ),
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
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveDebt,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: _isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(context.l10n('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
