import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'theme_provider.dart';

class AppTheme {
  static ThemeData getDynamicTheme(AppThemeMode mode) {
    final baseTheme = mode.brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    
    return ThemeData(
      brightness: mode.brightness,
      scaffoldBackgroundColor: mode.background,
      primaryColor: mode.primary,
      colorScheme: mode.brightness == Brightness.dark 
        ? ColorScheme.dark(
            primary: mode.primary,
            secondary: mode.primary.withOpacity(0.8),
            surface: mode.surface,
            error: AppColors.error,
          )
        : ColorScheme.light(
            primary: mode.primary,
            secondary: mode.primary.withOpacity(0.8),
            surface: mode.surface,
            error: AppColors.error,
          ),
      cardColor: mode.surface,
      textTheme: GoogleFonts.getTextTheme(
        mode.fontFamily,
        baseTheme.textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.getFont(mode.fontFamily, color: mode.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.getFont(mode.fontFamily, color: mode.textPrimary, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.getFont(mode.fontFamily, color: mode.textPrimary),
        bodyMedium: GoogleFonts.getFont(mode.fontFamily, color: mode.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: mode.textPrimary),
        titleTextStyle: GoogleFonts.getFont(
          mode.fontFamily,
          color: mode.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: mode.background.withOpacity(0.9),
        selectedItemColor: mode.primary,
        unselectedItemColor: mode.textSecondary.withOpacity(0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mode.primary,
          foregroundColor: mode.brightness == Brightness.dark ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.getFont(mode.fontFamily, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: mode.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 24,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: mode.surface,
        headerBackgroundColor: mode.primary,
        headerForegroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(mode.surface),
        ),
      ),
      canvasColor: mode.surface,
    );
  }

  static ThemeData get darkTheme => getDynamicTheme(AppThemeMode.midnight);
}
