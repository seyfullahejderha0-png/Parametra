import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../models/subscription_model.dart';
import 'iap_service.dart';

final subscriptionServiceProvider = Provider((ref) {
  final user = ref.watch(authStateProvider).value;
  return SubscriptionService(user?.uid);
});

final subscriptionStreamProvider = StreamProvider<SubscriptionData>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getSubscriptionData();
});

class SubscriptionService {
  final String? userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SubscriptionService(this.userId);

  DocumentReference get _userDoc => _firestore.collection('users').doc(userId ?? 'anonymous');
  DocumentReference get _subDoc => _userDoc.collection('subscription').doc('status');
  DocumentReference get _configDoc => _firestore.collection('config').doc('subscription');

  Future<int> _getTrialDays() async {
    try {
      final doc = await _configDoc.get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['trial_days'] ?? 7;
      }
    } catch (_) {}
    return 7; // Varsayılan
  }

  Stream<SubscriptionData> getSubscriptionData() {
    if (userId == null) return Stream.value(SubscriptionData.initial());
    
    return _subDoc.snapshots().asyncMap((doc) async {
      final trialDays = await _getTrialDays();
      final now = DateTime.now();
      
      if (!doc.exists || doc.data() == null) {
        // Yeni veya verisi eksik kullanıcılar için deneme süresi tanımla
        final initial = SubscriptionData(
          type: SubscriptionType.trial,
          startDate: now,
          endDate: now.add(Duration(days: trialDays > 0 ? trialDays : 7)),
          isTrialUsed: true,
        );
        await _subDoc.set(initial.toMap());
        return initial;
      }
      
      final map = doc.data() as Map<String, dynamic>;
      
      // Kritik Veri Eksikliği Kontrolü: Eğer tip bilgisi yoksa trial yap
      if (map['type'] == null) {
        final initial = SubscriptionData(
          type: SubscriptionType.trial,
          startDate: now,
          endDate: now.add(Duration(days: trialDays > 0 ? trialDays : 7)),
          isTrialUsed: true,
        );
        await _subDoc.set(initial.toMap());
        return initial;
      }

      final data = SubscriptionData.fromMap(map);
      
      // Hatalı test verilerini temizle (sadece çok uçuk süreleri düzelt)
      bool isGlitchTrial = false;
      if (data.type == SubscriptionType.trial && data.endDate != null) {
        final totalDays = data.endDate!.difference(data.startDate).inDays;
        if (totalDays > 365) { 
          isGlitchTrial = true;
        }
      }
      
      // Deneme süresi bittiyse otomatik olarak free'ye çek
      if (isGlitchTrial || (data.type == SubscriptionType.trial && !data.isActive)) {
        final freeSub = SubscriptionData(
          type: SubscriptionType.free,
          startDate: data.startDate,
          endDate: null,
          isTrialUsed: true,
        );
        await _subDoc.set(freeSub.toMap());
        return freeSub;
      }
      
      return data;
    });
  }

  Future<void> updateSubscription(SubscriptionType type, {int days = 30, String? sku}) async {
    final now = DateTime.now();
    final sub = SubscriptionData(
      type: type,
      startDate: now,
      endDate: days > 1000 ? null : now.add(Duration(days: days)),
      isTrialUsed: true,
      sku: sku,
    );
    await _subDoc.set(sub.toMap());
  }

  Future<void> handlePurchaseSuccess(String productId) async {
    SubscriptionType type = SubscriptionType.free;
    int days = 30;

    if (productId == IapService.premiumMonthly) {
      type = SubscriptionType.premium;
      days = 30;
    } else if (productId == IapService.premiumYearly) {
      type = SubscriptionType.premium;
      days = 365;
    } else if (productId == IapService.platinumMonthly) {
      type = SubscriptionType.platinum;
      days = 30;
    } else if (productId == IapService.platinumYearly) {
      type = SubscriptionType.platinum;
      days = 365;
    } else if (productId == IapService.platinumFamilyMonthly) {
      type = SubscriptionType.platinumFamily;
      days = 30;
    } else if (productId == IapService.platinumFamilyYearly) {
      type = SubscriptionType.platinumFamily;
      days = 365;
    } else if (productId == IapService.developerSupport) {
      await supportProject();
      return;
    }

    await updateSubscription(type, days: days, sku: productId);
  }

  Future<void> supportProject() async {
    final doc = await _subDoc.get();
    if (doc.exists) {
      await _subDoc.update({'isSupporter': true});
    } else {
      final initial = SubscriptionData.initial();
      await _subDoc.set(initial.copyWithSupporter(true).toMap());
    }
  }

  // Günlük/Toplam işlem sınırı kontrolü için yardımcı metodlar
  Future<bool> canAddEntry(String collectionName) async {
    final subData = await getSubscriptionData().first;
    if (subData.isUnlimited) return true;
    if (collectionName == 'smoking') return true;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    int count = 0;
    
    try {
      if (collectionName == 'finance') {
        final snap = await _userDoc.collection('finance').doc('data').collection('actions').get();
        count = snap.docs.where((d) {
          final data = d.data();
          if (!data.containsKey('date')) return false;
          return DateTime.parse(data['date']).isAfter(startOfDay);
        }).length;
      } else if (collectionName == 'notes') {
        final snap = await _userDoc.collection('notes').get();
        count = snap.docs.where((d) {
          final data = d.data();
          if (!data.containsKey('createdAt')) return false;
          return (data['createdAt'] as Timestamp).toDate().isAfter(startOfDay);
        }).length;
      } else if (collectionName == 'health') {
        final snap = await _userDoc.collection('health_logs').get();
        count = snap.docs.where((d) {
          final data = d.data();
          if (!data.containsKey('date')) return false;
          return DateTime.parse(data['date']).isAfter(startOfDay);
        }).length;
      } else if (collectionName == 'medication') {
        // İlaçlar için toplam limit 3
        final snap = await _userDoc.collection('medications').get();
        count = snap.docs.length;
      } else if (collectionName == 'goals') {
        // Hedefler için toplam limit 3
        final snap = await _userDoc.collection('goals').get();
        count = snap.docs.length;
      } else if (collectionName == 'debts') {
        final snap = await _userDoc.collection('debts').get();
        count = snap.docs.where((d) {
          final data = d.data();
          if (!data.containsKey('createdAt')) return false;
          return DateTime.parse(data['createdAt']).isAfter(startOfDay);
        }).length;
      }
    } catch (e) {
      debugPrint("Limit Check Error: $e");
      return true; // Hata durumunda işlemi kilitleme
    }

    return count < 3;
  }
}
