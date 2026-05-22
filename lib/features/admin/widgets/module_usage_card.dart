import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ModuleUsageCard extends StatelessWidget {
  final String title;
  final int activeUserCount;
  final double percentage;
  final IconData icon;

  const ModuleUsageCard({
    super.key,
    required this.title,
    required this.activeUserCount,
    required this.percentage,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.aiColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$activeUserCount Aktif (${percentage.toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.aiColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
