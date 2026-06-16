import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../services/iap_service.dart';
import '../../../core/utils/ui_helpers.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = false;
  bool _isLoadingProducts = true;
  int _currentPage = 1; // Ortadan başla (Platinum)
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.88);
    _initIap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initIap() async {
    await ref.read(iapServiceProvider).initialize();
    if (mounted) setState(() => _isLoadingProducts = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final subData = ref.watch(subscriptionStreamProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Arka plan dekorasyon
          Positioned(top: -80, right: -80,
            child: Container(width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurpleAccent.withOpacity(0.12)))),
          Positioned(bottom: 80, left: -40,
            child: Container(width: 180, height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withOpacity(0.08)))),

          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Icon(Icons.workspace_premium, size: 28, color: Colors.amber),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Başlık
                Text(
                  isTr ? 'Planını Seç' : 'Choose Your Plan',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  isTr ? 'İstediğin zaman iptal edebilirsin' : 'Cancel anytime',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 12),

                // Deneme süresi durumu
                _buildTrialBanner(subData),

                // Aylık / Yıllık toggle
                _buildToggle(),
                const SizedBox(height: 16),

                // Plan kartları (yatay kaydırılabilir)
                Expanded(
                  child: _isLoadingProducts
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _buildPlanCards(isTr, subData),
                ),

                // Sayfa göstergesi
                _buildPageIndicator(),
                const SizedBox(height: 8),

                // Footer
                _buildFooter(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBanner(SubscriptionData? sub) {
    if (sub == null || sub.type != SubscriptionType.trial || !sub.isActive) {
      return const SizedBox(height: 8);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Text(
            context.l10n('free_trial_remaining').replaceFirst('{days}', sub.remainingTrialDays.toString()),
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Center(
      child: Container(
        height: 44,
        width: 280,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(child: _toggleItem(context.l10n('monthly'), !_isYearly, () => setState(() => _isYearly = false))),
            Expanded(child: _toggleItem('${context.l10n('yearly')} 🔥', _isYearly, () => setState(() => _isYearly = true))),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
        ),
      ),
    );
  }

  Widget _buildPlanCards(bool isTr, SubscriptionData? subData) {
    final iap = ref.read(iapServiceProvider);

    final plans = [
      _PlanConfig(
        type: SubscriptionType.premium,
        title: context.l10n('subscription_premium'),
        subtitle: isTr ? 'Sınırsız kayıt, analiz ve dışa aktarım' : 'Unlimited entries, analysis & export',
        monthlyPrice: iap.getPrice(IapService.premiumMonthly, isTr ? '₺29,99' : '\$2.99'),
        yearlyPrice: iap.getPrice(IapService.premiumYearly, isTr ? '₺269,99' : '\$19.99'),
        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        features: [
          _Feat(Icons.all_inclusive, context.l10n('unlimited_entries')),
          _Feat(Icons.insights, context.l10n('adv_expense_analysis')),
          _Feat(Icons.category, context.l10n('custom_cats')),
          _Feat(Icons.file_download, context.l10n('export_pdf_excel')),
          _Feat(Icons.block, context.l10n('ad_free_experience')),
        ],
        monthlyProductId: IapService.premiumMonthly,
        yearlyProductId: IapService.premiumYearly,
      ),
      _PlanConfig(
        type: SubscriptionType.platinum,
        title: context.l10n('subscription_platinum'),
        subtitle: isTr ? 'AI destekli tam analiz (Günlük 20 Sorgu)' : 'AI-powered full analysis (Daily 20 Queries)',
        monthlyPrice: iap.getPrice(IapService.platinumMonthly, isTr ? '₺49,99' : '\$4.99'),
        yearlyPrice: iap.getPrice(IapService.platinumYearly, isTr ? '₺449,99' : '\$39.99'),
        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        isPopular: true,
        glowColor: Colors.deepPurpleAccent,
        features: [
          _Feat(Icons.psychology, context.l10n('ai_expense_coach')),
          _Feat(Icons.auto_graph, context.l10n('smart_saving_tips')),
          _Feat(Icons.summarize, context.l10n('weekly_ai_life_analysis')),
          _Feat(Icons.rocket_launch, context.l10n('early_access_features')),
          _Feat(Icons.star, context.l10n('all_premium_features')),
        ],
        monthlyProductId: IapService.platinumMonthly,
        yearlyProductId: IapService.platinumYearly,
      ),
      _PlanConfig(
        type: SubscriptionType.platinumFamily,
        title: isTr ? 'Premium AI Aile' : 'Premium AI Family',
        subtitle: isTr ? 'Ortak finans yönetimi (Günlük 20 Sorgu/Kişi)' : 'Shared family finance (Daily 20 Queries/User)',
        monthlyPrice: iap.getPrice(IapService.platinumFamilyMonthly, isTr ? '₺79,99' : '\$6.99'),
        yearlyPrice: iap.getPrice(IapService.platinumFamilyYearly, isTr ? '₺719,99' : '\$59.99'),
        gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        glowColor: Colors.amber,
        features: [
          _Feat(Icons.family_restroom, isTr ? 'Aile / Ortak Çalışma Alanı' : 'Family Shared Workspace'),
          _Feat(Icons.people_alt, isTr ? 'Üye davet ve rol yönetimi' : 'Member invites & role management'),
          _Feat(Icons.sync_alt, isTr ? 'Gerçek zamanlı veri senkronizasyonu' : 'Real-time data sync'),
          _Feat(Icons.psychology, isTr ? 'Tüm Premium AI özellikleri (Günlük 20 Sorgu)' : 'All Premium AI features (Daily 20 Queries)'),
          _Feat(Icons.health_and_safety, isTr ? 'Sağlık verisi gizlilik kontrolü' : 'Health privacy controls'),
        ],
        monthlyProductId: IapService.platinumFamilyMonthly,
        yearlyProductId: IapService.platinumFamilyYearly,
      ),
    ];

    return PageView.builder(
      controller: _pageController,
      itemCount: plans.length,
      onPageChanged: (i) => setState(() => _currentPage = i),
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isActive = index == _currentPage;
        final price = _isYearly ? plan.yearlyPrice : plan.monthlyPrice;
        final productId = _isYearly ? plan.yearlyProductId : plan.monthlyProductId;
        final btnText = _getButtonText(plan.type, subData?.type, productId, subData?.sku);

        return AnimatedScale(
          scale: isActive ? 1.0 : 0.93,
          duration: const Duration(milliseconds: 250),
          child: _buildPlanCard(plan, price, btnText, subData),
        );
      },
    );
  }

  Widget _buildPlanCard(_PlanConfig plan, String price, String btnText, SubscriptionData? subData) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: plan.isPopular || plan.glowColor != null ? [
          BoxShadow(color: (plan.glowColor ?? Colors.blueAccent).withOpacity(0.2), blurRadius: 30, spreadRadius: -4),
        ] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Renkli header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: plan.gradient,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(plan.title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        if (plan.isPopular)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(context.l10n('most_popular'),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(plan.subtitle, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(price, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _isYearly ? '/ ${context.l10n('per_year')}' : '/ ${context.l10n('per_month')}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Özellikler + Buton
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: plan.features.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(f.icon, size: 14, color: Colors.blueAccent),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      f.text, 
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.25),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _subscribe(plan.type),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(btnText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: i == _currentPage ? 20 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: i == _currentPage ? Colors.amber : Colors.white24,
          borderRadius: BorderRadius.circular(3),
        ),
      )),
    );
  }

  Widget _buildFooter() {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded, color: Colors.white24, size: 14),
              const SizedBox(width: 6),
              Text(context.l10n('secure_payment_msg'), style: const TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isTr
                ? 'Abonelik otomatik olarak yenilenir. Satın alma onaylandığında ödeme iTunes Hesabınızdan tahsil edilecektir. Abonelik, cari dönemin bitiminden en az 24 saat önce otomatik yenileme kapatılmadığı sürece otomatik olarak yenilenir. Cari dönemin sonundan 24 saat önce yenileme ücreti hesabınızdan tahsil edilecektir. Aboneliğinizi istediğiniz zaman App Store Hesap Ayarlarınızdan yönetebilirsiniz.'
                : 'Subscription automatically renews. Payment will be charged to iTunes Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period. Account will be charged for renewal within 24-hours prior to the end of the current period. You can manage your subscription anytime in your App Store Account Settings.',
            style: const TextStyle(color: Colors.white24, fontSize: 9),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/')),
                child: Text(isTr ? 'Kullanım Koşulları (EULA)' : 'Terms of Use (EULA)', style: const TextStyle(color: Colors.white38, fontSize: 11, decoration: TextDecoration.underline)),
              ),
              const Text('|', style: TextStyle(color: Colors.white24, fontSize: 11)),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://parametra.ai/privacy')),
                child: Text(isTr ? 'Gizlilik Politikası' : 'Privacy Policy', style: const TextStyle(color: Colors.white38, fontSize: 11, decoration: TextDecoration.underline)),
              ),
              const Text('|', style: TextStyle(color: Colors.white24, fontSize: 11)),
              TextButton(
                onPressed: _restorePurchases,
                child: Text(context.l10n('restore_purchases'), style: const TextStyle(color: Colors.white38, fontSize: 11, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getButtonText(SubscriptionType target, SubscriptionType? current, String targetSku, String? currentSku) {
    if (current == target && currentSku == targetSku) return context.l10n('current_plan');
    if (current == SubscriptionType.trial || current == SubscriptionType.free || current == null) {
      return context.l10n('start_subscription');
    }
    if (current == SubscriptionType.premium && target == SubscriptionType.platinum) return context.l10n('upgrade_to_platinum');
    if (current == SubscriptionType.platinum && target == SubscriptionType.premium) return context.l10n('downgrade_to_premium');
    if (current == target && currentSku != targetSku) {
      return _isYearly ? context.l10n('switch_to_yearly') : context.l10n('switch_to_monthly');
    }
    return context.l10n('start_subscription');
  }

  void _subscribe(SubscriptionType type) async {
    final productId = switch (type) {
      SubscriptionType.premium => _isYearly ? IapService.premiumYearly : IapService.premiumMonthly,
      SubscriptionType.platinum => _isYearly ? IapService.platinumYearly : IapService.platinumMonthly,
      SubscriptionType.platinumFamily => _isYearly ? IapService.platinumFamilyYearly : IapService.platinumFamilyMonthly,
      _ => IapService.premiumMonthly,
    };

    final iap = ref.read(iapServiceProvider);

    if (iap.isStoreAvailable) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
      try {
        await iap.buyProduct(productId);
        if (mounted) {
          Navigator.pop(context); // Diyaloğu kapat
          final typeName = type == SubscriptionType.platinumFamily
              ? 'Premium AI Aile'
              : type == SubscriptionType.platinum
                  ? 'Premium AI'
                  : 'Premium';
          UIHelpers.showSuccessSnackBar(
            context,
            context.l10n('sub_success_msg').replaceFirst('{type}', typeName),
          );
        }
      } catch (e) {
        debugPrint("Purchase Error: $e");
        if (mounted) {
          Navigator.pop(context); // Diyaloğu kapat
          UIHelpers.showErrorSnackBar(
            context,
            Localizations.localeOf(context).languageCode == 'tr'
                ? 'Satın alma işlemi sırasında bir hata oluştu: $e'
                : 'An error occurred during the purchase: $e',
          );
        }
      }
    } else {
      // Mağaza bağlantısı yoksa (örneğin simülatör veya test modundayken)
      if (kDebugMode || kProfileMode) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
        );
        await ref.read(subscriptionServiceProvider).updateSubscription(type, days: _isYearly ? 365 : 30, sku: productId);
        if (mounted) {
          Navigator.pop(context);
          final typeName = type == SubscriptionType.platinumFamily
              ? 'Premium AI Aile'
              : type == SubscriptionType.platinum
                  ? 'Premium AI'
                  : 'Premium';
          UIHelpers.showSuccessSnackBar(
            context,
            context.l10n('sub_success_msg').replaceFirst('{type}', typeName),
          );
        }
      } else {
        UIHelpers.showErrorSnackBar(
          context,
          Localizations.localeOf(context).languageCode == 'tr'
              ? 'Uygulama içi satın alma mağazasına bağlanılamadı. Lütfen daha sonra tekrar deneyin.'
              : 'Failed to connect to the in-app purchase store. Please try again later.',
        );
      }
    }
  }

  void _restorePurchases() async {
    final iap = ref.read(iapServiceProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
    
    try {
      await iap.restorePurchases();
      if (mounted) {
        Navigator.pop(context); // Diyaloğu kapat
        UIHelpers.showSuccessSnackBar(
          context,
          Localizations.localeOf(context).languageCode == 'tr'
              ? 'Satın alımlar başarıyla geri yüklendi.'
              : 'Purchases restored successfully.',
        );
      }
    } catch (e) {
      debugPrint("Restore Error: $e");
      if (mounted) {
        Navigator.pop(context); // Diyaloğu kapat
        UIHelpers.showErrorSnackBar(
          context,
          Localizations.localeOf(context).languageCode == 'tr'
              ? 'Satın alımları geri yükleme sırasında bir hata oluştu: $e'
              : 'An error occurred during restore: $e',
        );
      }
    }
  }
}

// ---- Yardımcı veri sınıfları ----

class _PlanConfig {
  final SubscriptionType type;
  final String title;
  final String subtitle;
  final String monthlyPrice;
  final String yearlyPrice;
  final Gradient gradient;
  final bool isPopular;
  final Color? glowColor;
  final List<_Feat> features;
  final String monthlyProductId;
  final String yearlyProductId;

  _PlanConfig({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.gradient,
    this.isPopular = false,
    this.glowColor,
    required this.features,
    required this.monthlyProductId,
    required this.yearlyProductId,
  });
}

class _Feat {
  final IconData icon;
  final String text;
  const _Feat(this.icon, this.text);
}
