enum SubscriptionType { free, trial, premium, platinum, platinumFamily }

class SubscriptionData {
  final SubscriptionType type;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isTrialUsed;
  final bool isSupporter;
  final String? sku; // New field to distinguish Monthly/Yearly

  SubscriptionData({
    required this.type,
    required this.startDate,
    this.endDate,
    this.isTrialUsed = false,
    this.isSupporter = false,
    this.sku,
  });

  bool get isActive {
    if (type == SubscriptionType.free) return true;
    if (endDate == null) return true;
    return endDate!.isAfter(DateTime.now());
  }

  int get remainingTrialDays {
    if (type != SubscriptionType.trial) return 0;
    final diff = endDate?.difference(DateTime.now()).inDays ?? 0;
    return diff > 0 ? diff : 0;
  }

  bool get hasAI {
    return true; // Tüm kullanıcılar günlük limitli AI asistanına erişebilir.
  }

  bool get isUnlimited {
    return type != SubscriptionType.free && isActive;
  }

  bool get hasPremium => type != SubscriptionType.free && isActive;
  bool get isPremium => hasPremium;

  /// Aile / Ortak Mod erişimi: sadece Platinum AI Aile
  bool get hasFamily => type == SubscriptionType.platinumFamily && isActive;

  String get typeNameKey {
    switch (type) {
      case SubscriptionType.free: return 'subscription_free';
      case SubscriptionType.trial: return 'subscription_trial';
      case SubscriptionType.premium: return 'subscription_premium';
      case SubscriptionType.platinum: return 'subscription_platinum';
      case SubscriptionType.platinumFamily: return 'subscription_platinum_family';
    }
  }

  String get typeName => typeNameKey; // Backward compatibility

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isTrialUsed': isTrialUsed,
      'isSupporter': isSupporter,
      'sku': sku,
    };
  }

  factory SubscriptionData.fromMap(Map<String, dynamic> map) {
    return SubscriptionData(
      type: SubscriptionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SubscriptionType.free,
      ),
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      isTrialUsed: map['isTrialUsed'] ?? false,
      isSupporter: map['isSupporter'] ?? false,
      sku: map['sku'],
    );
  }

  SubscriptionData copyWithSupporter(bool supporter) {
    return SubscriptionData(
      type: type,
      startDate: startDate,
      endDate: endDate,
      isTrialUsed: isTrialUsed,
      isSupporter: supporter,
      sku: sku,
    );
  }

  factory SubscriptionData.initial() {
    return SubscriptionData(
      type: SubscriptionType.trial,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      isTrialUsed: true,
      sku: 'trial_7_days',
    );
  }
}
