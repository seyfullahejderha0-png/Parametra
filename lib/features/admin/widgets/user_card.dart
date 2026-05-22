import 'package:flutter/material.dart';
import '../models/admin_user_model.dart';
import '../../subscription/models/subscription_model.dart';

class UserCard extends StatelessWidget {
  final AdminUserData user;
  final VoidCallback onTap;

  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (pkgName, pkgColor) = switch (user.subscriptionType) {
      SubscriptionType.premium => ('Premium', Colors.blueAccent),
      SubscriptionType.platinum => ('Premium AI', Colors.purpleAccent),
      SubscriptionType.platinumFamily => ('Premium AI Aile', Colors.amber),
      SubscriptionType.trial => ('Trial', Colors.tealAccent),
      SubscriptionType.free => ('Ücretsiz', Colors.white30),
    };

    final platformIcon = user.platform.toLowerCase() == 'ios'
        ? Icons.apple
        : (user.platform.toLowerCase() == 'web' ? Icons.language : Icons.android);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: pkgColor.withOpacity(0.1),
                    radius: 22,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: pkgColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(platformIcon, color: Colors.white30, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: pkgColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: pkgColor.withOpacity(0.2), width: 0.5),
                              ),
                              child: Text(
                                pkgName,
                                style: TextStyle(
                                  color: pkgColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (user.isSupporter)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.pink.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.pink.withOpacity(0.2), width: 0.5),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.favorite, color: Colors.pinkAccent, size: 10),
                                    SizedBox(width: 4),
                                    Text(
                                      'Destekçi',
                                      style: TextStyle(
                                        color: Colors.pinkAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bugün: ${user.dailyUsageCount}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
