import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/services/subscription_service.dart';
import '../models/health_models.dart';
import '../services/health_service.dart';
import '../widgets/life_tree_widget.dart';
import '../../smoking/services/smoking_service.dart';
import '../../smoking/models/smoking_model.dart';
import '../../../core/services/external_health_service.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  Timer? _refreshTimer;
  String _selectedActivityType = 'Yürüyüş';
  int? _targetMinutes;
  bool _isAuthorized = false;
  
  final Map<String, String> _activityTypeKeys = {
    'Yürüyüş': 'Walking',
    'Koşu': 'Running',
    'Fitness': 'Fitness',
    'Yüzme': 'Swimming',
    'Bisiklet': 'Cycling',
    'Yoga': 'Yoga',
  };

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
      _checkAuthorizationStatus();
    });
  }

  Future<void> _checkAuthorizationStatus() async {
    final externalService = ref.read(externalHealthServiceProvider);
    final authorized = await externalService.hasPermissions();
    if (mounted) {
      setState(() => _isAuthorized = authorized);
    }
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('health');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'health',
          title: context.l10n('health_intro_title'),
          description: context.l10n('health_intro_desc'),
          imagePath: 'assets/images/onboarding_health.png',
          themeColor: AppColors.diaryColor,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  void _startStopActivity(ActiveActivity? current) async {
    final service = ref.read(healthServiceProvider);
    
    if (current != null) {
      // Bitir
      final seconds = current.elapsed.inSeconds;
      if (seconds > 5) {
        final activity = Activity(
          id: const Uuid().v4(),
          type: current.type,
          durationMinutes: (seconds / 60).ceil(),
          date: DateTime.now(),
        );
        await service.addActivity(activity);
        if (mounted) {
          final typeLabel = Localizations.localeOf(context).languageCode == 'tr' ? current.type : (_activityTypeKeys[current.type] ?? current.type);
          UIHelpers.showSuccessSnackBar(context, '${context.l10n('save_success')}: $typeLabel (${(seconds / 60).toStringAsFixed(1)} min)');
        }
      }
      await service.stopActivity();
    } else {
      // Başlat
      final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('health');
      if (!canAdd && mounted) {
        final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
        if (isAnonymous) {
          await UIHelpers.showGuestLimitDialog(
            context: context,
            title: Localizations.localeOf(context).languageCode == 'tr'
                ? 'Verilerini Yedekle 🚀'
                : 'Backup Your Data 🚀',
            description: Localizations.localeOf(context).languageCode == 'tr'
                ? 'Misafir modunda günlük 3 sağlık aktivitesi limitine ulaştın. Aktivitelerini kaybetmemek ve sınırsız devam etmek için hesabını şimdi kaydet!'
                : 'You reached the daily limit of 3 health logs as a guest. Save your account now to keep your records!',
          );
          return;
        }
        UIHelpers.showErrorSnackBar(context, context.l10n('premium_needed_msg'));
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
        return;
      }

      final newActivity = ActiveActivity(
        type: _selectedActivityType,
        startTime: DateTime.now(),
        targetMinutes: (_targetMinutes != null && _targetMinutes! > 0) ? _targetMinutes : null,
      );
      await service.startActivity(newActivity);
    }
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showGoalEditDialog(double currentGoal) {
    final controller = TextEditingController(text: currentGoal.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.l10n('update_goal')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.l10n('amount')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final newGoal = double.tryParse(controller.text);
              if (newGoal != null && newGoal > 0) {
                await ref.read(healthServiceProvider).setWaterGoal(newGoal);
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(context.l10n('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waterDataAsync = ref.watch(dailyWaterProvider);
    final waterLogsAsync = ref.watch(waterLogsProvider);
    final weeklyWaterAsync = ref.watch(weeklyWaterProvider);
    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final waterGoalAsync = ref.watch(waterGoalProvider);
    final smokingAsync = ref.watch(smokingStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n('health_sport_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSyncSection(),
              const SizedBox(height: 24),
              _buildLifeTreeSection(waterDataAsync, waterGoalAsync, smokingAsync),
              const SizedBox(height: 24),
              _buildWaterSection(waterDataAsync, waterLogsAsync, weeklyWaterAsync, waterGoalAsync),
              const SizedBox(height: 32),
              _buildActivitySection(),
              const SizedBox(height: 32),
              Text(context.l10n('activity_history'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildActivityList(activitiesAsync),
              const SizedBox(height: 32),
              Text(context.l10n('stats_7_days'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildActivityChart(activitiesAsync),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterSection(
    AsyncValue<List<WaterIntake>> waterData,
    AsyncValue<List<WaterIntake>> waterLogs,
    AsyncValue<Map<int, double>> weeklyWater,
    AsyncValue<double> waterGoal,
  ) {
    final currentGoal = waterGoal.value ?? 3.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n('water_intake'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Text('${context.l10n('daily_goal')}: ${currentGoal.toStringAsFixed(1)} L', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showGoalEditDialog(currentGoal),
                          child: const Icon(Icons.edit, size: 14, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.water_drop, color: Colors.blueAccent, size: 32),
              ],
            ),
            const SizedBox(height: 24),
            waterData.when(
              data: (intakes) {
                final totalWater = intakes.fold(0.0, (sum, item) => sum + item.amount);
                final progress = (totalWater / currentGoal).clamp(0.0, 1.0);
                return Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 120,
                          width: 120,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            backgroundColor: Colors.white10,
                            color: Colors.blueAccent,
                          ),
                        ),
                        Column(
                          children: [
                            Text('${totalWater.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Text('%${(progress * 100).toInt()}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('${context.l10n('error_label')}: $e'),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildWaterAddButton(0.2, '200ml'),
                _buildWaterAddButton(0.33, '330ml'),
                _buildWaterAddButton(0.5, '500ml'),
                _buildWaterAddButton(1.0, '1.0L'),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(context.l10n('today_records'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.history, size: 20),
                children: [
                  waterLogs.when(
                    data: (logs) {
                      if (logs.isEmpty) return Padding(padding: const EdgeInsets.all(8.0), child: Text(context.l10n('no_data'), style: const TextStyle(fontSize: 12, color: Colors.white30)));
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return ListTile(
                              dense: true,
                              title: Text('${(log.amount * 1000).toInt()} ml', style: const TextStyle(fontSize: 13)),
                              subtitle: Text(DateFormat('HH:mm').format(log.date), style: const TextStyle(fontSize: 11, color: Colors.white30)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () => ref.read(healthServiceProvider).deleteWater(log.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('${context.l10n('error_label')}: $e'),
                  ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(context.l10n('weekly_summary'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                leading: const Icon(Icons.bar_chart, size: 20),
                children: [
                  weeklyWater.when(
                    data: (weekly) {
                      return Container(
                        height: 150,
                        padding: const EdgeInsets.all(16),
                        child: _buildWeeklyWaterChart(weekly),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('${context.l10n('error_label')}: $e'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLifeTreeSection(
    AsyncValue<List<WaterIntake>> waterData,
    AsyncValue<double> waterGoal,
    AsyncValue<SmokingData?> smokingData,
  ) {
    final currentWaterGoal = waterGoal.value ?? 3.0;
    final intakes = waterData.value ?? [];
    final totalWater = intakes.fold(0.0, (sum, item) => sum + item.amount);
    final waterProgress = (totalWater / currentWaterGoal).clamp(0.0, 1.0);

    final smoking = smokingData.value;
    double smokingProgress = 0.0;
    if (smoking != null) {
      final daysClean = DateTime.now().difference(smoking.startDate).inDays;
      smokingProgress = (daysClean / 7).clamp(0.0, 1.0);
    } else {
      smokingProgress = 1.0; // Sigara içmeyen kullanıcı için tam puan
    }

    final totalProgress = (waterProgress * 0.5 + smokingProgress * 0.5).clamp(0.01, 1.0);
    
    String message = "";
    if (totalProgress < 0.2) {
      message = context.l10n('tree_stage_1') ?? "Tohumların toprakla buluştu...";
    } else if (totalProgress < 0.5) {
      message = context.l10n('tree_stage_2') ?? "Yaşamın filizlenmeye başladı!";
    } else if (totalProgress < 0.8) {
      message = context.l10n('tree_stage_3') ?? "Güçlü bir ağaca dönüşüyorsun.";
    } else {
      message = context.l10n('tree_stage_4') ?? "Muazzam! Ağacın çiçek açıyor 🌸";
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: LifeTreeWidget(
        growthProgress: totalProgress,
        message: message,
      ),
    );
  }

  Widget _buildWeeklyWaterChart(Map<int, double> weekly) {
    final List<BarChartGroupData> barGroups = [];
    final now = DateTime.now();
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final daysTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final days = isTr ? daysTr : daysEn;

    for (var i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      final weekday = date.weekday;
      final amount = weekly[weekday] ?? 0.0;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: amount,
              color: Colors.blueAccent,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final date = now.subtract(Duration(days: 6 - val.toInt()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(days[date.weekday - 1], style: const TextStyle(fontSize: 9, color: Colors.white30)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }


  Widget _buildWaterAddButton(double amount, String label) {
    return ElevatedButton(
      onPressed: () async {
        final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('health');
        if (!canAdd && mounted) {
          final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
          if (isAnonymous) {
            await UIHelpers.showGuestLimitDialog(
              context: context,
              title: Localizations.localeOf(context).languageCode == 'tr'
                  ? 'Verilerini Yedekle 🚀'
                  : 'Backup Your Data 🚀',
              description: Localizations.localeOf(context).languageCode == 'tr'
                  ? 'Misafir modunda günlük 3 sağlık/su aktivitesi limitine ulaştın. Kayıtlarını kaybetmemek ve sınırsız devam etmek için hesabını şimdi kaydet!'
                  : 'You reached the daily limit of 3 health logs as a guest. Save your account now to keep your records!',
            );
            return;
          }
          UIHelpers.showErrorSnackBar(context, context.l10n('daily_limit_reached'));
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
          return;
        }
        final intake = WaterIntake(id: const Uuid().v4(), amount: amount, date: DateTime.now());
        await ref.read(healthServiceProvider).addWater(intake);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent.withOpacity(0.1),
        foregroundColor: Colors.blueAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blueAccent.withOpacity(0.2))),
      ),
      child: Text(label),
    );
  }

  Widget _buildActivitySection() {
    final activeSub = ref.watch(activeActivityProvider);
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    
    return activeSub.when(
      data: (active) {
        final isRunning = active != null;
        
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_run, color: isRunning ? Colors.greenAccent : Colors.orangeAccent),
                    const SizedBox(width: 12),
                    Text(isRunning ? context.l10n('activity_in_progress') : context.l10n('start_sport'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (!isRunning)
                      DropdownButton<String>(
                        value: _selectedActivityType,
                        underline: const SizedBox(),
                        dropdownColor: const Color(0xFF1E293B), // Solid background
                        items: _activityTypeKeys.keys.map((String key) {
                          return DropdownMenuItem<String>(value: key, child: Text(isTr ? key : _activityTypeKeys[key]!, style: const TextStyle(fontSize: 14)));
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) setState(() => _selectedActivityType = newValue);
                        },
                      ),
                    if (isRunning)
                      Text(isTr ? active.type : (_activityTypeKeys[active.type] ?? active.type), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isRunning) ...[
                  Row(
                    children: [
                      Flexible(
                        child: Text('${context.l10n('countdown')} (${context.l10n('minutes')}):', 
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 6,
                        children: [null, 15, 30, 60].map((val) {
                          final isSelected = _targetMinutes == val;
                          return GestureDetector(
                            onTap: () => setState(() => _targetMinutes = val),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.orangeAccent : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? Colors.orangeAccent : Colors.white10),
                              ),
                              child: Text(
                                val == null ? context.l10n('none') : '$val',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isRunning 
                      ? (active.isCountdown ? _formatTime(active.remaining!) : _formatTime(active.elapsed))
                      : "00:00:00",
                    style: TextStyle(
                      fontSize: 48, 
                      fontWeight: FontWeight.w200, 
                      letterSpacing: 2,
                      color: isRunning && active.isCountdown && active.remaining! == Duration.zero ? Colors.redAccent : Colors.white
                    ),
                  ),
                ),
                if (isRunning && active.isCountdown)
                  Text(context.l10n('remaining_time'), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _startStopActivity(active),
                  icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(isRunning ? context.l10n('end_sport') : context.l10n('start_sport')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? Colors.redAccent : Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('${context.l10n('error_label')}: $e'),
    );
  }

  Widget _buildActivityList(AsyncValue<List<Activity>> activitiesAsync) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) return Center(child: Text(context.l10n('no_activity_yet'), style: const TextStyle(color: Colors.white30)));
        
        final displayList = activities.take(5).toList();
        
        return Column(
          children: displayList.map((activity) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orangeAccent.withOpacity(0.1),
                child: const Icon(Icons.fitness_center, color: Colors.orangeAccent, size: 20),
              ),
              title: Text(isTr ? activity.type : (_activityTypeKeys[activity.type] ?? activity.type), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(DateFormat('dd MMM, HH:mm').format(activity.date), style: const TextStyle(fontSize: 12, color: Colors.white54)),
              trailing: Text('${activity.durationMinutes} min', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ),
          )).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('${context.l10n('error_label')}: $e'),
    );
  }

  Widget _buildActivityChart(AsyncValue<List<Activity>> activitiesAsync) {
    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) return SizedBox(height: 100, child: Center(child: Text(context.l10n('no_data'), style: const TextStyle(color: Colors.white24))));
        
        final Map<int, int> dailyMins = {};
        final now = DateTime.now();
        for (var i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          dailyMins[date.weekday] = 0;
        }

        for (var activity in activities) {
          if (activity.date.isAfter(now.subtract(const Duration(days: 7)))) {
            dailyMins[activity.date.weekday] = (dailyMins[activity.date.weekday] ?? 0) + activity.durationMinutes;
          }
        }

        final weekdays = dailyMins.keys.toList()..sort();
        final List<BarChartGroupData> barGroups = [];
        
        for (var i = 0; i < weekdays.length; i++) {
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dailyMins[weekdays[i]]!.toDouble(),
                  color: Colors.orangeAccent,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                )
              ],
            ),
          );
        }

        final isTr = Localizations.localeOf(context).languageCode == 'tr';
        final daysTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
        final daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = isTr ? daysTr : daysEn;

        return Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final index = weekdays[val.toInt()] - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(days[index], style: const TextStyle(fontSize: 10, color: Colors.white30)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('${context.l10n('error_label')}: $e'),
    );
  }

  Widget _buildSyncSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isAuthorized ? Colors.greenAccent.withOpacity(0.1) : Colors.orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isAuthorized ? Icons.check_circle : Icons.link_off, 
              color: _isAuthorized ? Colors.greenAccent : Colors.orangeAccent
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAuthorized 
                    ? (context.l10n('health_connected') ?? "Saglik Uygulamasi Bagli")
                    : (context.l10n('health_not_connected') ?? "Saglik Uygulamasi Bagli Degil"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  _isAuthorized
                    ? (context.l10n('health_sync_ready') ?? "Verileri esitlemeye hazirsin.")
                    : (context.l10n('health_connect_desc') ?? "Adim ve su verilerini cekmek icin baglan."),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isAuthorized ? _syncHealthData : _authorizeHealth,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAuthorized ? Colors.greenAccent : Colors.blueAccent,
              foregroundColor: _isAuthorized ? Colors.black87 : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _isAuthorized 
                ? (context.l10n('sync_label') ?? "Esitle")
                : (context.l10n('connect_label') ?? "Baglan")
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _authorizeHealth() async {
    final externalService = ref.read(externalHealthServiceProvider);
    setState(() => UIHelpers.showLoadingDialog(context));

    try {
      final authorized = await externalService.authorize();
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isAuthorized = authorized);
        if (authorized) {
          UIHelpers.showSuccessSnackBar(context, "Baglanti basariyla kuruldu!");
        } else {
          UIHelpers.showErrorSnackBar(context, "Izin verilmedi. Lutfen ayarlardan erisim yetkisi verin.");
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        UIHelpers.showErrorSnackBar(context, "Baglanti hatasi: $e");
      }
    }
  }

  Future<void> _syncHealthData() async {
    final externalService = ref.read(externalHealthServiceProvider);
    final internalService = ref.read(healthServiceProvider);

    setState(() => UIHelpers.showLoadingDialog(context));

    try {
      final authorized = await externalService.authorize();
      if (!authorized) {
        if (mounted) {
          Navigator.pop(context);
          UIHelpers.showErrorSnackBar(context, "Sağlık uygulaması izni verilmedi.");
        }
        return;
      }


      // 2. Su verisini çek ve senkronize et
      final externalWater = await externalService.getWaterToday();
      if (externalWater > 0) {
        final currentIntakes = await internalService.getDailyWater(DateTime.now()).first;
        final currentTotal = currentIntakes.fold(0.0, (sum, item) => sum + item.amount);
        
        // Eğer dışarıdaki veri içeridekinden fazlaysa aradaki farkı ekle
        if (externalWater > currentTotal) {
          final diff = externalWater - currentTotal;
          final intake = WaterIntake(
            id: const Uuid().v4(),
            amount: diff,
            date: DateTime.now(),
          );
          await internalService.addWater(intake);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        UIHelpers.showSuccessSnackBar(context, "Veriler başarıyla senkronize edildi!");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        UIHelpers.showErrorSnackBar(context, "Senkronizasyon hatası: $e");
      }
    }
  }
}
