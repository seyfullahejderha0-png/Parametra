import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/services/family_service.dart';
import '../../family/models/family_models.dart';
import '../models/life_timeline_event.dart';
import '../../../core/utils/stream_merger.dart';

final lifeTimelineServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  return LifeTimelineService(uid, ref);
});

final sharedLifeTimelineServiceProvider = Provider((ref) {
  final sharedOwnerId = ref.watch(sharedWorkspaceOwnerIdProvider);
  if (sharedOwnerId == null) return null;
  return LifeTimelineService(sharedOwnerId, ref);
});

final lifeTimelineEventsProvider = StreamProvider<List<LifeTimelineEvent>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(lifeTimelineServiceProvider);
  final sharedService = ref.watch(sharedLifeTimelineServiceProvider);

  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getEvents();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<LifeTimelineEvent>(
      personalService.getEvents(),
      sharedService.getEvents(),
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );
  }
  return personalService.getEvents();
});

class LifeTimelineService {
  final String? userId;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LifeTimelineService(this.userId, this._ref);

  CollectionReference get _timelineColl => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('life_timeline');

  CollectionReference get timelineColl => _timelineColl;

  DocumentReference get _summaryCacheDoc => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('meta')
      .doc('timeline_summary');

  Stream<List<LifeTimelineEvent>> getEvents({int? limit}) {
    if (userId == null) return Stream.value([]);
    var query = _timelineColl.orderBy('timestamp', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => LifeTimelineEvent.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  /// AI Summary caching methods
  Future<Map<String, dynamic>?> getCachedSummary() async {
    try {
      if (userId == null) return null;
      final doc = await _summaryCacheDoc.get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      print('Error getting cached summary: $e');
    }
    return null;
  }

  Future<void> saveCachedSummary({
    required String summary,
    required String lastEventId,
    required DateTime lastEventTimestamp,
  }) async {
    try {
      if (userId == null) return;
      await _summaryCacheDoc.set({
        'summary': summary,
        'lastEventId': lastEventId,
        'lastEventTimestamp': lastEventTimestamp.toIso8601String(),
        'generatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving cached summary: $e');
    }
  }

  Future<void> logEvent({
    required String module,
    required String title,
    required String description,
    required String icon,
    Map<String, dynamic>? metadata,
    String eventType = 'normal',
  }) async {
    try {
      if (userId == null) return;
      final actorId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final workspaceTypeVal = _ref.read(workspaceTypeProvider);
      final workspaceTypeStr = workspaceTypeVal == WorkspaceType.shared ? 'shared' : 'personal';

      // Grouping rules for anti-spam: Su, Sigara, İlaç
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      if (module == 'health' && (title == 'Su Tüketimi' || title == 'Sigara Kaydı' || title == 'İlaç Alındı')) {
        // Query if an event exists for today of the same title
        final query = await _timelineColl
            .where('module', isEqualTo: 'health')
            .where('title', isEqualTo: title)
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final existingEvent = LifeTimelineEvent.fromMap(doc.data() as Map<String, dynamic>);
          
          if (title == 'Su Tüketimi') {
            final oldAmount = (existingEvent.metadata?['amount'] as num?)?.toDouble() ?? 0.0;
            final additionalAmount = (metadata?['amount'] as num?)?.toDouble() ?? 0.25;
            final newAmount = oldAmount + additionalAmount;

            final updatedEvent = LifeTimelineEvent(
              id: existingEvent.id,
              timestamp: now,
              module: module,
              title: title,
              description: '${newAmount.toStringAsFixed(1)} L su içildi.',
              actorId: actorId,
              workspaceType: workspaceTypeStr,
              icon: icon,
              metadata: {
                'amount': newAmount,
              },
              eventType: eventType,
            );

            await doc.reference.set(updatedEvent.toMap());
            return;
          } else if (title == 'Sigara Kaydı') {
            final oldCount = (existingEvent.metadata?['count'] as num?)?.toInt() ?? 1;
            final newCount = oldCount + 1;

            final updatedEvent = LifeTimelineEvent(
              id: existingEvent.id,
              timestamp: now,
              module: module,
              title: title,
              description: 'Bugün $newCount sigara içildi.',
              actorId: actorId,
              workspaceType: workspaceTypeStr,
              icon: icon,
              metadata: {
                'count': newCount,
              },
              eventType: 'warning',
            );

            await doc.reference.set(updatedEvent.toMap());
            return;
          } else if (title == 'İlaç Alındı') {
            // Group if it is the same medication
            final medName = metadata?['medicationName'] ?? '';
            final existingMedName = existingEvent.metadata?['medicationName'] ?? '';
            if (medName == existingMedName) {
              final oldCount = (existingEvent.metadata?['count'] as num?)?.toInt() ?? 1;
              final newCount = oldCount + 1;

              final updatedEvent = LifeTimelineEvent(
                id: existingEvent.id,
                timestamp: now,
                module: module,
                title: title,
                description: '$medName ilacı bugünkü $newCount. dozu alındı.',
                actorId: actorId,
                workspaceType: workspaceTypeStr,
                icon: icon,
                metadata: {
                  'medicationName': medName,
                  'count': newCount,
                },
                eventType: eventType,
              );

              await doc.reference.set(updatedEvent.toMap());
              return;
            }
          }
        }
      }

      // Normal path: write new event document
      final docRef = _timelineColl.doc();
      final event = LifeTimelineEvent(
        id: docRef.id,
        timestamp: now,
        module: module,
        title: title,
        description: description,
        actorId: actorId,
        workspaceType: workspaceTypeStr,
        icon: icon,
        metadata: metadata,
        eventType: eventType,
      );

      await docRef.set(event.toMap());
    } catch (e) {
      print('Error logging timeline event: $e');
    }
  }

  Future<void> markEventAsDeleted({
    required String key,
    required String value,
  }) async {
    try {
      if (userId == null) return;
      final snap = await _timelineColl.where('metadata.$key', isEqualTo: value).get();
      for (var doc in snap.docs) {
        await doc.reference.update({
          'isDeleted': true,
          'eventType': 'deleted',
        });
      }
    } catch (e) {
      print('Error marking event as deleted: $e');
    }
  }
}
