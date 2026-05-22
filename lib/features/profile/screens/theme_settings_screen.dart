import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/localization/app_localizations.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n('premium_themes'))),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              currentTheme.background, 
              currentTheme.brightness == Brightness.dark ? Colors.black : Colors.white
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: AppThemeMode.values.length,
          itemBuilder: (context, index) {
            final theme = AppThemeMode.values[index];
            final isSelected = currentTheme == theme;

            return GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setTheme(theme),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  opacity: isSelected ? 0.2 : 0.05,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: theme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n(theme.nameKey),
                                    style: GoogleFonts.getFont(
                                      theme.fontFamily,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? theme.primary : (theme.brightness == Brightness.dark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  Text(
                                    "Aa Bb Cc - ${theme.fontFamily}",
                                    style: GoogleFonts.getFont(
                                      theme.fontFamily,
                                      fontSize: 12,
                                      color: isSelected ? theme.primary.withOpacity(0.7) : (theme.brightness == Brightness.dark ? Colors.white54 : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: theme.primary.withOpacity(0.3)),
                                ),
                                child: Text(
                                  context.l10n('active_label').toUpperCase(),
                                  style: TextStyle(fontSize: 10, color: theme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _colorBox(theme.background),
                            const SizedBox(width: 8),
                            _colorBox(theme.surface),
                            const SizedBox(width: 8),
                            _colorBox(theme.primary),
                            const SizedBox(width: 8),
                            _colorBox(theme.textPrimary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _colorBox(Color color) {
    return Expanded(
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white10),
        ),
      ),
    );
  }
}
