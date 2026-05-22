import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kisisel_asistan/core/services/notification_service.dart';
import 'package:kisisel_asistan/core/services/notification_providers.dart';
import 'package:kisisel_asistan/features/medication/models/medication_model.dart';
import 'package:kisisel_asistan/core/localization/app_localizations.dart';
import 'package:kisisel_asistan/core/localization/locale_provider.dart';

final medicationNotificationServiceProvider = Provider((ref) => MedicationNotificationService(ref));

class MedicationNotificationService {
  final Ref _ref;
  
  MedicationNotificationService(this._ref);

  Future<void> scheduleMedicationReminders(Medication med) async {
    final notificationService = _ref.read(notificationServiceProvider);
    
    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);
    
    for (var time in med.scheduleTimes) {
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        
        if (hour != null && minute != null) {
          final now = DateTime.now();
          var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
          
          if (scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          final notificationId = (med.id.hashCode.abs() + time.hashCode.abs()) % 100000;

          await notificationService.scheduleLocal(
            id: notificationId,
            title: l10n.translate('notification_medication_title'),
            body: l10n.translate('notification_medication_body').replaceFirst('{name}', med.name),
            scheduledDate: scheduledDate,
          );
        }
      }
    }
  }
}
