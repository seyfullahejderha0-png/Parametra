import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/labs_module.dart';

final labsSubscriptionsProvider = NotifierProvider<LabsSubscriptionsNotifier, Map<String, bool>>(() {
  return LabsSubscriptionsNotifier();
});

class LabsSubscriptionsNotifier extends Notifier<Map<String, bool>> {
  static const String _prefKeyPrefix = 'labs_sub_';

  @override
  Map<String, bool> build() {
    state = {};
    _loadPrefs();
    return state;
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, bool> loaded = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefKeyPrefix)) {
        final moduleId = key.substring(_prefKeyPrefix.length);
        loaded[moduleId] = prefs.getBool(key) ?? false;
      }
    }
    state = loaded;
  }

  Future<void> toggleSubscription(String moduleId) async {
    final currentValue = state[moduleId] ?? false;
    final newValue = !currentValue;
    
    final updated = Map<String, bool>.from(state);
    updated[moduleId] = newValue;
    state = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefKeyPrefix$moduleId', newValue);
  }
}

final labsModulesProvider = Provider<List<LabsModule>>((ref) {
  return const [
    // Geliştiriliyor
    LabsModule(
      id: 'bank_integration',
      name: 'Banka Entegrasyonu',
      nameEn: 'Bank Integration',
      status: 'Geliştiriliyor',
      statusEn: 'Developing',
      description: 'Otomatik banka hareketleri ve AI finans analizi',
      descriptionEn: 'Automatic bank transactions and AI financial analysis',
      progress: 0.60,
      icon: '🏦',
      category: 'geliştiriliyor',
    ),
    LabsModule(
      id: 'location_reminders',
      name: 'Konum Bazlı Hatırlatıcılar',
      nameEn: 'Location-Based Reminders',
      status: 'Geliştiriliyor',
      statusEn: 'Developing',
      description: 'Belirlenen konumlarda otomatik hatırlatma',
      descriptionEn: 'Automatic reminders at specified locations',
      progress: 0.45,
      icon: '📍',
      category: 'geliştiriliyor',
    ),
    LabsModule(
      id: 'ai_life_coach',
      name: 'AI Yaşam Koçu',
      nameEn: 'AI Life Coach',
      status: 'Geliştiriliyor',
      statusEn: 'Developing',
      description: 'Kişiselleştirilmiş günlük yaşam tavsiyeleri ve motivasyon',
      descriptionEn: 'Personalized daily life advice and motivation',
      progress: 0.70,
      icon: '🤖',
      category: 'geliştiriliyor',
    ),
    LabsModule(
      id: 'advanced_life_analytics',
      name: 'Gelişmiş Yaşam Analizleri',
      nameEn: 'Advanced Life Analytics',
      status: 'Geliştiriliyor',
      statusEn: 'Developing',
      description: 'Uyku, ruh hali ve üretkenlik korelasyon analizleri',
      descriptionEn: 'Correlation analysis of sleep, mood, and productivity',
      progress: 0.35,
      icon: '📊',
      category: 'geliştiriliyor',
    ),

    // Planlandı
    LabsModule(
      id: 'crypto_tracking',
      name: 'Coin & Kripto Takibi',
      nameEn: 'Coin & Crypto Tracking',
      status: 'Planlandı',
      statusEn: 'Planned',
      description: 'Portföy ve AI yatırım özeti',
      descriptionEn: 'Portfolio and AI investment summary',
      progress: 0.0,
      icon: '🪙',
      category: 'planlandı',
    ),
    LabsModule(
      id: 'investment_center',
      name: 'Yatırım Merkezi',
      nameEn: 'Investment Center',
      status: 'Planlandı',
      statusEn: 'Planned',
      description: 'Hisse senedi, fon ve AI destekli yatırım rehberi',
      descriptionEn: 'Stocks, funds, and AI-powered investment guide',
      progress: 0.0,
      icon: '📈',
      category: 'planlandı',
    ),
    LabsModule(
      id: 'cross_platform_sync',
      name: 'Çoklu Platform Senkronizasyonu',
      nameEn: 'Multi-Platform Sync',
      status: 'Planlandı',
      statusEn: 'Planned',
      description: 'Web, tablet ve mobil platformlar arası anlık senkronizasyon',
      descriptionEn: 'Instant synchronization across web, tablet, and mobile',
      progress: 0.0,
      icon: '🌍',
      category: 'planlandı',
    ),
    LabsModule(
      id: 'voice_ai_assistant',
      name: 'Sesli AI Asistan',
      nameEn: 'Voice AI Assistant',
      status: 'Planlandı',
      statusEn: 'Planned',
      description: 'Sesli komutlarla veri ekleme ve AI ile sesli sohbet',
      descriptionEn: 'Data entry via voice commands and voice chat with AI',
      progress: 0.0,
      icon: '🎙',
      category: 'planlandı',
    ),
    LabsModule(
      id: 'ocr_expense_input',
      name: 'OCR Destekli Harcama Girişi',
      nameEn: 'OCR-Powered Expense Input',
      status: 'Planlandı',
      statusEn: 'Planned',
      description: 'Fatura/fiş fotoğrafından otomatik harcama kaydı',
      descriptionEn: 'Automatic expense entry from receipt/invoice photo',
      progress: 0.0,
      icon: '🧾',
      category: 'planlandı',
    ),

    // Ar-Ge
    LabsModule(
      id: 'ai_finance_advisor',
      name: 'AI Finans Danışmanı',
      nameEn: 'AI Finance Advisor',
      status: 'Ar-Ge',
      statusEn: 'R&D',
      description: 'Tasarruf ve finans risk analizi',
      descriptionEn: 'Savings and financial risk analysis',
      progress: 0.15,
      icon: '🧠',
      category: 'arge',
    ),
    LabsModule(
      id: 'smart_notification_engine',
      name: 'Akıllı Bildirim Motoru',
      nameEn: 'Smart Notification Engine',
      status: 'Ar-Ge',
      statusEn: 'R&D',
      description: 'Kullanım alışkanlıklarına göre optimize bildirim saatleri',
      descriptionEn: 'Notification times optimized based on usage habits',
      progress: 0.10,
      icon: '🔔',
      category: 'arge',
    ),
    LabsModule(
      id: 'ai_goal_prediction',
      name: 'AI Hedef Tahmin Sistemi',
      nameEn: 'AI Goal Prediction System',
      status: 'Ar-Ge',
      statusEn: 'R&D',
      description: 'Geçmiş verilere göre finansal hedef gerçekleşme olasılığı tahmini',
      descriptionEn: 'Probability prediction of goal completion based on historical data',
      progress: 0.05,
      icon: '🎯',
      category: 'arge',
    ),
    LabsModule(
      id: 'smart_doc_reader',
      name: 'Akıllı Belge & Fatura Okuyucu',
      nameEn: 'Smart Document & Invoice Reader',
      status: 'Ar-Ge',
      statusEn: 'R&D',
      description: 'PDF ve belgelerden veri çıkarma ve arşivleme',
      descriptionEn: 'Data extraction and archiving from PDFs and documents',
      progress: 0.08,
      icon: '📄',
      category: 'arge',
    ),
    LabsModule(
      id: 'ai_career_coach',
      name: 'AI Kariyer Alanı',
      nameEn: 'AI Career Workspace',
      status: 'Ar-Ge',
      statusEn: 'R&D',
      description: 'CV analizi, iş önerileri ve kariyer gelişimi planlaması',
      descriptionEn: 'CV analysis, job recommendations, and career development planning',
      progress: 0.02,
      icon: '🧑‍💼',
      category: 'arge',
    ),
    LabsModule(
      id: 'smart_home_iot',
      name: 'Akıllı Ev & IoT',
      nameEn: 'Smart Home & IoT',
      status: 'Ar-Ge',
      statusEn: 'R&D',
      description: 'Akıllı cihazlarla entegrasyon ve ev içi asistanlık',
      descriptionEn: 'Integration with smart devices and home assistance',
      progress: 0.01,
      icon: '🏠',
      category: 'arge',
    ),
  ];
});
