import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subscription_service.dart';

final iapServiceProvider = Provider((ref) => IapService(ref));

class IapService {
  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Ürün ID'leri - Mağaza panellerinde aynı olmalıdır
  static const String premiumMonthly = 'pai_premium_monthly';
  static const String premiumYearly = 'pai_premium_yearly';
  static const String platinumMonthly = 'pai_platinum_monthly';
  static const String platinumYearly = 'pai_platinum_yearly';
  static const String platinumFamilyMonthly = 'pai_platinum_family_monthly';
  static const String platinumFamilyYearly = 'pai_platinum_family_yearly';
  static const String developerSupport = 'pai_developer_support';

  final Set<String> _productIds = {
    premiumMonthly,
    premiumYearly,
    platinumMonthly,
    platinumYearly,
    platinumFamilyMonthly,
    platinumFamilyYearly,
    developerSupport,
  };

  List<ProductDetails> products = [];
  bool isStoreAvailable = false;

  IapService(this._ref) {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint("IAP Error: $error"),
    );
  }

  Future<void> initialize() async {
    isStoreAvailable = await _iap.isAvailable();
    if (isStoreAvailable) {
      await fetchProducts();
    }
  }

  Future<void> fetchProducts() async {
    final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint("NotFoundIDs: ${response.notFoundIDs}");
    }
    products = response.productDetails;
  }

  ProductDetails? getProduct(String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String getPrice(String id, String defaultPrice) {
    final p = getProduct(id);
    return p?.price ?? defaultPrice;
  }

  Future<void> buyProduct(String id) async {
    final product = getProduct(id);
    if (product == null) return;

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    if (id.contains('monthly') || id.contains('yearly')) {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        _handleSuccessfulPurchase(purchase);
      }
      
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchase) {
    _ref.read(subscriptionServiceProvider).handlePurchaseSuccess(purchase.productID);
    debugPrint("Purchase Successful: ${purchase.productID}");
  }

  void dispose() {
    _subscription.cancel();
  }
}
