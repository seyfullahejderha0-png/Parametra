import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/notification_providers.dart';
import '../models/reminder_model.dart';

import '../../../core/utils/stream_merger.dart';
import '../../family/models/family_models.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/services/notification_event_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final reminderServiceProvider = Provider<ReminderService>((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  return ReminderService(uid, ref);
});

final sharedReminderServiceProvider = Provider<ReminderService?>((ref) {
  final sharedOwnerId = ref.watch(sharedWorkspaceOwnerIdProvider);
  if (sharedOwnerId == null) return null;
  return ReminderService(sharedOwnerId, ref);
});

final remindersStreamProvider = StreamProvider<List<Reminder>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(reminderServiceProvider);
  final sharedService = ref.watch(sharedReminderServiceProvider);

  final personalStream = personalService.getReminders();
  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getReminders();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<Reminder>(
      personalStream,
      sharedService.getReminders(),
      (a, b) => b.dateTime.compareTo(a.dateTime),
    );
  }
  return personalStream;
});

class ReminderService {
  final String? userId;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReminderService(this.userId, this._ref);

  CollectionReference get _remindersColl => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('reminders');

  Stream<List<Reminder>> getReminders() {
    if (userId == null) return Stream.value([]);
    return _remindersColl.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Reminder.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> addReminder(Reminder reminder) async {
    await _remindersColl.doc(reminder.id).set(reminder.toMap());
    
    // Ortak alan bildirimini gönder
    try {
      final profile = _ref.read(userProfileProvider).value;
      final actorName = (profile != null && profile.firstName.isNotEmpty)
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : 'Bir üye';
      await _ref.read(notificationEventServiceProvider).sendEvent(
        module: 'reminders',
        action: 'create',
        title: 'Yeni Hatırlatıcı',
        body: '$actorName yeni hatırlatıcı oluşturdu: ${reminder.title}',
      );
    } catch (_) {}

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'reminders',
        title: 'Hatırlatıcı Oluşturuldu',
        description: '\'${reminder.title}\' başlıklı hatırlatıcı oluşturuldu.',
        icon: '⏰',
        metadata: {
          'reminderId': reminder.id,
          'title': reminder.title,
        },
      );
    } catch (_) {}

    await _handleNotification(reminder);
  }

  Future<void> updateReminder(Reminder reminder) async {
    await _remindersColl.doc(reminder.id).update(reminder.toMap());
    await _handleNotification(reminder);
  }

  Future<void> deleteReminder(Reminder reminder) async {
    await _cancelNotification(reminder);
    await _remindersColl.doc(reminder.id).delete();
  }

  Future<void> toggleActive(Reminder reminder, bool isActive) async {
    final updated = reminder.copyWith(isActive: isActive);
    await updateReminder(updated);
  }

  Future<void> toggleCompleted(Reminder reminder) async {
    final updated = reminder.copyWith(isCompleted: !reminder.isCompleted);
    await updateReminder(updated);

    if (updated.isCompleted) {
      try {
        await _ref.read(lifeTimelineServiceProvider).logEvent(
          module: 'reminders',
          title: 'Hatırlatıcı Tamamlandı ✅',
          description: '\'${reminder.title}\' tamamlandı.',
          icon: '✅',
          metadata: {
            'reminderId': reminder.id,
            'title': reminder.title,
          },
          eventType: 'achievement',
        );
      } catch (_) {}
    }
  }

  Future<void> _handleNotification(Reminder reminder) async {
    await _cancelNotification(reminder);

    if (!reminder.isActive || reminder.isCompleted) return;

    final notificationService = _ref.read(notificationServiceProvider);
    final now = DateTime.now();

    final parts = reminder.timeOfDay.split(':');
    int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    switch (reminder.repeatType) {
      case ReminderRepeatType.once:
      case ReminderRepeatType.customDate:
        DateTime scheduled = DateTime(
          reminder.dateTime.year,
          reminder.dateTime.month,
          reminder.dateTime.day,
          hour,
          minute,
        );
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        await notificationService.scheduleLocal(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.description,
          scheduledDate: scheduled,
        );
        break;

      case ReminderRepeatType.daily:
        DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        await notificationService.scheduleRepeatingLocal(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.description,
          scheduledDate: scheduled,
          matchComponents: DateTimeComponents.time,
        );
        break;

      case ReminderRepeatType.specificDays:
        for (int day in reminder.specificDays) {
          // Calculate next occurrence of this weekday (1: Mon, ..., 7: Sun)
          int daysUntil = day - now.weekday;
          if (daysUntil < 0 || (daysUntil == 0 && (now.hour > hour || (now.hour == hour && now.minute >= minute)))) {
            daysUntil += 7;
          }
          DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: daysUntil));
          
          await notificationService.scheduleRepeatingLocal(
            id: reminder.notificationId + (day * 100000),
            title: reminder.title,
            body: reminder.description,
            scheduledDate: scheduled,
            matchComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
        break;
    }
  }

  Future<void> _cancelNotification(Reminder reminder) async {
    final notificationService = _ref.read(notificationServiceProvider);
    await notificationService.cancelLocal(reminder.notificationId);
    for (int day = 1; day <= 7; day++) {
      await notificationService.cancelLocal(reminder.notificationId + (day * 100000));
    }
  }
}
