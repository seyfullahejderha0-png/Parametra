import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../services/note_lock_service.dart';
import 'note_lock_screen.dart';
import 'add_note_screen.dart';
import '../../reminders/screens/add_reminder_screen.dart';
import '../../ai_assistant/screens/ai_assistant_screen.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/services/subscription_service.dart';
import 'notes_tab.dart';
import '../../reminders/screens/reminders_tab.dart';

class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({super.key});

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('notes');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'notes',
          title: context.l10n('notes_intro_title') ?? 'Notlar & Hatırlatıcılar',
          description: context.l10n('notes_intro_desc') ?? 'Günlük notlarınızı tutun ve tekrarlayan hatırlatıcılar kurun.',
          imagePath: 'assets/images/onboarding_notes.png',
          themeColor: AppColors.goalsColor,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(noteLockProvider);

    // Eğer kilit varsa ve bu oturumda henüz açılmadıysa kilit ekranını göster
    if (lockState.isLocked && !lockState.isUnlocked) {
      return const NoteLockScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('notes_title') ?? 'Notlar & Hatırlatıcılar'),
        actions: [
          IconButton(
            icon: Icon(lockState.isLocked ? Icons.lock_open : Icons.lock_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NoteLockScreen()),
              );
            },
            tooltip: context.l10n('password_settings_tooltip'),
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () {
              final sub = ref.read(subscriptionStreamProvider).value;
              if (sub != null && sub.hasAI) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AIAssistantScreen()),
                );
              } else {
                UIHelpers.showErrorSnackBar(context, context.l10n('ai_assistant_platinum_msg') ?? 'Bu özellik Premium AI gerektirir');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.aiColor,
          labelColor: AppColors.aiColor,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: const Icon(Icons.notes), text: context.l10n('notes_tab') ?? 'Notlar'),
            Tab(icon: const Icon(Icons.notifications_active_outlined), text: context.l10n('reminders_tab') ?? 'Hatırlatıcılar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          NotesTab(),
          RemindersTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_tabController.index == 0) {
            final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('notes');
            if (!canAdd && mounted) {
              UIHelpers.showErrorSnackBar(context, context.l10n('note_limit_msg') ?? 'Not ekleme limitine ulaştınız');
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
              return;
            }
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddNoteScreen()),
              );
            }
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddReminderScreen()),
            );
          }
        },
        backgroundColor: AppColors.aiColor,
        child: Icon(_tabController.index == 0 ? Icons.edit_note : Icons.add_alert),
      ),
    );
  }
}
