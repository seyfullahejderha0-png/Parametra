import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_service.dart';
import '../../family/services/family_service.dart';
import '../models/life_timeline_event.dart';
import '../services/life_timeline_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/stream_merger.dart';


enum TimelineFilter {
  personal,
  shared,
  all,
}

class TimelineLimitNotifier extends Notifier<int> {
  @override
  int build() => 25;

  void updateLimit(int value) {
    state = value;
  }
}

final timelineLimitProvider = NotifierProvider<TimelineLimitNotifier, int>(() {
  return TimelineLimitNotifier();
});

class TimelineFilterNotifier extends Notifier<TimelineFilter> {
  @override
  TimelineFilter build() => TimelineFilter.personal;

  void setFilter(TimelineFilter filter) {
    state = filter;
    ref.read(timelineLimitProvider.notifier).updateLimit(25);
  }
}

final timelineFilterProvider = NotifierProvider<TimelineFilterNotifier, TimelineFilter>(() {
  return TimelineFilterNotifier();
});

final filteredTimelineEventsProvider = StreamProvider<List<LifeTimelineEvent>>((ref) {
  final filter = ref.watch(timelineFilterProvider);
  final limit = ref.watch(timelineLimitProvider);
  final personalService = ref.watch(lifeTimelineServiceProvider);
  final sharedService = ref.watch(sharedLifeTimelineServiceProvider);

  if (filter == TimelineFilter.shared && sharedService != null) {
    return sharedService.getEvents(limit: limit);
  } else if (filter == TimelineFilter.all && sharedService != null) {
    return mergeListStreams<LifeTimelineEvent>(
      personalService.getEvents(limit: limit),
      sharedService.getEvents(limit: limit),
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );
  }
  return personalService.getEvents(limit: limit);
});

class LifeTimelineScreen extends ConsumerStatefulWidget {
  const LifeTimelineScreen({super.key});

  @override
  ConsumerState<LifeTimelineScreen> createState() => _LifeTimelineScreenState();
}

