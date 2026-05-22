import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kisisel_asistan/core/services/notification_providers.dart';
import 'package:kisisel_asistan/core/services/notification_service.dart';
import 'package:kisisel_asistan/core/localization/app_localizations.dart';
import 'package:kisisel_asistan/core/localization/locale_provider.dart';

final healthNotificationServiceProvider = Provider((ref) => HealthNotificationService(ref));

class HealthNotificationService {
  final Ref _ref;
  
  HealthNotificationService(this._ref);

  Future<void> scheduleWaterReminders() async {
    final notificationService = _ref.read(notificationServiceProvider);
    
    final hours = [8, 11, 14, 17, 20];
    
    for (var hour in hours) {
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, 0);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final locale = _ref.read(localeProvider);
      final l10n = AppLocalizations(locale);

      await notificationService.scheduleLocal(
        id: 400 + hour,
        title: l10n.translate('notification_water_title'),
        body: l10n.translate('notification_water_body'),
        scheduledDate: scheduledDate,
      );
    }
  }

  Future<void> scheduleSportReminder() async {
    final notificationService = _ref.read(notificationServiceProvider);
    
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 18, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);

    await notificationService.scheduleLocal(
      id: 500,
      title: l10n.translate('notification_sport_title'),
      body: l10n.translate('notification_sport_body'),
      scheduledDate: scheduledDate,
    );
  }
}
