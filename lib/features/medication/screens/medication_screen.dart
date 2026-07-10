import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../models/medication_model.dart';
import '../services/medication_service.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/services/subscription_service.dart';
import 'add_medication_screen.dart';

class MedicationScreen extends ConsumerStatefulWidget {
  const MedicationScreen({super.key});

  @override
  ConsumerState<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends ConsumerState<MedicationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final shouldShow = await ref.read(onboardingServiceProvider).shouldShowIntro('medication');
    if (shouldShow && mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ModuleIntroCard(
          moduleId: 'medication',
          title: context.l10n('medication_intro_title'),
          description: context.l10n('medication_intro_desc'),
          imagePath: 'assets/images/onboarding_medication.png',
          themeColor: AppColors.primary,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicationsAsync = ref.watch(medicationsStreamProvider);
    final logsAsync = ref.watch(logTodayStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n('med_tracking'))),
      body: SafeArea(
        child: medicationsAsync.when(
          data: (meds) {
            if (meds.isEmpty) {
              return Center(child: Text(context.l10n('no_meds_yet')));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n('today_doses'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDailySchedule(context, ref, meds, logsAsync.value ?? []),
                  const SizedBox(height: 32),
                  Text(context.l10n('all_my_meds'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...meds.map((med) => _buildMedicationCard(context, ref, med)),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final canAdd = await ref.read(subscriptionServiceProvider).canAddEntry('medication');
          if (!canAdd && mounted) {
            final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
            if (isAnonymous) {
              await UIHelpers.showGuestLimitDialog(
                context: context,
                title: Localizations.localeOf(context).languageCode == 'tr'
                    ? 'Verilerini Yedekle 🚀'
                    : 'Backup Your Data 🚀',
                description: Localizations.localeOf(context).languageCode == 'tr'
                    ? 'Misafir modunda 3 ilaç limitine ulaştın. İlaç listeni kaybetmemek ve sınırsız devam etmek için hesabını şimdi kaydet!'
                    : 'You reached the limit of 3 medications as a guest. Save your account now to keep your records!',
              );
              return;
            }
            UIHelpers.showErrorSnackBar(context, context.l10n('med_limit_msg'));
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
            return;
          }
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMedicationScreen()));
          }
        },
        child: const Icon(Icons.add_task),
      ),
    );
  }

  Widget _buildDailySchedule(BuildContext context, WidgetRef ref, List<Medication> meds, List<MedicationLog> logs) {
    final List<Map<String, dynamic>> todaySchedule = [];

    for (var med in meds) {
      if (med.isActiveToday) {
        for (var time in med.scheduleTimes) {
          final isTaken = logs.any((l) => l.medicationId == med.id && l.scheduledTime == time);
          todaySchedule.add({
            'med': med,
            'time': time,
            'isTaken': isTaken,
          });
        }
      }
    }

    todaySchedule.sort((a, b) => a['time'].compareTo(b['time']));

    if (todaySchedule.isEmpty) return Text(context.l10n('no_dose_plan_today'), style: const TextStyle(color: Colors.white30));

    return Column(
      children: todaySchedule.map((item) {
        final Medication med = item['med'];
        final String time = item['time'];
        final bool isTaken = item['isTaken'];

        // Zamanı geçti kontrolü
        final now = DateTime.now();
        final timeParts = time.split(':');
        final scheduleTime = DateTime(now.year, now.month, now.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
        final bool isMissed = !isTaken && now.isAfter(scheduleTime);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Icon(
              isTaken ? Icons.check_circle : (isMissed ? Icons.error_outline : Icons.pending_actions),
              color: isTaken ? Colors.greenAccent : (isMissed ? Colors.redAccent : Colors.blueAccent),
            ),
            title: Text(
              med.name, 
              style: TextStyle(
                decoration: isTaken ? TextDecoration.lineThrough : null, 
                fontWeight: FontWeight.bold,
                color: isMissed ? Colors.redAccent.withOpacity(0.8) : null,
              )
            ),
            subtitle: Text(
              '$time • ${med.dosage} (${med.isTok ? context.l10n('tok_label') : context.l10n('ac_label')})',
              style: TextStyle(color: isMissed ? Colors.redAccent.withOpacity(0.6) : Colors.white70),
            ),
            trailing: isTaken 
              ? Text(context.l10n('taken_label'), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMissed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          context.l10n('missed_label'), 
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () => _takeMedication(ref, med, time),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isMissed ? Colors.redAccent : Colors.blueAccent).withOpacity(0.1),
                        foregroundColor: isMissed ? Colors.redAccent : Colors.blueAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: isMissed ? const BorderSide(color: Colors.redAccent, width: 1) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(context.l10n('i_took_it_btn')),
                    ),
                  ],
                ),
          ),
        );
      }).toList(),
    );
  }

  void _takeMedication(WidgetRef ref, Medication med, String time) async {
    final log = MedicationLog(
      id: const Uuid().v4(),
      medicationId: med.id,
      medicationName: med.name,
      takenDate: DateTime.now(),
      scheduledTime: time,
    );
    await ref.read(medicationServiceProvider).addLog(log);
  }

  Widget _buildMedicationCard(BuildContext context, WidgetRef ref, Medication med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: med.isTok ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication,
                color: med.isTok ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
            title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${med.personName} • ${med.dosage}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: med.scheduleTimes.map((time) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.blueAccent),
                        const SizedBox(width: 4),
                        Text(time, style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmDelete(context, ref, med.id),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${context.l10n('treatment_process')}: ${med.totalDays} ${context.l10n('days_label')}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    Text(context.l10n('remaining_days').replaceFirst('{days}', med.remainingDays.toString()), style: const TextStyle(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: med.progress,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('delete_med_title'),
      content: context.l10n('delete_med_msg'),
    );

    if (confirmed) {
      await ref.read(medicationServiceProvider).deleteMedication(id);
      if (context.mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('med_delete_success'));
      }
    }
  }
}

