import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/goal_model.dart';
import '../../badges/services/badge_service.dart';

import '../../../core/utils/stream_merger.dart';
import '../../family/models/family_models.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/services/notification_event_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final goalServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  final badgeService = ref.watch(badgeServiceProvider);
  return GoalService(uid, badgeService, ref);
});

final sharedGoalServiceProvider = Provider((ref) {
  final sharedOwnerId = ref.watch(sharedWorkspaceOwnerIdProvider);
  if (sharedOwnerId == null) return null;
  final badgeService = ref.watch(badgeServiceProvider);
  return GoalService(sharedOwnerId, badgeService, ref);
});

final goalsStreamProvider = StreamProvider<List<Goal>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(goalServiceProvider);
  final sharedService = ref.watch(sharedGoalServiceProvider);

  final personalStream = personalService.getGoals();
  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getGoals();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<Goal>(
      personalStream,
      sharedService.getGoals(),
      (a, b) => a.title.compareTo(b.title),
    );
  }
  return personalStream;
});

class GoalService {
  final String? userId;
  final BadgeService _badgeService;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GoalService(this.userId, this._badgeService, this._ref);

  CollectionReference get _goalsColl => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('goals');

  Stream<List<Goal>> getGoals() {
    if (userId == null) return Stream.value([]);
    return _goalsColl.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Goal.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addGoal(Goal goal) async {
    await _goalsColl.doc(goal.id).set(goal.toMap());
    
    // Ortak alan bildirimini gönder
    try {
      final profile = _ref.read(userProfileProvider).value;
      final actorName = (profile != null && profile.firstName.isNotEmpty)
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : 'Bir üye';
      await _ref.read(notificationEventServiceProvider).sendEvent(
        module: 'goals',
        action: 'create',
        title: 'Yeni Hedef',
        body: '$actorName \'${goal.title}\' hedefini oluşturdu.',
      );
    } catch (_) {}

    await _badgeService.unlockBadge('goal_1');

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'goals',
        title: 'Yeni Hedef',
        description: '\'${goal.title}\' hedefi oluşturuldu. Hedef: ${goal.targetAmount.toStringAsFixed(0)} TL',
        icon: '🎯',
        metadata: {
          'goalId': goal.id,
          'targetAmount': goal.targetAmount,
        },
      );
    } catch (_) {}
  }

  Future<void> updateGoalProgress(String id, double currentAmount) async {
    await _goalsColl.doc(id).update({'currentAmount': currentAmount});
    await _checkGoalBadges(id);
  }

  Future<void> addGoalProgress(String id, double additionalAmount, {String? paymentMethodName}) async {
    final deposit = GoalDeposit(
      amount: additionalAmount,
      date: DateTime.now(),
      paymentMethodName: paymentMethodName,
    );

    await _goalsColl.doc(id).update({
      'currentAmount': FieldValue.increment(additionalAmount),
      'history': FieldValue.arrayUnion([deposit.toMap()]),
    });
    
    // Ortak alan bildirimini gönder
    try {
      final doc = await _goalsColl.doc(id).get();
      if (doc.exists) {
        final goal = Goal.fromMap(doc.data() as Map<String, dynamic>);
        final profile = _ref.read(userProfileProvider).value;
        final actorName = (profile != null && profile.firstName.isNotEmpty)
            ? '${profile.firstName} ${profile.lastName}'.trim()
            : 'Bir üye';
        await _ref.read(notificationEventServiceProvider).sendEvent(
          module: 'goals',
          action: 'progress',
          title: 'Hedef Güncellemesi',
          body: '$actorName, \'${goal.title}\' hedefine ${additionalAmount.toStringAsFixed(0)} TL ekledi.',
        );

        // Yaşam Akışı Loglama
        await _ref.read(lifeTimelineServiceProvider).logEvent(
          module: 'goals',
          title: 'Hedef İlerlemesi',
          description: '\'${goal.title}\' hedefine ${additionalAmount.toStringAsFixed(0)} TL eklendi.',
          icon: '📈',
          metadata: {
            'goalId': id,
            'amount': additionalAmount,
          },
        );
      }
    } catch (_) {}
    
    await _checkGoalBadges(id);
  }

  Future<void> _checkGoalBadges(String id) async {
    final doc = await _goalsColl.doc(id).get();
    if (doc.exists) {
      final goal = Goal.fromMap(doc.data() as Map<String, dynamic>);
      final progress = goal.currentAmount / goal.targetAmount;
      
      if (progress >= 0.5) await _badgeService.unlockBadge('goal_50');
      if (progress >= 1.0) {
        await _badgeService.unlockBadge('goal_done');
        try {
          final service = _ref.read(lifeTimelineServiceProvider);
          final existing = await service.timelineColl
              .where('module', isEqualTo: 'goals')
              .where('eventType', isEqualTo: 'achievement')
              .where('metadata.goalId', isEqualTo: id)
              .limit(1)
              .get();
          if (existing.docs.isEmpty) {
            await service.logEvent(
              module: 'goals',
              title: 'Hedef Tamamlandı 🏆',
              description: '\'${goal.title}\' hedefi başarıyla tamamlandı!',
              icon: '🏆',
              metadata: {
                'goalId': id,
              },
              eventType: 'achievement',
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> removeGoalProgress(String id, double amount) async {
    // History'den tam eşleşen kaydı silmek zor olabilir (timestamp milisaniye farkı vb)
    // Bu yüzden sadece tutarı düşüyoruz. 
    // Gelişmiş versiyonda history'den de silinebilir.
    await _goalsColl.doc(id).update({
      'currentAmount': FieldValue.increment(-amount),
    });
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _ref.read(lifeTimelineServiceProvider).markEventAsDeleted(key: 'goalId', value: id);
    } catch (_) {}
    await _goalsColl.doc(id).delete();
  }
}
