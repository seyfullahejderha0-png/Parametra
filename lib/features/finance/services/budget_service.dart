import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/budget_model.dart';
import 'package:intl/intl.dart';

final budgetServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  return BudgetService(uid);
});

final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final service = ref.watch(budgetServiceProvider);
  return service.getBudgets();
});

class BudgetService {
  final String? userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  BudgetService(this.userId);

  CollectionReference get _budgetsRef => _firestore
      .collection('users')
      .doc(userId ?? 'anonymous')
      .collection('budgets');

  Stream<List<Budget>> getBudgets({String? month}) {
    final currentMonth = month ?? DateFormat('yyyy-MM').format(DateTime.now());
    return _budgetsRef
        .where('month', isEqualTo: currentMonth)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Budget.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> setBudget(Budget budget) async {
    await _budgetsRef.doc(budget.id).set(budget.toMap());
  }

  Future<void> deleteBudget(String id) async {
    await _budgetsRef.doc(id).delete();
  }

  Future<Budget?> getBudgetForCategory(String categoryId, {String? month}) async {
    final currentMonth = month ?? DateFormat('yyyy-MM').format(DateTime.now());
    final snapshot = await _budgetsRef
        .where('categoryId', isEqualTo: categoryId)
        .where('month', isEqualTo: currentMonth)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return Budget.fromMap(snapshot.docs.first.data() as Map<String, dynamic>);
    }
    return null;
  }
}
