import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/admin_user_model.dart';
import '../../subscription/models/subscription_model.dart';

final adminServiceProvider = Provider((ref) => AdminService(ref));

final adminUsersProvider = FutureProvider<List<AdminUserData>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return await service.fetchAdminUsers();
});

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AdminService(Ref ref);

  Future<List<AdminUserData>> fetchAdminUsers() async {
    // 1. Tüm kullanıcı profillerini oku
    final usersSnap = await _firestore.collection('users').get();
    
    final List<AdminUserData> adminUsers = [];
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Veritabanı sorgularını kullanıcı bazında paralel yapıyoruz
    await Future.wait(usersSnap.docs.map((userDoc) async {
      final userId = userDoc.id;
      final data = userDoc.data();
      final firstName = data['firstName'] as String? ?? '';
      final lastName = data['lastName'] as String? ?? '';
      final email = data['email'] as String? ?? '';
      final platform = data['platform'] as String? ?? 'Android';
      
      DateTime? lastLoginTime;
      if (data['lastLogin'] is Timestamp) {
        lastLoginTime = (data['lastLogin'] as Timestamp).toDate();
      }

      // Her kullanıcının abonelik durumunu oku
      SubscriptionData sub = SubscriptionData(type: SubscriptionType.free, startDate: DateTime.now());
      try {
        final subDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('subscription')
            .doc('status')
            .get();
        if (subDoc.exists && subDoc.data() != null) {
          sub = SubscriptionData.fromMap(subDoc.data()!);
        }
      } catch (_) {}

      // Her kullanıcının AI kullanım miktarlarını oku
      int todayUsage = 0;
      int totalUsage = 0;
      try {
        final usagesSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('ai_usage')
            .get();
        for (var doc in usagesSnap.docs) {
          final count = doc.data()['count'] as int? ?? 0;
          totalUsage += count;
          if (doc.id == todayStr) {
            todayUsage = count;
          }
        }
      } catch (_) {}
      
      // Kullanıcının gerçek modül kullanımlarını sorgula
      final List<String> activeModules = [];
      
      // 1. Gelir Gider
      try {
        final snap = await _firestore.collection('users').doc(userId).collection('finance').limit(1).get();
        if (snap.docs.isNotEmpty) activeModules.add('Gelir Gider');
      } catch (_) {}

      // 2. Hedefler
      try {
        final snap = await _firestore.collection('users').doc(userId).collection('goals').limit(1).get();
        if (snap.docs.isNotEmpty) activeModules.add('Hedefler');
      } catch (_) {}

      // 3. Notlar
      try {
        final snap = await _firestore.collection('users').doc(userId).collection('notes').limit(1).get();
        if (snap.docs.isNotEmpty) activeModules.add('Notlar');
      } catch (_) {}

      // 4. Hatırlatıcılar
      try {
        final snap = await _firestore.collection('users').doc(userId).collection('reminders').limit(1).get();
        if (snap.docs.isNotEmpty) activeModules.add('Hatırlatıcılar');
      } catch (_) {}

      // 5. Sağlık (Su, İlaç vb.)
      try {
        final healthSnap = await _firestore.collection('users').doc(userId).collection('health').limit(1).get();
        final medSnap = await _firestore.collection('users').doc(userId).collection('medication').limit(1).get();
        if (healthSnap.docs.isNotEmpty || medSnap.docs.isNotEmpty) activeModules.add('Sağlık');
      } catch (_) {}

      // 6. AI Asistan
      if (totalUsage > 0) {
        activeModules.add('AI Asistan');
      }

      adminUsers.add(
        AdminUserData(
          userId: userId,
          name: '$firstName $lastName'.trim().isEmpty ? 'İsimsiz Kullanıcı' : '$firstName $lastName',
          email: email.isEmpty ? 'E-posta Yok' : email,
          subscriptionType: sub.type,
          startDate: sub.startDate,
          endDate: sub.endDate,
          dailyUsageCount: todayUsage,
          totalUsageCount: totalUsage,
          lastLogin: lastLoginTime,
          platform: platform,
          activeModules: activeModules,
          isSupporter: sub.isSupporter,
          sku: sub.sku,
        ),
      );
    }));

    return adminUsers;
  }
}
