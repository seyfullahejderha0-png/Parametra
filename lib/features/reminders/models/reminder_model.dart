enum ReminderRepeatType {
  once,
  daily,
  specificDays,
  customDate,
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime; // Used for once & customDate
  final String timeOfDay; // "HH:mm" format, used for daily & specificDays
  final ReminderRepeatType repeatType;
  final List<int> specificDays; // 1: Mon, 2: Tue, ..., 7: Sun
  final bool isActive;
  final bool isCompleted;
  final String categoryIcon; // e.g. 💊, 🏃, 🔔, 💧
  final String moduleType; // 'general', 'medicine', 'water', 'sport', 'smoking', 'ai'
  final int notificationId;

  Reminder({
    required this.id,
    required this.title,
    this.description = '',
    required this.dateTime,
    required this.timeOfDay,
    required this.repeatType,
    this.specificDays = const [],
    this.isActive = true,
    this.isCompleted = false,
    this.categoryIcon = '🔔',
    this.moduleType = 'general',
    required this.notificationId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'timeOfDay': timeOfDay,
      'repeatType': repeatType.name,
      'specificDays': specificDays,
      'isActive': isActive,
      'isCompleted': isCompleted,
      'categoryIcon': categoryIcon,
      'moduleType': moduleType,
      'notificationId': notificationId,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dateTime: DateTime.parse(map['dateTime'] ?? DateTime.now().toIso8601String()),
      timeOfDay: map['timeOfDay'] ?? '08:00',
      repeatType: ReminderRepeatType.values.firstWhere(
        (e) => e.name == map['repeatType'],
        orElse: () => ReminderRepeatType.once,
      ),
      specificDays: List<int>.from(map['specificDays'] ?? []),
      isActive: map['isActive'] ?? true,
      isCompleted: map['isCompleted'] ?? false,
      categoryIcon: map['categoryIcon'] ?? '🔔',
      moduleType: map['moduleType'] ?? 'general',
      notificationId: map['notificationId'] ?? 0,
    );
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    String? timeOfDay,
    ReminderRepeatType? repeatType,
    List<int>? specificDays,
    bool? isActive,
    bool? isCompleted,
    String? categoryIcon,
    String? moduleType,
    int? notificationId,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      repeatType: repeatType ?? this.repeatType,
      specificDays: specificDays ?? this.specificDays,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      moduleType: moduleType ?? this.moduleType,
      notificationId: notificationId ?? this.notificationId,
    );
  }
}
