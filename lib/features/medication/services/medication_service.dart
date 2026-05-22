import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/medication_model.dart';
import 'medication_notification_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final medicationServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  return MedicationService(uid, ref);
});

final medicationsStreamProvider = StreamProvider((ref) {
  final service = ref.watch(medicationServiceProvider);
  return service.getMedications();
});

final logTodayStreamProvider = StreamProvider<List<MedicationLog>>((ref) {
  final service = ref.watch(medicationServiceProvider);
  return service.getDailyLogs(DateTime.now());
});

class MedicationService {
  final String? userId;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MedicationService(this.userId, this._ref);

  DocumentReference get _userDoc => _firestore.collection('users').doc(userId ?? 'anonymous');
  CollectionReference get _medsColl => _userDoc.collection('medications');
  CollectionReference get _logsColl => _userDoc.collection('medication_logs');

  Stream<List<Medication>> getMedications() {
    if (userId == null) return Stream.value([]);
    return _medsColl
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Medication.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Stream<List<MedicationLog>> getDailyLogs(DateTime date) {
    if (userId == null) return Stream.value([]);
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _logsColl
        .where('takenDate', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('takenDate', isLessThan: endOfDay.toIso8601String())
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MedicationLog.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addMedication(Medication medication) async {
    await _medsColl.doc(medication.id).set(medication.toMap());
    try {
      await _ref.read(medicationNotificationServiceProvider).scheduleMedicationReminders(medication);
    } catch (e) {
      print("Medication Notification Error: $e");
    }
  }

  Future<void> addLog(MedicationLog log) async {
    await _logsColl.doc(log.id).set(log.toMap());

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'health',
        title: 'İlaç Alındı',
        description: '${log.medicationName} ilacı alındı.',
        icon: '💊',
        metadata: {
          'medicationName': log.medicationName,
          'count': 1,
        },
      );
    } catch (_) {}
  }

  Future<void> deleteMedication(String id) async {
    await _medsColl.doc(id).delete();
  }
}
