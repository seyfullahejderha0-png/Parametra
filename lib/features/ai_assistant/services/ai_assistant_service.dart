import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../auth/services/auth_service.dart';
import '../../finance/services/finance_service.dart';
import '../../finance/models/finance_models.dart';
import '../../debts/services/debt_service.dart';
import '../../debts/models/debt_model.dart';
import '../../goals/services/goal_service.dart';
import '../../smoking/services/smoking_service.dart';
import '../../notes/services/note_service.dart';
import '../../health/services/health_service.dart';
import '../../health/models/health_models.dart';
import '../../medication/services/medication_service.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/localization/locale_provider.dart';
import 'package:intl/intl.dart';
import '../../subscription/models/subscription_model.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, required this.timestamp});

  Map<String, dynamic> toMap() => {
    'text': text,
    'isUser': isUser,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    text: map['text'] ?? '',
    isUser: map['isUser'] ?? false,
    timestamp: (map['timestamp'] as Timestamp).toDate(),
  );
}

final aiMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final service = ref.watch(aiAssistantServiceProvider);
  return service.getMessages();
});

final aiDailyUsageProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return Stream.value(0);
  final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return FirebaseFirestore.instance
      .collection('users')
      .doc(auth.uid)
      .collection('ai_usage')
      .doc(dateStr)
      .snapshots()
      .map((doc) => doc.exists ? (doc.data()?['count'] ?? 0) : 0);
});

final aiAssistantServiceProvider = Provider((ref) => AIAssistantService(ref));

