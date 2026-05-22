import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/glass_card.dart';
import '../models/goal_model.dart';

class GoalProgressWidget extends StatelessWidget {
  final Goal goal;
  final String currencyCode;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;

  const GoalProgressWidget({
    super.key,
    required this.goal,
    required this.currencyCode,
    this.onUpdate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress.clamp(0.0, 1.0);
    final percentage = (progress * 100).toStringAsFixed(1);
    
    int remainingDays = 0;
    if (goal.deadline != null) {
      final now = DateTime.now();
      remainingDays = goal.deadline!.difference(now).inDays;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      goal.category,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: progress >= 1.0 ? Colors.greenAccent.withOpacity(0.15) : Colors.blueAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent).withOpacity(0.3)),
                ),
                child: Text(
                  "%$percentage",
                  style: TextStyle(color: progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSimpleStat(context.l10n('current_savings_label'), CurrencyFormatter.format(goal.currentAmount, context, currencyCode)),
              _buildSimpleStat(context.l10n('target_amount_label'), CurrencyFormatter.format(goal.targetAmount, context, currencyCode)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (goal.deadline != null) ...[
                const Icon(Icons.calendar_today, size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 6),
                Text(
                  remainingDays > 0 
                    ? "$remainingDays ${context.l10n('days_label')} ${context.l10n('remaining_label')}"
                    : context.l10n('due_date_label'),
                  style: const TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.w500),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                tooltip: context.l10n('update_goal'),
                onPressed: onUpdate,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}
