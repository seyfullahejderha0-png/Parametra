import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/family/services/family_service.dart';
import '../../features/family/models/family_models.dart';

final notificationEventServiceProvider = Provider((ref) {
  return NotificationEventService(ref);
});

class NotificationEventService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  NotificationEventService(this._ref);

  Future<void> sendEvent({
    required String module,
    required String action,
    required String title,
    required String body,
  }) async {
    try {
      final workspaceType = _ref.read(workspaceTypeProvider);
      if (workspaceType != WorkspaceType.shared) return;

      final spaceId = _ref.read(activeSharedSpaceIdProvider);
      if (spaceId == null) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final ownerId = _ref.read(workspaceUserIdProvider);
      if (ownerId == null) return;

      final docRef = _firestore.collection('family_notifications').doc();
      await docRef.set({
        'id': docRef.id,
        'spaceId': spaceId,
        'ownerId': ownerId,
        'actorId': currentUser.uid,
        'module': module,
        'action': action,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Fail silently to prevent UI disruption
      print('Error writing family notification event: $e');
    }
  }
}
