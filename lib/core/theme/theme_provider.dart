import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  midnight(
    "Gece Yarısı", "theme_midnight", 
    Color(0xFF0F172A), Color(0xFF38BDF8), Color(0xFF1E293B),
    Color(0xFFF1F5F9), Color(0xFF94A3B8), "Inter",
    Brightness.dark,
    Color(0xFF34D399), Color(0xFFF87171), Color(0xFF60A5FA),
    Color(0xFFFB923C), Color(0xFFA78BFA), Color(0xFF22D3EE), Color(0xFF94A3B8)
  ),
  emerald(
    "Zümrüt", "theme_emerald", 
    Color(0xFF064E3B), Color(0xFF34D399), Color(0xFF065F46),
    Color(0xFFECFDF5), Color(0xFFA7F3D0), "Roboto",
    Brightness.dark,
    Color(0xFF10B981), Color(0xFF6EE7B7), Color(0xFF34D399),
    Color(0xFF059669), Color(0xFF115E59), Color(0xFF2DD4BF), Color(0xFF065F46)
  ),
  ruby(
    "Yakut", "theme_ruby", 
    Color(0xFF450A0A), Color(0xFFFB7185), Color(0xFF7F1D1D),
    Color(0xFFFFF1F2), Color(0xFFFECDD3), "Lato",
    Brightness.dark,
    Color(0xFFE11D48), Color(0xFFFB7185), Color(0xFFF43F5E),
    Color(0xFF9F1239), Color(0xFFBE123C), Color(0xFFFDA4AF), Color(0xFF4C0519)
  ),
  royal(
    "Kraliyet", "theme_royal", 
    Color(0xFF1E1B4B), Color(0xFF818CF8), Color(0xFF312E81),
    Color(0xFFEEF2FF), Color(0xFFC7D2FE), "Playfair Display",
    Brightness.dark,
    Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFF4F46E5),
    Color(0xFF3730A3), Color(0xFF4338CA), Color(0xFFA5B4FC), Color(0xFF312E81)
  ),
  sunset(
    "Gün Batımı", "theme_sunset", 
    Color(0xFF431407), Color(0xFFFB923C), Color(0xFF7C2D12),
    Color(0xFFFFF7ED), Color(0xFFFFEDD5), "Montserrat",
    Brightness.dark,
    Color(0xFFEA580C), Color(0xFFFB923C), Color(0xFFF97316),
    Color(0xFFC2410C), Color(0xFF9A3412), Color(0xFFFED7AA), Color(0xFF7C2D12)
  ),
  snow(
    "Saf Kar", "theme_snow", 
    Color(0xFFF8FAFC), Color(0xFF0EA5E9), Color(0xFFFFFFFF),
    Color(0xFF0F172A), Color(0xFF475569), "Inter",
    Brightness.light,
    Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8),
    Color(0xFF0369A1), Color(0xFF075985), Color(0xFF7DD3FC), Color(0xFF64748B)
  );

  final String name;
  final String nameKey;
  final Color background;
  final Color primary;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final String fontFamily;
  final Brightness brightness;
  final Color financeColor;
  final Color debtColor;
  final Color noteColor;
  final Color healthColor;
  final Color medicationColor;
  final Color goalsColor;
  final Color smokingColor;

  const AppThemeMode(
    this.name, this.nameKey, this.background, this.primary, 
    this.surface, this.textPrimary, this.textSecondary, 
    this.fontFamily, this.brightness,
    this.financeColor, this.debtColor, this.noteColor,
    this.healthColor, this.medicationColor, this.goalsColor,
    this.smokingColor
  );
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _loadTheme();
    return AppThemeMode.midnight;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('app_theme');
    if (themeName != null) {
      try {
        final loadedTheme = AppThemeMode.values.firstWhere(
          (t) => t.name == themeName,
          orElse: () => AppThemeMode.midnight,
        );
        state = loadedTheme;
      } catch (e) {
        state = AppThemeMode.midnight;
      }
    }
  }

  Future<void> setTheme(AppThemeMode theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme.name);
  }
}
