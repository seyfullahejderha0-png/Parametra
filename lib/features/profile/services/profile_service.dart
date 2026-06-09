import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';

final profileServiceProvider = Provider((ref) {
  final authState = ref.watch(authStateProvider).value;
  return ProfileService(ref, authState?.uid, authState?.email);
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final service = ref.watch(profileServiceProvider);
  return service.getProfile();
});

class UserProfile {
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String? email;
  final bool hasAcceptedPrivacy;
  final String preferredCurrency;
  final bool notifyFinance;
  final bool notifyGoals;
  final bool notifyNotes;
  final bool notifyReminders;
  final bool notifyHealth;
  final DateTime? lastLogin;
  final String? platform;

  UserProfile({
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.email,
    this.hasAcceptedPrivacy = false,
    this.preferredCurrency = 'TRY',
    this.notifyFinance = true,
    this.notifyGoals = true,
    this.notifyNotes = true,
    this.notifyReminders = true,
    this.notifyHealth = false,
    this.lastLogin,
    this.platform,
  });

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'email': email,
      'hasAcceptedPrivacy': hasAcceptedPrivacy,
      'preferredCurrency': preferredCurrency,
      'notifyFinance': notifyFinance,
      'notifyGoals': notifyGoals,
      'notifyNotes': notifyNotes,
      'notifyReminders': notifyReminders,
      'notifyHealth': notifyHealth,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'platform': platform,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? lastLoginTime;
    if (map['lastLogin'] is Timestamp) {
      lastLoginTime = (map['lastLogin'] as Timestamp).toDate();
    }
    return UserProfile(
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      photoUrl: map['photoUrl'],
      email: map['email'],
      hasAcceptedPrivacy: map['hasAcceptedPrivacy'] ?? false,
      preferredCurrency: map['preferredCurrency'] ?? 'TRY',
      notifyFinance: map['notifyFinance'] ?? true,
      notifyGoals: map['notifyGoals'] ?? true,
      notifyNotes: map['notifyNotes'] ?? true,
      notifyReminders: map['notifyReminders'] ?? true,
      notifyHealth: map['notifyHealth'] ?? false,
      lastLogin: lastLoginTime,
      platform: map['platform'],
    );
  }
}

class ProfileService {
  final Ref _ref;
  final String? userId;
  final String? userEmail;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  ProfileService(this._ref, this.userId, this.userEmail);

  DocumentReference get _userDoc => _firestore.collection('users').doc(userId ?? 'anonymous');

  Stream<UserProfile?> getProfile() {
    if (userId == null) return Stream.value(null);
    return _userDoc.snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>;
      if (data['email'] == null && userEmail != null) {
        data['email'] = userEmail;
      }
      return UserProfile.fromMap(data);
    });
  }

  Future<void> updateProfile({required String firstName, required String lastName, String? photoUrl, String? preferredCurrency}) async {
    if (userId == null) return;
    await _userDoc.set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': userEmail,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (preferredCurrency != null) 'preferredCurrency': preferredCurrency,
    }, SetOptions(merge: true));
  }

  Future<void> updateCurrency(String currency) async {
    if (userId == null) return;
    await _userDoc.set({
      'preferredCurrency': currency,
    }, SetOptions(merge: true));
  }

  Future<void> recordUserActivity() async {
    if (userId == null) return;
    final platform = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Web');
    await _userDoc.set({
      'lastLogin': FieldValue.serverTimestamp(),
      'platform': platform,
    }, SetOptions(merge: true));
  }

  Future<void> updateNotificationPreference(String module, bool value) async {
    if (userId == null) return;
    String field;
    switch (module) {
      case 'finance':
        field = 'notifyFinance';
        break;
      case 'goals':
        field = 'notifyGoals';
        break;
      case 'notes':
        field = 'notifyNotes';
        break;
      case 'reminders':
        field = 'notifyReminders';
        break;
      case 'health':
        field = 'notifyHealth';
        break;
      default:
        return;
    }
    await _userDoc.set({
      field: value,
    }, SetOptions(merge: true));
  }

  Future<void> acceptPrivacy() async {
    if (userId == null) return;
    await _userDoc.set({
      'hasAcceptedPrivacy': true,
    }, SetOptions(merge: true));
  }

  Future<void> deleteUserData({void Function(double progress)? onProgress}) async {
    if (userId == null) return;
    
    final collections = ['finance', 'debts', 'goals', 'notes', 'smoking', 'health', 'medication', 'settings', 'subscription', 'badges', 'ai_chat', 'ai_usage'];
    final totalSteps = collections.length + 2; // collections + user doc delete + auth delete
    int currentStep = 0;
    
    for (final col in collections) {
      final snapshot = await _userDoc.collection(col).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      currentStep++;
      if (onProgress != null) {
        onProgress(currentStep / totalSteps);
      }
    }
    
    await _userDoc.delete();
    currentStep++;
    if (onProgress != null) {
      onProgress(currentStep / totalSteps);
    }

    try {
      await _firestore.terminate();
      await _firestore.clearPersistence();
    } catch (e) {
      print("Firestore Clear Error: $e");
    }

    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      await _auth.signOut();
    }
    currentStep++;
    if (onProgress != null) {
      onProgress(currentStep / totalSteps);
    }
  }

  Future<String?> uploadProfilePicture(File file) async {
    if (userId == null) return null;
    final ref = _storage.ref().child('users/$userId/profile_picture.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
