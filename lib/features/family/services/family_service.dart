import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/services/auth_service.dart';
import '../models/family_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../life_timeline/services/life_timeline_service.dart';

class WorkspaceTypeNotifier extends Notifier<WorkspaceType> {
  @override
  WorkspaceType build() {
    ref.watch(authStateProvider);
    _loadState();
    return WorkspaceType.personal;
  }

  Future<void> _loadState() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final valueString = prefs.getString('${user.uid}_last_workspace_type');
    if (valueString != null) {
      final type = WorkspaceType.values.firstWhere(
        (e) => e.name == valueString,
        orElse: () => WorkspaceType.personal,
      );
      if (state != type) {
        state = type;
      }
    }
  }

  @override
  set state(WorkspaceType value) {
    super.state = value;
    _saveState(value);
  }

  Future<void> _saveState(WorkspaceType type) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${user.uid}_last_workspace_type', type.name);
  }
}

final workspaceTypeProvider = NotifierProvider<WorkspaceTypeNotifier, WorkspaceType>(WorkspaceTypeNotifier.new);

class ActiveSharedSpaceIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authStateProvider);
    _loadState();
    return null;
  }

  Future<void> _loadState() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final spaceId = prefs.getString('${user.uid}_last_active_space_id');
    if (spaceId != null) {
      if (state != spaceId) {
        state = spaceId;
      }
    }
  }

  @override
  set state(String? value) {
    super.state = value;
    _saveState(value);
  }

  Future<void> _saveState(String? spaceId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (spaceId == null) {
      await prefs.remove('${user.uid}_last_active_space_id');
    } else {
      await prefs.setString('${user.uid}_last_active_space_id', spaceId);
    }
  }
}

final activeSharedSpaceIdProvider = NotifierProvider<ActiveSharedSpaceIdNotifier, String?>(ActiveSharedSpaceIdNotifier.new);

final workspaceUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final workspaceType = ref.watch(workspaceTypeProvider);
  final activeSpaceId = ref.watch(activeSharedSpaceIdProvider);

  if (workspaceType == WorkspaceType.shared && activeSpaceId != null) {
    final spacesAsync = ref.watch(sharedSpacesProvider);
    return spacesAsync.when(
      data: (spaces) {
        try {
          final activeSpace = spaces.firstWhere(
            (s) => s.id == activeSpaceId,
          );
          return activeSpace.ownerId;
        } catch (_) {
          return user?.uid;
        }
      },
      loading: () => user?.uid,
      error: (_, __) => user?.uid,
    );
  }

  return user?.uid;
});

final sharedWorkspaceOwnerIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final activeSpaceId = ref.watch(activeSharedSpaceIdProvider);
  if (activeSpaceId == null) return null;

  final spacesAsync = ref.watch(sharedSpacesProvider);
  return spacesAsync.when(
    data: (spaces) {
      try {
        final activeSpace = spaces.firstWhere((s) => s.id == activeSpaceId);
        if (activeSpace.ownerId == user?.uid) return null;
        return activeSpace.ownerId;
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final familyServiceProvider = Provider((ref) {
  final user = ref.watch(authStateProvider).value;
  return FamilyService(user?.uid, ref);
});

final sharedSpacesProvider = StreamProvider<List<SharedSpace>>((ref) {
  final service = ref.watch(familyServiceProvider);
  return service.getSharedSpaces();
});

class FamilyService {
  final String? userId;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FamilyService(this.userId, this._ref);

  CollectionReference get _spacesColl => _firestore.collection('users').doc(userId ?? 'anonymous').collection('shared_spaces');

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final randomPart = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    return 'PAI-$randomPart';
  }

  Future<DocumentReference> _getSpaceDocRef(String spaceId) async {
    final localDoc = _spacesColl.doc(spaceId);
    final localSnap = await localDoc.get();
    if (localSnap.exists) return localDoc;

    final query = await _firestore.collectionGroup('shared_spaces').where('id', isEqualTo: spaceId).limit(1).get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.reference;
    }
    
    return localDoc;
  }

  Future<void> _updateSpaceInAllLocations(SharedSpace updatedSpace, {String? inviteCode}) async {
    final batch = _firestore.batch();
    for (var uid in updatedSpace.memberUids) {
      final ref = _firestore.collection('users').doc(uid).collection('shared_spaces').doc(updatedSpace.id);
      batch.set(ref, updatedSpace.toMap());
    }

    // Write sharing metadata for owner
    final ownerSharingRef = _firestore.collection('users').doc(updatedSpace.ownerId).collection('meta').doc('sharing');
    final Map<String, dynamic> sharingData = {
      'allowedUids': updatedSpace.memberUids,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (inviteCode != null) {
      sharingData['inviteCode'] = inviteCode;
    }
    batch.set(ownerSharingRef, sharingData, SetOptions(merge: true));

    await batch.commit();
  }

  Stream<List<SharedSpace>> getSharedSpaces() {
    if (userId == null) return Stream.value([]);
    
    // Doğrudan kullanıcının kendi 'shared_spaces' alt koleksiyonunu dinliyoruz.
    // Batch sync mimarimiz sayesinde tüm üyelerin kendi koleksiyonlarında güncel veri kopyaları bulunur.
    // Bu sayede collectionGroup indeks hatası ('hata oluştu') tamamen önlenmiş olur.
    return _spacesColl.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SharedSpace.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<SharedSpace> createSharedSpace(String name) async {
    if (userId == null) throw Exception('Kullanıcı girişi yapılmamış.');

    final spaceId = 'space_${const Uuid().v4()}';
    final inviteCode = _generateInviteCode();

    final defaultPermissions = [
      ModulePermission(moduleId: 'finance', canView: true, canEdit: true),
      ModulePermission(moduleId: 'debts', canView: true, canEdit: false),
      ModulePermission(moduleId: 'goals', canView: true, canEdit: true),
      ModulePermission(moduleId: 'health', canView: true, canEdit: false),
      ModulePermission(moduleId: 'notes', canView: false, canEdit: false),
      ModulePermission(moduleId: 'reminders', canView: true, canEdit: true),
      ModulePermission(moduleId: 'reports', canView: true, canEdit: false),
    ];

    // Owner'ın profilinden ad soyad çek
    String ownerDisplayName = '';
    try {
      final ownerDoc = await _firestore.collection('users').doc(userId).get();
      if (ownerDoc.exists) {
        final d = ownerDoc.data() as Map<String, dynamic>;
        final first = d['firstName'] ?? '';
        final last = d['lastName'] ?? '';
        ownerDisplayName = '$first $last'.trim();
      }
    } catch (_) {}

    final ownerMember = SharedMember(
      uid: userId!,
      email: _ref.read(authStateProvider).value?.email ?? 'owner@family.com',
      displayName: ownerDisplayName,
      role: MemberRole.owner,
      joinedAt: DateTime.now(),
      permissions: defaultPermissions.map((p) => p.copyWith(canView: true, canEdit: true)).toList(),
      healthPrivacy: HealthPrivacySettings(shareWater: true, shareSport: true, shareSmoking: true, shareMedication: true),
    );

    final newSpace = SharedSpace(
      id: spaceId,
      ownerId: userId!,
      name: name,
      createdAt: DateTime.now(),
      inviteCode: inviteCode,
      members: [ownerMember],
      pendingRequests: [],
      memberUids: [userId!],
    );

    // invite_codes küresel koleksiyonuna da davet kodunu yazalım (hızlı ve güvenli davet için)
    final inviteData = {
      'spaceId': spaceId,
      'ownerId': userId!,
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    // Önce tüm üyelerin (şu an sadece sahibinin) konumlarına yaz (bu kesinlikle başarılı olmalı)
    await _updateSpaceInAllLocations(newSpace);
    
    // invite_codes koleksiyonuna ayrı yazalım, hata olsa bile alan oluşturulsun
    try {
      await _firestore.collection('invite_codes').doc(inviteCode).set(inviteData);
    } catch (e) {
      // invite_codes'a yazılamazsa sadece loglayıp devam et
      // Davet kodu yine de çalışır (fallback collectionGroup araması mevcut)
      // ignore: avoid_print
      print('[FamilyService] invite_codes yazma hatası (önemli değil): $e');
    }

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'family',
        title: 'Ortak Alan Aktif Edildi 👨‍👩‍👧',
        description: '\'$name\' isimli ortak çalışma alanı oluşturuldu!',
        icon: '👨‍👩‍👧',
        metadata: {
          'spaceId': spaceId,
          'name': name,
        },
        eventType: 'milestone',
      );
    } catch (_) {}

    return newSpace;
  }

  Future<void> _addMemberInternal(String spaceId, String targetUid, String email, MemberRole role, {List<ModulePermission>? customPermissions}) async {
    final docRef = await _getSpaceDocRef(spaceId);
    final spaceDoc = await docRef.get();
    if (!spaceDoc.exists) throw Exception('Çalışma alanı bulunamadı.');

    final space = SharedSpace.fromMap(spaceDoc.data() as Map<String, dynamic>);
    
    if (space.members.any((m) => m.uid == targetUid)) {
      throw Exception('Bu kullanıcı zaten çalışma alanına üye.');
    }

    final defaultPermissions = customPermissions ?? [
      ModulePermission(moduleId: 'finance', canView: true, canEdit: role != MemberRole.viewer),
      ModulePermission(moduleId: 'debts', canView: true, canEdit: false),
      ModulePermission(moduleId: 'goals', canView: true, canEdit: role != MemberRole.viewer),
      ModulePermission(moduleId: 'health', canView: true, canEdit: false),
      ModulePermission(moduleId: 'notes', canView: false, canEdit: false),
      ModulePermission(moduleId: 'reminders', canView: true, canEdit: role != MemberRole.viewer),
      ModulePermission(moduleId: 'reports', canView: true, canEdit: false),
    ];

    // Yeni üyenin profilinden ad soyad çek
    String memberDisplayName = '';
    try {
      final memberDoc = await _firestore.collection('users').doc(targetUid).get();
      if (memberDoc.exists) {
        final d = memberDoc.data() as Map<String, dynamic>;
        final first = d['firstName'] ?? '';
        final last = d['lastName'] ?? '';
        memberDisplayName = '$first $last'.trim();
      }
    } catch (_) {}

    final newMember = SharedMember(
      uid: targetUid,
      email: email,
      displayName: memberDisplayName,
      role: role,
      joinedAt: DateTime.now(),
      permissions: defaultPermissions,
      healthPrivacy: HealthPrivacySettings(), // Varsayılan kapalı
    );

    final updatedMembers = List<SharedMember>.from(space.members)..add(newMember);
    final updatedUids = List<String>.from(space.memberUids)..add(targetUid);
    final updatedSpace = space.copyWith(members: updatedMembers, memberUids: updatedUids);

    await _updateSpaceInAllLocations(updatedSpace);
  }

  Future<void> addMemberByEmail(String spaceId, String email, MemberRole role) async {
    if (userId == null) throw Exception('Kullanıcı girişi yapılmamış.');

    final userQuery = await _firestore.collection('users').where('email', isEqualTo: email.trim()).limit(1).get();
    if (userQuery.docs.isEmpty) {
      throw Exception('Bu e-posta adresine kayıtlı bir kullanıcı bulunamadı.');
    }

    final targetUserDoc = userQuery.docs.first;
    await _addMemberInternal(spaceId, targetUserDoc.id, email.trim(), role);
  }

  Future<void> addMemberByUid(String spaceId, String targetUid, MemberRole role) async {
    if (userId == null) throw Exception('Kullanıcı girişi yapılmamış.');

    final userDoc = await _firestore.collection('users').doc(targetUid.trim()).get();
    if (!userDoc.exists) {
      throw Exception('Bu UID adresine kayıtlı bir kullanıcı bulunamadı.');
    }

    final email = userDoc.data()?['email'] ?? 'user_${targetUid.substring(0, 5)}@family.com';
    await _addMemberInternal(spaceId, targetUid.trim(), email, role);
  }

  Future<String> requestJoinByInviteCode(String code) async {
    if (userId == null) throw Exception('Kullanıcı girişi yapılmamış.');

    String cleanCode = code.trim().toUpperCase();
    if (cleanCode.startsWith('PAI-FAM-')) {
      cleanCode = cleanCode.replaceFirst('PAI-FAM-', '');
    }

    // 1. Küresel invite_codes koleksiyonundan sorgula (Daha güvenli ve index gerektirmez)
    var inviteDoc = await _firestore.collection('invite_codes').doc(cleanCode).get();
    
    // Girdi bulunamadıysa ve PAI- ile başlamıyorsa, ön ek ekleyerek tekrar aramayı deneyelim (kullanıcı dostu deneyim)
    if (!inviteDoc.exists && !cleanCode.startsWith('PAI-')) {
      final prependedCode = 'PAI-$cleanCode';
      final prependedDoc = await _firestore.collection('invite_codes').doc(prependedCode).get();
      if (prependedDoc.exists) {
        inviteDoc = prependedDoc;
        cleanCode = prependedCode;
      }
    }
    
    String targetSpaceId;
    String targetOwnerId;
    
    if (inviteDoc.exists) {
      final data = inviteDoc.data()!;
      targetSpaceId = data['spaceId'] as String;
      targetOwnerId = data['ownerId'] as String;
    } else {
      // Geriye dönük uyumluluk için eski collectionGroup yöntemini deneyelim
      final spaceQuery = await _firestore.collectionGroup('shared_spaces').where('inviteCode', isEqualTo: cleanCode).limit(1).get();
      if (spaceQuery.docs.isEmpty) {
        throw Exception('Geçersiz davet kodu. Lütfen kodu kontrol edin.');
      }
      final spaceDoc = spaceQuery.docs.first;
      targetSpaceId = spaceDoc.id;
      final pathSegments = spaceDoc.reference.path.split('/');
      if (pathSegments.length >= 2 && pathSegments[0] == 'users') {
        targetOwnerId = pathSegments[1];
      } else {
        throw Exception('Geçersiz çalışma alanı konumu.');
      }
    }

    // 2. Doğrudan alan sahibinin dökümanına erişelim
    final spaceDocRef = _firestore.collection('users').doc(targetOwnerId).collection('shared_spaces').doc(targetSpaceId);
    final spaceDoc = await spaceDocRef.get();
    
    if (!spaceDoc.exists) {
      throw Exception('Çalışma alanı bulunamadı.');
    }

    final space = SharedSpace.fromMap(spaceDoc.data() as Map<String, dynamic>);
    
    if (space.members.any((m) => m.uid == userId)) {
      throw Exception('Zaten bu çalışma alanına üyesiniz.');
    }

    final currentUser = _ref.read(authStateProvider).value;
    
    // Eşlerin doğrudan bağlanması için davet kodu girildiğinde doğrudan üye olarak ekliyoruz
    String memberDisplayName = '';
    try {
      final memberDoc = await _firestore.collection('users').doc(userId).get();
      if (memberDoc.exists) {
        final d = memberDoc.data() as Map<String, dynamic>;
        final first = d['firstName'] ?? '';
        final last = d['lastName'] ?? '';
        memberDisplayName = '$first $last'.trim();
      }
    } catch (_) {}

    final defaultPermissions = [
      ModulePermission(moduleId: 'finance', canView: true, canEdit: true),
      ModulePermission(moduleId: 'debts', canView: true, canEdit: false),
      ModulePermission(moduleId: 'goals', canView: true, canEdit: true),
      ModulePermission(moduleId: 'health', canView: true, canEdit: false),
      ModulePermission(moduleId: 'notes', canView: false, canEdit: false),
      ModulePermission(moduleId: 'reminders', canView: true, canEdit: true),
      ModulePermission(moduleId: 'reports', canView: true, canEdit: false),
    ];

    final newMember = SharedMember(
      uid: userId!,
      email: currentUser?.email ?? 'invited@family.com',
      displayName: memberDisplayName,
      role: MemberRole.member,
      joinedAt: DateTime.now(),
      permissions: defaultPermissions,
      healthPrivacy: HealthPrivacySettings(),
    );

    final updatedMembers = List<SharedMember>.from(space.members)..add(newMember);
    final updatedUids = List<String>.from(space.memberUids)..add(userId!);
    final updatedSpace = space.copyWith(members: updatedMembers, memberUids: updatedUids);

    // Tüm üyelerin konumlarına batch ile yazıyoruz
    await _updateSpaceInAllLocations(updatedSpace, inviteCode: cleanCode);
    return targetSpaceId;
  }

  Future<void> respondToJoinRequest(String spaceId, String requestId, bool isApproved, {MemberRole? role, List<ModulePermission>? permissions}) async {
    final docRef = await _getSpaceDocRef(spaceId);
    final spaceDoc = await docRef.get();
    if (!spaceDoc.exists) throw Exception('Çalışma alanı bulunamadı.');

    final space = SharedSpace.fromMap(spaceDoc.data() as Map<String, dynamic>);
    final targetRequest = space.pendingRequests.firstWhere((r) => r.id == requestId);

    // İsteği listeden çıkar
    final updatedRequests = space.pendingRequests.where((r) => r.id != requestId).toList();
    final updatedSpace = space.copyWith(pendingRequests: updatedRequests);
    await _updateSpaceInAllLocations(updatedSpace);

    if (isApproved) {
      // Üyeyi ekle
      await _addMemberInternal(
        spaceId, 
        targetRequest.requesterUid, 
        targetRequest.requesterEmail, 
        role ?? MemberRole.member,
        customPermissions: permissions,
      );
    }
  }

  Future<void> resetInviteCode(String spaceId) async {
    return;
  }

  Future<void> updateMemberPermissions(String spaceId, String targetUid, List<ModulePermission> permissions, MemberRole role) async {
    final docRef = await _getSpaceDocRef(spaceId);
    final spaceDoc = await docRef.get();
    if (!spaceDoc.exists) throw Exception('Çalışma alanı bulunamadı.');

    final space = SharedSpace.fromMap(spaceDoc.data() as Map<String, dynamic>);
    final updatedMembers = space.members.map((m) {
      if (m.uid == targetUid) {
        return m.copyWith(permissions: permissions, role: role);
      }
      return m;
    }).toList();

    final updatedSpace = space.copyWith(members: updatedMembers);
    await _updateSpaceInAllLocations(updatedSpace);
  }

  Future<void> updateHealthPrivacy(String spaceId, HealthPrivacySettings privacy) async {
    if (userId == null) return;
    final docRef = await _getSpaceDocRef(spaceId);
    final spaceDoc = await docRef.get();
    if (!spaceDoc.exists) return;

    final space = SharedSpace.fromMap(spaceDoc.data() as Map<String, dynamic>);
    final updatedMembers = space.members.map((m) {
      if (m.uid == userId) {
        return m.copyWith(healthPrivacy: privacy);
      }
      return m;
    }).toList();

    final updatedSpace = space.copyWith(members: updatedMembers);
    await _updateSpaceInAllLocations(updatedSpace);
  }

  Future<void> removeMember(String spaceId, String targetUid) async {
    final docRef = await _getSpaceDocRef(spaceId);
    final spaceDoc = await docRef.get();
    if (!spaceDoc.exists) throw Exception('Çalışma alanı bulunamadı.');

    final space = SharedSpace.fromMap(spaceDoc.data() as Map<String, dynamic>);
    if (space.ownerId == targetUid) {
      throw Exception('Alan sahibi (Owner) alandan çıkarılamaz.');
    }

    final updatedMembers = space.members.where((m) => m.uid != targetUid).toList();
    final updatedUids = space.memberUids.where((u) => u != targetUid).toList();
    
    final updatedSpace = space.copyWith(members: updatedMembers, memberUids: updatedUids);
    
    // 1. Tüm kalan üyelerin dökümanlarını güncelle
    await _updateSpaceInAllLocations(updatedSpace);
    
    // 2. Çıkarılan üyenin kendi altındaki dökümanı sil
    await _firestore.collection('users').doc(targetUid).collection('shared_spaces').doc(spaceId).delete();
  }

  Future<void> deleteSharedSpace(String spaceId) async {
    final docRef = await _getSpaceDocRef(spaceId);
    final spaceDoc = await docRef.get();
    if (!spaceDoc.exists) return;

    final space = SharedSpace.fromMap(spaceDoc.data() as Map<String, dynamic>);
    if (space.ownerId != userId) {
      throw Exception('Sadece alan sahibi bu alanı silebilir.');
    }

    // 1. Tüm üyelerin altındaki dökümanları sil
    final batch = _firestore.batch();
    for (var uid in space.memberUids) {
      final ref = _firestore.collection('users').doc(uid).collection('shared_spaces').doc(spaceId);
      batch.delete(ref);
    }
    
    // 2. Küresel davet kodunu sil
    final inviteRef = _firestore.collection('invite_codes').doc(space.inviteCode);
    batch.delete(inviteRef);

    // 3. Sharing metadata'sını temizle (sadece sahibini bırak)
    final ownerSharingRef = _firestore.collection('users').doc(space.ownerId).collection('meta').doc('sharing');
    batch.set(ownerSharingRef, {
      'allowedUids': [space.ownerId],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }
}
