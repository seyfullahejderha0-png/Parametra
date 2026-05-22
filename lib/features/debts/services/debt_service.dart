import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/debt_model.dart';
import '../../finance/services/finance_notification_service.dart';

import '../../../core/utils/stream_merger.dart';
import '../../family/models/family_models.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/services/notification_event_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final debtServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  return DebtService(uid, ref);
});

final sharedDebtServiceProvider = Provider((ref) {
  final sharedOwnerId = ref.watch(sharedWorkspaceOwnerIdProvider);
  if (sharedOwnerId == null) return null;
  return DebtService(sharedOwnerId, ref);
});

final debtsStreamProvider = StreamProvider<List<Debt>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(debtServiceProvider);
  final sharedService = ref.watch(sharedDebtServiceProvider);

  final personalStream = personalService.getDebts();
  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getDebts();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<Debt>(
      personalStream,
      sharedService.getDebts(),
      (a, b) => b.date.compareTo(a.date),
    );
  }
  return personalStream;
});

class DebtService {
  final String? userId;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DebtService(this.userId, this._ref);

  CollectionReference get _debtsColl => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('debts');

  Stream<List<Debt>> getDebts() {
    if (userId == null) return Stream.value([]);
    return _debtsColl.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Debt.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addDebt(Debt debt) async {
    await _debtsColl.doc(debt.id).set(debt.toMap());
    
    // Ortak alan bildirimini gönder
    try {
      final profile = _ref.read(userProfileProvider).value;
      final actorName = (profile != null && profile.firstName.isNotEmpty)
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : 'Bir üye';
      final debtTypeName = debt.type == DebtType.borc ? 'borç' : 'alacak';
      await _ref.read(notificationEventServiceProvider).sendEvent(
        module: 'finance',
        action: 'create',
        title: 'Borç/Alacak Kaydı',
        body: '$actorName yeni bir $debtTypeName kaydı ekledi: ${debt.personName} (${debt.amount.toStringAsFixed(0)} TL)',
      );
    } catch (_) {}

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'finance',
        title: debt.type == DebtType.borc ? 'Borç Eklendi' : 'Alacak Eklendi',
        description: '${debt.personName}: ${debt.amount.toStringAsFixed(0)} TL',
        icon: debt.type == DebtType.borc ? '🤝' : '💸',
        metadata: {
          'debtId': debt.id,
          'amount': debt.amount,
          'type': debt.type.name,
          'personName': debt.personName,
        },
      );
    } catch (_) {}
    
    // Vade bildirimi planla
    if (debt.dueDate != null) {
      _ref.read(financeNotificationServiceProvider).scheduleDebtReminder(
        debt.personName, 
        debt.dueDate!,
        isCredit: debt.type == DebtType.alacak,
      );
    }
  }

  Future<void> updateDebt(Debt debt) async {
    await _debtsColl.doc(debt.id).set(debt.toMap());
  }

  Future<void> updateDebtStatus(String id, bool isPaid) async {
    await _debtsColl.doc(id).update({'isPaid': isPaid});
  }

  Future<void> deleteDebt(String id) async {
    try {
      await _ref.read(lifeTimelineServiceProvider).markEventAsDeleted(key: 'debtId', value: id);
    } catch (_) {}
    await _debtsColl.doc(id).delete();
  }

  Future<void> deleteGroupedDebts(String parentId) async {
    final snapshots = await _debtsColl.where('parentId', isEqualTo: parentId).get();
    final batch = _firestore.batch();
    for (var doc in snapshots.docs) {
      final debtId = doc.id;
      try {
        await _ref.read(lifeTimelineServiceProvider).markEventAsDeleted(key: 'debtId', value: debtId);
      } catch (_) {}
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
