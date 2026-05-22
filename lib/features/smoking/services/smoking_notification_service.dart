import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kisisel_asistan/core/services/notification_service.dart';
import 'package:kisisel_asistan/core/services/notification_providers.dart';
import 'package:kisisel_asistan/core/localization/app_localizations.dart';
import 'package:kisisel_asistan/core/localization/locale_provider.dart';

final smokingNotificationServiceProvider = Provider((ref) => SmokingNotificationService(ref));

class SmokingNotificationService {
  final Ref _ref;
  
  SmokingNotificationService(this._ref);

  Future<void> scheduleMilestones(DateTime startDate) async {
    final notificationService = _ref.read(notificationServiceProvider);
    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);
    
    final milestones = [
      {'id': 301, 'duration': const Duration(minutes: 20), 'title': '20 Min', 'bodyKey': 'notification_smoke_20min'},
      {'id': 302, 'duration': const Duration(hours: 1), 'title': '1 Hour', 'bodyKey': 'notification_smoke_1hour'},
      {'id': 303, 'duration': const Duration(hours: 8), 'title': '8 Hours', 'bodyKey': 'notification_smoke_8hour'},
      {'id': 304, 'duration': const Duration(days: 1), 'title': '24 Hours', 'bodyKey': 'notification_smoke_24hour'},
      {'id': 305, 'duration': const Duration(days: 3), 'title': '3 Days', 'bodyKey': 'notification_smoke_3day'},
      {'id': 306, 'duration': const Duration(days: 7), 'title': '7 Days', 'bodyKey': 'notification_smoke_7day'},
      {'id': 307, 'duration': const Duration(days: 30), 'title': '30 Days', 'bodyKey': 'notification_smoke_30day'},
    ];

    for (var m in milestones) {
      final scheduledDate = startDate.add(m['duration'] as Duration);
      if (scheduledDate.isAfter(DateTime.now())) {
        await notificationService.scheduleLocal(
          id: m['id'] as int,
          title: l10n.translate('notification_smoking_milestone_title'),
          body: l10n.translate(m['bodyKey'] as String),
          scheduledDate: scheduledDate,
        );
      }
    }
  }
}
