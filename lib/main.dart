import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/notification_providers.dart';
import 'core/services/notification_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('tr_TR', null);

  final container = ProviderContainer();
  
  // Bildirim servisini başlat ve ardından hatırlatıcıları kur
  container.read(notificationServiceProvider).init().then((_) {
    container.read(notificationManagerProvider).initAllReminders();
  }).catchError((e) {
    debugPrint("Notification Init Error: $e");
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ParametraApp(),
    ),
  );
}
