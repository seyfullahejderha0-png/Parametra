import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/glass_card.dart';
import '../../auth/services/auth_service.dart';
import '../models/family_models.dart';
import '../services/family_service.dart';

class FamilyManagementScreen extends ConsumerStatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  ConsumerState<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends ConsumerState<FamilyManagementScreen> {
  final _emailController = TextEditingController();
  final _uidController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _spaceNameController = TextEditingController();
  MemberRole _selectedRole = MemberRole.member;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _uidController.dispose();
    _inviteCodeController.dispose();
    _spaceNameController.dispose();
    super.dispose();
  }

  /// Modül ID'sini aktif dil bilgisiyle yerelleştirir.
  String _moduleLabel(BuildContext ctx, String moduleId) {
    final isTurkish = Localizations.localeOf(ctx).languageCode == 'tr';
    const trMap = {
      'finance': 'FİNANS',
      'debts': 'BORÇLAR',
      'goals': 'HEDEFLER',
      'health': 'SAĞLIK & SPOR',
      'notes': 'NOTLAR',
      'reminders': 'HATIRLATICILAR',
      'reports': 'RAPORLAR',
    };
    const enMap = {
      'finance': 'FINANCE',
      'debts': 'DEBTS',
      'goals': 'GOALS',
      'health': 'HEALTH & SPORT',
      'notes': 'NOTES',
      'reminders': 'REMINDERS',
      'reports': 'REPORTS',
    };
    return (isTurkish ? trMap[moduleId] : enMap[moduleId]) ?? moduleId.toUpperCase();
  }

  void _showCreateSpaceDialog() {
    _spaceNameController.clear();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.l10n('create_shared_space') ?? 'Yeni Ortak Alan Oluştur', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: _spaceNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: context.l10n('space_name_label') ?? 'Alan Adı (Örn: Yılmaz Ailesi)',
            labelStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(context.l10n('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final name = _spaceNameController.text.trim();
              if (name.isEmpty) return;
              // Önce dialog'u kapat, sonra yükleme başlat
              Navigator.pop(dialogCtx);
              if (!mounted) return;
              setState(() => _isLoading = true);
              try {
                final newSpace = await ref.read(familyServiceProvider).createSharedSpace(name);
                if (!mounted) return;
                ref.read(activeSharedSpaceIdProvider.notifier).state = newSpace.id;
                ref.read(workspaceTypeProvider.notifier).state = WorkspaceType.shared;
                UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
              } catch (e) {
                if (mounted) UIHelpers.showErrorSnackBar(context, 'Alan oluşturulamadı: $e');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text(context.l10n('create_btn') ?? 'Oluştur', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(String spaceId) {
    _emailController.clear();
    _uidController.clear();
    _selectedRole = MemberRole.member;

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(context.l10n('add_new_member') ?? 'Yeni Üye Davet Et', style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  indicatorColor: Colors.amber,
                  labelColor: Colors.amber,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: context.l10n('email_invite') ?? 'E-posta ile'),
                    Tab(text: context.l10n('uid_invite') ?? 'UID ile'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: TabBarView(
                    children: [
                      Center(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.l10n('email_label') ?? 'E-posta Adresi',
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.amber),
                          ),
                        ),
                      ),
                      Center(
                        child: TextField(
                          controller: _uidController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.l10n('uid_label') ?? 'Kullanıcı UID',
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            prefixIcon: const Icon(Icons.perm_identity, color: Colors.amber),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MemberRole>(
                  value: _selectedRole,
                  dropdownColor: const Color(0xFF1E293B),
                  decoration: InputDecoration(
                    labelText: context.l10n('role_label') ?? 'Rol Seçimi',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.amber),
                  ),
                  items: MemberRole.values.map((role) => DropdownMenuItem(
                    value: role, 
                    child: Text(role.name.toUpperCase(), style: const TextStyle(color: Colors.white))
                  )).toList(),
                  onChanged: (val) => setDialogState(() => _selectedRole = val!),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedRole == MemberRole.owner ? 'Tam yetkili yönetici.' :
                  _selectedRole == MemberRole.member ? 'Seçili modüllere kayıt girebilir.' : 'Sadece yetkili modülleri görüntüler.',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  final email = _emailController.text.trim();
                  final uid = _uidController.text.trim();
                  if (email.isEmpty && uid.isEmpty) return;

                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    if (email.isNotEmpty) {
                      await ref.read(familyServiceProvider).addMemberByEmail(spaceId, email, _selectedRole);
                    } else {
                      await ref.read(familyServiceProvider).addMemberByUid(spaceId, uid, _selectedRole);
                    }
                    if (mounted) UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                  } catch (e) {
                    if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: Text(context.l10n('invite_btn') ?? 'Davet Et', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinByCodeDialog() {
    _inviteCodeController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.l10n('join_by_code_title') ?? 'Davet Kodu ile Katıl', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: _inviteCodeController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: context.l10n('invite_code_label') ?? 'Davet Kodu (Örn: PAI-FAM-82XK91)',
            labelStyle: const TextStyle(color: Colors.white70, letterSpacing: 0, fontSize: 14, fontWeight: FontWeight.normal),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final code = _inviteCodeController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final spaceId = await ref.read(familyServiceProvider).requestJoinByInviteCode(code);
                if (mounted) {
                  ref.read(activeSharedSpaceIdProvider.notifier).state = spaceId;
                  ref.read(workspaceTypeProvider.notifier).state = WorkspaceType.shared;
                  UIHelpers.showSuccessSnackBar(context, 'Ortak alana başarıyla katıldınız!');
                }
              } catch (e) {
                if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text(context.l10n('join_btn') ?? 'Katıl', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showApproveRequestDialog(SharedSpace space, JoinRequest request) {
    MemberRole role = MemberRole.member;
    List<ModulePermission> permissions = [
      ModulePermission(moduleId: 'finance', canView: true, canEdit: true),
      ModulePermission(moduleId: 'debts', canView: true, canEdit: false),
      ModulePermission(moduleId: 'goals', canView: true, canEdit: true),
      ModulePermission(moduleId: 'health', canView: true, canEdit: false),
      ModulePermission(moduleId: 'notes', canView: false, canEdit: false),
      ModulePermission(moduleId: 'reminders', canView: true, canEdit: true),
      ModulePermission(moduleId: 'reports', canView: true, canEdit: false),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('${request.requesterEmail}\nKatılım İsteğini Onayla', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<MemberRole>(
                    value: role,
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: InputDecoration(
                      labelText: context.l10n('role_label') ?? 'Rol Seçimi',
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      prefixIcon: const Icon(Icons.badge_outlined, color: Colors.amber),
                    ),
                    items: MemberRole.values.map((r) => DropdownMenuItem(
                      value: r, 
                      child: Text(r.name.toUpperCase(), style: const TextStyle(color: Colors.white))
                    )).toList(),
                    onChanged: (val) => setDialogState(() => role = val!),
                  ),
                  const SizedBox(height: 20),
                  Text(context.l10n('permissions_label') ?? 'Modül Yetkileri', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: permissions.length,
                    itemBuilder: (context, index) {
                      final perm = permissions[index];
                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(_moduleLabel(context, perm.moduleId), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                              Column(
                                children: [
                                  const Text('Görüntüle', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                  Switch(
                                    value: perm.canView,
                                    activeColor: Colors.amber,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        permissions[index] = perm.copyWith(canView: val, canEdit: val ? perm.canEdit : false);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  const Text('Kayıt', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                  Switch(
                                    value: perm.canEdit,
                                    activeColor: Colors.amber,
                                    onChanged: perm.canView ? (val) {
                                      setDialogState(() {
                                        permissions[index] = perm.copyWith(canEdit: val);
                                      });
                                    } : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await ref.read(familyServiceProvider).respondToJoinRequest(space.id, request.id, true, role: role, permissions: permissions);
                  if (mounted) UIHelpers.showSuccessSnackBar(context, 'Kullanıcı alana başarıyla eklendi');
                } catch (e) {
                  if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
                } finally {
                  setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text('Kaydet ve Onayla', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionsDialog(SharedSpace space, SharedMember member, bool isMe) {
    final currentUser = ref.read(authStateProvider).value;
    final isOwner = space.ownerId == currentUser?.uid;

    List<ModulePermission> currentPermissions = List.from(member.permissions);
    MemberRole currentRole = member.role;
    HealthPrivacySettings currentHealthPrivacy = member.healthPrivacy;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(member.nameOrEmail, style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (member.displayName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(member.email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  if (isMe) ...[
                    Text(context.l10n('health_privacy_title') ?? 'Sağlık Verisi Paylaşımı', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(context.l10n('health_privacy_desc') ?? 'Sağlık verileriniz varsayılan olarak gizlidir. Ortak alanda paylaşmak istediğiniz modülleri açabilirsiniz.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Su Tüketimi', style: TextStyle(color: Colors.white, fontSize: 14)),
                            value: currentHealthPrivacy.shareWater,
                            activeColor: Colors.amber,
                            onChanged: (val) => setDialogState(() => currentHealthPrivacy = currentHealthPrivacy.copyWith(shareWater: val)),
                          ),
                          SwitchListTile(
                            title: const Text('Spor & Aktivite', style: TextStyle(color: Colors.white, fontSize: 14)),
                            value: currentHealthPrivacy.shareSport,
                            activeColor: Colors.amber,
                            onChanged: (val) => setDialogState(() => currentHealthPrivacy = currentHealthPrivacy.copyWith(shareSport: val)),
                          ),
                          SwitchListTile(
                            title: const Text('Sigara Takibi', style: TextStyle(color: Colors.white, fontSize: 14)),
                            value: currentHealthPrivacy.shareSmoking,
                            activeColor: Colors.amber,
                            onChanged: (val) => setDialogState(() => currentHealthPrivacy = currentHealthPrivacy.copyWith(shareSmoking: val)),
                          ),
                          SwitchListTile(
                            title: const Text('İlaç Rutini', style: TextStyle(color: Colors.white, fontSize: 14)),
                            value: currentHealthPrivacy.shareMedication,
                            activeColor: Colors.amber,
                            onChanged: (val) => setDialogState(() => currentHealthPrivacy = currentHealthPrivacy.copyWith(shareMedication: val)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Text(context.l10n('permissions_label') ?? 'Modül Yetkileri', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: currentPermissions.length,
                    itemBuilder: (context, index) {
                      final perm = currentPermissions[index];
                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(_moduleLabel(context, perm.moduleId), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                              Column(
                                children: [
                                  const Text('Görüntüle', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                  Switch(
                                    value: perm.canView,
                                    activeColor: Colors.amber,
                                    onChanged: isOwner ? (val) {
                                      setDialogState(() {
                                        currentPermissions[index] = perm.copyWith(canView: val, canEdit: val ? perm.canEdit : false);
                                      });
                                    } : null,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  const Text('Kayıt', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                  Switch(
                                    value: perm.canEdit,
                                    activeColor: Colors.amber,
                                    onChanged: (isOwner && perm.canView) ? (val) {
                                      setDialogState(() {
                                        currentPermissions[index] = perm.copyWith(canEdit: val);
                                      });
                                    } : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isOwner && member.uid != space.ownerId)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    await ref.read(familyServiceProvider).removeMember(space.id, member.uid);
                    if (mounted) UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                  } catch (e) {
                    if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                label: const Text('Üyeyi Çıkar', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n('cancel'))),
            if (isOwner || isMe)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    if (isOwner) {
                      await ref.read(familyServiceProvider).updateMemberPermissions(space.id, member.uid, currentPermissions, currentRole);
                    }
                    if (isMe) {
                      await ref.read(familyServiceProvider).updateHealthPrivacy(space.id, currentHealthPrivacy);
                    }
                    if (mounted) UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                  } catch (e) {
                    if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: Text(context.l10n('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacesAsync = ref.watch(sharedSpacesProvider);
    final activeSpaceId = ref.watch(activeSharedSpaceIdProvider);
    final workspaceType = ref.watch(workspaceTypeProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n('family_workspace') ?? 'Aile / Ortak Alan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined, color: Colors.amber),
            tooltip: context.l10n('join_by_code_title') ?? 'Davet Kodu ile Katıl',
            onPressed: _showJoinByCodeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add_business_outlined, color: Colors.amber),
            tooltip: context.l10n('create_shared_space') ?? 'Ortak Alan Oluştur',
            onPressed: _showCreateSpaceDialog,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : spacesAsync.when(
            data: (spaces) {
              if (spaces.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.family_restroom, size: 80, color: Colors.amber),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n('no_shared_space_title') ?? 'Henüz Bir Ortak Alan Yok',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n('no_shared_space_desc') ?? 'Aileniz veya ortaklarınızla bütçe, hedef ve notlarınızı anlık paylaşmak için yeni bir alan oluşturun.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _showJoinByCodeDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.qr_code),
                              label: Text(context.l10n('join_btn') ?? 'Koda Katıl', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _showCreateSpaceDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber, 
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.add),
                              label: Text(context.l10n('create_shared_space') ?? 'Alan Oluştur', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              final activeSpace = spaces.firstWhere((s) => s.id == activeSpaceId, orElse: () => spaces.first);
              if (activeSpaceId == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(activeSharedSpaceIdProvider.notifier).state = activeSpace.id;
                });
              }

              final isOwner = activeSpace.ownerId == currentUser?.uid;
              final pendingRequests = activeSpace.pendingRequests.where((r) => r.status == JoinRequestStatus.pending).toList();

              return Column(
                children: [
                  // Bekleyen İstekler Bildirim Barı (Sadece Owner görebilir)
                  if (isOwner && pendingRequests.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_active, color: Colors.amber),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${pendingRequests.length} Yeni Katılım İsteği', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 16)
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: pendingRequests.length,
                            itemBuilder: (context, index) {
                              final req = pendingRequests[index];
                              return Card(
                                color: Colors.black45,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(req.requesterEmail, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: const Text('Aile alanına katılmak istiyor', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.redAccent),
                                        onPressed: () async {
                                          setState(() => _isLoading = true);
                                          try {
                                            await ref.read(familyServiceProvider).respondToJoinRequest(activeSpace.id, req.id, false);
                                            if (mounted) UIHelpers.showSuccessSnackBar(context, 'İstek reddedildi');
                                          } catch (e) {
                                            if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
                                          } finally {
                                            setState(() => _isLoading = false);
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.greenAccent),
                                        onPressed: () => _showApproveRequestDialog(activeSpace, req),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  // Alan Seçimi, Davet Kodu ve Filtre Barı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      border: const Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspaces_outline, color: Colors.amber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: activeSpace.id,
                                  dropdownColor: const Color(0xFF1E293B),
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                                  items: spaces.map((s) => DropdownMenuItem(
                                    value: s.id, 
                                    child: Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))
                                  )).toList(),
                                  onChanged: (val) {
                                    if (val != null) ref.read(activeSharedSpaceIdProvider.notifier).state = val;
                                  },
                                ),
                              ),
                            ),
                            if (isOwner)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E293B),
                                      title: const Text('Alanı Sil', style: TextStyle(color: Colors.white)),
                                      content: const Text('Bu ortak alanı ve tüm üye bağlantılarını silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n('cancel'))),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true), 
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          child: const Text('Sil', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    setState(() => _isLoading = true);
                                    try {
                                      await ref.read(familyServiceProvider).deleteSharedSpace(activeSpace.id);
                                      ref.read(activeSharedSpaceIdProvider.notifier).state = null;
                                      ref.read(workspaceTypeProvider.notifier).state = WorkspaceType.personal;
                                      if (mounted) UIHelpers.showSuccessSnackBar(context, context.l10n('save_success'));
                                    } catch (e) {
                                      if (mounted) UIHelpers.showErrorSnackBar(context, '${context.l10n('error_label')}: $e');
                                    } finally {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Davet Kodu Barı
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.l10n('invite_code_label') ?? 'Davet Kodu', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                  const SizedBox(height: 2),
                                  Text(activeSpace.inviteCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 2)),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20, color: Colors.white70),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: activeSpace.inviteCode));
                                      UIHelpers.showSuccessSnackBar(context, 'Davet kodu panoya kopyalandı');
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share, size: 20, color: Colors.white70),
                                    onPressed: () {
                                      Share.share('Pai Aile / Ortak Alanına Katıl! Davet Kodum: ${activeSpace.inviteCode}\nUygulamayı indir ve Profil -> Aile / Ortak Alan -> Koda Katıl menüsünden bu kodu gir.');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Filtre Segmentleri (Kişisel, Ortak, Tümü)
                        SegmentedButton<WorkspaceType>(
                          segments: [
                            ButtonSegment(value: WorkspaceType.personal, label: Text(context.l10n('personal_filter') ?? 'Kişisel', style: const TextStyle(fontSize: 12))),
                            ButtonSegment(value: WorkspaceType.shared, label: Text(context.l10n('shared_filter') ?? 'Ortak', style: const TextStyle(fontSize: 12))),
                            ButtonSegment(value: WorkspaceType.all, label: Text(context.l10n('all_filter') ?? 'Tümü', style: const TextStyle(fontSize: 12))),
                          ],
                          selected: {workspaceType},
                          onSelectionChanged: (vals) {
                            ref.read(workspaceTypeProvider.notifier).state = vals.first;
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              return states.contains(WidgetState.selected) ? Colors.amber : Colors.transparent;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                              return states.contains(WidgetState.selected) ? Colors.black : Colors.white;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Üyeler Listesi Başlığı
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${context.l10n('members_label') ?? 'Üyeler'} (${activeSpace.members.length})', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)
                        ),
                        if (isOwner)
                          TextButton.icon(
                            onPressed: () => _showAddMemberDialog(activeSpace.id), 
                            icon: const Icon(Icons.person_add_alt_1, color: Colors.amber),
                            label: Text(context.l10n('add_member') ?? 'Üye Ekle', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),

                  // Üyeler Listesi
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: activeSpace.members.length,
                      itemBuilder: (context, index) {
                        final member = activeSpace.members[index];
                        final isMe = member.uid == currentUser?.uid;
                        final isMemberOwner = member.role == MemberRole.owner;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            onTap: (isOwner || isMe) ? () => _showPermissionsDialog(activeSpace, member, isMe) : null,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isMemberOwner ? Colors.amber.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                                  child: Icon(
                                    isMemberOwner ? Icons.workspace_premium : Icons.person,
                                    color: isMemberOwner ? Colors.amber : Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              member.nameOrEmail, 
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isMe ? Colors.amber : Colors.white),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isMe)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                              child: const Text('Sen', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        member.role.name.toUpperCase(), 
                                        style: TextStyle(fontSize: 12, color: isMemberOwner ? Colors.amberAccent : Colors.white54, fontWeight: FontWeight.bold)
                                      ),
                                      if (member.displayName.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          member.email,
                                          style: const TextStyle(fontSize: 11, color: Colors.white38),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isOwner || isMe)
                                  const Icon(Icons.chevron_right, color: Colors.white24),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('${context.l10n('error_label')}: $e')),
          ),
    );
  }
}
