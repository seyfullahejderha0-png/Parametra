import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/debt_model.dart';
import '../services/debt_service.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/currency_formatter.dart'; // Yeni import
import '../../finance/services/finance_service.dart';
import '../../finance/models/finance_models.dart';
import 'package:uuid/uuid.dart';

class DebtDetailScreen extends ConsumerWidget {
  final String parentId;

  const DebtDetailScreen({
    super.key,
    required this.parentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return debtsAsync.when(
      data: (allDebts) {
        final installments = allDebts.where((d) => d.parentId == parentId).toList();
        if (installments.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detay')),
            body: const Center(child: Text('Kayıt bulunamadı veya silindi.')),
          );
        }

        final sortedInstallments = [...installments]..sort((a, b) => a.currentInstallment.compareTo(b.currentInstallment));
        final representative = installments.first;
        
        double totalAmount = 0;
        double totalPaid = 0;
        for (var d in installments) {
          totalAmount += d.amount;
          totalPaid += d.paidAmount;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(representative.personName),
          ),
          body: Column(
            children: [
              _buildHeader(representative, totalAmount, totalPaid, currencyFormat),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedInstallments.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final debt = sortedInstallments[index];
                    return _buildInstallmentItem(context, ref, debt, currencyFormat);
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Hata: $err'))),
    );
  }

  Widget _buildHeader(Debt rep, double total, double paid, NumberFormat format) {
    final remaining = total - paid;
    final progress = total > 0 ? paid / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerStat('Toplam', format.format(total * rep.exchangeRate), Colors.white70),
              _headerStat('Ödenen', format.format(paid * rep.exchangeRate), Colors.greenAccent),
              _headerStat('Kalan', format.format(remaining * rep.exchangeRate), Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(rep.type == DebtType.alacak ? Colors.blueAccent : Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '%${(progress * 100).toStringAsFixed(1)} Tamamlandı',
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildInstallmentItem(BuildContext context, WidgetRef ref, Debt debt, NumberFormat format) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: debt.isPaid ? Colors.greenAccent.withOpacity(0.1) : Colors.white10,
          child: Text(
            debt.currentInstallment.toString(),
            style: TextStyle(
              color: debt.isPaid ? Colors.greenAccent : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          'Taksit ${debt.currentInstallment} / ${debt.totalInstallments}',
          style: TextStyle(
            decoration: debt.isPaid ? TextDecoration.lineThrough : null,
            color: debt.isPaid ? Colors.white38 : Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMMM yyyy', 'tr_TR').format(debt.dueDate ?? debt.date),
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            if (debt.paidAmount > 0)
              Text(
                'Ödenen: ${format.format(debt.paidAmount * debt.exchangeRate)}',
                style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  format.format(debt.amount * debt.exchangeRate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (!debt.isPaid)
                  Text(
                    'Kalan: ${format.format(debt.remainingAmount * debt.exchangeRate)}',
                    style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                debt.isPaid ? Icons.check_circle : Icons.payment,
                color: debt.isPaid ? Colors.greenAccent : Colors.blueAccent,
              ),
              onPressed: debt.isPaid ? null : () => _showPaymentDialog(context, ref, debt),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, Debt debt) {
    final controller = TextEditingController(text: debt.remainingAmount.toString());
    String? localPaymentMethodId = debt.paymentMethodId; // Default to the one selected when created

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(debt.type == DebtType.alacak ? 'Tahsilat Gir' : 'Ödeme Gir'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kalan Tutar: ${debt.remainingAmount.toStringAsFixed(2)} ${debt.currency}'),
                const SizedBox(height: 16),
                ref.watch(paymentMethodsWithBalanceProvider).when(
                  data: (methods) {
                    if (methods.isNotEmpty) {
                      if (localPaymentMethodId == null || !methods.any((m) => m.id == localPaymentMethodId)) {
                        localPaymentMethodId = methods.first.id;
                      }
                    }
                    return DropdownButtonFormField<String>(
                      value: localPaymentMethodId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Ödeme Hesabı'),
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
                    labelText: 'Ödenecek Tutar (${debt.currency})',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  final payAmount = double.tryParse(controller.text) ?? 0;
                  if (payAmount <= 0 || payAmount > debt.remainingAmount || localPaymentMethodId == null) {
                    UIHelpers.showErrorSnackBar(context, 'Geçersiz tutar veya hesap seçilmedi.');
                    return;
                  }

                  final updatedDebt = debt.copyWith(
                    paidAmount: debt.paidAmount + payAmount,
                    isPaid: (debt.paidAmount + payAmount) >= debt.amount - 0.01,
                  );

                  await ref.read(debtServiceProvider).updateDebt(updatedDebt);
                  
                  // Finans Entegrasyonu
                  if (debt.isBalanceEffect) {
                    final isCollection = debt.type == DebtType.alacak;
                    await ref.read(financeServiceProvider).addFinanceAction(FinanceAction(
                      id: Uuid().v4(),
                      categoryId: isCollection ? 'cat_other_in' : 'cat_other_ex',
                      paymentMethodId: localPaymentMethodId!,
                      amount: payAmount,
                      date: DateTime.now(),
                      description: '${isCollection ? 'Tahsilat' : 'Ödeme'}: ${debt.personName} (Taksit ${debt.currentInstallment})',
                      type: isCollection ? FinanceType.income : FinanceType.expense,
                    ));
                  }

                  if (context.mounted) {
                    FocusScope.of(context).unfocus();
                    UIHelpers.showSuccessSnackBar(context, 'İşlem kaydedildi.');
                    Navigator.pop(context);
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        }
      ),
    );
  }
}
