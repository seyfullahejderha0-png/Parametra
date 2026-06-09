import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/services/auth_service.dart';
import '../../onboarding/widgets/module_intro_card.dart';
import '../services/profile_service.dart';
import '../../badges/screens/badge_screen.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/services/app_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../subscription/services/subscription_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../subscription/models/subscription_model.dart';
import 'module_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'legal_detail_screen.dart';
import 'faq_screen.dart';
import 'parametra_labs_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/services/reporting_service.dart';
import '../../subscription/services/iap_service.dart';
import '../../debts/services/debt_service.dart';
import '../../finance/services/finance_service.dart';
import '../../finance/services/budget_service.dart';
import '../../goals/services/goal_service.dart';
import '../../health/services/health_service.dart';
import '../../smoking/services/smoking_service.dart';
import '../../medication/services/medication_service.dart';
import '../../notes/services/note_service.dart';
import '../../reminders/services/reminder_service.dart';
import '../../gamification/services/gamification_service.dart';
import '../../reports/providers/report_cache_provider.dart';
import '../../family/models/family_models.dart';
import '../../family/services/family_service.dart';
import '../../family/screens/family_management_screen.dart';
import '../../../app.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _updateAvatar() async {
    final profile = ref.read(userProfileProvider).value;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n('select_avatar'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _avatarOption('assets/images/avatars/male1.png'),
                    _avatarOption('assets/images/avatars/female1.png'),
                    _avatarOption('assets/images/avatars/robot1.png'),
                    _avatarOption('assets/images/avatars/male2.png'),
                    _avatarOption('assets/images/avatars/female2.png'),
                    _avatarOption('assets/images/avatars/robot2.png'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Colors.blueAccent, size: 20),
                ),
                title: Text(context.l10n('choose_from_gallery'), style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (image != null) {
                      if (context.mounted) {
                        UIHelpers.showInfoSnackBar(context, context.l10n('uploading_image'));
                      }
                      
                      final url = await ref.read(profileServiceProvider).uploadProfilePicture(File(image.path));
                      if (url != null) {
                        await ref.read(profileServiceProvider).updateProfile(
                          firstName: profile?.firstName ?? '',
                          lastName: profile?.lastName ?? '',
                          photoUrl: url,
                        );
                        if (context.mounted) {
                          UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                        }
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      UIHelpers.showErrorSnackBar(context, "${context.l10n('error_label')}: $e");
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarOption(String path) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final profile = ref.read(userProfileProvider).value;
        await ref.read(profileServiceProvider).updateProfile(
          firstName: profile?.firstName ?? '',
          lastName: profile?.lastName ?? '',
          photoUrl: path,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
          border: Border.all(color: Colors.white10, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final subscriptionAsync = ref.watch(subscriptionStreamProvider);
    final appConfigAsync = ref.watch(appConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.scaffoldBackgroundColor, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(profileAsync, theme),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPremiumCard(subscriptionAsync, theme),
                    const SizedBox(height: 16),
                    _buildFamilyWorkspaceCard(subscriptionAsync, theme),
                    const SizedBox(height: 16),
                    _buildNotificationPreferencesCard(profileAsync.value, theme),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context.l10n('subscription')),
                    const SizedBox(height: 12),
                    _buildGroupedCard([
                      _buildGroupTile(
                        icon: Icons.star_outline,
                        title: context.l10n('subscription'),
                        color: Colors.amber,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: context.l10n('generate_monthly_report'),
                        color: Colors.redAccent,
                        onTap: () async {
                          final progressNotifier = ValueNotifier<ReportProgressState>(
                            ReportProgressState(0.0, context.l10n('report_preparing') ?? 'Hazırlanıyor...'),
                          );
                          _showReportProgressDialog(context, progressNotifier);
                          try {
                            await ref.read(reportingServiceProvider).generateMonthlyReport(
                              onProgress: (progress, status) {
                                progressNotifier.value = ReportProgressState(progress, status);
                              },
                            );
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                              UIHelpers.showSuccessSnackBar(context, context.l10n('report_completed') ?? 'Rapor başarıyla oluşturuldu!');
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                              if (e.toString().contains('AI_QUOTA_ERROR')) {
                                UIHelpers.showErrorSnackBar(context, context.l10n('report_later_msg'));
                              } else {
                                UIHelpers.showErrorSnackBar(context, "${context.l10n('error_label')}: $e");
                              }
                            }
                          } finally {
                            progressNotifier.dispose();
                          }
                        },
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context.l10n('settings')),
                    const SizedBox(height: 12),
                    _buildGroupedCard([
                      _buildGroupTile(
                        icon: Icons.emoji_events_outlined,
                        title: context.l10n('achievements'),
                        color: Colors.amber,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgeScreen())),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.palette_outlined,
                        title: context.l10n('premium_themes'),
                        color: theme.primaryColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeSettingsScreen())),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.settings_suggest_outlined,
                        title: context.l10n('module_settings'),
                        color: Colors.blueAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleSettingsScreen())),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.language,
                        title: context.l10n('language'),
                        color: Colors.tealAccent,
                        onTap: () => _showLanguageDialog(context, ref),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.payments_outlined,
                        title: context.l10n('currency'),
                        color: Colors.greenAccent,
                        onTap: () => _showCurrencyDialog(context, ref, profileAsync.value?.preferredCurrency ?? 'TRY'),
                        showDivider: true,
                      ),
                      _buildLabsMenuTile(context, showDivider: false),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context.l10n('dev_support_section')),
                    const SizedBox(height: 12),
                    _buildDeveloperSupportCard(theme, subscriptionAsync.value),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context.l10n('share_app_title')),
                    const SizedBox(height: 12),
                    _buildShareAppCard(theme, appConfigAsync),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context.l10n('help_and_support')),
                    const SizedBox(height: 12),
                    _buildSupportCard(theme),
                    const SizedBox(height: 16),
                    _buildGroupedCard([
                      _buildGroupTile(
                        icon: Icons.help_outline,
                        title: context.l10n('faq_title'),
                        color: Colors.orangeAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FAQScreen())),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.visibility_outlined,
                        title: context.l10n('vision_title'),
                        color: Colors.blueAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDetailScreen(
                          title: context.l10n('vision_title'),
                          content: context.l10n('vision_content'),
                        ))),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.track_changes_outlined,
                        title: context.l10n('mission_title'),
                        color: Colors.redAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDetailScreen(
                          title: context.l10n('mission_title'),
                          content: context.l10n('mission_content'),
                        ))),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.info_outline,
                        title: context.l10n('about_us_title'),
                        color: Colors.cyanAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDetailScreen(
                          title: context.l10n('about_us_title'),
                          content: context.l10n('about_us_content'),
                        ))),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.policy_outlined,
                        title: context.l10n('privacy_policy'),
                        color: Colors.white54,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDetailScreen(
                          title: context.l10n('privacy_policy'),
                          content: context.l10n('privacy_policy_content'),
                        ))),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.description_outlined,
                        title: context.l10n('terms_of_use'),
                        color: Colors.white54,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDetailScreen(
                          title: context.l10n('terms_of_use'),
                          content: context.l10n('terms_of_use_content'),
                        ))),
                        showDivider: true,
                      ),
                      _buildGroupTile(
                        icon: Icons.gavel_outlined,
                        title: context.l10n('data_deletion_policy'),
                        color: Colors.white54,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LegalDetailScreen(
                          title: context.l10n('data_deletion_policy'),
                          content: context.l10n('data_deletion_policy_content'),
                        ))),
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 32),
                    _buildLogoutButton(),
                    const SizedBox(height: 12),
                    _buildMenuTile(
                      icon: Icons.delete_forever_outlined,
                      title: context.l10n('delete_account_and_data'),
                      color: Colors.redAccent.withOpacity(0.7),
                      onTap: () => _showDeleteAccountDialog(context, ref),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPreferencesCard(UserProfile? profile, ThemeData theme) {
    if (profile == null) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent, size: 20),
        ),
        title: Text(
          context.l10n('family_notifications') ?? 'Aile Bildirimleri',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        subtitle: const Text(
          'Ortak alan aktiviteleri bildirim ayarları',
          style: TextStyle(fontSize: 12, color: Colors.white54),
        ),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white30,
        children: [
          const Divider(color: Colors.white12, height: 16),
          _buildNotificationSwitchRow(
            title: context.l10n('notify_finance') ?? 'Finans İşlemleri',
            value: profile.notifyFinance,
            onChanged: (val) => ref.read(profileServiceProvider).updateNotificationPreference('finance', val),
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildNotificationSwitchRow(
            title: context.l10n('notify_goals') ?? 'Hedefler',
            value: profile.notifyGoals,
            onChanged: (val) => ref.read(profileServiceProvider).updateNotificationPreference('goals', val),
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildNotificationSwitchRow(
            title: context.l10n('notify_notes') ?? 'Notlar',
            value: profile.notifyNotes,
            onChanged: (val) => ref.read(profileServiceProvider).updateNotificationPreference('notes', val),
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildNotificationSwitchRow(
            title: context.l10n('notify_reminders') ?? 'Hatırlatıcılar',
            value: profile.notifyReminders,
            onChanged: (val) => ref.read(profileServiceProvider).updateNotificationPreference('reminders', val),
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildNotificationSwitchRow(
            title: context.l10n('notify_health') ?? 'Sağlık Bildirimleri (Varsayılan Kapalı)',
            value: profile.notifyHealth,
            onChanged: (val) => ref.read(profileServiceProvider).updateNotificationPreference('health', val),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitchRow({required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue profileAsync, ThemeData theme) {
    final subData = ref.watch(subscriptionStreamProvider).value;
    final isSupporter = subData?.isSupporter ?? false;

    return profileAsync.when(
      data: (profile) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isSupporter ? Colors.orangeAccent.withOpacity(0.2) : theme.primaryColor.withOpacity(0.3),
                    Colors.transparent
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _updateAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Yıldızlı Çerçeve (Destekçi için)
                    if (isSupporter)
                      Positioned(
                        top: -5, left: -5, right: -5, bottom: -5,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber, width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
                            ],
                          ),
                        ),
                      ),
                    
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSupporter ? Colors.amber : theme.primaryColor, 
                          width: 2
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white10,
                        backgroundImage: profile?.photoUrl != null 
                          ? (profile!.photoUrl!.startsWith('assets') 
                              ? AssetImage(profile.photoUrl!) as ImageProvider
                              : NetworkImage(profile.photoUrl!))
                          : null,
                        child: profile?.photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white24) : null,
                      ),
                    ),
                    
                    // Kral Tacı (Destekçi için)
                    if (isSupporter)
                      Positioned(
                        top: -25,
                        left: 0,
                        right: 0,
                        child: const Center(
                          child: Text('👑', style: TextStyle(fontSize: 32)),
                        ),
                      ),
                      
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSupporter ? Colors.amber : theme.primaryColor, 
                          shape: BoxShape.circle
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${profile?.firstName ?? ''} ${profile?.lastName ?? ''}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
                    onPressed: () => _showEditProfileDialog(profile),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                profile?.email ?? FirebaseAuth.instance.currentUser?.email ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.white54),
              ),
              if (subData != null) ...[
                const SizedBox(height: 8),
                _buildHeaderSubscriptionBadge(subData, theme),
              ],
            ],
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildHeaderSubscriptionBadge(SubscriptionData sub, ThemeData theme) {
    final type = sub.type;
    final isPremium = sub.isPremium;
    final isTrial = type == SubscriptionType.trial && sub.isActive;
    final isPlatinum = type == SubscriptionType.platinum;
    final isPlatinumFamily = type == SubscriptionType.platinumFamily;

    IconData icon = Icons.star_border;
    Color color = Colors.white54;

    if (isTrial) {
      icon = Icons.auto_awesome;
      color = Colors.amber;
    } else if (isPlatinumFamily) {
      icon = Icons.workspace_premium;
      color = Colors.amber;
    } else if (isPlatinum) {
      icon = Icons.bolt;
      color = theme.primaryColor;
    } else if (isPremium) {
      icon = Icons.star;
      color = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            context.l10n(sub.typeNameKey),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(AsyncValue subscriptionAsync, ThemeData theme) {
    return subscriptionAsync.when(
      data: (sub) {
        if (sub == null) return const SizedBox.shrink();
        
        final type = sub.type;
        final isPremium = sub.isPremium;
        final isTrial = type == SubscriptionType.trial && sub.isActive;
        final isPlatinum = type == SubscriptionType.platinum;
        final isPlatinumFamily = type == SubscriptionType.platinumFamily;
        
        String titleKey = sub.typeNameKey;
        String subtitleKey = 'limited_access';
        IconData icon = Icons.star_border;
        Color color = Colors.white24;

        if (isTrial) {
          subtitleKey = 'all_features_unlocked';
          icon = Icons.auto_awesome;
          color = Colors.amber;
        } else if (isPlatinumFamily) {
          subtitleKey = 'all_features_unlocked';
          icon = Icons.workspace_premium;
          color = Colors.amber;
        } else if (isPlatinum) {
          subtitleKey = 'all_features_unlocked';
          icon = Icons.bolt;
          color = theme.primaryColor;
        } else if (isPremium) {
          subtitleKey = 'all_features_unlocked';
          icon = Icons.star;
          color = Colors.amber;
        }

        return GlassCard(
          opacity: 0.1,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n(titleKey),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            isTrial 
                              ? context.l10n('free_trial_remaining').replaceFirst('{days}', sub.remainingTrialDays.toString())
                              : context.l10n(subtitleKey),
                            style: TextStyle(
                              fontSize: 12, 
                              color: isTrial ? Colors.amber : Colors.white54,
                              fontWeight: isTrial ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                  ),
                ),
                if (type == SubscriptionType.free || isTrial)
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(context.l10n('upgrade_btn'), style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildFamilyWorkspaceCard(AsyncValue subscriptionAsync, ThemeData theme) {
    final spacesAsync = ref.watch(sharedSpacesProvider);
    final activeSpaceId = ref.watch(activeSharedSpaceIdProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return subscriptionAsync.when(
      data: (sub) {
        final hasFamily = sub?.hasFamily ?? false;

        return GlassCard(
          onTap: () {
            if (hasFamily) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyManagementScreen()));
            } else {
              UIHelpers.showErrorSnackBar(context, context.l10n('shared_mode_upsell') ?? 'Aile / Ortak Mod sadece Premium AI Aile üyelerinde kullanılabilir.');
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            }
          },
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: hasFamily ? Colors.amber.withValues(alpha: 0.1) : Colors.white10, shape: BoxShape.circle),
                    child: Icon(Icons.family_restroom, color: hasFamily ? Colors.amber : Colors.white38),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n('family_workspace') ?? 'Aile / Ortak Alan', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        spacesAsync.when(
                          data: (spaces) {
                            if (!hasFamily) {
                              return Text(
                                context.l10n('shared_mode_upsell') ?? 'Sadece Premium AI Aile üyelerinde kullanılabilir', 
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            if (spaces.isEmpty) {
                              return const Text(
                                'Henüz aktif bir ortak alan yok. Oluşturmak için dokun.', 
                                style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            final activeSpace = spaces.firstWhere((s) => s.id == activeSpaceId, orElse: () => spaces.first);
                            final myInfo = activeSpace.members.firstWhere((m) => m.uid == currentUser?.uid, orElse: () => activeSpace.members.first);
                            return Text(
                              'Aktif: ${activeSpace.name} • ${activeSpace.members.length} Üye • Rol: ${myInfo.role.name.toUpperCase()}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                          loading: () => const Text('Yükleniyor...', style: TextStyle(fontSize: 12, color: Colors.white54)),
                          error: (_, __) => const Text('Hata oluştu', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ),
                  if (hasFamily)
                    const Icon(Icons.chevron_right, color: Colors.white24)
                  else
                    const Icon(Icons.lock_outline, color: Colors.redAccent, size: 20),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String title, Color? color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: ListTile(
          leading: Icon(icon, color: color ?? Colors.white70, size: 22),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.white24),
          onTap: onTap,
          dense: true,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildGroupTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? leadingWidget,
    Color? color,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: leadingWidget ?? Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (color ?? Colors.white70).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white70, size: 20),
          ),
          title: Text(
            title, 
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)
          ),
          subtitle: subtitle != null 
              ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)) 
              : null,
          trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white24),
          onTap: onTap,
          dense: subtitle == null,
        ),
        if (showDivider)
          const Divider(color: Colors.white10, height: 1, indent: 56),
      ],
    );
  }

  Widget _buildLabsMenuTile(BuildContext context, {bool showDivider = true}) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    return _buildGroupTile(
      icon: Icons.science_outlined,
      leadingWidget: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Text('🚀', style: TextStyle(fontSize: 14)),
      ),
      title: 'Parametra Labs',
      subtitle: isTr ? 'Yakında gelecek özellikleri keşfet' : 'Discover upcoming features',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ParametraLabsScreen()),
      ),
      showDivider: showDivider,
    );
  }

  void _clearAllUserDataAndNavigate(BuildContext context, WidgetRef ref) {
    // 1. Tüm Stream ve Future Provider'ları temizle (Invalidate)
    ref.invalidate(userProfileProvider);
    ref.invalidate(subscriptionStreamProvider);
    ref.invalidate(debtsStreamProvider);
    ref.invalidate(actionsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(paymentMethodsProvider);
    ref.invalidate(recurringPaymentsProvider);
    ref.invalidate(budgetLimitProvider);
    ref.invalidate(budgetsStreamProvider);
    ref.invalidate(goalsStreamProvider);
    ref.invalidate(waterGoalProvider);
    ref.invalidate(dailyWaterProvider);
    ref.invalidate(waterLogsProvider);
    ref.invalidate(weeklyWaterProvider);
    ref.invalidate(activitiesStreamProvider);
    ref.invalidate(activeActivityProvider);
    ref.invalidate(smokingStreamProvider);
    ref.invalidate(medicationsStreamProvider);
    ref.invalidate(logTodayStreamProvider);
    ref.invalidate(notesStreamProvider);
    ref.invalidate(remindersStreamProvider);
    ref.invalidate(userProgressStreamProvider);
    ref.invalidate(financialReportCacheProvider);
    ref.invalidate(debtReportCacheProvider);
    ref.invalidate(goalReportCacheProvider);
    ref.invalidate(healthReportCacheProvider);

    // 2. Kök navigasyon yığınını tamamen sıfırla ve AuthWrapper'a dön
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: () async {
        await ref.read(authServiceProvider).signOut();
        if (mounted) {
          _clearAllUserDataAndNavigate(context, ref);
        }
      },
      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
      label: Text(context.l10n('logout'), style: const TextStyle(color: Colors.redAccent)),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.l10n('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Türkçe'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('tr', 'TR'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en', 'US'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.l10n('select_currency_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _currencyTile(context, ref, context.l10n('currency_try'), 'TRY', '₺', current == 'TRY'),
            _currencyTile(context, ref, context.l10n('currency_usd'), 'USD', '\$', current == 'USD'),
            _currencyTile(context, ref, context.l10n('currency_eur'), 'EUR', '€', current == 'EUR'),
          ],
        ),
      ),
    );
  }

  Widget _currencyTile(BuildContext context, WidgetRef ref, String name, String code, String symbol, bool isSelected) {
    return ListTile(
      title: Text(name),
      trailing: Text(symbol, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white24, fontWeight: FontWeight.bold)),
      onTap: () async {
        await ref.read(profileServiceProvider).updateCurrency(code);
        Navigator.pop(context);
        UIHelpers.showSuccessSnackBar(context, '${context.l10n('currency')} $code ${context.l10n('save_success')}');
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.l10n('delete_data_confirmation')),
        content: Text(context.l10n('delete_data_warning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel').toUpperCase())),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close confirmation dialog
              _showDeletionProgressDialog(context, ref);
            }, 
            child: Text(context.l10n('delete_label').toUpperCase(), style: const TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  void _showDeletionProgressDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        double progress = 0.0;
        bool started = false;
        
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              if (!started) {
                started = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await ref.read(profileServiceProvider).deleteUserData(
                      onProgress: (p) {
                        setState(() {
                          progress = p;
                        });
                      },
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext); // Close progress dialog
                      _clearAllUserDataAndNavigate(context, ref);
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e')),
                      );
                    }
                  }
                });
              }
              
              return AlertDialog(
                backgroundColor: AppColors.surface,
                title: Text(
                  context.l10n('deleting_account_progress') ?? 'Hesap ve veriler siliniyor...',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n('do_not_close_app_warning') ?? 'Lütfen bu ekranı kapatmayın veya geri tuşuna basmayın.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSupportCard(ThemeData theme) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Text(context.l10n('support_card_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n('support_card_desc'),
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => launchUrl(Uri.parse('mailto:seyfullahejderha0@gmail.com')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.withOpacity(0.1)),
                    child: Text(context.l10n('send_email_btn'), style: const TextStyle(color: Colors.blueAccent)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(UserProfile? profile) {
    final firstNameCtrl = TextEditingController(text: profile?.firstName ?? '');
    final lastNameCtrl = TextEditingController(text: profile?.lastName ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(context.l10n('edit_profile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameCtrl,
              decoration: InputDecoration(labelText: context.l10n('first_name_label')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastNameCtrl,
              decoration: InputDecoration(labelText: context.l10n('last_name_label')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (firstNameCtrl.text.isNotEmpty && lastNameCtrl.text.isNotEmpty) {
                await ref.read(profileServiceProvider).updateProfile(
                  firstName: firstNameCtrl.text,
                  lastName: lastNameCtrl.text,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(context.l10n('save')),
          ),
        ],
      ),
    );
  }
  Widget _buildDeveloperSupportCard(ThemeData theme, SubscriptionData? sub) {
    if (sub == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orangeAccent.withOpacity(0.1), Colors.redAccent.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
          const SizedBox(height: 8),
          Text(
            context.l10n('support_dev_title'),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n('support_dev_desc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: sub.isSupporter ? null : () async {
              final iap = ref.read(iapServiceProvider);
              if (iap.isStoreAvailable) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                );
                try {
                  await iap.buyProduct(IapService.developerSupport);
                } catch (e) {
                  debugPrint("Developer Support Purchase Error: $e");
                  if (mounted) {
                    UIHelpers.showErrorSnackBar(
                      context,
                      Localizations.localeOf(context).languageCode == 'tr'
                          ? 'Ödeme işlemi başlatılamadı: $e'
                          : 'Could not initiate payment: $e',
                    );
                  }
                } finally {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              } else {
                if (kDebugMode || kProfileMode) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                  await ref.read(subscriptionServiceProvider).handlePurchaseSuccess(IapService.developerSupport);
                  if (mounted) {
                    Navigator.pop(context);
                    UIHelpers.showSuccessSnackBar(context, context.l10n('support_success_msg'));
                  }
                } else {
                  UIHelpers.showErrorSnackBar(
                    context,
                    Localizations.localeOf(context).languageCode == 'tr'
                        ? 'Mağazaya bağlanılamadı. Lütfen daha sonra tekrar deneyin.'
                        : 'Failed to connect to the store. Please try again later.',
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: sub.isSupporter ? Colors.grey : Colors.orangeAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(sub.isSupporter ? context.l10n('already_supported') : context.l10n('support_now')),
                if (!sub.isSupporter)
                  Text(
                    ref.read(iapServiceProvider).getPrice(IapService.developerSupport, Localizations.localeOf(context).languageCode == 'tr' ? '₺29,99' : '\$1.99'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white.withOpacity(0.8)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareAppCard(ThemeData theme, AsyncValue<AppConfig> configAsync) {
    final config = configAsync.value;
    final playStoreLink = config?.playStoreUrl ?? AppConstants.playStoreUrl;
    final appStoreLink = config?.appStoreUrl ?? AppConstants.appStoreUrl;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.share_outlined, color: Colors.greenAccent),
                const SizedBox(width: 12),
                Text(
                  context.l10n('share_app_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n('share_app_desc'),
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final shareText = context.l10n('share_app_text')
                        .replaceAll('{play_store_link}', playStoreLink)
                        .replaceAll('{app_store_link}', appStoreLink);
                      Share.share(shareText);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.1),
                    ),
                    icon: const Icon(Icons.send_outlined, color: Colors.greenAccent, size: 18),
                    label: Text(
                      context.l10n('share_app_btn'),
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportProgressDialog(BuildContext context, ValueNotifier<ReportProgressState> progressNotifier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<ReportProgressState>(
          valueListenable: progressNotifier,
          builder: (context, state, child) {
            final percentage = (state.progress * 100).toInt();
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n('report_generating') ?? 'Rapor Hazırlanıyor',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.status,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: state.progress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "%$percentage",
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class ReportProgressState {
  final double progress;
  final String status;
  ReportProgressState(this.progress, this.status);
}

