class GoalDeposit {
  final double amount;
  final DateTime date;
  final String? paymentMethodName;

  GoalDeposit({
    required this.amount,
    required this.date,
    this.paymentMethodName,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': date.toIso8601String(),
      'paymentMethodName': paymentMethodName,
    };
  }

  factory GoalDeposit.fromMap(Map<String, dynamic> map) {
    return GoalDeposit(
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      paymentMethodName: map['paymentMethodName'],
    );
  }
}

class Goal {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final String category;
  final List<GoalDeposit> history;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    required this.category,
    this.history = const [],
  });

  double get progress => targetAmount > 0 ? currentAmount / targetAmount : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline?.toIso8601String(),
      'category': category,
      'history': history.map((e) => e.toMap()).toList(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0).toDouble(),
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      category: map['category'] ?? 'Genel',
      history: (map['history'] as List? ?? [])
          .map((e) => GoalDeposit.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

