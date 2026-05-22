import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../models/smoking_model.dart';
import '../services/smoking_service.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/utils/currency_formatter.dart';

class RecoveryStage {
  final Duration duration;
  final String title;
  final String description;

  RecoveryStage({required this.duration, required this.title, required this.description});
}

class SmokingScreen extends ConsumerStatefulWidget {
  const SmokingScreen({super.key});

  @override
  ConsumerState<SmokingScreen> createState() => _SmokingScreenState();
}

class _SmokingScreenState extends ConsumerState<SmokingScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _bgAnimationController;

  List<RecoveryStage> _getRecoveryStages(BuildContext context) {
    return [
      RecoveryStage(duration: const Duration(minutes: 20), title: context.l10n('stage1_title'), description: context.l10n('stage1_desc')),
      RecoveryStage(duration: const Duration(hours: 8), title: context.l10n('stage2_title'), description: context.l10n('stage2_desc')),
      RecoveryStage(duration: const Duration(hours: 24), title: context.l10n('stage3_title'), description: context.l10n('stage3_desc')),
      RecoveryStage(duration: const Duration(hours: 48), title: context.l10n('stage4_title'), description: context.l10n('stage4_desc')),
      RecoveryStage(duration: const Duration(hours: 72), title: context.l10n('stage5_title'), description: context.l10n('stage5_desc')),
      RecoveryStage(duration: const Duration(days: 14), title: context.l10n('stage6_title'), description: context.l10n('stage6_desc')),
      RecoveryStage(duration: const Duration(days: 90), title: context.l10n('stage7_title'), description: context.l10n('stage7_desc')),
      RecoveryStage(duration: const Duration(days: 365), title: context.l10n('stage8_title'), description: context.l10n('stage8_desc')),
    ];
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('smoking');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'smoking',
          title: context.l10n('smoking_intro_title'),
          description: context.l10n('smoking_intro_desc'),
          imagePath: 'assets/images/onboarding_smoking.png',
          themeColor: AppColors.smokingColor,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bgAnimationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d, BuildContext context) {
    if (d.inDays > 0) return '${d.inDays} ${context.l10n('days_label')} ${d.inHours % 24} ${context.l10n('hours_label')}';
    if (d.inHours > 0) return '${d.inHours} ${context.l10n('hours_label')} ${d.inMinutes % 60} ${context.l10n('mins_label')}';
    return '${d.inMinutes} ${context.l10n('mins_label')} ${d.inSeconds % 60} ${context.l10n('secs_label')}';
  }

  @override
  Widget build(BuildContext context) {
    final smokingDataAsync = ref.watch(smokingStreamProvider);
    final profile = ref.watch(userProfileProvider).value;
    final currency = profile?.preferredCurrency ?? 'TRY';
    final stages = _getRecoveryStages(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(context.l10n('smoking_tracking'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              final currentData = ref.read(smokingStreamProvider).value;
              _showSettingsDialog(context, ref, currentData);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.1 + (_bgAnimationController.value * 0.05),
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/peaceful_beach.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          smokingDataAsync.when(
            data: (data) {
              if (data == null) {
                return _buildEmptyState();
              }

              final diff = DateTime.now().difference(data.startDate);
              final duration = diff.isNegative ? Duration.zero : diff;
              final savedMoney = (duration.inSeconds / (24 * 3600)) * data.dailyQuantity * (data.packetPrice / 20);
              final longestStreak = Duration(seconds: data.longestSmokeFreeSeconds);

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildGlassStatCard(context.l10n('elapsed_time'), _formatDuration(duration, context), Icons.timer, Colors.blueAccent),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildGlassStatCard(context.l10n('longest_streak_label'), _formatDuration(longestStreak, context), Icons.star, Colors.amber, small: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildGlassStatCard(context.l10n('savings'), CurrencyFormatter.format(savedMoney, context, currency), Icons.savings, Colors.greenAccent, small: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDailySmokedLogger(data),
                      const SizedBox(height: 24),
                      _buildWeeklyReport(data),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n('health_recovery_process'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...stages.map((stage) => _buildRecoveryStageItem(stage, duration)),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySmokedLogger(SmokingData data) {
    final today = DateTime.now();
    final key = "${today.year}-${today.month}-${today.day}";
    final smokedToday = data.dailySmokedLogs[key] ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n('daily_smoked_label'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('$smokedToday adet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _handleLogCigarette(data),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 16),
                    const SizedBox(width: 8),
                    Text(context.l10n('restart_process') ?? 'Süreci Yeniden Başlat'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyReport(SmokingData data) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n('weekly_smoking_report'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                height: 150,
                child: _buildBarChart(data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(SmokingData data) {
    final now = DateTime.now();
    final List<BarChartGroupData> groups = [];
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final days = isTr ? ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'] : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = "${date.year}-${date.month}-${date.day}";
      final count = data.dailySmokedLogs[key] ?? 0;
      
      groups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: count > 0 ? Colors.redAccent : Colors.greenAccent,
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: groups,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final date = now.subtract(Duration(days: 6 - val.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(days[date.weekday - 1], style: const TextStyle(color: Colors.white38, fontSize: 10)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smoke_free, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 24),
                Text(
                  context.l10n('life_without_smoke'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n('configure_settings_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _showSettingsDialog(context, ref, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(context.l10n('start_now')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, Color color, {bool small = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(small ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: small ? 28 : 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(value, style: TextStyle(fontSize: small ? 14 : 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryStageItem(RecoveryStage stage, Duration currentDuration) {
    final bool isAchieved = currentDuration >= stage.duration;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAchieved 
                  ? Colors.greenAccent.withOpacity(0.3) 
                  : Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAchieved 
                    ? Colors.greenAccent.withOpacity(0.7) 
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAchieved ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isAchieved ? Colors.greenAccent : Colors.white54,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stage.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref, SmokingData? currentData) {
    final priceController = TextEditingController(text: currentData?.packetPrice.toString() ?? '50');
    final quantityController = TextEditingController(text: currentData?.dailyQuantity.toString() ?? '20');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(context.l10n('smoking_settings'), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController, 
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '${context.l10n('packet_price')} (${CurrencyFormatter.getSymbol(ref.read(userProfileProvider).value?.preferredCurrency ?? 'TRY')})', 
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              keyboardType: TextInputType.number
            ),
            TextField(
              controller: quantityController, 
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: context.l10n('daily_quantity'), labelStyle: const TextStyle(color: Colors.white70)), 
              keyboardType: TextInputType.number
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final data = SmokingData(
                startDate: currentData?.startDate ?? DateTime.now(),
                dailyQuantity: int.tryParse(quantityController.text) ?? 20,
                packetPrice: double.tryParse(priceController.text) ?? 50.0,
                longestSmokeFreeSeconds: currentData?.longestSmokeFreeSeconds ?? 0,
                dailySmokedLogs: currentData?.dailySmokedLogs ?? {},
              );
              await ref.read(smokingServiceProvider).saveSmokingData(data);
              if (context.mounted) {
                Navigator.pop(context);
                UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
              }
            },
            child: Text(context.l10n('save')),
          ),
        ],
      ),
    );
  }

  void _handleLogCigarette(SmokingData data) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('reset_confirm_title'),
      content: context.l10n('reset_confirm_msg'),
      confirmText: context.l10n('reset_label'),
      confirmColor: Colors.redAccent,
    );

    if (confirmed) {
      await ref.read(smokingServiceProvider).logCigarette(data);
      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('smoking_reset_success'));
      }
    }
  }
}
