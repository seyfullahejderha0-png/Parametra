import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_constants.dart';
import '../models/subscription_model.dart';
import '../../auth/services/auth_service.dart';

final iapServiceProvider = ChangeNotifierProvider((ref) => IapService(ref));

class IapService extends ChangeNotifier {
  final Ref _ref;
  List<StoreProduct> products = [];
  bool isStoreAvailable = false;

  // Ürün ID'leri (Clean ID'ler)
  static const String premiumMonthly = 'pai_premium_monthly';
  static const String premiumYearly = 'pai_premium_yearly';
  static const String platinumMonthly = 'pai_platinum_monthly';
  static const String platinumYearly = 'pai_platinum_yearly';
  static const String platinumFamilyMonthly = 'pai_platinum_family_monthly';
  static const String platinumFamilyYearly = 'pai_platinum_family_yearly';
  static const String developerSupport = 'pai_developer_support';

  Set<String> get _productIds {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return {
        // Suffixed IDs (RevenueCat Android format)
        '$premiumMonthly:1premium',
        '$premiumYearly:premiumyillik',
        '$platinumMonthly:1platinum',
        '$platinumYearly:12platinum',
        '$platinumFamilyMonthly:1aileaylik',
        '$platinumFamilyYearly:12aileyillik',
        developerSupport,
        // Clean IDs (Legacy/Direct format)
        premiumMonthly,
        premiumYearly,
        platinumMonthly,
        platinumYearly,
        platinumFamilyMonthly,
        platinumFamilyYearly,
      };
    }
    return {
      premiumMonthly,
      premiumYearly,
      platinumMonthly,
      platinumYearly,
      platinumFamilyMonthly,
      platinumFamilyYearly,
      developerSupport,
    };
  }

  IapService(this._ref);

  Future<void> initialize() async {
    if (isStoreAvailable) return;

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration configuration;
      if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration(AppConstants.revenueCatApiKeyAndroid);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        configuration = PurchasesConfiguration(AppConstants.revenueCatApiKeyIOS);
      } else {
        return; // Desteklenmeyen platformlar için işlem yapma
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        configuration.appUserID = currentUser.uid;
      }

      await Purchases.configure(configuration);
      isStoreAvailable = true;

      // Ürün detaylarını çek
      await fetchProducts();

      // Müşteri bilgisi değişikliklerini dinle
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        syncSubscriptionWithCustomerInfo(customerInfo);
      });

      // Başlangıçta mevcut abonelik durumunu eşitle
      final currentInfo = await Purchases.getCustomerInfo();
      await syncSubscriptionWithCustomerInfo(currentInfo);

      // Auth durum değişikliklerini takip et
      _setupAuthListener();
    } catch (e) {
      debugPrint("RevenueCat Initialization Error: $e");
    }
    notifyListeners();
  }

  void _setupAuthListener() {
    _ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) async {
      final user = next.value;
      if (user != null) {
        try {
          if (isStoreAvailable) {
            final infoResult = await Purchases.logIn(user.uid);
            await syncSubscriptionWithCustomerInfo(infoResult.customerInfo);
          }
        } catch (e) {
          debugPrint("RevenueCat LogIn Error: $e");
        }
      } else {
        try {
          if (isStoreAvailable) {
            await Purchases.logOut();
          }
        } catch (e) {
          debugPrint("RevenueCat LogOut Error: $e");
        }
      }
    });
  }

  Future<void> fetchProducts() async {
    try {
      products = await Purchases.getProducts(_productIds.toList());
      debugPrint("RevenueCat: successfully fetched ${products.length} products.");
    } catch (e) {
      debugPrint("RevenueCat fetchProducts Error: $e");
    }
  }

  String resolveProductId(String cleanId) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final match = products.firstWhere((p) => p.identifier.startsWith(cleanId));
        return match.identifier;
      } catch (_) {
        // Fallback varsayılanları
        if (cleanId == premiumMonthly) return '$premiumMonthly:1premium';
        if (cleanId == premiumYearly) return '$premiumYearly:premiumyillik';
        if (cleanId == platinumMonthly) return '$platinumMonthly:1platinum';
        if (cleanId == platinumYearly) return '$platinumYearly:12platinum';
        if (cleanId == platinumFamilyMonthly) return '$platinumFamilyMonthly:1aileaylik';
        if (cleanId == platinumFamilyYearly) return '$platinumFamilyYearly:12aileyillik';
        return cleanId;
      }
    }
    return cleanId;
  }

  String getPrice(String id, String defaultPrice) {
    try {
      final resolvedId = resolveProductId(id);
      final p = products.firstWhere((element) => element.identifier == resolvedId);
      return p.priceString;
    } catch (_) {
      return defaultPrice;
    }
  }

  Future<void> buyProduct(String id) async {
    if (!isStoreAvailable) throw Exception("Store is not available");
    final resolvedId = resolveProductId(id);
    StoreProduct? product;
    if (products.isNotEmpty) {
      try {
        product = products.firstWhere((p) => p.identifier == resolvedId);
      } catch (_) {
        product = null;
      }
    }
    if (product == null) {
      product = StoreProduct(
        resolvedId,
        '',
        '',
        0,
        '',
        '',
        introductoryPrice: null,
        discounts: [],
        subscriptionPeriod: null,
        productCategory: ProductCategory.nonSubscription,
      );
    }
    final customerInfo = await Purchases.purchaseStoreProduct(product);
    await syncSubscriptionWithCustomerInfo(customerInfo);
  }

  Future<void> restorePurchases() async {
    if (!isStoreAvailable) throw Exception("Store is not available");
    final customerInfo = await Purchases.restorePurchases();
    await syncSubscriptionWithCustomerInfo(customerInfo);
  }

  Future<void> syncSubscriptionWithCustomerInfo(CustomerInfo customerInfo) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    SubscriptionType type = SubscriptionType.free;
    DateTime? endDate;
    String? sku;
    bool isSupporter = false;

    // Yetkileri önem sırasına göre kontrol et
    if (customerInfo.entitlements.active.containsKey('platinum_family')) {
      final ent = customerInfo.entitlements.active['platinum_family']!;
      type = SubscriptionType.platinumFamily;
      endDate = ent.expirationDate != null ? DateTime.parse(ent.expirationDate!) : null;
      sku = ent.productIdentifier;
    } else if (customerInfo.entitlements.active.containsKey('platinum')) {
      final ent = customerInfo.entitlements.active['platinum']!;
      type = SubscriptionType.platinum;
      endDate = ent.expirationDate != null ? DateTime.parse(ent.expirationDate!) : null;
      sku = ent.productIdentifier;
    } else if (customerInfo.entitlements.active.containsKey('premium')) {
      final ent = customerInfo.entitlements.active['premium']!;
      type = SubscriptionType.premium;
      endDate = ent.expirationDate != null ? DateTime.parse(ent.expirationDate!) : null;
      sku = ent.productIdentifier;
    }

    // Geliştirici desteği (bağış) kontrolü
    if (customerInfo.allPurchasedProductIdentifiers.contains(developerSupport)) {
      isSupporter = true;
    }

    final subDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('status');

    final now = DateTime.now();
    
    // Mevcut abonelik verisini oku (isTrialUsed vb. alanları korumak için)
    final doc = await subDoc.get();
    SubscriptionType currentType = SubscriptionType.free;
    DateTime? currentEndDate;
    bool isTrialUsed = true;
    bool currentSupporter = false;

    if (doc.exists && doc.data() != null) {
      final map = doc.data() as Map<String, dynamic>;
      currentType = SubscriptionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SubscriptionType.free,
      );
      if (map['endDate'] != null) {
        currentEndDate = DateTime.parse(map['endDate']);
      }
      isTrialUsed = map['isTrialUsed'] ?? true;
      currentSupporter = map['isSupporter'] ?? false;
    }

    // Kullanıcıda aktif abonelik yoksa ancak yerel trial (deneme) süresi aktifse koru
    if (type == SubscriptionType.free && currentType == SubscriptionType.trial) {
      if (currentEndDate != null && currentEndDate.isAfter(now)) {
        return;
      }
    }

    final updatedData = SubscriptionData(
      type: type,
      startDate: now,
      endDate: endDate,
      isTrialUsed: isTrialUsed,
      isSupporter: isSupporter || currentSupporter,
      sku: sku,
    );

    await subDoc.set(updatedData.toMap());
    debugPrint("RevenueCat: Synced subscription status to Firestore (Type: ${type.name}, Supporter: ${isSupporter || currentSupporter})");
  }

  @override
  void dispose() {
    super.dispose();
  }
}