class _LifeTimelineScreenState extends ConsumerState<LifeTimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isYesterdayExpanded = false;
  bool _isThisWeekExpanded = false;
  bool _isOlderExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final currentLimit = ref.read(timelineLimitProvider);
      ref.read(timelineLimitProvider.notifier).updateLimit(currentLimit + 20);
    }
  }

  List<LifeTimelineEvent> _groupTimelineEvents(List<LifeTimelineEvent> events, bool isTr) {
    final Map<String, LifeTimelineEvent> grouped = {};

    for (var event in events) {
      if (event.isDeleted) {
        grouped[event.id] = event;
        continue;
      }
      final dateStr = DateFormat('yyyy-MM-dd').format(event.timestamp);
      
      if (event.module == 'health' && (event.title == 'Su Tüketimi' || event.title == 'Sigara Kaydı' || event.title == 'İlaç Alındı')) {
        String key;
        if (event.title == 'İlaç Alındı') {
          final medName = event.metadata?['medicationName'] ?? '';
          key = '${dateStr}_Medication_${medName}_${event.actorId}_${event.workspaceType}';
        } else {
          key = '${dateStr}_${event.title}_${event.actorId}_${event.workspaceType}';
        }

        if (grouped.containsKey(key)) {
          final existing = grouped[key]!;
          if (event.title == 'Su Tüketimi') {
            final oldAmount = (existing.metadata?['amount'] as num?)?.toDouble() ?? 0.0;
            final additionalAmount = (event.metadata?['amount'] as num?)?.toDouble() ?? 0.25;
            final newAmount = oldAmount + additionalAmount;
            
            grouped[key] = LifeTimelineEvent(
              id: existing.id,
              timestamp: existing.timestamp.isAfter(event.timestamp) ? existing.timestamp : event.timestamp,
              module: existing.module,
              title: existing.title,
              description: isTr ? '${newAmount.toStringAsFixed(1)} L su içildi.' : '${newAmount.toStringAsFixed(1)} L water consumed.',
              actorId: existing.actorId,
              workspaceType: existing.workspaceType,
              icon: existing.icon,
              metadata: {'amount': newAmount},
              eventType: existing.eventType,
            );
          } else if (event.title == 'Sigara Kaydı') {
            final oldCount = (existing.metadata?['count'] as num?)?.toInt() ?? 1;
            final newCount = oldCount + ((event.metadata?['count'] as num?)?.toInt() ?? 1);
            
            grouped[key] = LifeTimelineEvent(
              id: existing.id,
              timestamp: existing.timestamp.isAfter(event.timestamp) ? existing.timestamp : event.timestamp,
              module: existing.module,
              title: existing.title,
              description: isTr ? 'Bugün $newCount sigara içildi.' : '$newCount cigarettes smoked today.',
              actorId: existing.actorId,
              workspaceType: existing.workspaceType,
              icon: existing.icon,
              metadata: {'count': newCount},
              eventType: 'warning',
            );
          } else if (event.title == 'İlaç Alındı') {
            final oldCount = (existing.metadata?['count'] as num?)?.toInt() ?? 1;
            final newCount = oldCount + ((event.metadata?['count'] as num?)?.toInt() ?? 1);
            final medName = existing.metadata?['medicationName'] ?? '';
            
            grouped[key] = LifeTimelineEvent(
              id: existing.id,
              timestamp: existing.timestamp.isAfter(event.timestamp) ? existing.timestamp : event.timestamp,
              module: existing.module,
              title: existing.title,
              description: isTr
                  ? (newCount == 1 ? '$medName ilacı alındı.' : '$medName ilacı bugünkü $newCount. dozu alındı.')
                  : (newCount == 1 ? '$medName medication taken.' : '$medName medication taken ($newCount times today).'),
              actorId: existing.actorId,
              workspaceType: existing.workspaceType,
              icon: existing.icon,
              metadata: {
                'medicationName': medName,
                'count': newCount,
              },
              eventType: existing.eventType,
            );
          }
        } else {
          final metadata = Map<String, dynamic>.from(event.metadata ?? {});
          if (event.title == 'Su Tüketimi' && !metadata.containsKey('amount')) {
            metadata['amount'] = 0.25;
          } else if (event.title == 'Sigara Kaydı' && !metadata.containsKey('count')) {
            metadata['count'] = 1;
          } else if (event.title == 'İlaç Alındı' && !metadata.containsKey('count')) {
            metadata['count'] = 1;
          }
          grouped[key] = LifeTimelineEvent(
            id: event.id,
            timestamp: event.timestamp,
            module: event.module,
            title: event.title,
            description: event.description,
            actorId: event.actorId,
            workspaceType: event.workspaceType,
            icon: event.icon,
            metadata: metadata,
            eventType: event.eventType,
          );
        }
      } else {
        grouped[event.id] = event;
      }
    }

    final list = grouped.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final filter = ref.watch(timelineFilterProvider);
    final eventsAsync = ref.watch(filteredTimelineEventsProvider);
    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    return Scaffold(
      backgroundColor: themeMode.background,
      appBar: AppBar(
        title: Text(
          context.l10n('life_timeline_title'),
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
      body: Column(
        children: [
          // Filter Selector
          _buildFilterSelector(context, ref, themeMode, filter),
          
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return _buildEmptyState(context, themeMode);
                }

                // Apply dynamic grouping (Su, Sigara, Ilaç)
                final grouped = _groupTimelineEvents(events, isTr);

                // Group into buckets
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final yesterdayStart = todayStart.subtract(const Duration(days: 1));
                final weekStart = todayStart.subtract(const Duration(days: 7));

                final List<LifeTimelineEvent> todayEvents = [];
                final List<LifeTimelineEvent> yesterdayEvents = [];
                final List<LifeTimelineEvent> thisWeekEvents = [];
                final List<LifeTimelineEvent> olderEvents = [];

                for (var event in grouped) {
                  final eventDate = DateTime(event.timestamp.year, event.timestamp.month, event.timestamp.day);
                  if (eventDate.isAtSameMomentAs(todayStart)) {
                    todayEvents.add(event);
                  } else if (eventDate.isAtSameMomentAs(yesterdayStart)) {
                    yesterdayEvents.add(event);
                  } else if (eventDate.isAfter(weekStart)) {
                    thisWeekEvents.add(event);
                  } else {
                    olderEvents.add(event);
                  }
                }

                return RefreshIndicator(
                  onRefresh: () async {},
                  color: themeMode.primary,
                  backgroundColor: themeMode.surface,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Bugün Section (always open)
                      if (todayEvents.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(context, themeMode, isTr ? 'Bugün' : 'Today'),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final event = todayEvents[index];
                                final isLast = index == todayEvents.length - 1;
                                return _buildTimelineItem(context, themeMode, event, isLast, isSummaryMode: false);
                              },
                              childCount: todayEvents.length,
                            ),
                          ),
                        ),
                      ],

                      // Dün Section (Accordion)
                      if (yesterdayEvents.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildAccordionHeader(
                            context,
                            themeMode,
                            title: isTr ? 'Dün' : 'Yesterday',
                            count: yesterdayEvents.length,
                            isExpanded: _isYesterdayExpanded,
                            onTap: () => setState(() => _isYesterdayExpanded = !_isYesterdayExpanded),
                          ),
                        ),
                        if (_isYesterdayExpanded)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final event = yesterdayEvents[index];
                                  final isLast = index == yesterdayEvents.length - 1;
                                  return _buildTimelineItem(context, themeMode, event, isLast, isSummaryMode: false);
                                },
                                childCount: yesterdayEvents.length,
                              ),
                            ),
                          ),
                      ],

                      // Bu Hafta Section (Accordion)
                      if (thisWeekEvents.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildAccordionHeader(
                            context,
                            themeMode,
                            title: isTr ? 'Bu Hafta' : 'This Week',
                            count: thisWeekEvents.length,
                            isExpanded: _isThisWeekExpanded,
                            onTap: () => setState(() => _isThisWeekExpanded = !_isThisWeekExpanded),
                          ),
                        ),
                        if (_isThisWeekExpanded)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final event = thisWeekEvents[index];
                                  final isLast = index == thisWeekEvents.length - 1;
                                  return _buildTimelineItem(context, themeMode, event, isLast, isSummaryMode: false);
                                },
                                childCount: thisWeekEvents.length,
                              ),
                            ),
                          ),
                      ],

                      // Eski Section (Accordion, summary mode)
                      if (olderEvents.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildAccordionHeader(
                            context,
                            themeMode,
                            title: isTr ? 'Eski' : 'Older',
                            count: olderEvents.length,
                            isExpanded: _isOlderExpanded,
                            onTap: () => setState(() => _isOlderExpanded = !_isOlderExpanded),
                          ),
                        ),
                        if (_isOlderExpanded)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final event = olderEvents[index];
                                  final isLast = index == olderEvents.length - 1;
                                  return _buildTimelineItem(context, themeMode, event, isLast, isSummaryMode: true);
                                },
                                childCount: olderEvents.length,
                              ),
                            ),
                          ),
                      ],

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80.0),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: themeMode.primary),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    isTr ? 'Bir hata oluştu: $err' : 'An error occurred: $err',
                    style: TextStyle(color: themeMode.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    AppThemeMode themeMode,
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: themeMode.textSecondary,
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAccordionHeader(
    BuildContext context,
    AppThemeMode themeMode, {
    required String title,
    required int count,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: themeMode.surface,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: themeMode.textSecondary.withOpacity(0.08),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: themeMode.primary,
                  size: 24.0,
                ),
                const SizedBox(width: 12.0),
                Text(
                  title,
                  style: TextStyle(
                    color: themeMode.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.0,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: themeMode.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: themeMode.primary,
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSelector(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode themeMode,
    TimelineFilter currentFilter,
  ) {
    final hasSharedSpace = ref.watch(sharedLifeTimelineServiceProvider) != null;

    final List<Map<String, dynamic>> items = [
      {
        'filter': TimelineFilter.personal,
        'label': context.l10n('life_timeline_personal_filter'),
      },
      if (hasSharedSpace) ...[
        {
          'filter': TimelineFilter.shared,
          'label': context.l10n('life_timeline_shared_filter'),
        },
        {
          'filter': TimelineFilter.all,
          'label': context.l10n('life_timeline_all_filter'),
        },
      ],
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: themeMode.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: themeMode.textSecondary.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Row(
        children: items.map((item) {
          final filterType = item['filter'] as TimelineFilter;
          final label = item['label'] as String;
          final isSelected = filterType == currentFilter;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(timelineFilterProvider.notifier).setFilter(filterType);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: BoxDecoration(
                  color: isSelected ? themeMode.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeMode.primary.withOpacity(0.3),
                            blurRadius: 8.0,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? (themeMode.brightness == Brightness.dark ? Colors.white : Colors.black)
                        : themeMode.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14.0,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppThemeMode themeMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: themeMode.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeMode.primary.withOpacity(0.1),
                    blurRadius: 20.0,
                    spreadRadius: 5.0,
                  )
                ],
              ),
              child: Icon(
                Icons.history,
                size: 60.0,
                color: themeMode.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              context.l10n('life_timeline_title'),
              style: TextStyle(
                color: themeMode.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              context.l10n('life_timeline_empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: themeMode.textSecondary,
                fontSize: 14.0,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    AppThemeMode themeMode,
    LifeTimelineEvent event,
    bool isLast, {
    required bool isSummaryMode,
  }) {
    final moduleColor = _getModuleColor(themeMode, event.module);
    final timeStr = _formatEventTime(context, event.timestamp);
    final bool isDeleted = event.isDeleted;

    BoxDecoration iconDecoration;
    double glowRadius = 0.0;
    Color glowColor = Colors.transparent;

    if (isDeleted) {
      iconDecoration = BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white24,
          width: 1.0,
        ),
      );
    } else {
      switch (event.eventType) {
        case 'milestone':
          glowRadius = 8.0;
          glowColor = Colors.purpleAccent.withOpacity(0.5);
          iconDecoration = BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Colors.purpleAccent, Colors.deepPurpleAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: glowRadius,
                spreadRadius: 1.0,
              ),
            ],
          );
          break;
        case 'achievement':
          glowRadius = 10.0;
          glowColor = Colors.amber.withOpacity(0.6);
          iconDecoration = BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Colors.amber, Colors.orangeAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: glowRadius,
                spreadRadius: 2.0,
              ),
            ],
          );
          break;
        case 'warning':
          glowRadius = 8.0;
          glowColor = Colors.redAccent.withOpacity(0.5);
          iconDecoration = BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Colors.orangeAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: glowRadius,
                spreadRadius: 1.0,
              ),
            ],
          );
          break;
        case 'ai':
          glowRadius = 8.0;
          glowColor = themeMode.primary.withOpacity(0.5);
          iconDecoration = BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [themeMode.primary, Colors.blueAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: glowRadius,
                spreadRadius: 1.0,
              ),
            ],
          );
          break;
        case 'normal':
        default:
          iconDecoration = BoxDecoration(
            color: moduleColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: moduleColor.withOpacity(0.6),
              width: 1.5,
            ),
          );
          break;
      }
    }

    final isSharedEvent = event.workspaceType == 'shared';
    final actorName = isSharedEvent ? _getActorDisplayName(event.actorId, context) : null;

    final isTr = Localizations.localeOf(context).languageCode == 'tr';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50.0,
            child: Column(
              children: [
                Container(
                  width: 2.0,
                  height: 16.0,
                  color: themeMode.textSecondary.withOpacity(0.15),
                ),
                Container(
                  width: 34.0,
                  height: 34.0,
                  decoration: iconDecoration,
                  child: Center(
                    child: Opacity(
                      opacity: isDeleted ? 0.4 : 1.0,
                      child: Text(
                        event.icon,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2.0,
                    color: isLast ? Colors.transparent : themeMode.textSecondary.withOpacity(0.15),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
              child: Card(
                elevation: 0,
                color: isDeleted ? themeMode.surface.withOpacity(0.4) : themeMode.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: BorderSide(
                    color: isDeleted 
                        ? Colors.white10 
                        : themeMode.textSecondary.withOpacity(0.08),
                    width: 1.0,
                  ),
                ),
                child: Padding(
                  padding: isSummaryMode 
                      ? const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0)
                      : const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              event.title + (isDeleted ? (isTr ? ' (Silindi)' : ' (Deleted)') : ''),
                              style: TextStyle(
                                color: isDeleted ? themeMode.textSecondary.withOpacity(0.5) : themeMode.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isSummaryMode ? 14.0 : 15.0,
                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: themeMode.textSecondary.withOpacity(0.8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSummaryMode ? 4.0 : 8.0),
                      Text(
                        event.description,
                        maxLines: isSummaryMode ? 1 : null,
                        overflow: isSummaryMode ? TextOverflow.ellipsis : null,
                        style: TextStyle(
                          color: isDeleted 
                              ? themeMode.textSecondary.withOpacity(0.4) 
                              : themeMode.textPrimary.withOpacity(isSummaryMode ? 0.6 : 0.8),
                          fontSize: isSummaryMode ? 12.0 : 13.5,
                          height: isSummaryMode ? 1.2 : 1.4,
                          decoration: isDeleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      
                      if (isSharedEvent && !isSummaryMode) ...[
                        const SizedBox(height: 10.0),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: themeMode.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: themeMode.primary.withOpacity(0.2),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 12.0,
                                    color: themeMode.primary,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    actorName ?? '',
                                    style: TextStyle(
                                      color: themeMode.primary,
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getModuleColor(AppThemeMode themeMode, String module) {
    switch (module) {
      case 'finance':
        return themeMode.financeColor;
      case 'debts':
        return themeMode.debtColor;
      case 'notes':
      case 'reminders':
        return themeMode.noteColor;
      case 'goals':
        return themeMode.goalsColor;
      case 'health':
        return themeMode.healthColor;
      case 'medication':
        return themeMode.medicationColor;
      case 'smoking':
        return themeMode.smokingColor;
      case 'family':
      default:
        return themeMode.primary;
    }
  }

  String _formatEventTime(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    final timeStr = DateFormat('HH:mm').format(timestamp);

    if (eventDate == today) {
      return timeStr;
    } else if (eventDate == yesterday) {
      final yestLabel = Localizations.localeOf(context).languageCode == 'tr' ? 'Dün' : 'Yesterday';
      return '$yestLabel $timeStr';
    } else {
      return '${DateFormat('dd.MM.yyyy').format(timestamp)} $timeStr';
    }
  }

  String _getActorDisplayName(String actorId, BuildContext context) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final currentUser = ref.watch(authStateProvider).value;
    if (currentUser != null && actorId == currentUser.uid) {
      return isTr ? 'Siz' : 'You';
    }
    final spacesAsync = ref.watch(sharedSpacesProvider);
    return spacesAsync.when(
      data: (spaces) {
        for (var space in spaces) {
          for (var member in space.members) {
            if (member.uid == actorId) {
              return member.displayName;
            }
          }
        }
        return isTr ? 'Bir üye' : 'A member';
      },
      loading: () => '...',
      error: (_, __) => isTr ? 'Bir üye' : 'A member',
    );
  }
}
