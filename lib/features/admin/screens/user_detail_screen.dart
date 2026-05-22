import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/admin_user_model.dart';
import '../../subscription/models/subscription_model.dart';

class UserDetailScreen extends StatelessWidget {
  final AdminUserData user;

  const UserDetailScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

    final (pkgName, pkgColor) = switch (user.subscriptionType) {
      SubscriptionType.premium => ('Premium', Colors.blueAccent),
      SubscriptionType.platinum => ('Premium AI', Colors.purpleAccent),
      SubscriptionType.platinumFamily => ('Premium AI Aile', Colors.amber),
      SubscriptionType.trial => ('Trial (Deneme)', Colors.tealAccent),
      SubscriptionType.free => ('Ücretsiz Plan', Colors.white30),
    };

    final platformIcon = user.platform.toLowerCase() == 'ios'
        ? Icons.apple
        : (user.platform.toLowerCase() == 'web' ? Icons.language : Icons.android);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Kullanıcı Detayı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: pkgColor.withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(color: pkgColor, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: pkgColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pkgColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      pkgName,
                      style: TextStyle(color: pkgColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailSectionTitle('📋 GENEL BİLGİLER'),
            _buildInfoCard([
              _buildInfoRow('Kullanıcı ID', user.userId),
              _buildInfoRow('Platform', user.platform, icon: platformIcon),
              _buildInfoRow(
                'Son Giriş',
                user.lastLogin != null ? dateTimeFormat.format(user.lastLogin!) : 'Bilinmiyor',
              ),
            ]),
            const SizedBox(height: 24),
            _buildDetailSectionTitle('💎 ABONELİK BİLGİLERİ'),
            _buildInfoCard([
              _buildInfoRow('Abonelik Tipi', pkgName),
              _buildInfoRow('Faturalandırma Periyodu', user.billingCycleText),
              _buildInfoRow(
                'Başlangıç Tarihi',
                user.startDate != null ? dateFormat.format(user.startDate!) : '-',
              ),
              _buildInfoRow(
                'Bitiş Tarihi',
                user.endDate != null ? dateFormat.format(user.endDate!) : 'Sınırsız / Yok',
              ),
              _buildInfoRow(
                'Deneme (Trial) Kullanıldı mı?',
                user.subscriptionType == SubscriptionType.trial || user.subscriptionType != SubscriptionType.free
                    ? 'Evet'
                    : 'Hayır',
              ),
              _buildInfoRow(
                'Gönüllü Bağışçı / Destekçi',
                user.isSupporter ? 'Evet' : 'Hayır',
              ),
            ]),
            const SizedBox(height: 24),
            _buildDetailSectionTitle('🤖 YAPAY ZEKA KULLANIMI'),
            _buildInfoCard([
              _buildInfoRow('Bugünkü AI Kullanımı', '${user.dailyUsageCount} sorgu'),
              _buildInfoRow('Toplam AI Kullanımı', '${user.totalUsageCount} sorgu'),
              _buildInfoRow('Son 30 Gün Kullanım', '${user.totalUsageCount} sorgu'),
            ]),
            const SizedBox(height: 24),
            _buildDetailSectionTitle('🧩 AKTİF MODÜLLER'),
            _buildInfoCard([
              _buildInfoRow('Açık Olan Modüller', user.activeModules.isEmpty ? 'Aktif modül yok' : user.activeModules.join(', ')),
              _buildInfoRow('En Çok Kullanılan Modül', user.activeModules.isNotEmpty ? user.activeModules.first : '-'),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
