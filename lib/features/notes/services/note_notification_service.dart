import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_providers.dart';
import '../models/note_model.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';

final noteNotificationServiceProvider = Provider((ref) => NoteNotificationService(ref));

class NoteNotificationService {
  final Ref _ref;

  NoteNotificationService(this._ref);

  Future<void> scheduleNoteReminder(NoteEntry note) async {
    if (note.reminderDateTime == null) return;
    if (note.reminderDateTime!.isBefore(DateTime.now())) return;

    final notificationService = _ref.read(notificationServiceProvider);
    
    // Notun ID'sinin hash'ini kullanarak benzersiz bir bildirim ID'si oluşturalım
    final int notificationId = note.id.hashCode.abs() % 100000;

    final locale = _ref.read(localeProvider);
    final l10n = AppLocalizations(locale);

    await notificationService.scheduleLocal(
      id: notificationId,
      title: l10n.translate('notification_note_title'),
      body: note.title.isNotEmpty ? note.title : l10n.translate('notification_note_body'),
      scheduledDate: note.reminderDateTime!,
    );
  }

  Future<void> cancelNoteReminder(String noteId) async {
    final notificationService = _ref.read(notificationServiceProvider);
    final int notificationId = noteId.hashCode.abs() % 100000;
    await notificationService.cancelLocal(notificationId);
  }
}
