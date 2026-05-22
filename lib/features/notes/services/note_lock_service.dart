import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State yapısı
class NoteLockState {
  final bool isLocked;
  final bool isUnlocked;
  final String? savedPin;

  NoteLockState({
    required this.isLocked,
    required this.isUnlocked,
    this.savedPin,
  });

  NoteLockState copyWith({bool? isLocked, bool? isUnlocked, String? savedPin}) {
    return NoteLockState(
      isLocked: isLocked ?? this.isLocked,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      savedPin: savedPin ?? this.savedPin,
    );
  }
}

// Yeni Notifier yapısı (Riverpod 2.0+)
class NoteLockNotifier extends Notifier<NoteLockState> {
  @override
  NoteLockState build() {
    // Başlangıçta boş state döndür, _init ile güncelle
    _init();
    return NoteLockState(isLocked: false, isUnlocked: false);
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('note_pin');
    state = state.copyWith(isLocked: pin != null, savedPin: pin);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('note_pin', pin);
    state = state.copyWith(isLocked: true, isUnlocked: true, savedPin: pin);
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('note_pin');
    state = state.copyWith(isLocked: false, isUnlocked: false, savedPin: null);
  }

  void unlock(String pin) {
    if (state.savedPin == pin) {
      state = state.copyWith(isUnlocked: true);
    }
  }

  void lockSession() {
    state = state.copyWith(isUnlocked: false);
  }
}

// Yeni Provider tanımı
final noteLockProvider = NotifierProvider<NoteLockNotifier, NoteLockState>(() {
  return NoteLockNotifier();
});
