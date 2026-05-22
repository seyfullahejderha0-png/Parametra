import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringPeriod { monthly, yearly }

class RecurringPayment {
  final String id;
  final String name;
  final double amount;
  final String currency;
  final RecurringPeriod period;
  final DateTime nextPaymentDate;
  final String categoryId;
  final bool isAutoPay;
  final String? icon;

  RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.period,
    required this.nextPaymentDate,
    required this.categoryId,
    this.isAutoPay = false,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'currency': currency,
      'period': period.name,
      'nextPaymentDate': nextPaymentDate.toIso8601String(),
      'categoryId': categoryId,
      'isAutoPay': isAutoPay,
      'icon': icon,
    };
  }

  factory RecurringPayment.fromMap(Map<String, dynamic> map) {
    return RecurringPayment(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'TRY',
      period: RecurringPeriod.values.firstWhere(
        (e) => e.name == map['period'],
        orElse: () => RecurringPeriod.monthly,
      ),
      nextPaymentDate: DateTime.parse(map['nextPaymentDate']),
      categoryId: map['categoryId'] ?? 'other',
      isAutoPay: map['isAutoPay'] ?? false,
      icon: map['icon'],
    );
  }

  RecurringPayment copyWith({
    String? id,
    String? name,
    double? amount,
    String? currency,
    RecurringPeriod? period,
    DateTime? nextPaymentDate,
    String? categoryId,
    bool? isAutoPay,
    String? icon,
  }) {
    return RecurringPayment(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      period: period ?? this.period,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      categoryId: categoryId ?? this.categoryId,
      isAutoPay: isAutoPay ?? this.isAutoPay,
      icon: icon ?? this.icon,
    );
  }
}
