import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kisisel_asistan/core/services/notification_service.dart';
import 'package:kisisel_asistan/core/services/notification_providers.dart';
import 'package:kisisel_asistan/core/localization/app_localizations.dart';
import 'package:kisisel_asistan/core/localization/locale_provider.dart';

final financeNotificationServiceProvider = Provider((ref) => FinanceNotificationService(ref));

class FinanceNotificationService {
  final Ref _ref;
  
  FinanceNotificationService(this._ref);

  Future<void> sendOverspendingWarning() async {
    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);
    await _ref.read(notificationServiceProvider).sendPushNotification(
      title: l10n.translate('notification_overspending_title'),
      message: l10n.translate('notification_overspending_body'),
    );
  }

  Future<void> scheduleDailyEntryReminder() async {
    final notificationService = _ref.read(notificationServiceProvider);
    
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 21, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);

    await notificationService.scheduleLocal(
      id: 900,
      title: l10n.translate('notification_finance_entry_title'),
      body: l10n.translate('notification_finance_entry_body'),
      scheduledDate: scheduledDate,
    );
  }

  Future<void> scheduleDebtReminder(String title, DateTime dueDate, {bool isCredit = false}) async {
    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);
    final notificationService = _ref.read(notificationServiceProvider);

    // Alacak (tahsilat) ve borç (ödeme) için farklı lokalizasyon anahtarları
    final approachingTitleKey = isCredit
        ? 'notification_credit_approaching_title'
        : 'notification_debt_approaching_title';
    final approachingBodyKey = isCredit
        ? 'notification_credit_approaching_body'
        : 'notification_debt_approaching_body';
    final todayTitleKey = isCredit
        ? 'notification_credit_today_title'
        : 'notification_debt_today_title';
    final todayBodyKey = isCredit
        ? 'notification_credit_today_body'
        : 'notification_debt_today_body';
    
    final threeDaysBefore = dueDate.subtract(const Duration(days: 3));
    if (threeDaysBefore.isAfter(DateTime.now())) {
      await notificationService.scheduleLocal(
        id: title.hashCode + (isCredit ? 3 : 1),
        title: l10n.translate(approachingTitleKey),
        body: l10n.translate(approachingBodyKey).replaceFirst('{title}', title),
        scheduledDate: DateTime(threeDaysBefore.year, threeDaysBefore.month, threeDaysBefore.day, 10, 0),
      );
    }

    if (dueDate.isAfter(DateTime.now())) {
      await notificationService.scheduleLocal(
        id: title.hashCode + (isCredit ? 4 : 2),
        title: l10n.translate(todayTitleKey),
        body: l10n.translate(todayBodyKey).replaceFirst('{title}', title),
        scheduledDate: DateTime(dueDate.year, dueDate.month, dueDate.day, 09, 0),
      );
    }
  }
}
