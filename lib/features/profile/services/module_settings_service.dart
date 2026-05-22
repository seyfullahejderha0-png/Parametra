import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notification_providers.dart';
import '../../auth/services/auth_service.dart';
import '../models/module_setting.dart';

final moduleSettingsProvider = NotifierProvider<ModuleSettingsNotifier, List<ModuleSetting>>(() {
  return ModuleSettingsNotifier();
});

class ModuleSettingsNotifier extends Notifier<List<ModuleSetting>> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _userId => ref.watch(authStateProvider).value?.uid;

  DocumentReference get _settingsDoc => _firestore
      .collection('users')
      .doc(_userId ?? 'anonymous')
      .collection('data')
      .doc('module_settings');

  @override
  List<ModuleSetting> build() {
    _loadSettings();
    return _defaultSettings;
  }

  List<ModuleSetting> get _defaultSettings => [
    ModuleSetting(id: 'finance', nameKey: 'finance_card', icon: Icons.account_balance_wallet, canHide: false),
    ModuleSetting(id: 'debts', nameKey: 'debt_card', icon: Icons.handshake),
    ModuleSetting(id: 'notes', nameKey: 'notes_card', icon: Icons.note_alt_outlined),
    ModuleSetting(id: 'smoking', nameKey: 'smoking_card', icon: Icons.smoke_free),
    ModuleSetting(id: 'health', nameKey: 'health_card', icon: Icons.favorite),
    ModuleSetting(id: 'medication', nameKey: 'medication_card', icon: Icons.medication),
    ModuleSetting(id: 'goals', nameKey: 'goals_card', icon: Icons.track_changes),
    ModuleSetting(id: 'ai', nameKey: 'ai_assistant_card', icon: Icons.psychology),
  ];

  Future<void> _loadSettings() async {
    if (_userId == null) return;

    try {
      final doc = await _settingsDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> settingsList = data['settings'] ?? [];
        
        final List<ModuleSetting> loaded = _defaultSettings.map((def) {
          final found = settingsList.firstWhere((s) => s['id'] == def.id, orElse: () => null);
          if (found != null) {
            return def.copyWith(
              isVisible: found['isVisible'] ?? true,
              notificationsEnabled: found['notificationsEnabled'] ?? true,
            );
          }
          return def;
        }).toList();

        state = loaded;
      }
    } catch (e) {
      debugPrint('Error loading module settings: $e');
    }
  }

  Future<void> updateSetting(String id, {bool? isVisible, bool? notificationsEnabled}) async {
    state = [
      for (final s in state)
        if (s.id == id)
          s.copyWith(
            isVisible: isVisible ?? s.isVisible,
            notificationsEnabled: notificationsEnabled ?? s.notificationsEnabled,
          )
        else
          s
    ];

    if (notificationsEnabled != null) {
      ref.read(notificationServiceProvider).sendTag('${id}_notifications', notificationsEnabled);
    }

    await _saveSettings();
  }

  Future<void> restoreDefaults() async {
    state = _defaultSettings;
    for (final s in state) {
      ref.read(notificationServiceProvider).sendTag('${s.id}_notifications', s.notificationsEnabled);
    }
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    if (_userId == null) return;

    try {
      await _settingsDoc.set({
        'settings': state.map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving module settings: $e');
    }
  }
}
