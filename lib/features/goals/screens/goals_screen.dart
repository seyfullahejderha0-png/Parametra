import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../widgets/goal_progress_widget.dart';
import '../services/goal_service.dart';
import '../models/goal_model.dart';
import 'add_goal_screen.dart';
import '../../finance/services/finance_service.dart';
import '../../finance/models/finance_models.dart';
import '../../ai_assistant/screens/ai_assistant_screen.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/services/subscription_service.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../../profile/services/profile_service.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('goals');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'goals',
          title: context.l10n('goals_intro_title'),
          description: context.l10n('goals_intro_desc'),
          imagePath: 'assets/images/onboarding_finance.png',
          themeColor: AppColors.goalsColor,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n('my_goals_title')),
          bottom: TabBar(
            indicatorColor: AppColors.goalsColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: context.l10n('my_goals_title')),
              Tab(text: context.l10n('deposit_history_label')),
            ],
          ),
          actions: [
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
                  UIHelpers.showErrorSnackBar(context, context.l10n('ai_assistant_platinum_msg'));
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                  );
                }
              },
            ),
          ],
        ),
        body: goalsAsync.when(
          data: (goals) {
            if (goals.isEmpty) {
              return Center(child: Text(context.l10n('no_goals_msg')));
            }
            
            final avgProgress = goals.isEmpty ? 0.0 : goals.fold(0.0, (sum, g) => sum + g.progress) / goals.length;
            
            return TabBarView(
              children: [
                // Tab 1: Mevcut Hedefler Listesi
                Column(
                  children: [
                    _buildGoalsSummary(avgProgress, context),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: goals.length,
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          return GoalProgressWidget(
                            goal: goal, 
                            currencyCode: currency,
                            onUpdate: () => _showUpdateProgressDialog(context, ref, goal),
                            onDelete: () => _confirmDelete(context, ref, goal.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Tab 2: Yatırım Geçmişi Listesi (ExpansionTile ile Genişleyip Daralan Yapı)
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    if (goal.history.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.goalsColor.withOpacity(0.2),
                            child: const Icon(Icons.track_changes, color: AppColors.goalsColor),
                          ),
                          title: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text(
                            '${context.l10n('current_savings_label')}: ${CurrencyFormatter.format(goal.currentAmount, context, goal.category == 'Döviz' ? 'USD' : 'TRY')}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          children: [
                            const Divider(color: Colors.white10),
                            ...goal.history.reversed.map((deposit) {
                              return ListTile(
                                leading: const Icon(Icons.history, color: AppColors.goalsColor, size: 18),
                                title: Text(
                                  '${CurrencyFormatter.format(deposit.amount, context, goal.category == 'Döviz' ? 'USD' : 'TRY')} - ${deposit.paymentMethodName ?? ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                subtitle: Text(
                                  DateFormat('dd MMM yyyy, HH:mm').format(deposit.date),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('goals');
            if (!canAdd && mounted) {
              final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
              if (isAnonymous) {
                await UIHelpers.showGuestLimitDialog(
                  context: context,
                  title: Localizations.localeOf(context).languageCode == 'tr'
                      ? 'Verilerini Yedekle 🚀'
                      : 'Backup Your Data 🚀',
                  description: Localizations.localeOf(context).languageCode == 'tr'
                      ? 'Misafir modunda 3 hedef limitine ulaştın. Girdiğin hedefleri kaybetmemek ve sınırsız devam etmek için hesabını şimdi kaydet!'
                      : 'You reached the limit of 3 goals as a guest. Save your account now to keep your records!',
                );
                return;
              }
              UIHelpers.showErrorSnackBar(context, context.l10n('goal_limit_msg'));
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
              return;
            }
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddGoalScreen()),
              );
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // Eski metod temizlendi (GoalProgressWidget kullanılıyor)

  Future<void> _showUpdateProgressDialog(BuildContext context, WidgetRef ref, Goal goal) async {
    print("ADD BUTTON CLICKED");
    print("OPENING SHEET");
    debugPrint(StackTrace.current.toString());

    await Future.delayed(Duration.zero);

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => _UpdateGoalProgressDialog(
        key: UniqueKey(), // 10. ADIM: UniqueKey verin
        goal: goal,
      ),
    );

    if (result == true && context.mounted) {
      UIHelpers.showSuccessSnackBar(context, context.l10n('goal_updated_msg'));
    }
  }
  
  void _confirmDelete(BuildContext context, WidgetRef ref, String goalId) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('delete_goal_title'),
      content: context.l10n('delete_goal_msg'),
    );

    if (confirmed) {
      await ref.read(goalServiceProvider).deleteGoal(goalId);
      if (context.mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('goal_delete_success'));
      }
    }
  }

  Widget _buildGoalsSummary(double avgProgress, BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n('overall_success_rate'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '%${(avgProgress * 100).toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: avgProgress,
              strokeWidth: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateGoalProgressDialog extends ConsumerStatefulWidget {
  final Goal goal;
  const _UpdateGoalProgressDialog({super.key, required this.goal});

  @override
  ConsumerState<_UpdateGoalProgressDialog> createState() => _UpdateGoalProgressDialogState();
}

class _UpdateGoalProgressDialogState extends ConsumerState<_UpdateGoalProgressDialog> {
  late final TextEditingController _controller;
  String? _selectedPaymentMethodId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 5. ADIM Final Çözümü: ref.watch ile dinleniyor, böylece Stream ilk açılışta loading olsa bile data gelince form otomatik belirir!
    // Kullanıcının talebi üzerine Yatırım Geçmişi (Deposit History) bu ekrandan TAMAMEN KALDIRILDI
    // ve ana ekranda (GoalsScreen) ayrı bir sekme (Tab) olarak taşındı!
    final paymentMethodsAsync = ref.watch(paymentMethodsWithBalanceProvider);
    final goal = widget.goal;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), 
        side: BorderSide(color: Colors.white.withOpacity(0.1))
      ),
      title: Text(context.l10n('update_progress_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            
            // Ödeme yöntemleri dropdown ve tutar TextField'ı içeren form
            if (paymentMethodsAsync.hasValue && paymentMethodsAsync.value!.isNotEmpty)
              _buildForm(paymentMethodsAsync.value!, context)
            else if (paymentMethodsAsync.isLoading)
              const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (paymentMethodsAsync.hasError)
              Text('Error: ${paymentMethodsAsync.error}', style: const TextStyle(color: Colors.redAccent))
            else
              Text(
                context.l10n('no_payment_methods_msg'),
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            
            const SizedBox(height: 16),
            Text(
              '${context.l10n('current_savings_label')}: ${CurrencyFormatter.format(goal.currentAmount, context, goal.category == 'Döviz' ? 'USD' : 'TRY')}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context, rootNavigator: true).pop(), 
          child: Text(context.l10n('cancel'))
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(context.l10n('update_goal')),
        ),
      ],
    );
  }

  Widget _buildForm(List<PaymentMethod> methods, BuildContext context) {
    String effectiveMethodId = _selectedPaymentMethodId ?? methods.first.id;
    if (!methods.any((m) => m.id == effectiveMethodId)) {
      effectiveMethodId = methods.first.id;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: effectiveMethodId,
          dropdownColor: AppColors.surface,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.l10n('payment_method_label'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: methods.map((m) => DropdownMenuItem(
            value: m.id,
            child: Text(
              '${m.icon} ${m.name} (${CurrencyFormatter.format(m.currentBalance ?? 0, context, 'TRY')})',
              overflow: TextOverflow.ellipsis,
            ),
          )).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedPaymentMethodId = val);
            }
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n('amount'),
            hintText: '0.0',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final val = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
    final methods = ref.read(paymentMethodsWithBalanceProvider).value ?? [];
    
    if (val <= 0 || (_selectedPaymentMethodId == null && methods.isEmpty)) {
      UIHelpers.showErrorSnackBar(
        context, 
        methods.isEmpty ? context.l10n('select_payment_method') : context.l10n('invalid_amount_msg')
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final finalMethodId = _selectedPaymentMethodId ?? methods.first.id;
      final selectedMethod = methods.firstWhere(
        (m) => m.id == finalMethodId, 
        orElse: () => methods.first,
      );

      await ref.read(goalServiceProvider).addGoalProgress(
        widget.goal.id, 
        val, 
        paymentMethodName: selectedMethod.name,
      );

      final goalDesc = context.l10n('goal_deposit_desc').replaceAll('{goalName}', widget.goal.title);

      await ref.read(financeServiceProvider).addFinanceAction(FinanceAction(
        id: const Uuid().v4(),
        categoryId: 'cat_goal_savings',
        paymentMethodId: selectedMethod.id,
        amount: val,
        date: DateTime.now(),
        description: goalDesc,
        type: FinanceType.expense,
        relatedId: widget.goal.id,
      ));

      if (mounted) {
        FocusScope.of(context).unfocus();
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        UIHelpers.showErrorSnackBar(context, "Hata oluştu: $e");
      }
    }
  }
}

