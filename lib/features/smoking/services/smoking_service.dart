import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/services/family_service.dart';
import '../models/smoking_model.dart';
import '../../badges/services/badge_service.dart';
import '../../../core/services/widget_service.dart';
import '../../gamification/services/gamification_service.dart';
import 'smoking_notification_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final smokingServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  final badgeService = ref.watch(badgeServiceProvider);
  return SmokingService(uid, badgeService, ref);
});

final smokingStreamProvider = StreamProvider<SmokingData?>((ref) {
  final service = ref.watch(smokingServiceProvider);
  return service.getSmokingData();
});

class SmokingService {
  final String? userId;
  final BadgeService _badgeService;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SmokingService(this.userId, this._badgeService, this._ref);

  DocumentReference get _smokingDoc => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('data')
      .doc('smoking');

  Stream<SmokingData?> getSmokingData() {
    if (userId == null) return Stream.value(null);
    return _smokingDoc
        .snapshots()
        .map((doc) => doc.exists ? SmokingData.fromMap(doc.data() as Map<String, dynamic>) : null);
  }

  Future<void> saveSmokingData(SmokingData data) async {
    await _smokingDoc.set(data.toMap());
    await checkBadges(data);
    
    // Miltaşlarını planla
    _ref.read(smokingNotificationServiceProvider).scheduleMilestones(data.startDate);
    
    _ref.read(widgetServiceProvider).updateWidgets();
  }

  Future<void> logCigarette(SmokingData current) async {
    final now = DateTime.now();
    final key = "${now.year}-${now.month}-${now.day}";
    
    // Günlük logları güncelle
    final logs = Map<String, int>.from(current.dailySmokedLogs);
    logs[key] = (logs[key] ?? 0) + 1;
    
    // Rekor süreyi kontrol et ve güncelle
    final currentStreakSeconds = now.difference(current.startDate).inSeconds;
    final newLongest = currentStreakSeconds > current.longestSmokeFreeSeconds 
        ? currentStreakSeconds 
        : current.longestSmokeFreeSeconds;
        
    // Puan düşür (ceza mantığı)
    await _ref.read(gamificationServiceProvider).addPoints(-20, "Sigara içildi - Süre sıfırlandı");
    
    // Veriyi kaydet (Süre sıfırlanır, rekor güncellenir, log artar)
    await saveSmokingData(current.copyWith(
      dailySmokedLogs: logs,
      startDate: now,
      longestSmokeFreeSeconds: newLongest,
    ));

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'health',
        title: 'Sigara Kaydı',
        description: 'Bugün 1 sigara içildi.',
        icon: '🚬',
        metadata: {
          'count': 1,
        },
        eventType: 'warning',
      );
    } catch (_) {}
  }

  Future<void> resetProcess(SmokingData current) async {
    final now = DateTime.now();
    final currentStreakSeconds = now.difference(current.startDate).inSeconds;
    final newLongest = currentStreakSeconds > current.longestSmokeFreeSeconds 
        ? currentStreakSeconds 
        : current.longestSmokeFreeSeconds;
        
    await _ref.read(gamificationServiceProvider).addPoints(100, "Yeni bir temiz başlangıç!");
    
    final newData = current.copyWith(
      startDate: now,
      longestSmokeFreeSeconds: newLongest,
    );
    
    await saveSmokingData(newData);

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'health',
        title: 'Yeni Bir Başlangıç 🌟',
        description: 'Sigarayı bırakma süreci sıfırlandı ve yeni bir başlangıç yapıldı!',
        icon: '🌟',
        eventType: 'milestone',
      );
    } catch (_) {}
  }

  Future<void> checkBadges(SmokingData data) async {
    final diff = DateTime.now().difference(data.startDate);
    if (diff.inHours >= 24) await _badgeService.unlockBadge('smoke_1');
    if (diff.inDays >= 7) await _badgeService.unlockBadge('smoke_7');
    if (diff.inDays >= 30) await _badgeService.unlockBadge('smoke_30');
  }
}
