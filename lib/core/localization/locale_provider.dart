import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kisisel_asistan/core/services/notification_manager.dart';

// Yeni Notifier yapısı (Riverpod 2.0+ / 3.0 uyumlu)
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadLocale();
    
    // İlk açılışta sistem dilini alalım (tr veya en)
    final systemLocale = ui.PlatformDispatcher.instance.locale.languageCode;
    final defaultLocale = (systemLocale == 'tr' || systemLocale == 'en') ? systemLocale : 'en';
    
    return Locale(defaultLocale);
  }

  static const String _key = 'selected_locale';

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      state = Locale(code);
    } else {
      // Eğer kayıtlı bir dil yoksa build içindeki varsayılan kalır
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    
    // Dil değiştiğinde tüm bildirimleri yeni dilde yeniden kur
    ref.read(notificationManagerProvider).initAllReminders();
  }
}

// Yeni Provider tanımı
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});
