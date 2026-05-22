enum FinanceType { income, expense }

class FinanceCategory {
  final String id;
  final String name;
  final String emoji;
  final FinanceType type;

  FinanceCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'type': type.name,
    };
  }

  factory FinanceCategory.fromMap(Map<String, dynamic> map) {
    return FinanceCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '📁',
      type: FinanceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FinanceType.expense,
      ),
    );
  }
}

enum AccountType { cash, bank, credit_card }

class PaymentMethod {
  final String id;
  final String name;
  final String icon;
  final double openingBalance;
  final AccountType type;
  final double? currentBalance; // Yeni Alan: Hesap bakiyesi için
  final int? statementDay; // Yeni Alan: Kredi kartı hesap kesim / ödeme günü

  PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    this.openingBalance = 0,
    this.type = AccountType.bank,
    this.currentBalance,
    this.statementDay,
  });

  PaymentMethod copyWith({
    String? id,
    String? name,
    String? icon,
    double? openingBalance,
    AccountType? type,
    double? currentBalance,
    int? statementDay,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      openingBalance: openingBalance ?? this.openingBalance,
      type: type ?? this.type,
      currentBalance: currentBalance ?? this.currentBalance,
      statementDay: statementDay ?? this.statementDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'openingBalance': openingBalance,
      'type': type.name,
      if (statementDay != null) 'statementDay': statementDay,
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: map['icon'] ?? '💳',
      openingBalance: (map['openingBalance'] ?? 0).toDouble(),
      type: AccountType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AccountType.bank,
      ),
      statementDay: map['statementDay'] as int?,
    );
  }
}

class FinanceAction {
  final String id;
  final String categoryId;
  final String paymentMethodId;
  final double amount;
  final DateTime date;
  final String description;
  final FinanceType type;
  final bool isBalanceEffect;
  final String? relatedId; // New Field: Link to Goal, Debt, etc.

  FinanceAction({
    required this.id,
    required this.categoryId,
    required this.paymentMethodId,
    required this.amount,
    required this.date,
    required this.description,
    required this.type,
    this.isBalanceEffect = true,
    this.relatedId,
  });

  bool get isPureIncomeExpense {
    if (categoryId == 'cat_goal_savings' || 
        categoryId == 'cat_transfer_in' || 
        categoryId == 'cat_transfer_out') {
      return false;
    }
    if (relatedId != null && relatedId!.isNotEmpty) {
      return false;
    }
    final desc = description.toLowerCase();
    if (desc.contains('transfer') || 
        desc.contains('borç') || 
        desc.contains('kredi') || 
        desc.contains('tahsilat') || 
        desc.contains('taksit') ||
        desc.contains('hedef')) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'paymentMethodId': paymentMethodId,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'type': type.name,
      'isBalanceEffect': isBalanceEffect,
      'relatedId': relatedId,
    };
  }

  factory FinanceAction.fromMap(Map<String, dynamic> map) {
    return FinanceAction(
      id: map['id'] ?? '',
      categoryId: map['categoryId'] ?? '',
      paymentMethodId: map['paymentMethodId'] ?? 'default',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      description: map['description'] ?? '',
      type: FinanceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FinanceType.expense,
      ),
      isBalanceEffect: map['isBalanceEffect'] ?? true,
      relatedId: map['relatedId'],
    );
  }
}
