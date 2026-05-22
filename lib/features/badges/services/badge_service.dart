import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../models/badge_model.dart';

final badgeServiceProvider = Provider((ref) {
  final user = ref.watch(authStateProvider).value;
  return BadgeService(user?.uid);
});

final userBadgesStreamProvider = StreamProvider<List<BadgeModel>>((ref) {
  final service = ref.watch(badgeServiceProvider);
  return service.getBadgesStream();
});

class BadgeService {
  final String? userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  BadgeService(this.userId);

  CollectionReference get _badgeDoc => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('badges');

  // Tüm rozetlerin statik listesi
  static final List<BadgeModel> allBadges = [
    // FİNANS
    BadgeModel(id: 'fin_1', titleKey: 'badge_fin_1_title', descriptionKey: 'badge_fin_1_desc', icon: '💸', category: BadgeCategory.finance, rarity: BadgeRarity.common, themeColor: Colors.green),
    BadgeModel(id: 'fin_7', titleKey: 'badge_fin_7_title', descriptionKey: 'badge_fin_7_desc', icon: '📊', category: BadgeCategory.finance, rarity: BadgeRarity.rare, themeColor: Colors.green),
    BadgeModel(id: 'fin_30', titleKey: 'badge_fin_30_title', descriptionKey: 'badge_fin_30_desc', icon: '🏆', category: BadgeCategory.finance, rarity: BadgeRarity.legendary, themeColor: Colors.green),
    
    // BORÇ
    BadgeModel(id: 'debt_3', titleKey: 'badge_debt_3_title', descriptionKey: 'badge_debt_3_desc', icon: '📅', category: BadgeCategory.debt, rarity: BadgeRarity.common, themeColor: Colors.orange),
    BadgeModel(id: 'debt_seri', titleKey: 'badge_debt_seri_title', descriptionKey: 'badge_debt_seri_desc', icon: '✅', category: BadgeCategory.debt, rarity: BadgeRarity.rare, themeColor: Colors.orange),
    
    // NOTLAR
    BadgeModel(id: 'note_1', titleKey: 'badge_note_1_title', descriptionKey: 'badge_note_1_desc', icon: '📝', category: BadgeCategory.notes, rarity: BadgeRarity.common, themeColor: Colors.purple),
    BadgeModel(id: 'note_7', titleKey: 'badge_note_7_title', descriptionKey: 'badge_note_7_desc', icon: '📖', category: BadgeCategory.notes, rarity: BadgeRarity.rare, themeColor: Colors.purple),
    
    // SİGARA
    BadgeModel(id: 'smoke_1', titleKey: 'badge_smoke_1_title', descriptionKey: 'badge_smoke_1_desc', icon: '🚭', category: BadgeCategory.smoking, rarity: BadgeRarity.common, themeColor: Colors.deepOrange),
    BadgeModel(id: 'smoke_7', titleKey: 'badge_smoke_7_title', descriptionKey: 'badge_smoke_7_desc', icon: '💪', category: BadgeCategory.smoking, rarity: BadgeRarity.epic, themeColor: Colors.deepOrange),
    BadgeModel(id: 'smoke_30', titleKey: 'badge_smoke_30_title', descriptionKey: 'badge_smoke_30_desc', icon: '🔥', category: BadgeCategory.smoking, rarity: BadgeRarity.legendary, themeColor: Colors.deepOrange),
    
    // SAĞLIK
    BadgeModel(id: 'water_1', titleKey: 'badge_water_1_title', descriptionKey: 'badge_water_1_desc', icon: '💧', category: BadgeCategory.health, rarity: BadgeRarity.common, themeColor: Colors.blue),
    BadgeModel(id: 'water_7', titleKey: 'badge_water_7_title', descriptionKey: 'badge_water_7_desc', icon: '🌊', category: BadgeCategory.health, rarity: BadgeRarity.rare, themeColor: Colors.blue),
    BadgeModel(id: 'health_7', titleKey: 'badge_health_7_title', descriptionKey: 'badge_health_7_desc', icon: '🏃', category: BadgeCategory.health, rarity: BadgeRarity.epic, themeColor: Colors.redAccent),
    
    // İLAÇ
    BadgeModel(id: 'med_7', titleKey: 'badge_med_7_title', descriptionKey: 'badge_med_7_desc', icon: '💊', category: BadgeCategory.medication, rarity: BadgeRarity.rare, themeColor: Colors.tealAccent),
    
    // HEDEF
    BadgeModel(id: 'goal_1', titleKey: 'badge_goal_1_title', descriptionKey: 'badge_goal_1_desc', icon: '🎯', category: BadgeCategory.goals, rarity: BadgeRarity.common, themeColor: Colors.deepPurple),
    BadgeModel(id: 'goal_50', titleKey: 'badge_goal_50_title', descriptionKey: 'badge_goal_50_desc', icon: '📈', category: BadgeCategory.goals, rarity: BadgeRarity.rare, themeColor: Colors.deepPurple),
    BadgeModel(id: 'goal_done', titleKey: 'badge_goal_done_title', descriptionKey: 'badge_goal_done_desc', icon: '🏆', category: BadgeCategory.goals, rarity: BadgeRarity.epic, themeColor: Colors.deepPurple),
    
    // AI
    BadgeModel(id: 'ai_1', titleKey: 'badge_ai_1_title', descriptionKey: 'badge_ai_1_desc', icon: '🤖', category: BadgeCategory.ai, rarity: BadgeRarity.epic, themeColor: Colors.indigoAccent),
  ];

  Stream<List<BadgeModel>> getBadgesStream() {
    if (userId == null) return Stream.value(allBadges);

    return _badgeDoc.snapshots().map((snapshot) {
      final unlockedData = {for (var doc in snapshot.docs) doc.id: (doc.data() as Map<String, dynamic>)['unlockedAt']};
      
      return allBadges.map((badge) {
        if (unlockedData.containsKey(badge.id)) {
          return badge.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.tryParse(unlockedData[badge.id] ?? ''),
          );
        }
        return badge;
      }).toList();
    });
  }

  Future<void> unlockBadge(String badgeId) async {
    if (userId == null) return;

    final doc = await _badgeDoc.doc(badgeId).get();
    if (doc.exists) return; // Zaten açılmış

    await _badgeDoc.doc(badgeId).set({
      'unlockedAt': DateTime.now().toIso8601String(),
    });

    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Bildirim tetiklenebilir (UI tarafında Stream dinlenerek yapılmalı)
  }
}
