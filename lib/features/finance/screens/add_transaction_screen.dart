import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/utils/currency_formatter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final FinanceAction? initialAction;
  const AddTransactionScreen({super.key, this.initialAction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  FinanceType _selectedType = FinanceType.expense;
  String? _selectedCategoryId;
  String? _selectedPaymentMethodId;
  bool _isBalanceEffect = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != null) {
      _amountController.text = widget.initialAction!.amount.toString();
      _descriptionController.text = widget.initialAction!.description;
      _selectedType = widget.initialAction!.type;
      _selectedCategoryId = widget.initialAction!.categoryId;
      _selectedPaymentMethodId = widget.initialAction!.paymentMethodId;
      _isBalanceEffect = widget.initialAction!.isBalanceEffect;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveTransaction() async {
    final cleanAmount = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0 || _selectedCategoryId == null || _selectedPaymentMethodId == null) {
      UIHelpers.showErrorSnackBar(context, context.l10n('form_error_msg'));
      return;
    }

    // Bakiye Kontrolü (Sadece Gider, Bakiye Etkili ve Kredi Kartı OLMAYAN işlemler için)
    if (_selectedType == FinanceType.expense && _isBalanceEffect) {
      final actions = ref.read(actionsProvider).value ?? [];
      final methods = ref.read(paymentMethodsProvider).value ?? [];
      
      final method = methods.firstWhere((m) => m.id == _selectedPaymentMethodId);
      
      // Kredi kartı değilse kontrol yap
      if (method.type != AccountType.credit_card) {
        double currentBalance = method.openingBalance;
        
        for (var action in actions) {
          if (action.paymentMethodId == method.id && action.isBalanceEffect) {
            currentBalance += (action.type == FinanceType.income ? action.amount : -action.amount);
          }
        }

        // Eğer düzenleme yapılıyorsa, eski tutarı bakiyeye geri ekleyelim ki net kontrol yapalım
        if (widget.initialAction != null && widget.initialAction!.paymentMethodId == method.id && widget.initialAction!.isBalanceEffect) {
          currentBalance += (widget.initialAction!.type == FinanceType.expense ? widget.initialAction!.amount : -widget.initialAction!.amount);
        }

        if (currentBalance < amount) {
          UIHelpers.showErrorSnackBar(context, context.l10n('insufficient_balance'));
          return;
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      String updatedDescription = _descriptionController.text;
      
      // AI Açıklamasını Otomatik Güncelle (Eğer method değiştiyse ve AI formatındaysa)
      if (widget.initialAction != null && updatedDescription.startsWith("AI: ")) {
        final methods = ref.read(paymentMethodsProvider).value ?? [];
        final oldMethod = methods.firstWhere((m) => m.id == widget.initialAction!.paymentMethodId, orElse: () => methods.first);
        final newMethod = methods.firstWhere((m) => m.id == _selectedPaymentMethodId, orElse: () => methods.first);
        
        if (oldMethod.id != newMethod.id) {
          updatedDescription = updatedDescription.replaceFirst("(${oldMethod.name})", "(${newMethod.name})");
        }
      }

      final newAction = FinanceAction(
        id: widget.initialAction?.id ?? const Uuid().v4(),
        categoryId: _selectedCategoryId!,
        paymentMethodId: _selectedPaymentMethodId!,
        amount: amount,
        date: widget.initialAction?.date ?? DateTime.now(),
        description: updatedDescription,
        type: _selectedType,
        isBalanceEffect: _isBalanceEffect,
      );

      if (widget.initialAction != null) {
        await ref.read(financeServiceProvider).updateFinanceAction(newAction);
      } else {
        await ref.read(financeServiceProvider).addFinanceAction(newAction);
      }
      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('transaction_save_success'));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsWithBalanceProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';
    final symbol = CurrencyFormatter.getSymbol(currency);

    return Scaffold(
      appBar: AppBar(title: Text(widget.initialAction != null ? context.l10n('edit_transaction') : context.l10n('add_new_transaction'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gelir/Gider Seçimi
              if (widget.initialAction == null) // Düzenleme modunda tür değiştirmeyi engelleyelim (mantıksal tutarlılık için)
              Center(
                child: SegmentedButton<FinanceType>(
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: FinanceType.expense, 
                      label: Text(context.l10n('expense_label'), style: const TextStyle(fontSize: 12)), 
                      icon: const Icon(Icons.remove_circle_outline, size: 18)
                    ),
                    ButtonSegment(
                      value: FinanceType.income, 
                      label: Text(context.l10n('income_label'), style: const TextStyle(fontSize: 12)), 
                      icon: const Icon(Icons.add_circle_outline, size: 18)
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (val) => setState(() {
                    _selectedType = val.first;
                    _selectedCategoryId = null;
                  }),
                ),
              ),
              if (widget.initialAction == null) const SizedBox(height: 32),

              // Tutar Girişi
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0.00 $symbol',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(vertical: 30),
                ),
              ),
              const SizedBox(height: 32),

              // Ödeme Yöntemi / Hesap
              paymentMethodsAsync.when(
                data: (methods) {
                  if (methods.isNotEmpty) {
                    if (_selectedPaymentMethodId == null || !methods.any((m) => m.id == _selectedPaymentMethodId)) {
                      _selectedPaymentMethodId = methods.first.id;
                    }
                  }
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedPaymentMethodId,
                  dropdownColor: const Color(0xFF1E293B), // Koyu arka plan rengi
                  decoration: InputDecoration(
                    labelText: _selectedType == FinanceType.expense ? context.l10n('payment_method_label') : context.l10n('deposit_account_label'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                  items: methods.map((m) => DropdownMenuItem(
                    value: m.id, 
                    child: Text(
                      '${m.icon} ${m.name} (${CurrencyFormatter.format(m.currentBalance ?? 0, context, currency)})', 
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    )
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedPaymentMethodId = val),
                  );
                },
                loading: () => const SizedBox(height: 60, child: Center(child: LinearProgressIndicator())),
                error: (e, s) => Text(context.l10n('error_label')),
              ),
              const SizedBox(height: 24),

              // Kategori Seçimi
              categoriesAsync.when(
                data: (categories) {
                  final filtered = categories.where((c) => c.type == _selectedType).toList();
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedCategoryId,
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: InputDecoration(
                      labelText: _selectedType == FinanceType.expense ? context.l10n('expense_item_label') : context.l10n('income_item_label'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.category_outlined),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    items: filtered.map((c) => DropdownMenuItem(
                      value: c.id, 
                      child: Text('${c.emoji} ${c.name}', style: const TextStyle(fontSize: 14))
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  );
                },
                loading: () => const SizedBox(height: 60, child: Center(child: LinearProgressIndicator())),
                error: (e, s) => Text(context.l10n('error_label')),
              ),
              const SizedBox(height: 24),

              // Açıklama
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n('description_optional'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.notes),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
              const SizedBox(height: 24),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _isSaving ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: _selectedType == FinanceType.expense ? Colors.redAccent : Colors.greenAccent,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: (_selectedType == FinanceType.expense ? Colors.redAccent : Colors.greenAccent).withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(context.l10n('save'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
