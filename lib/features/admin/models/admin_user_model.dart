import '../../subscription/models/subscription_model.dart';

class AdminUserData {
  final String userId;
  final String name;
  final String email;
  final SubscriptionType subscriptionType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dailyUsageCount;
  final int totalUsageCount;
  final DateTime? lastLogin;
  final String platform;
  final List<String> activeModules;
  final bool isSupporter;
  final String? sku;

  AdminUserData({
    required this.userId,
    required this.name,
    required this.email,
    required this.subscriptionType,
    this.startDate,
    this.endDate,
    this.dailyUsageCount = 0,
    this.totalUsageCount = 0,
    this.lastLogin,
    this.platform = 'Android',
    required this.activeModules,
    this.isSupporter = false,
    this.sku,
  });

  String get billingCycleText {
    if (subscriptionType == SubscriptionType.free) return 'Sınırsız / Ücretsiz';
    if (subscriptionType == SubscriptionType.trial) return 'Deneme';
    if (sku == null) return 'Aylık (Varsayılan)';
    if (sku!.contains('yearly')) return 'Yıllık';
    if (sku!.contains('monthly')) return 'Aylık';
    return 'Aylık';
  }

  bool get isSubExpired {
    if (endDate == null) return false;
    return endDate!.isBefore(DateTime.now());
  }

  bool get isSubExpiringSoon {
    if (endDate == null) return false;
    final diff = endDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 5;
  }
}
