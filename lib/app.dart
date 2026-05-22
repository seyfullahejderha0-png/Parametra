import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kisisel_asistan/core/localization/app_localizations.dart';
import 'package:kisisel_asistan/core/localization/locale_provider.dart';
import 'package:kisisel_asistan/core/theme/app_theme.dart';
import 'package:kisisel_asistan/core/theme/theme_provider.dart';
import 'package:kisisel_asistan/features/auth/services/auth_service.dart';
import 'package:kisisel_asistan/features/auth/screens/login_screen.dart';
import 'package:kisisel_asistan/features/main/screens/main_screen.dart';
import 'package:kisisel_asistan/features/onboarding/screens/splash_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:kisisel_asistan/features/profile/services/profile_service.dart';

class ParametraApp extends ConsumerWidget {
  const ParametraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final theme = ref.watch(themeProvider);

    // Oturum durumundaki değişiklikleri dinle ve kullanıcı giriş yaptığında son aktiviteyi kaydet
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        ref.read(profileServiceProvider).recordUserActivity();
      }
    });

    return MaterialApp(
      title: 'Parametra AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getDynamicTheme(theme),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    // KÖK NEDEN ÇÖZÜMÜ: authStateProvider splash ekranı çalışırken de arka planda dinlenir!
    // Böylece 6 saniyelik splash süresi boyunca Firebase Auth çoktan yüklenmiş (AsyncData) olur.
    // Splash bittiğinde hiçbir siyah ekran veya loading beklemesi olmadan şimşek hızında ana ekran açılır!
    final authState = ref.watch(authStateProvider);

    if (_showSplash) {
      return SplashScreen(onFinish: () {
        setState(() => _showSplash = false);
      });
    }

    return authState.when(
      data: (user) {
        if (user != null) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(
        body: Center(child: Text('Hata: $e')),
      ),
    );
  }
}
