import 'package:flutter/material.dart';

class ModuleSetting {
  final String id;
  final String nameKey;
  final IconData icon;
  final bool isVisible;
  final bool notificationsEnabled;
  final bool canHide;

  ModuleSetting({
    required this.id,
    required this.nameKey,
    required this.icon,
    this.isVisible = true,
    this.notificationsEnabled = true,
    this.canHide = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isVisible': isVisible,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory ModuleSetting.fromMap(Map<String, dynamic> map, String nameKey, IconData icon, bool canHide) {
    return ModuleSetting(
      id: map['id'],
      nameKey: nameKey,
      icon: icon,
      isVisible: map['isVisible'] ?? true,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      canHide: canHide,
    );
  }

  ModuleSetting copyWith({
    bool? isVisible,
    bool? notificationsEnabled,
  }) {
    return ModuleSetting(
      id: id,
      nameKey: nameKey,
      icon: icon,
      isVisible: isVisible ?? this.isVisible,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      canHide: canHide,
    );
  }
}
