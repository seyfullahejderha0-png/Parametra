import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kisisel_asistan/features/ai_assistant/services/ai_assistant_service.dart';
import 'package:kisisel_asistan/core/services/notification_service.dart';
import 'package:kisisel_asistan/core/services/notification_providers.dart';

final proactiveAIMessageProvider = NotifierProvider<ProactiveAIMessageNotifier, String?>(() {
  return ProactiveAIMessageNotifier();
});

class ProactiveAIMessageNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String? message) => state = message;
}

final proactiveAIServiceProvider = Provider((ref) => ProactiveAIService(ref));

class ProactiveAIService {
  final Ref _ref;

  ProactiveAIService(this._ref);

  Future<void> generateMorningBriefing() async {
    final aiService = _ref.read(aiAssistantServiceProvider);
    
    final prompt = "Sen bir Yaşam Mentorusun. Kullanıcıya mentorsal, proaktif ve veri odaklı bir sabah mesajı yaz. Bugün için onu motive et ve su hedefini hatırlat.";
    
    try {
      final response = await aiService.getChatResponse([], prompt);
      _ref.read(proactiveAIMessageProvider.notifier).setMessage(response);
      
      await _ref.read(notificationServiceProvider).sendPushNotification(
        title: "Günaydın! ☀️",
        message: response,
      );
    } catch (e) {
      print("Proactive AI Error: $e");
    }
  }

  Future<void> generateEveningReview() async {
    final aiService = _ref.read(aiAssistantServiceProvider);
    
    final prompt = "Sen bir Yaşam Mentorusun. Kullanıcının bugünkü verilerini değerlendiren, başarılarını takdir eden ve yarına dair motivasyon veren bir gün sonu analizi yaz.";
    
    try {
      final response = await aiService.getChatResponse([], prompt);
      _ref.read(proactiveAIMessageProvider.notifier).setMessage(response);
      
      await _ref.read(notificationServiceProvider).sendPushNotification(
        title: "Günün Özeti ✨",
        message: response,
      );
    } catch (e) {
      print("Proactive AI Error: $e");
    }
  }
}
