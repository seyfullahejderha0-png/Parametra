import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/labs_module.dart';
import '../services/labs_dummy_service.dart';
import '../widgets/labs_module_card.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/glass_card.dart';

class ParametraLabsScreen extends ConsumerStatefulWidget {
  const ParametraLabsScreen({super.key});

  @override
  ConsumerState<ParametraLabsScreen> createState() => _ParametraLabsScreenState();
}

class _ParametraLabsScreenState extends ConsumerState<ParametraLabsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final modules = ref.watch(labsModulesProvider);
    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    // Grouping modules by categories/tabs
    final developingModules = modules.where((m) => m.category == 'geliştiriliyor').toList();
    final plannedModules = modules.where((m) => m.category == 'planlandı').toList();
    final argeModules = modules.where((m) => m.category == 'arge').toList();

    return Scaffold(
      backgroundColor: themeMode.background,
      appBar: AppBar(
        title: Text(
          isTr ? 'Parametra Labs' : 'Parametra Labs',
          style: TextStyle(
            color: themeMode.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: themeMode.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Hero Gradient Header
            SliverToBoxAdapter(
              child: _buildHeroHeader(context, themeMode, isTr),
            ),
            // Stats Indicator Card
            SliverToBoxAdapter(
              child: _buildStatsCard(context, themeMode, isTr),
            ),
            // Persistent Tab Bar Header
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.blueAccent,
                    labelColor: Colors.white,
                    unselectedLabelColor: themeMode.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: isTr ? 'Geliştiriliyor' : 'Developing'),
                      Tab(text: isTr ? 'Planlandı' : 'Planned'),
                      Tab(text: isTr ? 'Ar-Ge' : 'R&D'),
                    ],
                  ),
                  themeMode.background,
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTabContent(developingModules),
            _buildTabContent(plannedModules),
            _buildTabContent(argeModules),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, AppThemeMode themeMode, bool isTr) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueAccent.withOpacity(0.2),
            Colors.blueAccent.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🚀',
                style: TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Text(
                isTr ? 'Parametra Labs' : 'Parametra Labs',
                style: TextStyle(
                  color: themeMode.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTr 
                ? 'Parametra sürekli gelişiyor. Gelecekte eklemeyi hedeflediğimiz vizyoner modülleri buradan inceleyebilir, haberdar olmak istediklerinizi seçebilirsiniz.'
                : 'Parametra is constantly evolving. Here you can explore the visionary modules we plan to add, and choose to be notified when they launch.',
            style: TextStyle(
              color: themeMode.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, AppThemeMode themeMode, bool isTr) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        borderRadius: 20,
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                value: '12',
                label: isTr ? 'Aktif Modül' : 'Active Modules',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white10,
            ),
            Expanded(
              child: _buildStatItem(
                value: '15',
                label: isTr ? 'Planlanan Özellik' : 'Planned Features',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(List<LabsModule> items) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    
    return SafeArea(
      top: false,
      bottom: false,
      child: Builder(
        builder: (context) {
          return CustomScrollView(
            key: PageStorageKey<String>(items.isEmpty ? 'empty' : items.first.category),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < items.length) {
                        return LabsModuleCard(module: items[index]);
                      } else {
                        // Large Vision Card at the end
                        return _buildVisionCard(isTr);
                      }
                    },
                    childCount: items.length + 1, // +1 for the vision card
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVisionCard(bool isTr) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 32),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        color: Colors.blueAccent.withOpacity(0.05),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.15), width: 1.5),
        child: Column(
          children: [
            const Icon(
              Icons.auto_awesome,
              color: Colors.blueAccent,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              isTr ? 'Parametra Vizyonu' : 'Parametra Vision',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isTr 
                  ? '“Hayatı planlayan değil, hayatı yöneten AI platformu.”'
                  : '“Not a life planner, but an AI platform that manages life.”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.85),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
