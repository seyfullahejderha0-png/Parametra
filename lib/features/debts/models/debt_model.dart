enum DebtType { borc, alacak, kredi, credit_card }

class Debt {
  final String id;
  final String personName;
  final double amount;
  final double paidAmount; // Ödenen miktar
  final String currency;
  final double exchangeRate;
  final DateTime date;
  final DateTime? dueDate;
  final bool isPaid;
  final DebtType type;
  final int totalInstallments;
  final int currentInstallment;
  final String? parentId;
  final bool isBalanceEffect;
  final String? paymentMethodId; // Link to credit card account

  Debt({
    required this.id,
    required this.personName,
    required this.amount,
    this.paidAmount = 0.0,
    required this.currency,
    this.exchangeRate = 1.0,
    required this.date,
    this.dueDate,
    this.isPaid = false,
    required this.type,
    this.totalInstallments = 1,
    this.currentInstallment = 1,
    this.parentId,
    this.isBalanceEffect = true,
    this.paymentMethodId,
  });

  double get amountInTL => amount * exchangeRate;
  double get remainingAmount => amount - paidAmount;

  Debt copyWith({
    String? id,
    String? personName,
    double? amount,
    double? paidAmount,
    String? currency,
    double? exchangeRate,
    DateTime? date,
    DateTime? dueDate,
    bool? isPaid,
    DebtType? type,
    int? totalInstallments,
    int? currentInstallment,
    String? parentId,
    bool? isBalanceEffect,
    String? paymentMethodId,
  }) {
    return Debt(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      type: type ?? this.type,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      currentInstallment: currentInstallment ?? this.currentInstallment,
      parentId: parentId ?? this.parentId,
      isBalanceEffect: isBalanceEffect ?? this.isBalanceEffect,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'paidAmount': paidAmount,
      'currency': currency,
      'exchangeRate': exchangeRate,
      'date': date.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isPaid': isPaid,
      'type': type.name,
      'totalInstallments': totalInstallments,
      'currentInstallment': currentInstallment,
      'parentId': parentId,
      'isBalanceEffect': isBalanceEffect,
      'paymentMethodId': paymentMethodId,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] ?? '',
      personName: map['personName'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'TRY',
      exchangeRate: (map['exchangeRate'] ?? 1.0).toDouble(),
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      isPaid: map['isPaid'] ?? false,
      type: DebtType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DebtType.borc,
      ),
      totalInstallments: map['totalInstallments'] ?? 1,
      currentInstallment: map['currentInstallment'] ?? 1,
      parentId: map['parentId'],
      isBalanceEffect: map['isBalanceEffect'] ?? true,
      paymentMethodId: map['paymentMethodId'],
    );
  }
}
