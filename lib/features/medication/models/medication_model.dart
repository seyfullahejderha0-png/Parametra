class Medication {
  final String id;
  final String name;
  final String personName;
  final String dosage;
  final List<String> scheduleTimes; // Multiple times e.g., ["08:00", "14:00", "20:00"]
  final String description;
  final bool isTok;
  final DateTime dateCreated;
  final int totalDays; // How many days to use
  final DateTime startDate; // When to start
  final int timesPerDay;

  Medication({
    required this.id,
    required this.name,
    required this.personName,
    required this.dosage,
    required this.scheduleTimes,
    required this.description,
    required this.isTok,
    required this.dateCreated,
    this.totalDays = 1,
    required this.startDate,
    this.timesPerDay = 1,
  });

  // Calculate remaining days
  int get remainingDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final diff = today.difference(start).inDays;
    final remaining = totalDays - diff;
    return remaining > 0 ? remaining : 0;
  }

  bool get isStarted {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return today.isAtSameMomentAs(start) || today.isAfter(start);
  }

  bool get isActiveToday {
    return isStarted && remainingDays > 0;
  }

  double get progress {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final diff = today.difference(start).inDays;
    if (diff <= 0) return 0.0;
    if (diff >= totalDays) return 1.0;
    return diff / totalDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'personName': personName,
      'dosage': dosage,
      'scheduleTimes': scheduleTimes,
      'description': description,
      'isTok': isTok,
      'dateCreated': dateCreated.toIso8601String(),
      'totalDays': totalDays,
      'startDate': startDate.toIso8601String(),
      'timesPerDay': timesPerDay,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      personName: map['personName'] ?? '',
      dosage: map['dosage'] ?? '',
      scheduleTimes: List<String>.from(map['scheduleTimes'] ?? []),
      description: map['description'] ?? '',
      isTok: map['isTok'] ?? true,
      dateCreated: DateTime.parse(map['dateCreated'] ?? DateTime.now().toIso8601String()),
      totalDays: map['totalDays'] ?? 1,
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      timesPerDay: map['timesPerDay'] ?? 1,
    );
  }

  Medication copyWith({
    String? id,
    String? name,
    String? personName,
    String? dosage,
    List<String>? scheduleTimes,
    String? description,
    bool? isTok,
    DateTime? dateCreated,
    int? totalDays,
    DateTime? startDate,
    int? timesPerDay,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      personName: personName ?? this.personName,
      dosage: dosage ?? this.dosage,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      description: description ?? this.description,
      isTok: isTok ?? this.isTok,
      dateCreated: dateCreated ?? this.dateCreated,
      totalDays: totalDays ?? this.totalDays,
      startDate: startDate ?? this.startDate,
      timesPerDay: timesPerDay ?? this.timesPerDay,
    );
  }
}

class MedicationLog {
  final String id;
  final String medicationId;
  final String medicationName;
  final DateTime takenDate;
  final String scheduledTime;

  MedicationLog({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.takenDate,
    required this.scheduledTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'takenDate': takenDate.toIso8601String(),
      'scheduledTime': scheduledTime,
    };
  }

  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      id: map['id'] ?? '',
      medicationId: map['medicationId'] ?? '',
      medicationName: map['medicationName'] ?? '',
      takenDate: DateTime.parse(map['takenDate'] ?? DateTime.now().toIso8601String()),
      scheduledTime: map['scheduledTime'] ?? '',
    );
  }
}

