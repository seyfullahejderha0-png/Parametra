import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/health_models.dart';
import '../../badges/services/badge_service.dart';
import '../../../core/services/widget_service.dart';
import '../../gamification/services/gamification_service.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/services/notification_event_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final healthServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  final badgeService = ref.watch(badgeServiceProvider);
  return HealthService(uid, badgeService, ref);
});

final waterGoalProvider = StreamProvider<double>((ref) {
  final service = ref.watch(healthServiceProvider);
  return service.getWaterGoal();
});

final dailyWaterProvider = StreamProvider<List<WaterIntake>>((ref) {
  final service = ref.watch(healthServiceProvider);
  return service.getDailyWater(DateTime.now());
});

final waterLogsProvider = StreamProvider<List<WaterIntake>>((ref) {
  final service = ref.watch(healthServiceProvider);
  return service.getDailyWater(DateTime.now()).map((list) => list.reversed.toList());
});

final weeklyWaterProvider = StreamProvider<Map<int, double>>((ref) {
  final service = ref.watch(healthServiceProvider);
  return service.getWeeklyWater();
});

final activitiesStreamProvider = StreamProvider<List<Activity>>((ref) {
  final service = ref.watch(healthServiceProvider);
  return service.getActivities();
});

final activeActivityProvider = StreamProvider<ActiveActivity?>((ref) {
  final service = ref.watch(healthServiceProvider);
  return service.getActiveActivity();
});

class HealthService {
  final String? userId;
  final BadgeService _badgeService;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  HealthService(this.userId, this._badgeService, this._ref);

  CollectionReference get _userHealthDoc => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('health');

  Stream<ActiveActivity?> getActiveActivity() {
    if (userId == null) return Stream.value(null);
    return _userHealthDoc
        .doc('activities')
        .collection('active')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? ActiveActivity.fromMap(doc.data() as Map<String, dynamic>) : null);
  }

  Future<void> startActivity(ActiveActivity activity) async {
    await _userHealthDoc.doc('activities').collection('active').doc('current').set(activity.toMap());
  }

  Future<void> stopActivity() async {
    await _userHealthDoc.doc('activities').collection('active').doc('current').delete();
  }

  Stream<double> getWaterGoal() {
    if (userId == null) return Stream.value(3.0);
    return _userHealthDoc.doc('water').snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['goal'] as num?)?.toDouble() ?? 3.0;
      }
      return 3.0;
    });
  }

  Future<void> setWaterGoal(double goal) async {
    await _userHealthDoc.doc('water').set({'goal': goal}, SetOptions(merge: true));
  }

  Stream<List<WaterIntake>> getDailyWater(DateTime date) {
    if (userId == null) return Stream.value([]);
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _userHealthDoc
        .doc('water')
        .collection('intakes')
        .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('date', isLessThan: endOfDay.toIso8601String())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => WaterIntake.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Stream<Map<int, double>> getWeeklyWater() {
    if (userId == null) return Stream.value({});
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return _userHealthDoc
        .doc('water')
        .collection('intakes')
        .where('date', isGreaterThanOrEqualTo: sevenDaysAgo.toIso8601String())
        .snapshots()
        .map((snapshot) {
          final Map<int, double> weeklyData = {};
          for (var doc in snapshot.docs) {
            final intake = WaterIntake.fromMap(doc.data() as Map<String, dynamic>);
            final weekday = intake.date.weekday;
            weeklyData[weekday] = (weeklyData[weekday] ?? 0.0) + intake.amount;
          }
          return weeklyData;
        });
  }

  Stream<List<Activity>> getActivities() {
    if (userId == null) return Stream.value([]);
    return _userHealthDoc
        .doc('activities')
        .collection('entries')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Activity.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addWater(WaterIntake intake) async {
    await _userHealthDoc.doc('water').collection('intakes').doc(intake.id).set(intake.toMap());
    
    // Ortak alan bildirimini gönder
    try {
      final profile = _ref.read(userProfileProvider).value;
      final actorName = (profile != null && profile.firstName.isNotEmpty)
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : 'Bir üye';
      await _ref.read(notificationEventServiceProvider).sendEvent(
        module: 'health',
        action: 'create',
        title: 'Su Tüketimi',
        body: '$actorName su içti: ${intake.amount.toStringAsFixed(1)} L',
      );
    } catch (_) {}
    
    // Rozet Kontrolü
    final goal = await getWaterGoal().first;
    final intakes = await getDailyWater(DateTime.now()).first;
    final total = intakes.fold(0.0, (sum, WaterIntake item) => sum + item.amount);
    
    if (total >= goal) {
      await _badgeService.unlockBadge('water_1');
      await _ref.read(gamificationServiceProvider).addPoints(50, "Günlük su hedefine ulaşıldı!");
    } else {
      await _ref.read(gamificationServiceProvider).addPoints(10, "Su içildi");
    }
    
    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'health',
        title: 'Su Tüketimi',
        description: '${intake.amount.toStringAsFixed(1)} L su içildi.',
        icon: '💧',
        metadata: {
          'amount': intake.amount,
        },
      );
    } catch (_) {}
    
    // Update Widget
    _ref.read(widgetServiceProvider).updateWidgets();
  }

  Future<void> deleteWater(String id) async {
    await _userHealthDoc.doc('water').collection('intakes').doc(id).delete();
    _ref.read(widgetServiceProvider).updateWidgets();
  }

  Future<void> addActivity(Activity activity) async {
    await _userHealthDoc.doc('activities').collection('entries').doc(activity.id).set(activity.toMap());
    
    // Ortak alan bildirimini gönder
    try {
      final profile = _ref.read(userProfileProvider).value;
      final actorName = (profile != null && profile.firstName.isNotEmpty)
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : 'Bir üye';
      await _ref.read(notificationEventServiceProvider).sendEvent(
        module: 'health',
        action: 'create',
        title: 'Sağlık Aktivitesi',
        body: '$actorName yeni bir sağlık aktivitesi kaydetti: ${activity.type}',
      );
    } catch (_) {}

    // Rozet Kontrolü
    await _badgeService.unlockBadge('health_7');

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'health',
        title: 'Sağlık Aktivitesi',
        description: '${activity.type} tamamlandı: ${activity.durationMinutes} dakika.',
        icon: '🏃',
        metadata: {
          'activityId': activity.id,
          'type': activity.type,
          'durationMinutes': activity.durationMinutes,
        },
      );
    } catch (_) {}
  }
}
