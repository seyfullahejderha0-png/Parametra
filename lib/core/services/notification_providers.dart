import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider((ref) {
  return NotificationService(ref);
});
