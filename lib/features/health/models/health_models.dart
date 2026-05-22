import 'package:cloud_firestore/cloud_firestore.dart';

class WaterIntake {
  final String id;
  final double amount; // Liters
  final DateTime date;

  WaterIntake({required this.id, required this.amount, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory WaterIntake.fromMap(Map<String, dynamic> map) {
    return WaterIntake(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class Activity {
  final String id;
  final String type; // Running, Walking, etc.
  final int durationMinutes;
  final DateTime date;

  Activity({required this.id, required this.type, required this.durationMinutes, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'durationMinutes': durationMinutes,
      'date': date.toIso8601String(),
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 0,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class ActiveActivity {
  final String type;
  final DateTime startTime;
  final int? targetMinutes;

  ActiveActivity({
    required this.type,
    required this.startTime,
    this.targetMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'startTime': startTime.toIso8601String(),
      'targetMinutes': targetMinutes,
    };
  }

  factory ActiveActivity.fromMap(Map<String, dynamic> map) {
    return ActiveActivity(
      type: map['type'] ?? 'Yürüyüş',
      startTime: DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      targetMinutes: map['targetMinutes'],
    );
  }

  bool get isCountdown => targetMinutes != null;
  
  Duration get elapsed => DateTime.now().difference(startTime);
  
  Duration? get remaining {
    if (targetMinutes == null) return null;
    final target = Duration(minutes: targetMinutes!);
    final diff = target - elapsed;
    return diff.isNegative ? Duration.zero : diff;
  }
}
