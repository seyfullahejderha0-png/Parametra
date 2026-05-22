import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';

class AddReminderScreen extends ConsumerStatefulWidget {
  final Reminder? reminderToEdit;

  const AddReminderScreen({super.key, this.reminderToEdit});

  @override
  ConsumerState<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends ConsumerState<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late ReminderRepeatType _repeatType;
  late List<int> _specificDays;
  late bool _isActive;
  late String _categoryIcon;

  final List<String> _availableIcons = ['🔔', '💊', '🏃', '💧', '💰', '🎯', '🛒', '📚', '🎂', '✈️'];

  @override
  void initState() {
    super.initState();
    final edit = widget.reminderToEdit;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _descriptionController = TextEditingController(text: edit?.description ?? '');
    _selectedDate = edit?.dateTime ?? DateTime.now();

    if (edit != null) {
      final parts = edit.timeOfDay.split(':');
      int h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
      int m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      _selectedTime = TimeOfDay(hour: h, minute: m);
    } else {
      _selectedTime = const TimeOfDay(hour: 8, minute: 0);
    }

    _repeatType = edit?.repeatType ?? ReminderRepeatType.once;
    _specificDays = List<int>.from(edit?.specificDays ?? []);
    _isActive = edit?.isActive ?? true;
    _categoryIcon = edit?.categoryIcon ?? '🔔';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_repeatType == ReminderRepeatType.specificDays && _specificDays.isEmpty) {
      UIHelpers.showErrorSnackBar(context, context.l10n('select_days_error') ?? 'Lütfen en az bir gün seçin');
      return;
    }

    final String timeString = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final reminder = Reminder(
      id: widget.reminderToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dateTime: _selectedDate,
      timeOfDay: timeString,
      repeatType: _repeatType,
      specificDays: _specificDays,
      isActive: _isActive,
      isCompleted: widget.reminderToEdit?.isCompleted ?? false,
      categoryIcon: _categoryIcon,
      moduleType: widget.reminderToEdit?.moduleType ?? 'general',
      notificationId: widget.reminderToEdit?.notificationId ?? DateTime.now().millisecondsSinceEpoch.abs() % 100000,
    );

    final service = ref.read(reminderServiceProvider);
    if (widget.reminderToEdit != null) {
      await service.updateReminder(reminder);
    } else {
      await service.addReminder(reminder);
    }

    if (mounted) {
      UIHelpers.showSuccessSnackBar(context, context.l10n('save_success') ?? 'Başarıyla kaydedildi');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reminderToEdit != null
              ? (context.l10n('edit_reminder') ?? 'Hatırlatıcı Düzenle')
              : (context.l10n('add_reminder') ?? 'Yeni Hatırlatıcı'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Kategori İkonu Seçimi
            Text(
              context.l10n('select_icon') ?? 'İkon Seçin',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = icon == _categoryIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryIcon = icon),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.aiColor : Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Başlık
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: context.l10n('title') ?? 'Başlık',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? (context.l10n('form_error_msg') ?? 'Lütfen başlık girin') : null,
            ),
            const SizedBox(height: 16),

            // Açıklama
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.l10n('description_optional') ?? 'Açıklama (Opsiyonel)',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Tekrar Tipi
            Text(
              context.l10n('repeat_type') ?? 'Tekrar Seçeneği',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReminderRepeatType.values.map((type) {
                String label = '';
                switch (type) {
                  case ReminderRepeatType.once:
                    label = context.l10n('once') ?? 'Tek Seferlik';
                    break;
                  case ReminderRepeatType.daily:
                    label = context.l10n('daily') ?? 'Her Gün';
                    break;
                  case ReminderRepeatType.specificDays:
                    label = context.l10n('specific_days') ?? 'Belirli Günler';
                    break;
                  case ReminderRepeatType.customDate:
                    label = context.l10n('custom_date') ?? 'Özel Tarih';
                    break;
                }
                return ChoiceChip(
                  label: Text(label),
                  selected: _repeatType == type,
                  onSelected: (val) {
                    if (val) setState(() => _repeatType = type);
                  },
                  selectedColor: AppColors.aiColor,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Tarih ve Saat Seçimi
            Row(
              children: [
                if (_repeatType == ReminderRepeatType.once || _repeatType == ReminderRepeatType.customDate) ...[
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n('date') ?? 'Tarih', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd MMM yyyy', locale).format(_selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n('time') ?? 'Saat', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_selectedTime.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Belirli Günler Çoklu Seçim
            if (_repeatType == ReminderRepeatType.specificDays) ...[
              Text(
                context.l10n('select_days') ?? 'Günleri Seçin',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                  final daysMap = {
                    1: context.l10n('mon') ?? 'Pzt',
                    2: context.l10n('tue') ?? 'Sal',
                    3: context.l10n('wed') ?? 'Çar',
                    4: context.l10n('thu') ?? 'Per',
                    5: context.l10n('fri') ?? 'Cum',
                    6: context.l10n('sat') ?? 'Cts',
                    7: context.l10n('sun') ?? 'Paz',
                  };
                  final isSelected = _specificDays.contains(day);
                  return FilterChip(
                    label: Text(daysMap[day]!),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _specificDays.add(day);
                        } else {
                          _specificDays.remove(day);
                        }
                      });
                    },
                    selectedColor: AppColors.aiColor,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Aktif / Pasif Switch
            SwitchListTile(
              title: Text(context.l10n('notification_active') ?? 'Bildirimler Aktif'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
              activeColor: AppColors.aiColor,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 48), // Alt kısımdan rahatça kaydırma boşluğu
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 8),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aiColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              context.l10n('save') ?? 'Kaydet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
