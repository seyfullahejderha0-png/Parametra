import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/labs_module.dart';
import '../services/labs_dummy_service.dart';
import '../../../core/widgets/glass_card.dart';

class LabsModuleCard extends ConsumerWidget {
  final LabsModule module;

  const LabsModuleCard({
    super.key,
    required this.module,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final subscriptions = ref.watch(labsSubscriptionsProvider);
    final isSubscribed = subscriptions[module.id] ?? false;

    Color badgeColor;
    String statusText = isTr ? module.status : module.statusEn;

    switch (module.category) {
      case 'geliştiriliyor':
        badgeColor = Colors.greenAccent;
        break;
      case 'planlandı':
        badgeColor = Colors.orangeAccent;
        break;
      case 'arge':
        badgeColor = Colors.cyanAccent;
        break;
      default:
        badgeColor = Colors.white54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Module Emoji Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    module.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                // Module Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTr ? module.name : module.nameEn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor.withOpacity(0.35), width: 1),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              isTr ? module.description : module.descriptionEn,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            
            // Progress Bar (if development has started)
            if (module.progress > 0.0) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isTr ? 'İlerleme' : 'Progress',
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                      Text(
                        '${(module.progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: module.progress,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            
            // Notify me switch row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSubscribed ? Icons.notifications_active : Icons.notifications_outlined,
                      size: 16,
                      color: isSubscribed ? Colors.blueAccent : Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isTr ? 'Beni Haberdar Et' : 'Notify Me',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSubscribed ? Colors.blueAccent : Colors.white38,
                        fontWeight: isSubscribed ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: isSubscribed,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) {
                    ref.read(labsSubscriptionsProvider.notifier).toggleSubscription(module.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
