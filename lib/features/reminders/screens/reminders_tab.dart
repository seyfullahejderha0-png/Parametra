import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';
import 'add_reminder_screen.dart';

class RemindersTab extends ConsumerWidget {
  const RemindersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersStreamProvider);
    final locale = Localizations.localeOf(context).toString();

    return remindersAsync.when(
      data: (reminders) {
        if (reminders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active_outlined, size: 64, color: Colors.white38),
                const SizedBox(height: 16),
                Text(
                  context.l10n('no_reminders_msg') ?? 'Henüz bir hatırlatıcı eklemediniz.',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reminders.length,
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return _buildReminderCard(context, ref, reminder, locale);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
    );
  }

  Widget _buildReminderCard(BuildContext context, WidgetRef ref, Reminder reminder, String locale) {
    String repeatText = '';
    switch (reminder.repeatType) {
      case ReminderRepeatType.once:
      case ReminderRepeatType.customDate:
        repeatText = DateFormat('dd MMM yyyy', locale).format(reminder.dateTime);
        break;
      case ReminderRepeatType.daily:
        repeatText = context.l10n('daily') ?? 'Her Gün';
        break;
      case ReminderRepeatType.specificDays:
        final daysMap = {
          1: context.l10n('mon') ?? 'Pzt',
          2: context.l10n('tue') ?? 'Sal',
          3: context.l10n('wed') ?? 'Çar',
          4: context.l10n('thu') ?? 'Per',
          5: context.l10n('fri') ?? 'Cum',
          6: context.l10n('sat') ?? 'Cts',
          7: context.l10n('sun') ?? 'Paz',
        };
        repeatText = reminder.specificDays.map((d) => daysMap[d]).join(' / ');
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.aiColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    reminder.categoryIcon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                          color: reminder.isCompleted ? Colors.white54 : Colors.white,
                        ),
                      ),
                      if (reminder.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: AppColors.aiColor),
                          const SizedBox(width: 4),
                          Text(
                            '${reminder.timeOfDay} • $repeatText',
                            style: const TextStyle(color: AppColors.aiColor, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: reminder.isActive,
                  onChanged: (val) {
                    ref.read(reminderServiceProvider).toggleActive(reminder, val);
                  },
                  activeColor: AppColors.aiColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    ref.read(reminderServiceProvider).toggleCompleted(reminder);
                  },
                  icon: Icon(
                    reminder.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    color: reminder.isCompleted ? Colors.greenAccent : Colors.white54,
                  ),
                  label: Text(
                    reminder.isCompleted
                        ? (context.l10n('completed') ?? 'Tamamlandı')
                        : (context.l10n('mark_completed') ?? 'Tamamla'),
                    style: TextStyle(
                      color: reminder.isCompleted ? Colors.greenAccent : Colors.white70,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddReminderScreen(reminderToEdit: reminder),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        ref.read(reminderServiceProvider).deleteReminder(reminder);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
