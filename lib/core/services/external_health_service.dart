import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

final externalHealthServiceProvider = Provider((ref) => ExternalHealthService(ref));

class ExternalHealthService {
  final Ref _ref;
  final Health _health = Health();

  ExternalHealthService(this._ref);

  static const List<HealthDataType> _types = [
    HealthDataType.WATER,
  ];

  Future<bool> authorize() async {
    // 1. İzinleri kontrol et
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return false;
    }

    // 2. Health Kit / Health Connect yetkilendirmesi
    bool? hasPermissions = await _health.hasPermissions(_types);
    if (hasPermissions == false) {
      try {
        hasPermissions = await _health.requestAuthorization(_types);
      } catch (e) {
        print("Health Auth Error: $e");
        return false;
      }
    }
    return hasPermissions ?? false;
  }

  Future<bool> hasPermissions() async {
    try {
      bool? hasPermissions = await _health.hasPermissions(_types);
      return hasPermissions ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<List<HealthDataPoint>> fetchHealthData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    try {
      final dataPoints = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: _types,
      );
      return _health.removeDuplicates(dataPoints);
    } catch (e) {
      print("Health Fetch Error: $e");
      return [];
    }
  }



  Future<double> getWaterToday() async {
    // Health Connect/Kit'ten su verisi çekme
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.WATER],
      );
      
      double total = 0;
      for (var p in data) {
        final val = p.value as NumericHealthValue;
        total += val.numericValue.toDouble();
      }
      return total;
    } catch (e) {
      return 0;
    }
  }
}
