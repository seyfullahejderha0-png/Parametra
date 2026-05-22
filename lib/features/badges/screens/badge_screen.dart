import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/badge_service.dart';
import '../models/badge_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';

class BadgeScreen extends ConsumerWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('achievements')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: badgesAsync.when(
        data: (badges) {
          return CustomScrollView(
            slivers: [
              _buildCategorySection(context, context.l10n('finance_card'), badges.where((b) => b.category == BadgeCategory.finance).toList()),
              _buildCategorySection(context, context.l10n('debt_card'), badges.where((b) => b.category == BadgeCategory.debt).toList()),
              _buildCategorySection(context, context.l10n('notes_card'), badges.where((b) => b.category == BadgeCategory.notes).toList()),
              _buildCategorySection(context, context.l10n('smoking_card'), badges.where((b) => b.category == BadgeCategory.smoking).toList()),
              _buildCategorySection(context, context.l10n('health_card'), badges.where((b) => b.category == BadgeCategory.health).toList()),
              _buildCategorySection(context, context.l10n('medication_card'), badges.where((b) => b.category == BadgeCategory.medication).toList()),
              _buildCategorySection(context, context.l10n('goals_card'), badges.where((b) => b.category == BadgeCategory.goals).toList()),
              _buildCategorySection(context, context.l10n('ai_assistant_card'), badges.where((b) => b.category == BadgeCategory.ai).toList()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, String title, List<BadgeModel> categoryBadges) {
    if (categoryBadges.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white54),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _BadgeItem(badge: categoryBadges[index]),
              childCount: categoryBadges.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatefulWidget {
  final BadgeModel badge;

  const _BadgeItem({required this.badge});

  @override
  State<_BadgeItem> createState() => _BadgeItemState();
}

class _BadgeItemState extends State<_BadgeItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.badge.isUnlocked && (widget.badge.rarity == BadgeRarity.epic || widget.badge.rarity == BadgeRarity.legendary)) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    Color rarityColor = _getRarityColor(badge.rarity);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Rarity Aura / Glow
            if (badge.isUnlocked)
              _buildRarityEffect(badge.rarity, rarityColor),
            
            // Badge Body
            ClipOval(
              child: ImageFiltered(
                imageFilter: badge.isUnlocked ? ImageFilter.blur(sigmaX: 0, sigmaY: 0) : ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: ColorFiltered(
                  colorFilter: badge.isUnlocked 
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                    : const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]),
                  child: Container(
                    height: 74,
                    width: 74,
                    decoration: BoxDecoration(
                      color: badge.isUnlocked ? badge.themeColor.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: badge.isUnlocked ? rarityColor.withOpacity(0.8) : Colors.white10,
                        width: badge.rarity == BadgeRarity.legendary ? 2.5 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        badge.icon, 
                        style: TextStyle(
                          fontSize: 32, 
                          color: Colors.white.withOpacity(badge.isUnlocked ? 1.0 : 0.4),
                          shadows: badge.isUnlocked && badge.rarity != BadgeRarity.common ? [
                            Shadow(color: rarityColor, blurRadius: 10),
                          ] : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Lock Icon
            if (!badge.isUnlocked)
              const Icon(Icons.lock_outline, color: Colors.white24, size: 20),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n(badge.titleKey),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: badge.isUnlocked ? FontWeight.bold : FontWeight.normal,
            color: badge.isUnlocked ? Colors.white : Colors.white38,
          ),
        ),
        if (badge.isUnlocked && badge.rarity != BadgeRarity.common)
          Text(
            badge.rarity.name.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: rarityColor,
              letterSpacing: 0.5,
            ),
          ),
      ],
    );
  }

  Color _getRarityColor(BadgeRarity rarity) {
    switch (rarity) {
      case BadgeRarity.legendary: return Colors.amber;
      case BadgeRarity.epic: return Colors.purpleAccent;
      case BadgeRarity.rare: return Colors.blueAccent;
      default: return Colors.white54;
    }
  }

  Widget _buildRarityEffect(BadgeRarity rarity, Color color) {
    if (rarity == BadgeRarity.common) return const SizedBox.shrink();

    if (rarity == BadgeRarity.legendary) {
      return RotationTransition(
        turns: _controller,
        child: Container(
          height: 86,
          width: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [Colors.transparent, color, Colors.transparent],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      );
    }

    if (rarity == BadgeRarity.epic) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            height: 74 + (math.sin(_controller.value * math.pi * 2) * 8),
            width: 74 + (math.sin(_controller.value * math.pi * 2) * 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          );
        },
      );
    }

    return Container(
      height: 74,
      width: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
