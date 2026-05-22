import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_assistant/services/ai_assistant_service.dart';
import '../../life_timeline/models/life_timeline_event.dart';
import '../../life_timeline/services/life_timeline_service.dart';
import '../../../core/localization/locale_provider.dart';

final lifeTimelineAIServiceProvider = Provider((ref) {
  return LifeTimelineAIService(ref);
});

final lifeTimelineAIProvider = FutureProvider.family<String, List<LifeTimelineEvent>>((ref, events) async {
  final aiService = ref.watch(lifeTimelineAIServiceProvider);
  final locale = ref.watch(localeProvider).languageCode;
  return await aiService.getSummary(events, locale);
});

class LifeTimelineAIService {
  final Ref _ref;

  LifeTimelineAIService(this._ref);

  Future<String> getSummary(List<LifeTimelineEvent> events, String locale) async {
    if (events.isEmpty) {
      return locale == 'en'
          ? "No activities found. Start logging your day to get personalized AI summaries!"
          : "Henüz aktivite bulunmuyor. Kişiselleştirilmiş AI özeti için veri girmeye başlayın!";
    }

    final latestEvent = events.first;
    final timelineService = _ref.read(lifeTimelineServiceProvider);

    // 1. Check cache
    try {
      final cache = await timelineService.getCachedSummary();
      if (cache != null) {
        final cacheLastId = cache['lastEventId'] as String?;
        final cacheLastTs = cache['lastEventTimestamp'] as String?;
        
        if (cacheLastId == latestEvent.id && cacheLastTs == latestEvent.timestamp.toIso8601String()) {
          final cachedText = cache['summary'] as String?;
          if (cachedText != null && cachedText.isNotEmpty) {
            print('LifeTimelineAI: Using cached summary.');
            return cachedText;
          }
        }
      }
    } catch (e) {
      print('LifeTimelineAI: Cache read error: $e');
    }

    // 2. Generate new summary
    print('LifeTimelineAI: Cache miss or stale. Calling Gemini to generate summary.');
    try {
      final aiAssistant = _ref.read(aiAssistantServiceProvider);

      final eventStrings = events.take(15).map((e) {
        final dateStr = "${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}";
        return "[$dateStr] ${e.title}: ${e.description} (${e.module})";
      }).join("\n");

      final prompt = locale == 'en'
          ? "Based on the following recent user timeline events, generate a summary of exactly 3 short, wise, and highly engaging bullet points in English. Do NOT use markdown bold headers or '*' bullet points. Make it feel premium, motivating, and smart. Return plain text with line breaks.\n\nEvents:\n$eventStrings"
          : "Aşağıdaki son kullanıcı yaşam akışı olaylarına dayanarak, Türkçe dilinde tam 3 adet kısa, bilgece ve son derece etkileyici maddeler halinde özet oluştur. Kalın başlıklar kullanma. Yıldız (*) işareti kullanmadan sade satır sonu ayrımıyla dön. Premium, motive edici ve akıllıca olsun.\n\nOlaylar:\n$eventStrings";

      final generatedSummary = await aiAssistant.getChatResponse([], prompt, isAnalysis: true);
      
      // 3. Save to cache
      await timelineService.saveCachedSummary(
        summary: generatedSummary,
        lastEventId: latestEvent.id,
        lastEventTimestamp: latestEvent.timestamp,
      );

      return generatedSummary;
    } catch (e) {
      print('LifeTimelineAI: Gemini error: $e');
      return locale == 'en'
          ? "An error occurred while generating AI summary."
          : "AI özeti oluşturulurken bir hata oluştu.";
    }
  }
}
