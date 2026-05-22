import 'package:flutter/material.dart';
import '../models/admin_user_model.dart';
import '../widgets/user_card.dart';
import 'user_detail_screen.dart';
import '../../subscription/models/subscription_model.dart';

class PremiumUsersScreen extends StatefulWidget {
  final String initialFilter;
  final List<AdminUserData> users;

  const PremiumUsersScreen({
    super.key,
    required this.initialFilter,
    required this.users,
  });

  @override
  State<PremiumUsersScreen> createState() => _PremiumUsersScreenState();
}

class _PremiumUsersScreenState extends State<PremiumUsersScreen> {
  late String _selectedFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = widget.users.where((user) {
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      return switch (_selectedFilter) {
        'Tümü' => true,
        'Premium' => user.subscriptionType == SubscriptionType.premium,
        'Premium AI' => user.subscriptionType == SubscriptionType.platinum || user.subscriptionType == SubscriptionType.platinumFamily,
        'Trial' => user.subscriptionType == SubscriptionType.trial,
        'Süresi Yaklaşan' => user.isSubExpiringSoon,
        'Süresi Dolmuş' => user.isSubExpired,
        'Destekçiler' => user.isSupporter,
        _ => true,
      };
    }).toList();

    final tabs = ['Tümü', 'Premium', 'Premium AI', 'Trial', 'Destekçiler', 'Süresi Yaklaşan', 'Süresi Dolmuş'];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Kullanıcı Listesi ($_selectedFilter)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'İsim veya e-posta ile ara...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white30),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white30),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: tabs.map((tab) {
                final isSelected = _selectedFilter == tab;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(
                      tab,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent,
                    backgroundColor: const Color(0xFF1E293B),
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = tab);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 48, color: Colors.white10),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'Aramayla eşleşen kullanıcı bulunamadı.' : 'Bu filtreye uygun kullanıcı yok.',
                          style: const TextStyle(color: Colors.white30, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return UserCard(
                        user: user,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailScreen(user: user),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
