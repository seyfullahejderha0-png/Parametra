import 'package:flutter/material.dart';

enum BadgeCategory { finance, health, debt, notes, smoking, medication, goals, ai }
enum BadgeRarity { common, rare, epic, legendary }

class BadgeModel {
  final String id;
  final String titleKey;
  final String descriptionKey;
  final String icon;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final Color themeColor;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  BadgeModel({
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.category,
    this.rarity = BadgeRarity.common,
    required this.themeColor,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  BadgeModel copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return BadgeModel(
      id: id,
      titleKey: titleKey,
      descriptionKey: descriptionKey,
      icon: icon,
      category: category,
      rarity: rarity,
      themeColor: themeColor,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}
