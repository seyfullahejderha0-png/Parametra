import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/finance_models.dart';
import '../models/recurring_payment_model.dart';
import '../../badges/services/badge_service.dart';
import '../../debts/services/debt_service.dart';
import '../../debts/models/debt_model.dart';
import '../../goals/services/goal_service.dart'; // Yeni import
import 'finance_notification_service.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/stream_merger.dart';
import '../../family/models/family_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../profile/services/profile_service.dart';
import '../../../core/services/notification_event_service.dart';
import '../../life_timeline/services/life_timeline_service.dart';

final financeServiceProvider = Provider((ref) {
  final uid = ref.watch(workspaceUserIdProvider);
  final badgeService = ref.watch(badgeServiceProvider);
  return FinanceService(uid, badgeService, ref);
});

final sharedFinanceServiceProvider = Provider((ref) {
  final sharedOwnerId = ref.watch(sharedWorkspaceOwnerIdProvider);
  if (sharedOwnerId == null) return null;
  final badgeService = ref.watch(badgeServiceProvider);
  return FinanceService(sharedOwnerId, badgeService, ref);
});

final actionsProvider = StreamProvider<List<FinanceAction>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(financeServiceProvider);
  final sharedService = ref.watch(sharedFinanceServiceProvider);

  final personalStream = personalService.getActions();
  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getActions();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<FinanceAction>(
      personalStream,
      sharedService.getActions(),
      (a, b) => b.date.compareTo(a.date),
    );
  }
  return personalStream;
});

final categoriesProvider = StreamProvider<List<FinanceCategory>>((ref) {
  final service = ref.watch(financeServiceProvider);
  return service.getCategories();
});

final paymentMethodsProvider = StreamProvider<List<PaymentMethod>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(financeServiceProvider);
  final sharedService = ref.watch(sharedFinanceServiceProvider);

  final personalStream = personalService.getPaymentMethods();
  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getPaymentMethods();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<PaymentMethod>(
      personalStream,
      sharedService.getPaymentMethods(),
      (a, b) => a.name.compareTo(b.name),
    );
  }
  return personalStream;
});

final paymentMethodsWithBalanceProvider = Provider<AsyncValue<List<PaymentMethod>>>((ref) {
  final methodsAsync = ref.watch(paymentMethodsProvider);
  final actionsAsync = ref.watch(actionsProvider);

  // Eğer elimizde zaten önceden yüklenmiş data (value) varsa, anlık loading durumlarını atla ve mevcut datayı kullan!
  if (methodsAsync.hasValue && actionsAsync.hasValue) {
    final methods = methodsAsync.value!;
    final actions = actionsAsync.value!;
    final updatedMethods = methods.map((m) {
      double balance = m.openingBalance;
      for (var a in actions) {
        if (a.paymentMethodId == m.id && a.isBalanceEffect) {
          if (a.type == FinanceType.income) {
            balance += a.amount;
          } else {
            balance -= a.amount;
          }
        }
      }
      return m.copyWith(currentBalance: balance);
    }).toList();
    return AsyncData(updatedMethods);
  }

  // Eğer henüz hiç data yüklenmemişse loading veya error durumlarına bak
  if (methodsAsync.isLoading || actionsAsync.isLoading) {
    return const AsyncLoading();
  }
  if (methodsAsync.hasError) {
    return AsyncError(methodsAsync.error!, methodsAsync.stackTrace!);
  }
  if (actionsAsync.hasError) {
    return AsyncError(actionsAsync.error!, actionsAsync.stackTrace!);
  }

  return const AsyncLoading();
});

final recurringPaymentsProvider = StreamProvider<List<RecurringPayment>>((ref) {
  final workspaceType = ref.watch(workspaceTypeProvider);
  final personalService = ref.watch(financeServiceProvider);
  final sharedService = ref.watch(sharedFinanceServiceProvider);

  final personalStream = personalService.getRecurringPayments();
  if (workspaceType == WorkspaceType.shared && sharedService != null) {
    return sharedService.getRecurringPayments();
  } else if (workspaceType == WorkspaceType.all && sharedService != null) {
    return mergeListStreams<RecurringPayment>(
      personalStream,
      sharedService.getRecurringPayments(),
      (a, b) => b.nextPaymentDate.compareTo(a.nextPaymentDate),
    );
  }
  return personalStream;
});

final budgetLimitProvider = StreamProvider<double?>((ref) {
  final service = ref.watch(financeServiceProvider);
  return service.getBudgetLimit();
});

class FinanceService {
  final String? userId;
  final BadgeService _badgeService;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FinanceService(this.userId, this._badgeService, this._ref);

