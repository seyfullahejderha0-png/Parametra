import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kisisel_asistan/core/services/notification_service.dart';
import 'package:kisisel_asistan/core/services/notification_providers.dart';
import 'package:kisisel_asistan/core/services/health_notification_service.dart';
import 'package:kisisel_asistan/features/finance/services/finance_notification_service.dart';
import 'package:kisisel_asistan/core/localization/app_localizations.dart';
import 'package:kisisel_asistan/core/localization/locale_provider.dart';

final notificationManagerProvider = Provider((ref) => NotificationManager(ref));

class NotificationManager {
  final Ref _ref;
  
  NotificationManager(this._ref);

  Future<void> initAllReminders() async {
    await _ref.read(healthNotificationServiceProvider).scheduleWaterReminders();
    await _ref.read(healthNotificationServiceProvider).scheduleSportReminder();
    await _ref.read(financeNotificationServiceProvider).scheduleDailyEntryReminder();
    await _scheduleWeeklyGoalReminder();
  }

  Future<void> _scheduleWeeklyGoalReminder() async {
    final notificationService = _ref.read(notificationServiceProvider);
    final now = DateTime.now();
    
    int daysUntilSunday = 7 - now.weekday;
    if (daysUntilSunday < 0) daysUntilSunday += 7;
    if (daysUntilSunday == 0 && now.hour >= 19) daysUntilSunday = 7;

    final scheduledDate = DateTime(now.year, now.month, now.day, 19, 0).add(Duration(days: daysUntilSunday));

    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);

    await notificationService.scheduleLocal(
      id: 700,
      title: l10n.translate('notification_weekly_goal_title'),
      body: l10n.translate('notification_weekly_goal_body'),
      scheduledDate: scheduledDate,
    );
  }
}
