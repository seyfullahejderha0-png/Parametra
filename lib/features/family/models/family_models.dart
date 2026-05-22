import 'package:flutter/foundation.dart';

enum MemberRole { owner, member, viewer }

enum WorkspaceType { personal, shared, all }

enum JoinRequestStatus { pending, approved, rejected }

class JoinRequest {
  final String id;
  final String spaceId;
  final String requesterUid;
  final String requesterEmail;
  final DateTime requestedAt;
  final JoinRequestStatus status;

  JoinRequest({
    required this.id,
    required this.spaceId,
    required this.requesterUid,
    required this.requesterEmail,
    required this.requestedAt,
    required this.status,
  });

  JoinRequest copyWith({
    String? id,
    String? spaceId,
    String? requesterUid,
    String? requesterEmail,
    DateTime? requestedAt,
    JoinRequestStatus? status,
  }) {
    return JoinRequest(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      requesterUid: requesterUid ?? this.requesterUid,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spaceId': spaceId,
      'requesterUid': requesterUid,
      'requesterEmail': requesterEmail,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      id: map['id'] ?? '',
      spaceId: map['spaceId'] ?? '',
      requesterUid: map['requesterUid'] ?? '',
      requesterEmail: map['requesterEmail'] ?? '',
      requestedAt: DateTime.parse(map['requestedAt'] ?? DateTime.now().toIso8601String()),
      status: JoinRequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => JoinRequestStatus.pending,
      ),
    );
  }
}

class HealthPrivacySettings {
  final bool shareWater;
  final bool shareSport;
  final bool shareSmoking;
  final bool shareMedication;

  HealthPrivacySettings({
    this.shareWater = false,
    this.shareSport = false,
    this.shareSmoking = false,
    this.shareMedication = false,
  });

  HealthPrivacySettings copyWith({
    bool? shareWater,
    bool? shareSport,
    bool? shareSmoking,
    bool? shareMedication,
  }) {
    return HealthPrivacySettings(
      shareWater: shareWater ?? this.shareWater,
      shareSport: shareSport ?? this.shareSport,
      shareSmoking: shareSmoking ?? this.shareSmoking,
      shareMedication: shareMedication ?? this.shareMedication,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shareWater': shareWater,
      'shareSport': shareSport,
      'shareSmoking': shareSmoking,
      'shareMedication': shareMedication,
    };
  }

  factory HealthPrivacySettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return HealthPrivacySettings();
    return HealthPrivacySettings(
      shareWater: map['shareWater'] ?? false,
      shareSport: map['shareSport'] ?? false,
      shareSmoking: map['shareSmoking'] ?? false,
      shareMedication: map['shareMedication'] ?? false,
    );
  }
}

class ModulePermission {
  final String moduleId; // finance, debts, goals, health, notes, reminders, reports
  final bool canView;
  final bool canEdit;

  ModulePermission({
    required this.moduleId,
    required this.canView,
    required this.canEdit,
  });

  ModulePermission copyWith({
    String? moduleId,
    bool? canView,
    bool? canEdit,
  }) {
    return ModulePermission(
      moduleId: moduleId ?? this.moduleId,
      canView: canView ?? this.canView,
      canEdit: canEdit ?? this.canEdit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moduleId': moduleId,
      'canView': canView,
      'canEdit': canEdit,
    };
  }

  factory ModulePermission.fromMap(Map<String, dynamic> map) {
    return ModulePermission(
      moduleId: map['moduleId'] ?? '',
      canView: map['canView'] ?? true,
      canEdit: map['canEdit'] ?? false,
    );
  }
}

class SharedMember {
  final String uid;
  final String email;
  final String displayName; // Ad Soyad
  final MemberRole role;
  final DateTime joinedAt;
  final List<ModulePermission> permissions;
  final HealthPrivacySettings healthPrivacy;

  SharedMember({
    required this.uid,
    required this.email,
    this.displayName = '',
    required this.role,
    required this.joinedAt,
    required this.permissions,
    required this.healthPrivacy,
  });

  /// Üyenin gösterim adı: ad soyad varsa onu, yoksa email'in @ öncesini döndürür.
  String get nameOrEmail {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    return email.contains('@') ? email.split('@').first : email;
  }

  SharedMember copyWith({
    String? uid,
    String? email,
    String? displayName,
    MemberRole? role,
    DateTime? joinedAt,
    List<ModulePermission>? permissions,
    HealthPrivacySettings? healthPrivacy,
  }) {
    return SharedMember(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      permissions: permissions ?? this.permissions,
      healthPrivacy: healthPrivacy ?? this.healthPrivacy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
      'permissions': permissions.map((p) => p.toMap()).toList(),
      'healthPrivacy': healthPrivacy.toMap(),
    };
  }

  factory SharedMember.fromMap(Map<String, dynamic> map) {
    return SharedMember(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: MemberRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => MemberRole.viewer,
      ),
      joinedAt: DateTime.parse(map['joinedAt'] ?? DateTime.now().toIso8601String()),
      permissions: (map['permissions'] as List<dynamic>?)
              ?.map((p) => ModulePermission.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      healthPrivacy: HealthPrivacySettings.fromMap(map['healthPrivacy'] as Map<String, dynamic>?),
    );
  }
}

class SharedSpace {
  final String id;
  final String ownerId;
  final String name;
  final DateTime createdAt;
  final String inviteCode;
  final List<SharedMember> members;
  final List<JoinRequest> pendingRequests;
  final List<String> memberUids;

  SharedSpace({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.createdAt,
    required this.inviteCode,
    required this.members,
    required this.pendingRequests,
    required this.memberUids,
  });

  SharedSpace copyWith({
    String? id,
    String? ownerId,
    String? name,
    DateTime? createdAt,
    String? inviteCode,
    List<SharedMember>? members,
    List<JoinRequest>? pendingRequests,
    List<String>? memberUids,
  }) {
    return SharedSpace(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      memberUids: memberUids ?? this.memberUids,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'inviteCode': inviteCode,
      'members': members.map((m) => m.toMap()).toList(),
      'pendingRequests': pendingRequests.map((r) => r.toMap()).toList(),
      'memberUids': memberUids,
    };
  }

  factory SharedSpace.fromMap(Map<String, dynamic> map) {
    final membersList = (map['members'] as List<dynamic>?)
            ?.map((m) => SharedMember.fromMap(m as Map<String, dynamic>))
            .toList() ??
        [];
    return SharedSpace(
      id: map['id'] ?? '',
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      inviteCode: map['inviteCode'] ?? '',
      members: membersList,
      pendingRequests: (map['pendingRequests'] as List<dynamic>?)
              ?.map((r) => JoinRequest.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
      memberUids: (map['memberUids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? membersList.map((m) => m.uid).toList(),
    );
  }
}
