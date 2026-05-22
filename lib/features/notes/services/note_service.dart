import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/note_model.dart';
import '../../badges/services/badge_service.dart';
import 'note_notification_service.dart';

import '../../../core/utils/stream_merger.dart';
import '../../family/models/family_models.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/services/notification_event_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final noteServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  final badgeService = ref.watch(badgeServiceProvider);
  return NoteService(uid, badgeService, ref);
});

final sharedNoteServiceProvider = Provider((ref) {
  final sharedOwnerId = ref.watch(sharedWorkspaceOwnerIdProvider);
  if (sharedOwnerId == null) return null;
  final badgeService = ref.watch(badgeServiceProvider);
  return NoteService(sharedOwnerId, badgeService, ref);
});

final notesStreamProvider = StreamProvider<List<NoteEntry>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(noteServiceProvider);
  final sharedService = ref.watch(sharedNoteServiceProvider);

  final personalStream = personalService.getNotes();
  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getNotes();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<NoteEntry>(
      personalStream,
      sharedService.getNotes(),
      (a, b) => b.date.compareTo(a.date),
    );
  }
  return personalStream;
});

class NoteService {
  final String? userId;
  final BadgeService _badgeService;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  NoteService(this.userId, this._badgeService, this._ref);

  CollectionReference get _notesColl => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('notes');

  Stream<List<NoteEntry>> getNotes() {
    if (userId == null) return Stream.value([]);
    return _notesColl.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => NoteEntry.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addNoteEntry(NoteEntry entry) async {
    await _notesColl.doc(entry.id).set(entry.toMap());
    
    // Ortak alan bildirimini gönder
    try {
      final profile = _ref.read(userProfileProvider).value;
      final actorName = (profile != null && profile.firstName.isNotEmpty)
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : 'Bir üye';
      await _ref.read(notificationEventServiceProvider).sendEvent(
        module: 'notes',
        action: 'create',
        title: 'Ortak Not',
        body: '$actorName ortak not ekledi: ${entry.title}',
      );
    } catch (_) {}
    
    // Hatırlatıcıyı planla
    if (entry.reminderDateTime != null) {
      await _ref.read(noteNotificationServiceProvider).scheduleNoteReminder(entry);
    } else {
      await _ref.read(noteNotificationServiceProvider).cancelNoteReminder(entry.id);
    }

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'notes',
        title: 'Not Eklendi',
        description: '\'${entry.title}\' başlıklı not oluşturuldu.',
        icon: '📝',
        metadata: {
          'noteId': entry.id,
          'title': entry.title,
        },
      );
    } catch (_) {}

    // Rozet Kontrolleri
    await _badgeService.unlockBadge('note_1');
    
    final snapshot = await _notesColl.limit(10).get();
    if (snapshot.docs.length >= 7) {
      await _badgeService.unlockBadge('note_7');
    }
  }

  Future<String> uploadImage(File imageFile, String entryId) async {
    final ref = _storage.ref().child('users').child(userId ?? 'anonymous').child('note_images').child(entryId).child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = await ref.putFile(imageFile);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> deleteNoteEntry(String id) async {
    await _ref.read(noteNotificationServiceProvider).cancelNoteReminder(id);
    await _notesColl.doc(id).delete();
  }
}
