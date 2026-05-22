import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';

class UserProgress {
  final int points;
  final int level;
  final Map<String, int> dailyStreaks;
  final DateTime lastUpdate;

  UserProgress({
    required this.points,
    required this.level,
    required this.dailyStreaks,
    required this.lastUpdate,
  });

  factory UserProgress.initial() => UserProgress(
    points: 0,
    level: 1,
    dailyStreaks: {},
    lastUpdate: DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'points': points,
    'level': level,
    'dailyStreaks': dailyStreaks,
    'lastUpdate': Timestamp.fromDate(lastUpdate),
  };

  factory UserProgress.fromMap(Map<String, dynamic> map) => UserProgress(
    points: map['points'] ?? 0,
    level: map['level'] ?? 1,
    dailyStreaks: Map<String, int>.from(map['dailyStreaks'] ?? {}),
    lastUpdate: (map['lastUpdate'] as Timestamp).toDate(),
  );

  UserProgress copyWith({int? points, int? level, Map<String, int>? dailyStreaks}) {
    return UserProgress(
      points: points ?? this.points,
      level: level ?? this.level,
      dailyStreaks: dailyStreaks ?? this.dailyStreaks,
      lastUpdate: DateTime.now(),
    );
  }
}

final gamificationServiceProvider = Provider((ref) => GamificationService(ref));

final userProgressStreamProvider = StreamProvider<UserProgress>((ref) {
  final service = ref.watch(gamificationServiceProvider);
  return service.getProgress();
});

class GamificationService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GamificationService(this._ref);

  String? get _userId => _ref.read(authStateProvider).value?.uid;
  DocumentReference get _progressDoc => _firestore.collection('users').doc(_userId ?? 'anonymous').collection('data').doc('progress');

  Stream<UserProgress> getProgress() {
    if (_userId == null) return Stream.value(UserProgress.initial());
    return _progressDoc.snapshots().map((doc) {
      if (doc.exists) {
        return UserProgress.fromMap(doc.data() as Map<String, dynamic>);
      }
      return UserProgress.initial();
    });
  }

  Future<void> addPoints(int amount, String reason) async {
    if (_userId == null) return;
    final current = await getProgress().first;
    int newPoints = current.points + amount;
    int newLevel = (newPoints / 500).floor() + 1;

    await _progressDoc.set(current.copyWith(
      points: newPoints,
      level: newLevel,
    ).toMap());

    // Opsiyonel: Bildirim veya log eklenebilir
  }

  Future<void> updateStreak(String module) async {
    if (_userId == null) return;
    final current = await getProgress().first;
    final streaks = Map<String, int>.from(current.dailyStreaks);
    streaks[module] = (streaks[module] ?? 0) + 1;
    
    await _progressDoc.set(current.copyWith(dailyStreaks: streaks).toMap());
  }
}
