import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/theme/app_colors.dart';
import '../services/ai_assistant_service.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/ui_helpers.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/models/subscription_model.dart';
import '../../finance/screens/finance_screen.dart';
import '../../debts/screens/debts_screen.dart';
import '../../goals/screens/goals_screen.dart';
import '../../health/screens/health_screen.dart';
import 'dart:ui';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('ai');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'ai',
          title: context.l10n('ai_intro_title'),
          description: context.l10n('ai_intro_desc'),
          imagePath: 'assets/images/onboarding_notes.png',
          themeColor: AppColors.aiColor,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final sub = ref.read(subscriptionStreamProvider).value;
    final limit = ref.read(aiAssistantServiceProvider).getDailyLimit(sub?.type ?? SubscriptionType.free);

    // Limit check and count increment
    final allowed = await ref.read(aiAssistantServiceProvider).checkAndIncrementAIUsage(limit);
    if (!allowed) {
      if (mounted) {
        final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
        if (isAnonymous) {
          await UIHelpers.showGuestLimitDialog(
            context: context,
            title: Localizations.localeOf(context).languageCode == 'tr'
                ? 'Pai Asistan ile Sınırsız Konuş 🚀'
                : 'Unlimited AI Chat with Pai 🚀',
            description: Localizations.localeOf(context).languageCode == 'tr'
                ? 'Misafir modunda günlük AI limitine ulaştın. Sohbetine kaldığın yerden devam etmek ve verilerini senkronize etmek için hesabını şimdi kaydet!'
                : 'You reached the daily limit of AI messages as a guest. Save your account now to keep chatting with Pai and sync your data!',
          );
          return;
        }
        UIHelpers.showErrorSnackBar(context, context.l10n('ai_limit_reached_msg'));
      }
      return;
    }

    _messageController.clear();
    setState(() => _isLoading = true);
    
    // Kullanıcı mesajını kaydet
    await ref.read(aiAssistantServiceProvider).saveMessage(text, true);
    _scrollToBottom();

    // Geçmişi hazırla
    final messages = ref.read(aiMessagesProvider).value ?? [];
    final history = messages.map((m) {
      return m.isUser ? Content.text(m.text) : Content.model([TextPart(m.text)]);
    }).toList();

    final response = await ref.read(aiAssistantServiceProvider).getChatResponse(history, text);

    if (mounted) {
      // Asistan yanıtını kaydet
      await ref.read(aiAssistantServiceProvider).saveMessage(response, false);
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }
  
  void _onChipTap(String moduleKey) {
    String message = "";
    switch (moduleKey) {
      case 'finance':
        message = context.l10n('analyze_finance_req');
        break;
      case 'debts':
        message = context.l10n('analyze_debts_req');
        break;
      case 'goals':
        message = context.l10n('analyze_goals_req');
        break;
      case 'health':
        message = context.l10n('analyze_health_req');
        break;
    }
    if (message.isNotEmpty) {
      _messageController.text = message;
      _sendMessage();
    }
  }

  void _onChipLongPress(String moduleKey) {
    Widget? screen;
    switch (moduleKey) {
      case 'finance':
        screen = const FinanceScreen();
        break;
      case 'debts':
        screen = const DebtsScreen();
        break;
      case 'goals':
        screen = const GoalsScreen();
        break;
      case 'health':
        screen = const HealthScreen();
        break;
    }
    if (screen != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (error) => debugPrint('STT Error: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _messageController.text = result.recognizedWords;
            });
            if (result.finalResult) {
              setState(() => _isListening = false);
              _sendMessage();
            }
          },
          localeId: Localizations.localeOf(context).languageCode == 'tr' ? 'tr_TR' : 'en_US',
        );
      } else {
        if (mounted) {
          final status = await Permission.microphone.request();
          if (status.isDenied) {
            UIHelpers.showErrorSnackBar(context, 'Mikrofon izni gerekli');
          }
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // Reversed list oldugu icin 0 en alt
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(aiMessagesProvider);
    final subAsync = ref.watch(subscriptionStreamProvider);
    final usageAsync = ref.watch(aiDailyUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('chat_with_assistant')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(context.l10n('clear_history_title'), style: const TextStyle(color: Colors.white)),
                  content: Text(context.l10n('clear_history_msg'), style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n('cancel').toUpperCase(), style: const TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        context.l10n('delete_label').toUpperCase(),
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(aiAssistantServiceProvider).clearHistory();
              }
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: subAsync.when(
        data: (sub) {
          final limit = ref.read(aiAssistantServiceProvider).getDailyLimit(sub.type);
          final usage = usageAsync.value ?? 0;
          final isLimitReached = usage >= limit;

          return Column(
            children: [
              _buildContextStatus(),
              _buildQuotaIndicator(usage, limit),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome, size: 64, color: Colors.white10),
                            const SizedBox(height: 16),
                            Text(context.l10n('no_messages_msg'), style: const TextStyle(color: Colors.white30)),
                          ],
                        ),
                      );
                    }
                    final reversedMessages = messages.reversed.toList();
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Titremeyi onlemek icin en alttan baslat
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: reversedMessages.length,
                      itemBuilder: (context, index) => _buildMessageBubble(reversedMessages[index]),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.l10n('assistant_thinking'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              isLimitReached ? _buildLimitReachedInputArea(limit) : _buildInputArea(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildQuotaIndicator(int count, int limit) {
    final percent = (count / limit).clamp(0.0, 1.0);
    final isAlmostFull = percent >= 0.8;
    final progressColor = isAlmostFull ? Colors.redAccent : AppColors.aiColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n('ai_daily_quota')
                    .replaceAll('{count}', count.toString())
                    .replaceAll('{limit}', limit.toString()),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (percent >= 0.5)
                Text(
                  '%${(percent * 100).toStringAsFixed(0)}',
                  style: TextStyle(color: progressColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedInputArea(int limit) {
    return GlassCard(
      borderRadius: 0,
      blur: 20,
      opacity: 0.1,
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n('ai_limit_reached_msg'),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
                icon: const Icon(Icons.workspace_premium),
                label: Text(context.l10n('upgrade_to_platinum') ?? 'Yükselt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          gradient: isUser 
            ? const LinearGradient(colors: [Colors.blueAccent, Color(0xFF2563EB)])
            : LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.white.withOpacity(0.95),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color: (isUser ? Colors.white : Colors.white54).withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextStatus() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _contextChip(Icons.account_balance_wallet, context.l10n('finance_card'), Colors.greenAccent, 'finance'),
          _contextChip(Icons.warning_amber_rounded, context.l10n('debt_card'), Colors.orangeAccent, 'debts'),
          _contextChip(Icons.track_changes, context.l10n('goals_card'), Colors.blueAccent, 'goals'),
          _contextChip(Icons.medical_services, context.l10n('health_card'), Colors.redAccent, 'health'),
        ],
      ),
    );
  }
  Widget _contextChip(IconData icon, String label, Color color, String moduleKey) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: Tooltip(
        message: '${context.l10n('tap_to_analyze')} / ${context.l10n('long_press_to_open')}',
        child: InkWell(
          onTap: () => _onChipTap(moduleKey),
          onLongPress: () => _onChipLongPress(moduleKey),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return GlassCard(
      borderRadius: 0,
      blur: 20,
      opacity: 0.1,
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n('ask_something_hint'),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _listen,
                child: Container(
                  height: 45,
                  width: 45,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: _isListening ? Colors.redAccent : Colors.white10),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.redAccent : Colors.white70,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  height: 45,
                  width: 45,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.blueAccent, Color(0xFF1E40AF)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

