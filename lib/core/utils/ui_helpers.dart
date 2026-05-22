import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UIHelpers {
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.all(16),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              )
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          ),
        ],
      ),
    );

    // 3 saniye sonra otomatik kapat
    Future.delayed(const Duration(seconds: 3), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Evet, Sil',
    String cancelText = 'Vazgeç',
    Color confirmColor = Colors.redAccent,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      ),
    );
  }
}
