import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivacyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setPrivacy(bool value) => state = value;
}

final privacyProvider = NotifierProvider<PrivacyNotifier, bool>(() {
  return PrivacyNotifier();
});
