import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/note_lock_service.dart';

class NoteLockScreen extends ConsumerStatefulWidget {
  const NoteLockScreen({super.key});

  @override
  ConsumerState<NoteLockScreen> createState() => _NoteLockScreenState();
}

class _NoteLockScreenState extends ConsumerState<NoteLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isSettingPin = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(noteLockProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(lockState.isLocked ? 'Notlar Kilitli' : 'Şifre Ayarları'),
        automaticallyImplyLeading: !lockState.isLocked,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                lockState.isLocked ? Icons.lock_person : Icons.security,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 32),
              if (!lockState.isLocked) ...[
                const Text(
                  'Notlarınızı korumak için 4 haneli bir şifre belirleyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                _buildPinField(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (_pinController.text.length == 4) {
                      ref.read(noteLockProvider.notifier).setPin(_pinController.text);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre belirlendi')));
                    }
                  },
                  child: const Text('Şifreyi Kaydet'),
                ),
              ] else if (lockState.isLocked && !lockState.isUnlocked) ...[
                const Text(
                  'Devam etmek için şifrenizi girin.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                _buildPinField(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.read(noteLockProvider.notifier).unlock(_pinController.text);
                    if (!ref.read(noteLockProvider).isUnlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hatalı şifre')));
                      _pinController.clear();
                    }
                  },
                  child: const Text('Kilidi Aç'),
                ),
              ] else ...[
                const Text('Şifre aktif.', style: TextStyle(color: Colors.greenAccent)),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    ref.read(noteLockProvider.notifier).removePin();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre kaldırıldı')));
                  },
                  child: const Text('Şifreyi Kaldır', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField() {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 32, letterSpacing: 16),
        decoration: const InputDecoration(
          counterText: '',
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
        ),
      ),
    );
  }
}