  CollectionReference get _userDoc => _firestore.collection('users').doc(userId ?? 'anonymous').collection('finance');
  CollectionReference get _actionsColl => _userDoc.doc('data').collection('actions');
  CollectionReference get _categoriesColl => _userDoc.doc('data').collection('categories');
  CollectionReference get _paymentMethodsColl => _userDoc.doc('data').collection('payment_methods');
  CollectionReference get _recurringColl => _userDoc.doc('data').collection('recurring_payments');

  Stream<List<FinanceAction>> getActions() {
    if (userId == null) return Stream.value([]);
    return _actionsColl.orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => FinanceAction.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Stream<List<FinanceCategory>> getCategories() {
    if (userId == null) return Stream.value([]);
    return _categoriesColl.snapshots().asyncMap((snapshot) async {
      List<FinanceCategory> list = [];
      if (snapshot.docs.isEmpty) {
        await _initializeDefaultCategories();
        final newSnap = await _categoriesColl.get();
        list = newSnap.docs.map((doc) => FinanceCategory.fromMap(doc.data() as Map<String, dynamic>)).toList();
      } else {
        list = snapshot.docs.map((doc) => FinanceCategory.fromMap(doc.data() as Map<String, dynamic>)).toList();
      }

      // 'cat_goal_savings' ve transfer kategorilerinin her zaman var olduğundan emin ol
      if (!list.any((c) => c.id == 'cat_goal_savings')) {
        list.add(FinanceCategory(id: 'cat_goal_savings', name: 'Hedef Birikimi', emoji: '🎯', type: FinanceType.expense));
      }
      if (!list.any((c) => c.id == 'cat_transfer_in')) {
        list.add(FinanceCategory(id: 'cat_transfer_in', name: 'Transfer Girişi', emoji: '🔄', type: FinanceType.income));
      }
      if (!list.any((c) => c.id == 'cat_transfer_out')) {
        list.add(FinanceCategory(id: 'cat_transfer_out', name: 'Transfer Çıkışı', emoji: '🔄', type: FinanceType.expense));
      }
      
      return list;
    });
  }

  Future<void> _initializeDefaultCategories() async {
    final defaults = [
      FinanceCategory(id: 'cat_sal', name: 'Maaş', emoji: '💰', type: FinanceType.income),
      FinanceCategory(id: 'cat_free', name: 'Freelance', emoji: '💻', type: FinanceType.income),
      FinanceCategory(id: 'cat_inv', name: 'Yatırım/Borsa', emoji: '📈', type: FinanceType.income),
      FinanceCategory(id: 'cat_rent', name: 'Kira Geliri', emoji: '🏠', type: FinanceType.income),
      FinanceCategory(id: 'cat_gift', name: 'Hediye/Prim', emoji: '🎁', type: FinanceType.income),
      FinanceCategory(id: 'cat_sale', name: 'Satış', emoji: '🤝', type: FinanceType.income),
      FinanceCategory(id: 'cat_transfer_in', name: 'Transfer Girişi', emoji: '🔄', type: FinanceType.income),
      FinanceCategory(id: 'cat_other_in', name: 'Diğer Gelir', emoji: '🪙', type: FinanceType.income),
      
      FinanceCategory(id: 'cat_food', name: 'Mutfak/Yemek', emoji: '🛒', type: FinanceType.expense),
      FinanceCategory(id: 'cat_rent_ex', name: 'Kira/Fatura', emoji: '🏠', type: FinanceType.expense),
      FinanceCategory(id: 'cat_trans', name: 'Ulaşım/Yakıt', emoji: '🚗', type: FinanceType.expense),
      FinanceCategory(id: 'cat_ent', name: 'Eğlence', emoji: '🎭', type: FinanceType.expense),
      FinanceCategory(id: 'cat_health', name: 'Sağlık', emoji: '🏥', type: FinanceType.expense),
      FinanceCategory(id: 'cat_shop', name: 'Giyim/Alışveriş', emoji: '🛍️', type: FinanceType.expense),
      FinanceCategory(id: 'cat_goal_savings', name: 'Hedef Birikimi', emoji: '🎯', type: FinanceType.expense),
      FinanceCategory(id: 'cat_transfer_out', name: 'Transfer Çıkışı', emoji: '🔄', type: FinanceType.expense),
      FinanceCategory(id: 'cat_other_ex', name: 'Diğer Gider', emoji: '💸', type: FinanceType.expense),
    ];

    for (var cat in defaults) {
      await addCategory(cat);
    }
  }

  Stream<List<PaymentMethod>> getPaymentMethods() {
    if (userId == null) return Stream.value([]);
    return _paymentMethodsColl.snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        return await _initializeDefaultPaymentMethods();
      }
      return snapshot.docs.map((doc) => PaymentMethod.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<List<PaymentMethod>> _initializeDefaultPaymentMethods() async {
    final defaults = [
      PaymentMethod(id: 'pm_cash', name: 'Nakit', icon: '💵', openingBalance: 0, type: AccountType.cash),
      PaymentMethod(id: 'pm_bank', name: 'Banka Hesabı', icon: '🏦', openingBalance: 0, type: AccountType.bank),
      PaymentMethod(id: 'pm_cc', name: 'Kredi Kartı', icon: '💳', openingBalance: 0, type: AccountType.credit_card),
    ];
    for (var m in defaults) {
      await addPaymentMethod(m);
    }
    return defaults;
  }

  Future<void> addFinanceAction(FinanceAction action) async {
    await _actionsColl.doc(action.id).set(action.toMap());
    
    // Ortak alan bildirimini gönder
    try {
      final profile = _ref.read(userProfileProvider).value;
      final actorName = (profile != null && profile.firstName.isNotEmpty)
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : 'Bir üye';
      final actionName = action.type == FinanceType.income ? 'gelir' : 'gider';
      await _ref.read(notificationEventServiceProvider).sendEvent(
        module: 'finance',
        action: 'create',
        title: 'Finans Kaydı',
        body: '$actorName ${action.amount.toStringAsFixed(0)} TL $actionName ekledi: ${action.description}',
      );
    } catch (_) {}

    // Yaşam Akışı Loglama
    try {
      await _ref.read(lifeTimelineServiceProvider).logEvent(
        module: 'finance',
        title: action.type == FinanceType.income ? 'Gelir Eklendi' : 'Gider Eklendi',
        description: '${action.amount.toStringAsFixed(0)} TL - ${action.description}',
        icon: action.type == FinanceType.income ? '💰' : '💸',
        metadata: {
          'actionId': action.id,
          'amount': action.amount,
          'type': action.type.name,
        },
      );
    } catch (_) {}

    // Yan Etkileri Uygula (Kredi Kartı Borcu vb.)
    await _applyActionEffects(action);



    // Bütçe Kontrolü (%120 Aşımı)
    if (action.type == FinanceType.expense) {
      final budgetLimit = await getBudgetLimit().first;
      if (budgetLimit != null && budgetLimit > 0) {
        final dailyLimit = budgetLimit / 30;
        final actions = await getActions().first;
        final today = DateTime.now();
        final todayTotal = actions
            .where((a) => a.type == FinanceType.expense && 
                          a.date.year == today.year && 
                          a.date.month == today.month && 
                          a.date.day == today.day)
            .fold(0.0, (sum, a) => sum + a.amount);
            
        if (todayTotal > (dailyLimit * 1.2)) {
          _ref.read(financeNotificationServiceProvider).sendOverspendingWarning();
        }
      }
    }

    // Rozet Kontrolleri
    await _badgeService.unlockBadge('fin_1');
    
    final snapshot = await _actionsColl.limit(10).get();
    if (snapshot.docs.length >= 7) {
      await _badgeService.unlockBadge('fin_7');
    }
  }

  Future<void> _applyActionEffects(FinanceAction action) async {
    if (!action.isBalanceEffect) return;

    final methods = await getPaymentMethods().first;
    if (methods.isEmpty) return;
    
    final method = methods.firstWhere((m) => m.id == action.paymentMethodId, orElse: () => methods.first);
    
    // Eğer kredi kartı ile harcama yapıldıysa borcu güncelle
    if (method.type == AccountType.credit_card) {
      final delta = action.type == FinanceType.expense ? action.amount : -action.amount;
      await _updateCreditCardDebt(method.id, delta);
    }
  }

  Future<void> _revertActionEffects(FinanceAction action) async {
    if (!action.isBalanceEffect) return;

    final methods = await getPaymentMethods().first;
    if (methods.isEmpty) return;

    final method = methods.firstWhere((m) => m.id == action.paymentMethodId, orElse: () => methods.first);
    
    // Kredi kartı borç güncellemesini geri al
    if (method.type == AccountType.credit_card) {
      // Delta tersine çevrilir: Harcama silindiyse borç azalır (-amount), Gelir silindiyse borç artar (+amount)
      final delta = action.type == FinanceType.expense ? -action.amount : action.amount;
      await _updateCreditCardDebt(method.id, delta);
    }
  }

  Future<void> updateFinanceAction(FinanceAction newAction) async {
    // 1. Eski işlemi bul
    final existingDoc = await _actionsColl.doc(newAction.id).get();
    if (existingDoc.exists) {
      final oldAction = FinanceAction.fromMap(existingDoc.data() as Map<String, dynamic>);
      // 2. Eski etkileri geri al
      await _revertActionEffects(oldAction);
    }

    // 3. Yeni işlemi kaydet ve yeni etkileri uygula
    await addFinanceAction(newAction);
  }

  Future<void> addCategory(FinanceCategory category) async {
    await _categoriesColl.doc(category.id).set(category.toMap());
  }

  Future<void> addPaymentMethod(PaymentMethod method) async {
    await _paymentMethodsColl.doc(method.id).set(method.toMap());
    
    // Eğer kredi kartı ise Borçlar modülüne ekle
    if (method.type == AccountType.credit_card) {
      await _syncCreditCardToDebt(method);
    }
  }

  Future<void> _syncCreditCardToDebt(PaymentMethod method) async {
    final debtService = _ref.read(debtServiceProvider);
    final existingDebts = await debtService.getDebts().first;
    final now = DateTime.now();
    final targetDueDate = method.statementDay != null ? DateTime(now.year, now.month, method.statementDay!) : null;

    final existingDebt = existingDebts.firstWhere(
      (d) => d.paymentMethodId == method.id,
      orElse: () => Debt(
        id: const Uuid().v4(),
        personName: method.name,
        amount: method.openingBalance,
        currency: 'TRY',
        date: now,
        dueDate: targetDueDate,
        type: DebtType.credit_card,
        paymentMethodId: method.id,
        isBalanceEffect: false, 
      ),
    );

    if (existingDebt.amount != method.openingBalance || existingDebt.personName != method.name || existingDebt.dueDate?.day != method.statementDay) {
       await debtService.addDebt(existingDebt.copyWith(
         personName: method.name,
         amount: method.openingBalance,
         dueDate: targetDueDate,
       ));
    } else if (!existingDebts.any((d) => d.id == existingDebt.id)) {
       await debtService.addDebt(existingDebt);
    }
  }

  Future<void> _updateCreditCardDebt(String paymentMethodId, double delta) async {
    final debtService = _ref.read(debtServiceProvider);
    final existingDebts = await debtService.getDebts().first;
    try {
      final debt = existingDebts.firstWhere((d) => d.paymentMethodId == paymentMethodId);
      await debtService.updateDebt(debt.copyWith(
        amount: debt.amount + delta,
      ));
    } catch (_) {
      // Eğer borç kaydı bir şekilde silindiyse veya bulunamadıysa (nadiren) bir şey yapma 
      // veya kartı tekrar senkronize et
    }
  }

  Future<void> deletePaymentMethod(String id) async {
    // Önce borcu sil (eğer varsa)
    final debtService = _ref.read(debtServiceProvider);
    final existingDebts = await debtService.getDebts().first;
    final debt = existingDebts.where((d) => d.paymentMethodId == id).toList();
    for (var d in debt) {
      await debtService.deleteDebt(d.id);
    }
    
    await _paymentMethodsColl.doc(id).delete();
  }

  Stream<List<RecurringPayment>> getRecurringPayments() {
    if (userId == null) return Stream.value([]);
    return _recurringColl.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RecurringPayment.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addRecurringPayment(RecurringPayment payment) async {
    await _recurringColl.doc(payment.id).set(payment.toMap());
  }

  Future<void> deleteRecurringPayment(String id) async {
    await _recurringColl.doc(id).delete();
  }

  Future<void> deleteAction(String id) async {
    final actions = await getActions().first;
    final action = actions.firstWhere((a) => a.id == id);
    
    // Etkileri geri al
    await _revertActionEffects(action);

    // Eğer bu bir hedef birikimi ise ve relatedId varsa hedefi de güncelle
    if (action.categoryId == 'cat_goal_savings' && action.relatedId != null) {
      try {
        await _ref.read(goalServiceProvider).removeGoalProgress(action.relatedId!, action.amount);
      } catch (e) {
        print("Hedef güncellenirken hata: $e");
      }
    }

    // Yaşam Akışı Güncellemesi
    try {
      await _ref.read(lifeTimelineServiceProvider).markEventAsDeleted(key: 'actionId', value: id);
    } catch (_) {}

    await _actionsColl.doc(id).delete();
  }

  Future<void> setBudgetLimit(double amount) async {
    await _userDoc.doc('settings').set({'monthlyBudget': amount}, SetOptions(merge: true));
  }

  Stream<double?> getBudgetLimit() {
    if (userId == null) return Stream.value(null);
    return _userDoc.doc('settings').snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return (snapshot.data() as Map<String, dynamic>)['monthlyBudget']?.toDouble();
    });
  }

  Future<void> clearAllData() async {
    if (userId == null) return;
    final collections = ['actions', 'categories', 'payment_methods'];
    for (var coll in collections) {
      final snapshots = await _userDoc.doc('data').collection(coll).get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
    }
  }
}
