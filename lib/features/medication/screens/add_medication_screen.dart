import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/medication_model.dart';
import '../services/medication_service.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _personController;
  late final TextEditingController _dosageController;
  final _descriptionController = TextEditingController();
  final _daysController = TextEditingController(text: '7');
  
  int _timesPerDay = 1;
  List<TimeOfDay> _scheduleTimes = [const TimeOfDay(hour: 09, minute: 00)];
  bool _isTok = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _personController = TextEditingController(text: context.l10n('myself_label'));
  }

  void _updateTimesCount(int count) {
    setState(() {
      _timesPerDay = count;
      if (_scheduleTimes.length < count) {
        for (var i = _scheduleTimes.length; i < count; i++) {
          _scheduleTimes.add(TimeOfDay(hour: 09 + (i * 4), minute: 00));
        }
      } else if (_scheduleTimes.length > count) {
        _scheduleTimes = _scheduleTimes.sublist(0, count);
      }
    });
  }

  void _saveMedication() async {
    final name = _nameController.text;
    final person = _personController.text;
    final dosage = _dosageController.text;
    final days = int.tryParse(_daysController.text) ?? 1;

    if (name.isEmpty || person.isEmpty || dosage.isEmpty) {
      UIHelpers.showErrorSnackBar(context, context.l10n('fill_required_fields'));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newMed = Medication(
        id: const Uuid().v4(),
        name: name,
        personName: person,
        dosage: dosage,
        scheduleTimes: _scheduleTimes.map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}').toList(),
        description: _descriptionController.text,
        isTok: _isTok,
        dateCreated: DateTime.now(),
        totalDays: days,
        startDate: DateTime.now(),
        timesPerDay: _timesPerDay,
      );

      await ref.read(medicationServiceProvider).addMedication(newMed);
      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('med_add_success'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n('add_new_med'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n('med_name_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.medication),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _personController,
                decoration: InputDecoration(
                  labelText: context.l10n('for_who_label'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _dosageController,
                      decoration: InputDecoration(
                        labelText: context.l10n('dosage_label_hint'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _daysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n('duration_days_label'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(context.l10n('how_many_times_day'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 4, label: Text('4')),
                ],
                selected: {_timesPerDay},
                onSelectionChanged: (val) => _updateTimesCount(val.first),
              ),
              const SizedBox(height: 24),
              Text(context.l10n('usage_hours_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(_timesPerDay, (index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(context.l10n('dose_time_index').replaceFirst('{index}', (index + 1).toString())),
                    trailing: Text(_scheduleTimes[index].format(context), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    leading: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: _scheduleTimes[index]);
                      if (time != null) {
                        setState(() => _scheduleTimes[index] = time);
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(context.l10n('on_empty_stomach')), icon: const Icon(Icons.restaurant_menu_outlined)),
                  ButtonSegment(value: true, label: Text(context.l10n('on_full_stomach')), icon: const Icon(Icons.restaurant)),
                ],
                selected: {_isTok},
                onSelectionChanged: (val) => setState(() => _isTok = val.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n('description_optional'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveMedication,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(context.l10n('save'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
