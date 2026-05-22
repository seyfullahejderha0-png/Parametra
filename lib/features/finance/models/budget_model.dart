import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  final String id;
  final String categoryId;
  final double limitAmount;
  final String month; // YYYY-MM format
  final DateTime createdAt;

  Budget({
    required this.id,
    required this.categoryId,
    required this.limitAmount,
    required this.month,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'limitAmount': limitAmount,
      'month': month,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] ?? '',
      categoryId: map['categoryId'] ?? '',
      limitAmount: (map['limitAmount'] ?? 0).toDouble(),
      month: map['month'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
