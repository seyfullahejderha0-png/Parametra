import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_constants.dart';

class AppConfig {
  final String appStoreUrl;
  final String playStoreUrl;
  final String webUrl;

  AppConfig({
    required this.appStoreUrl,
    required this.playStoreUrl,
    required this.webUrl,
  });

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      appStoreUrl: map['appStoreUrl'] ?? AppConstants.appStoreUrl,
      playStoreUrl: map['playStoreUrl'] ?? AppConstants.playStoreUrl,
      webUrl: map['webUrl'] ?? AppConstants.webUrl,
    );
  }
}

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('settings')
      .doc('app_config')
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      return AppConfig.fromMap(snapshot.data()!);
    }
    return AppConfig(
      appStoreUrl: AppConstants.appStoreUrl,
      playStoreUrl: AppConstants.playStoreUrl,
      webUrl: AppConstants.webUrl,
    );
  });
});
