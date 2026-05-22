class SmokingData {
  final DateTime startDate;
  final int dailyQuantity;
  final double packetPrice;
  final int longestSmokeFreeSeconds;
  final Map<String, int> dailySmokedLogs; // ISO Date String -> Count

  SmokingData({
    required this.startDate,
    required this.dailyQuantity,
    required this.packetPrice,
    this.longestSmokeFreeSeconds = 0,
    this.dailySmokedLogs = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'dailyQuantity': dailyQuantity,
      'packetPrice': packetPrice,
      'longestSmokeFreeSeconds': longestSmokeFreeSeconds,
      'dailySmokedLogs': dailySmokedLogs,
    };
  }

  factory SmokingData.fromMap(Map<String, dynamic> map) {
    return SmokingData(
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      dailyQuantity: map['dailyQuantity'] ?? 0,
      packetPrice: (map['packetPrice'] ?? 0.0).toDouble(),
      longestSmokeFreeSeconds: map['longestSmokeFreeSeconds'] ?? 0,
      dailySmokedLogs: Map<String, int>.from(map['dailySmokedLogs'] ?? {}),
    );
  }

  SmokingData copyWith({
    DateTime? startDate,
    int? dailyQuantity,
    double? packetPrice,
    int? longestSmokeFreeSeconds,
    Map<String, int>? dailySmokedLogs,
  }) {
    return SmokingData(
      startDate: startDate ?? this.startDate,
      dailyQuantity: dailyQuantity ?? this.dailyQuantity,
      packetPrice: packetPrice ?? this.packetPrice,
      longestSmokeFreeSeconds: longestSmokeFreeSeconds ?? this.longestSmokeFreeSeconds,
      dailySmokedLogs: dailySmokedLogs ?? this.dailySmokedLogs,
    );
  }
}
