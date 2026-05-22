import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../profile/services/profile_service.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _fromPaymentMethodId;
  String? _toPaymentMethodId;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _executeTransfer() async {
    final cleanAmount = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0 || _fromPaymentMethodId == null || _toPaymentMethodId == null) {
      UIHelpers.showErrorSnackBar(context, context.l10n('form_error_msg'));
      return;
    }

    if (_fromPaymentMethodId == _toPaymentMethodId) {
      UIHelpers.showErrorSnackBar(context, context.l10n('same_account_transfer_error') ?? 'Gönderen ve alıcı hesap aynı olamaz!');
      return;
    }

    final methods = ref.read(paymentMethodsProvider).value ?? [];
    final fromMethod = methods.firstWhere((m) => m.id == _fromPaymentMethodId);
    final toMethod = methods.firstWhere((m) => m.id == _toPaymentMethodId);

    // Kredi kartı değilse bakiye kontrolü yap (Gönderen hesap için)
    if (fromMethod.type != AccountType.credit_card) {
      final actions = ref.read(actionsProvider).value ?? [];
      double currentBalance = fromMethod.openingBalance;
      for (var action in actions) {
        if (action.paymentMethodId == fromMethod.id && action.isBalanceEffect) {
          currentBalance += (action.type == FinanceType.income ? action.amount : -action.amount);
        }
      }

      if (currentBalance < amount) {
        UIHelpers.showErrorSnackBar(context, context.l10n('insufficient_balance'));
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final transferId = 'transfer_${const Uuid().v4()}';
      final desc = _descriptionController.text.trim().isEmpty 
          ? '${fromMethod.name} ➔ ${toMethod.name} Transferi' 
          : _descriptionController.text.trim();

      // 1. Gönderen Hesaptan Çıkış (Gider)
      final expenseAction = FinanceAction(
        id: const Uuid().v4(),
        categoryId: 'cat_transfer_out',
        paymentMethodId: _fromPaymentMethodId!,
        amount: amount,
        date: DateTime.now(),
        description: desc,
        type: FinanceType.expense,
        isBalanceEffect: true,
        relatedId: transferId,
      );

      // 2. Alıcı Hesaba Giriş (Gelir)
      final incomeAction = FinanceAction(
        id: const Uuid().v4(),
        categoryId: 'cat_transfer_in',
        paymentMethodId: _toPaymentMethodId!,
        amount: amount,
        date: DateTime.now(),
        description: desc,
        type: FinanceType.income,
        isBalanceEffect: true,
        relatedId: transferId,
      );

      final financeService = ref.read(financeServiceProvider);
      await financeService.addFinanceAction(expenseAction);
      await financeService.addFinanceAction(incomeAction);

      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('transfer_success') ?? 'Transfer başarıyla gerçekleşti!');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethodsAsync = ref.watch(paymentMethodsWithBalanceProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';
    final symbol = CurrencyFormatter.getSymbol(currency);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n('transfer_between_accounts') ?? 'Hesaplar Arası Transfer')),
      body: SafeArea(
        child: paymentMethodsAsync.when(
          data: (methods) {
            if (methods.length < 2) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    context.l10n('need_two_accounts_transfer') ?? 'Transfer yapabilmek için en az 2 adet tanımlı hesabınız (nakit, banka vb.) olmalıdır.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ),
              );
            }

            if (_fromPaymentMethodId == null || !methods.any((m) => m.id == _fromPaymentMethodId)) {
              _fromPaymentMethodId = methods.first.id;
            }
            if (_toPaymentMethodId == null || !methods.any((m) => m.id == _toPaymentMethodId)) {
              _toPaymentMethodId = methods.last.id;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(vertical: 30),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Gönderen Hesap (From)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _fromPaymentMethodId,
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: InputDecoration(
                      labelText: context.l10n('from_account_label') ?? 'Gönderen Hesap / Kasa',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.arrow_upward, color: Colors.redAccent),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                    items: methods.map((m) => DropdownMenuItem(
                      value: m.id, 
                      child: Text(
                        '${m.icon} ${m.name} (${CurrencyFormatter.format(m.currentBalance ?? 0, context, currency)})', 
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      )
                    )).toList(),
                    onChanged: (val) => setState(() => _fromPaymentMethodId = val),
                  ),
                  const SizedBox(height: 24),

                  // Alıcı Hesap (To)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _toPaymentMethodId,
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: InputDecoration(
                      labelText: context.l10n('to_account_label') ?? 'Alıcı Hesap / Kasa',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.arrow_downward, color: Colors.greenAccent),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                    items: methods.map((m) => DropdownMenuItem(
                      value: m.id, 
                      child: Text(
                        '${m.icon} ${m.name} (${CurrencyFormatter.format(m.currentBalance ?? 0, context, currency)})', 
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      )
                    )).toList(),
                    onChanged: (val) => setState(() => _toPaymentMethodId = val),
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
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Kaydet Butonu
                  ElevatedButton(
                    onPressed: _isSaving ? null : _executeTransfer,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.orangeAccent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: _isSaving 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(context.l10n('execute_transfer_btn') ?? 'Transferi Tamamla', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text(context.l10n('error_label'))),
        ),
      ),
    );
  }
}