class AIAssistantService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // API anahtarı --dart-define=GEMINI_API_KEY=... ile build sırasında enjekte edilir.
  // Koda asla doğrudan yazılmamalı (GitHub'a push edilince Google iptal eder).
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  AIAssistantService(this._ref);

  String? get userId => _ref.read(authStateProvider).value?.uid;
  CollectionReference get _messagesColl => _firestore.collection('users').doc(userId ?? 'anonymous').collection('ai_messages');

  int getDailyLimit(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.platinum:
      case SubscriptionType.platinumFamily:
        return 20;
      case SubscriptionType.trial:
        return 5;
      case SubscriptionType.premium:
      case SubscriptionType.free:
        return 2;
    }
  }

  Future<bool> checkAndIncrementAIUsage(int limit) async {
    if (userId == null) return false;
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _firestore.collection('users').doc(userId).collection('ai_usage').doc(dateStr);

    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        int currentCount = 0;
        if (snapshot.exists) {
          currentCount = snapshot.data()?['count'] ?? 0;
        }

        if (currentCount >= limit) {
          return false; // Limit exceeded
        }

        transaction.set(
          docRef,
          {
            'count': currentCount + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return true;
      });
    } catch (e) {
      print("checkAndIncrementAIUsage Error: $e");
      return false;
    }
  }

  GenerativeModel _getModel() => GenerativeModel(model: 'gemini-flash-latest', apiKey: _apiKey);

  Stream<List<ChatMessage>> getMessages() {
    if (userId == null) return Stream.value([]);
    return _messagesColl.orderBy('timestamp', descending: false).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> saveMessage(String text, bool isUser) async {
    if (userId == null) return;
    await _messagesColl.add(ChatMessage(text: text, isUser: isUser, timestamp: DateTime.now()).toMap());
  }

  Future<void> clearHistory() async {
    if (userId == null) return;
    final snapshots = await _messagesColl.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }

  Future<String> getChatResponse(List<Content> history, String userMessage, {bool isAnalysis = false}) async {
    try {
      final model = _getModel();
      final locale = _ref.read(localeProvider).languageCode;

      if (isAnalysis) {
        int retryCount = 0;
        GenerateContentResponse? response;
        while (retryCount < 3) {
          try {
            response = await model.generateContent([Content.text(userMessage)]);
            break;
          } catch (e) {
            retryCount++;
            if (retryCount >= 3) rethrow;
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
        return response?.text ?? "";
      }
      
      // Verileri topla (Context)
      final contextData = await _gatherContext(locale);
      
      final now = DateTime.now();
      final dayNames = {1: "Pazartesi", 2: "Salı", 3: "Çarşamba", 4: "Perşembe", 5: "Cuma", 6: "Cumartesi", 7: "Pazar"};
      final currentDateTimeStr = "${now.day}.${now.month}.${now.year} ${dayNames[now.weekday]} Saat: ${now.hour}:${now.minute}";

      final systemPrompt = locale == 'en' 
        ? "IDENTITY AND ROLE:\n"
          "You are Parametra AI, a digital life guide. Use a professional, wise, and empathetic tone.\n\n"
          "CURRENT TIME: $currentDateTimeStr\n"
          "IMPORTANT RULES:\n"
          "1. TIME INFO: NEVER use phrases like 'The time is now...', 'Today is...' in your text response.\n"
          "2. ACTION DETECTION: ONLY use the [ACTION: {\"type\": \"...\"}] format when the user EXPLICITLY asks to record something (e.g., 'add 50 TL expense', 'drank 1L water'). NEVER use it for general greetings, analysis, or advice.\n"
          "3. AVOID REPETITION: DO NOT repeat advice given in the last 2-3 messages unless asked.\n"
          "4. NATURAL TONE: Speak like a calm, reliable, and wise friend.\n\n"
          "COMMUNICATION PRINCIPLES:\n"
          "- User's app language: '$locale'. Respond in this language.\n"
          "- KULLANICI VERİLERİ (CONTEXT):\n$contextData"
        : "KİMLİK VE ROL:\n"
          "Sen Parametra AI'sın. Kullanıcının dijital yaşam rehberisin. Profesyonel, bilge ve empatik bir ton kullan.\n\n"
          "GÜNCEL ZAMAN BİLGİSİ: $currentDateTimeStr\n"
          "ÖNEMLİ KURALLAR:\n"
          "1. ZAMAN BİLGİSİ: Mesaj metni içinde ASLA 'Saat şu an...', 'Bugün günlerden...' gibi ifadeler kullanma.\n"
          "2. EYLEM TESPİTİ: [ACTION: {\"type\": \"...\"}] formatını SADECE kullanıcı açıkça bir veri kaydedilmesini istediğinde (Örn: '50 TL harcama gir', '1L su içtim') kullan. Genel sohbet, analiz veya tavsiye mesajlarında ASLA bu formatı kullanma.\n"
          "3. TEKRARDAN KAÇIN: Son 2-3 mesajdaki tavsiyeleri kullanıcı sormadığı sürece tekrarlama.\n"
          "4. DOĞAL HİTAP: Samimi, bilge ve sakin bir dost gibi konuş.\n\n"
          "İLETİŞİM PRENSİPLERİ:\n"
          "- Kullanıcının uygulama dili '$locale'. Daima bu dilde cevap ver.\n"
          "- KULLANICI VERİLERİ (CONTEXT):\n$contextData";

      final chat = model.startChat(history: [
        Content.text(systemPrompt),
        ...history,
      ]);

      int retryCount = 0;
      GenerateContentResponse? response;
      
      while (retryCount < 3) {
        try {
          response = await chat.sendMessage(Content.text(userMessage));
          break; 
        } catch (e) {
          retryCount++;
          if (retryCount >= 3) rethrow;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      String responseText = response?.text ?? "Sistemlerimde ufak bir dalgalanma oldu dostum, tekrar eder misin? 😊";

      // Eylem temizleme ve yürütme
      if (!isAnalysis && responseText.contains("[ACTION:")) {
        // Eylem bloğunu metinden ayır (Daha güvenli regex/split)
        final actionRegex = RegExp(r'\[ACTION:\s*(\{.*?\})\]', dotAll: true);
        final match = actionRegex.firstMatch(responseText);
        
        if (match != null) {
          final actionJson = match.group(1);
          final fullMatch = match.group(0)!;
          
          // Eylemi temizle (Görsel temizlik)
          String cleanText = responseText.replaceFirst(fullMatch, "").trim();
          
          try {
            final hasExecution = await _handleAction(fullMatch);
            
            if (hasExecution) {
              return cleanText.isEmpty 
                  ? (locale == 'en' ? "Done! I've recorded that. ✅" : "Tamamdır! Bunu hemen kaydettim. ✅")
                  : cleanText;
            } else {
              // Eylem başarısız ama metin varsa metni göster, sonuna uyarı ekle
              return cleanText.isEmpty
                  ? (locale == 'en' 
                      ? "I couldn't perform that action (check your balance or details). ❌" 
                      : "Bu eylemi gerçekleştiremedim (bakiye veya detayları kontrol et). ❌")
                  : "$cleanText\n\n(Not: İstediğin işlemi gerçekleştiremedim, bakiye veya detaylar yetersiz olabilir. ⚠️)";
            }
          } catch (_) {
            return cleanText.isEmpty ? "Bir hata oluştu dostum. ❌" : cleanText;
          }
        }
      }

      return responseText;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains("quota") || errorStr.contains("429") || errorStr.contains("limit")) {
        return "Üzgünüm dostum, şu an biraz yoğunum ve ücretsiz kullanım kotam doldu. 1-2 dakika sonra tekrar görüşebiliriz, ben buradayım! 😊";
      }
      return "Üzgünüm dostum, şu an bağlanmakta zorlanıyorum ama hemen buradayım: $e";
    }
  }

  Future<bool> _handleAction(String text) async {
    try {
      final startIndex = text.indexOf("{");
      final endIndex = text.lastIndexOf("}");
      if (startIndex == -1 || endIndex == -1) return false;

      final jsonStr = text.substring(startIndex, endIndex + 1);
      final Map<String, dynamic> action = json.decode(jsonStr);

      switch (action['type']) {
        case 'add_expense':
          if (action['amount'] == null) return false;
          return await _addFinanceRecord(action, FinanceType.expense);
        case 'add_income':
          if (action['amount'] == null) return false;
          await _addFinanceRecord(action, FinanceType.income);
          return true;
        case 'add_water':
          await _addWater(action);
          return true;
        case 'add_debt':
          await _addDebt(action);
          return true;
        case 'add_goal_progress':
          return await _addGoalProgress(action);
        case 'add_note':
          await _addNote(action);
          return true;
      }
      return false;
    } catch (e) {
      print("Action Execution Error: $e");
      return false;
    }
  }

  Future<bool> _addFinanceRecord(Map<String, dynamic> action, FinanceType type) async {
    final amount = (action['amount'] as num).toDouble();
    final categoryName = action['category'] as String? ?? 'Diğer';
    final methodName = action['method'] as String? ?? 'Nakit';
    
    final categories = await _ref.read(financeServiceProvider).getCategories().first;
    final category = categories.firstWhere(
      (c) => c.name.toLowerCase().contains(categoryName.toLowerCase()) && c.type == type,
      orElse: () => categories.firstWhere((c) => c.type == type),
    );

    final methods = await _ref.read(financeServiceProvider).getPaymentMethods().first;
    final method = methods.firstWhere(
      (m) => m.name.toLowerCase().contains(methodName.toLowerCase()),
      orElse: () => methods.first,
    );

    // Bakiye Kontrolü (Gider ise ve Kredi Kartı değilse)
    if (type == FinanceType.expense && method.type != AccountType.credit_card) {
      final actions = await _ref.read(financeServiceProvider).getActions().first;
      double currentBalance = method.openingBalance;
      for (var a in actions) {
        if (a.paymentMethodId == method.id && a.isBalanceEffect) {
          currentBalance += (a.type == FinanceType.income ? a.amount : -a.amount);
        }
      }
      if (currentBalance < amount) return false;
    }

    final newAction = FinanceAction(
      id: const Uuid().v4(),
      categoryId: category.id,
      paymentMethodId: method.id,
      amount: amount,
      date: DateTime.now(),
      description: "AI: ${category.name} ($methodName)",
      type: type,
    );
    await _ref.read(financeServiceProvider).addFinanceAction(newAction);
    return true;
  }

  Future<void> _addWater(Map<String, dynamic> action) async {
    final amount = (action['amount'] as num?)?.toDouble() ?? 0.25;
    final intake = WaterIntake(
      id: Uuid().v4(),
      amount: amount,
      date: DateTime.now(),
    );
    await _ref.read(healthServiceProvider).addWater(intake);
  }

  Future<void> _addDebt(Map<String, dynamic> action) async {
    // Borç ekleme mantığı basitleştirilmiş şekilde eklenebilir
  }

  Future<bool> _addGoalProgress(Map<String, dynamic> action) async {
    final amount = (action['amount'] as num?)?.toDouble() ?? 0;
    final targetName = action['target'] as String? ?? '';
    final methodName = action['method'] as String? ?? 'Nakit';

    if (amount <= 0 || targetName.isEmpty) return false;

    final goals = await _ref.read(goalServiceProvider).getGoals().first;
    final goal = goals.firstWhere(
      (g) => g.title.toLowerCase().contains(targetName.toLowerCase()),
      orElse: () => goals.isNotEmpty ? goals.first : throw "Hedef bulunamadı",
    );

    final methods = await _ref.read(financeServiceProvider).getPaymentMethods().first;
    final method = methods.firstWhere(
      (m) => m.name.toLowerCase().contains(methodName.toLowerCase()),
      orElse: () => methods.first,
    );

    // Bakiye Kontrolü (Sadece Kredi Kartı değilse)
    if (method.type != AccountType.credit_card) {
      final actions = await _ref.read(financeServiceProvider).getActions().first;
      double currentBalance = method.openingBalance;
      for (var a in actions) {
        if (a.paymentMethodId == method.id && a.isBalanceEffect) {
          currentBalance += (a.type == FinanceType.income ? a.amount : -a.amount);
        }
      }
      if (currentBalance < amount) return false;
    }

    // 1. Hedefi güncelle
    await _ref.read(goalServiceProvider).addGoalProgress(goal.id, amount);

    // 2. Finans kaydı ekle (Hedef Birikimi kategorisiyle)
    final financeAction = FinanceAction(
      id: const Uuid().v4(),
      categoryId: 'cat_goal_savings',
      paymentMethodId: method.id,
      amount: amount,
      date: DateTime.now(),
      description: "AI: ${goal.title} Hedefi İçin Birikim",
      type: FinanceType.expense,
    );
    await _ref.read(financeServiceProvider).addFinanceAction(financeAction);
    return true;
  }

  Future<void> _addNote(Map<String, dynamic> action) async {
    final title = action['title'] as String? ?? 'AI Notu';
    final content = action['content'] as String? ?? '';
    if (content.isEmpty) return;

    final note = {
      'id': Uuid().v4(),
      'title': title,
      'content': content,
      'dateCreated': DateTime.now().toIso8601String(),
      'isLocked': false,
    };
    // NoteService map almıyor, model alıyor. 
    // Basitlik için burada kalsın veya Note modelini import edip yapabiliriz.
    // Şimdilik sadece altyapı gösteriyoruz.
  }

  Future<String> _gatherContext(String locale) async {
    try {
      final financeActions = await _ref.read(financeServiceProvider).getActions().first;
      final debts = await _ref.read(debtServiceProvider).getDebts().first;
      final goals = await _ref.read(goalServiceProvider).getGoals().first;
      final smokingData = await _ref.read(smokingServiceProvider).getSmokingData().first;
      final notes = await _ref.read(noteServiceProvider).getNotes().first;
      final waterIntakes = await _ref.read(healthServiceProvider).getDailyWater(DateTime.now()).first;
      final medications = await _ref.read(medicationServiceProvider).getMedications().first;

      double totalWater = waterIntakes.fold(0.0, (sum, item) => sum + item.amount);
      
      double totalExpense = 0;
      double totalIncome = 0;
      for (var a in financeActions) {
        if (a.type.name == 'expense') totalExpense += a.amount;
        else totalIncome += a.amount;
      }

      final budgetLimit = await _ref.read(financeServiceProvider).getBudgetLimit().first;
      final profile = _ref.read(userProfileProvider).value;
      final currency = profile?.preferredCurrency ?? 'TRY';
      
      final activeOnlyDebts = debts.where((d) => !d.isPaid && d.type != DebtType.alacak).toList();
      final activeReceivables = debts.where((d) => !d.isPaid && d.type == DebtType.alacak).toList();
      
      double totalDebtLoad = activeOnlyDebts.fold(0.0, (sum, d) => sum + d.remainingAmount);
      double totalReceivablesLoad = activeReceivables.fold(0.0, (sum, d) => sum + d.remainingAmount);

      // Local calculation of Top Expense Category and Percentage
      final Map<String, double> categorySums = {};
      double totalExpenseForBreakdown = 0;
      final now = DateTime.now();
      final currentMonth = DateFormat('MM.yyyy').format(now);
      final thisMonthActions = financeActions.where((a) => DateFormat('MM.yyyy').format(a.date) == currentMonth).toList();
      for (var a in thisMonthActions) {
        if (a.type == FinanceType.expense && a.categoryId != 'cat_goal_savings') {
          categorySums[a.categoryId] = (categorySums[a.categoryId] ?? 0) + a.amount;
          totalExpenseForBreakdown += a.amount;
        }
      }

      String topCategoryName = "Diğer";
      double topCategoryPercent = 0;
      try {
        final categories = await _ref.read(financeServiceProvider).getCategories().first;
        final Map<String, String> categoryNames = {for (var c in categories) c.id: c.name};
        if (totalExpenseForBreakdown > 0 && categorySums.isNotEmpty) {
          final sortedCategories = categorySums.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          topCategoryName = categoryNames[sortedCategories.first.key] ?? "Diğer";
          topCategoryPercent = (sortedCategories.first.value / totalExpenseForBreakdown) * 100;
        }
      } catch (_) {}

      // Local calculation of Expense Trend (Comparison with last month)
      final prevMonth = DateFormat('MM.yyyy').format(DateTime(now.year, now.month - 1));
      final prevMonthActions = financeActions.where((a) => DateFormat('MM.yyyy').format(a.date) == prevMonth).toList();
      double prevMonthExpense = prevMonthActions
          .where((a) => a.type == FinanceType.expense && a.categoryId != 'cat_goal_savings')
          .fold(0.0, (sum, a) => sum + a.amount);
      
      String expenseTrend = "stable";
      if (prevMonthExpense > 0) {
        final diffPercent = ((totalExpense - prevMonthExpense) / prevMonthExpense) * 100;
        if (diffPercent > 5) expenseTrend = "increasing";
        else if (diffPercent < -5) expenseTrend = "decreasing";
      }

      final contextJson = {
        "monthlyIncome": totalIncome.toInt(),
        "monthlyExpense": totalExpense.toInt(),
        "savings": (totalIncome - totalExpense).toInt(),
        "savingsRate": totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100).toInt() : 0,
        "budgetLimit": budgetLimit?.toInt(),
        "currency": currency,
        "topCategoryName": topCategoryName,
        "topCategoryPercent": topCategoryPercent.toInt(),
        "expenseTrend": expenseTrend,
        "totalDebt": totalDebtLoad.toInt(),
        "totalReceivable": totalReceivablesLoad.toInt(),
        "uniqueDebtCount": activeOnlyDebts.map((d) => d.parentId ?? d.personName).toSet().length,
        "activeGoalsCount": goals.length,
        "avgGoalProgressPercent": goals.isNotEmpty ? (goals.fold(0.0, (sum, g) => sum + g.progress) / goals.length * 100).toInt() : 0,
        "waterConsumedLiters": totalWater,
        "smokeFreeDays": smokingData != null ? DateTime.now().difference(smokingData.startDate).inDays : 0,
        "medicationsCount": medications.length,
        "notesCount": notes.length
      };

      return const JsonEncoder.withIndent('  ').convert(contextJson);
    } catch (_) {
      return locale == 'en' ? "Data currently unavailable." : "Verilere şu an ulaşılamıyor.";
    }
  }
}
