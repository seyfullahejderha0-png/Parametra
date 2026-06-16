import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

final externalHealthServiceProvider = Provider((ref) => ExternalHealthService(ref));

class ExternalHealthService {
  final Ref _ref;

  ExternalHealthService(this._ref);

  Future<bool> authorize() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) return false;
    }
    return false;
  }

  Future<bool> hasPermissions() async {
    return false;
  }

  Future<List<dynamic>> fetchHealthData() async {
    return [];
  }

  Future<double> getWaterToday() async {
    return 0.0;
  }
}
