import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../services/module_settings_service.dart';
import '../models/module_setting.dart';

class ModuleSettingsScreen extends ConsumerWidget {
  const ModuleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(moduleSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('module_settings')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n('restore_defaults'),
            onPressed: () => _confirmReset(context, ref),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: settings.length,
        itemBuilder: (context, index) {
          final setting = settings[index];
          return _buildModuleItem(context, ref, setting);
        },
      ),
    );
  }

  Widget _buildModuleItem(BuildContext context, WidgetRef ref, ModuleSetting setting) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(setting.icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          context.l10n(setting.nameKey),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          setting.isVisible ? context.l10n('active_label') : context.l10n('none'),
          style: TextStyle(
            color: setting.isVisible ? Colors.greenAccent : Colors.white24,
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildToggleRow(
                  context,
                  title: context.l10n('notifications'),
                  value: setting.notificationsEnabled,
                  onChanged: (val) {
                    ref.read(moduleSettingsProvider.notifier).updateSetting(
                      setting.id,
                      notificationsEnabled: val,
                    );
                  },
                ),
                if (setting.canHide) ...[
                  const Divider(color: Colors.white12),
                  _buildToggleRow(
                    context,
                    title: context.l10n('hide_module'),
                    value: !setting.isVisible,
                    onChanged: (val) {
                      ref.read(moduleSettingsProvider.notifier).updateSetting(
                        setting.id,
                        isVisible: !val,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(BuildContext context, {required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await UIHelpers.showConfirmDialog(
      context: context,
      title: context.l10n('restore_defaults'),
      content: context.l10n('reset_confirm_msg'),
    );

    if (confirmed) {
      await ref.read(moduleSettingsProvider.notifier).restoreDefaults();
      if (context.mounted) {
        UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
      }
    }
  }
}
