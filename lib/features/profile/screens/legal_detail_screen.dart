import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/screens/owner_admin_panel_screen.dart';

class LegalDetailScreen extends ConsumerStatefulWidget {
  final String title;
  final String content;

  const LegalDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  ConsumerState<LegalDetailScreen> createState() => _LegalDetailScreenState();
}

class _LegalDetailScreenState extends ConsumerState<LegalDetailScreen> {
  int _tapCount = 0;

  void _handleTap() async {
    _tapCount++;
    if (_tapCount >= 7) {
      _tapCount = 0;
      final passwordController = TextEditingController();
      final correctPassword = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '🔒 Yönetici Girişi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sistem verilerini görüntülemek için şifreyi giriniz:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İPTAL', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                if (passwordController.text == 'Pai**.?') {
                  Navigator.pop(context, true);
                } else {
                  Navigator.pop(context, false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hatalı şifre girdiniz!'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('GİRİŞ', style: TextStyle(color: AppColors.aiColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (correctPassword == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OwnerAdminPanelScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAboutUs = widget.title.toLowerCase().contains('hakk') || 
                      widget.title.toLowerCase().contains('about');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surface],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              if (isAboutUs) ...[
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _handleTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.aiColor.withOpacity(0.1),
                              border: Border.all(color: AppColors.aiColor.withOpacity(0.2)),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AppColors.aiColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'PARAMETRA – PAI',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
