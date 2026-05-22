import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';

class NotesTab extends ConsumerWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    final locale = Localizations.localeOf(context).toString();

    return notesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(child: Text(context.l10n('no_notes_msg') ?? 'Henüz bir not eklemediniz.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _buildNoteCard(context, ref, entry, locale);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildNoteCard(BuildContext context, WidgetRef ref, NoteEntry entry, String locale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showEntryDetails(context, entry, locale),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMMM yyyy', locale).format(entry.date),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      if (entry.reminderDateTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.alarm, size: 12, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd.MM HH:mm', locale).format(entry.reminderDateTime!),
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(context, ref, entry.id),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                entry.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              if (entry.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    entry.imageUrls.first,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEntryDetails(BuildContext context, NoteEntry entry, String locale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('dd MMMM yyyy HH:mm', locale).format(entry.date), style: const TextStyle(color: Colors.white54)),
                  if (entry.reminderDateTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm, size: 14, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm', locale).format(entry.reminderDateTime!),
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(entry.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SelectableText(entry.content, style: const TextStyle(fontSize: 16, height: 1.5)),
              const SizedBox(height: 24),
              ...entry.imageUrls.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(url),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String noteId) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('delete_note_title') ?? 'Notu Sil',
      content: context.l10n('delete_note_msg') ?? 'Bu notu silmek istediğinize emin misiniz?',
    );

    if (confirmed) {
      await ref.read(noteServiceProvider).deleteNoteEntry(noteId);
      if (context.mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('note_delete_success') ?? 'Not başarıyla silindi');
      }
    }
  }
}
