import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';

import 'package:intl/intl.dart';

class AddNoteScreen extends ConsumerStatefulWidget {
  const AddNoteScreen({super.key});

  @override
  ConsumerState<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends ConsumerState<AddNoteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;
  DateTime? _reminderDateTime;
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
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
              _contentController.text = result.recognizedWords;
            });
            if (result.finalResult) {
              setState(() => _isListening = false);
            }
          },
          localeId: Localizations.localeOf(context).languageCode == 'tr' ? 'tr_TR' : 'en_US',
        );
      } else {
        if (mounted) {
          final status = await Permission.microphone.request();
          if (status.isDenied) {
            UIHelpers.showErrorSnackBar(context, context.l10n('mic_permission_required'));
          }
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _pickReminder() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _reminderDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _saveEntry() async {
    final title = _titleController.text;
    final content = _contentController.text;

    if (title.isEmpty || content.isEmpty) {
      UIHelpers.showErrorSnackBar(context, context.l10n('enter_title_content_msg'));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final entryId = const Uuid().v4();
      List<String> imageUrls = [];

      if (_selectedImage != null) {
        final url = await ref.read(noteServiceProvider).uploadImage(_selectedImage!, entryId);
        imageUrls.add(url);
      }

      final newEntry = NoteEntry(
        id: entryId,
        title: title,
        content: content,
        date: DateTime.now(),
        imageUrls: imageUrls,
        reminderDateTime: _reminderDateTime,
      );

      await ref.read(noteServiceProvider).addNoteEntry(newEntry);
      if (mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('note_save_success'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n('add_new_note'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: context.l10n('title_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 12,
                    decoration: InputDecoration(
                      hintText: context.l10n('content_hint'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FloatingActionButton.small(
                      heroTag: 'mic_note',
                      onPressed: _listen,
                      backgroundColor: _isListening ? Colors.redAccent : Colors.blueAccent,
                      child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickReminder,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.alarm, color: _reminderDateTime != null ? Colors.blueAccent : Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _reminderDateTime == null ? context.l10n('remind_me') : context.l10n('reminder_set'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (_reminderDateTime != null)
                              Text(
                                DateFormat('dd.MM.yyyy HH:mm').format(_reminderDateTime!),
                                style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                              ),
                          ],
                        ),
                      ),
                      if (_reminderDateTime != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _reminderDateTime = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _saveEntry,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.save_outlined),
                label: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(context.l10n('save').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
