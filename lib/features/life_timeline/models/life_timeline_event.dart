import 'package:cloud_firestore/cloud_firestore.dart';

class LifeTimelineEvent {
  final String id;
  final DateTime timestamp;
  final String module; // 'finance', 'goals', 'health', 'notes', 'reminders', 'family', 'ai'
  final String title;
  final String description;
  final String actorId;
  final String workspaceType; // 'personal' or 'shared'
  final String icon; // Emoji or Icon name
  final Map<String, dynamic>? metadata;
  final String eventType; // 'normal', 'milestone', 'achievement', 'warning', 'ai'
  final bool isDeleted;

  LifeTimelineEvent({
    required this.id,
    required this.timestamp,
    required this.module,
    required this.title,
    required this.description,
    required this.actorId,
    required this.workspaceType,
    required this.icon,
    this.metadata,
    this.eventType = 'normal',
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': Timestamp.fromDate(timestamp),
      'module': module,
      'title': title,
      'description': description,
      'actorId': actorId,
      'workspaceType': workspaceType,
      'icon': icon,
      'metadata': metadata,
      'eventType': eventType,
      'isDeleted': isDeleted,
    };
  }

  factory LifeTimelineEvent.fromMap(Map<String, dynamic> map) {
    DateTime ts;
    if (map['timestamp'] is Timestamp) {
      ts = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is String) {
      ts = DateTime.parse(map['timestamp']);
    } else {
      ts = DateTime.now();
    }

    return LifeTimelineEvent(
      id: map['id'] ?? '',
      timestamp: ts,
      module: map['module'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      actorId: map['actorId'] ?? '',
      workspaceType: map['workspaceType'] ?? 'personal',
      icon: map['icon'] ?? '🕒',
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
      eventType: map['eventType'] ?? 'normal',
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}
