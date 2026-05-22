import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/localization/app_localizations.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  final FinanceType type;
  const CategoryManagementScreen({super.key, required this.type});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '📁';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == FinanceType.income ? 'Gelir Kategorileri' : 'Gider Kategorileri'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final filteredCategories = categories.where((c) => c.type == widget.type).toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final category = filteredCategories[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: ListTile(
                    leading: Text(category.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                          onPressed: () => _showAddCategoryDialog(context, initialCategory: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteCategory(category),
                        ),
                      ],
                    ),
                    onTap: () => _showAddCategoryDialog(context, initialCategory: category),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${context.l10n('error_label')}: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _deleteCategory(FinanceCategory category) async {
    final confirm = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('confirm_delete') ?? 'Silmeyi Onayla',
      content: '${category.name} silinecek. Emin misiniz?',
    );
    if (confirm) {
      // Not: FinanceService'e deleteCategory metodu eklenmelidir, şimdilik sadece UI bildirimi
      // await ref.read(financeServiceProvider).deleteCategory(category.id);
      if (mounted) UIHelpers.showSuccessSnackBar(context, context.l10n('record_deleted_msg'));
    }
  }

  void _showAddCategoryDialog(BuildContext context, {FinanceCategory? initialCategory}) {
    if (initialCategory != null) {
      _nameController.text = initialCategory.name;
      _selectedEmoji = initialCategory.emoji;
    } else {
      _nameController.clear();
      _selectedEmoji = '📁';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(initialCategory != null ? context.l10n('edit_category') ?? 'Düzenle' : 'Yeni Kategori Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Kategori Adı', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 20),
              const Text('Emoji Seçin:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ['💰', '🍔', '🚗', '🏠', '🎁', '🏥', '🎮', '💡', '👕', '📁', '💻', '🛍️', '🎭', '🥗'].map((e) => GestureDetector(
                  onTap: () => setDialogState(() => _selectedEmoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: _selectedEmoji == e ? Colors.blue : Colors.white10),
                      borderRadius: BorderRadius.circular(8),
                      color: _selectedEmoji == e ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  final category = FinanceCategory(
                    id: initialCategory?.id ?? const Uuid().v4(),
                    name: _nameController.text,
                    emoji: _selectedEmoji,
                    type: widget.type,
                  );
                  await ref.read(financeServiceProvider).addCategory(category);
                  _nameController.clear();
                  if (mounted) {
                    UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                    Navigator.pop(context);
                  }
                }
              },
              child: Text(context.l10n('save')),
            ),
          ],
        ),
      ),
    );
  }
}
