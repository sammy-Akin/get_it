import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/screens/vendor/vendor_earning_screen.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../map/location_picker_screen.dart';

class VendorProfileScreen extends StatelessWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'My Shop',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('getit_users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Shop header
              _buildShopHeader(user, data),
              const SizedBox(height: 24),

              // Stats row
              _buildStatsRow(uid),
              const SizedBox(height: 24),

              // Shop settings
              _buildSectionTitle('Shop Settings'),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.store_outlined,
                  label: 'Edit Shop Info',
                  onTap: () => _showEditShopSheet(context, uid, data),
                ),
                _MenuItem(
                  icon: Icons.schedule_rounded,
                  label: 'Shop Hours',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.payments_rounded,
                  label: 'Earnings & Withdrawals',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VendorEarningsScreen(),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              _buildSectionTitle('Account'),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About Get It',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 24),

              // Sign out
              _buildSignOutButton(context),
              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'Get It Vendor v1.0.0',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShopHeader(User? user, Map<String, dynamic> data) {
    final shopName = data['shopName'] ?? data['fullName'] ?? 'My Shop';
    final category = data['shopCategory'] ?? 'General';
    final location = data['location'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppTheme.primary,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppTheme.textSecondary,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '● Open',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
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

  Widget _buildStatsRow(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('status', whereIn: ['delivered'])
          .snapshots(),
      builder: (context, snapshot) {
        final orders = snapshot.data?.docs ?? [];
        final myOrders = orders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shops = data['shops'] as Map<String, dynamic>? ?? {};
          return shops.containsKey(uid);
        }).toList();

        double totalRevenue = 0;
        for (final doc in myOrders) {
          final data = doc.data() as Map<String, dynamic>;
          final shops = data['shops'] as Map<String, dynamic>? ?? {};
          final myShop = shops[uid] as Map<String, dynamic>? ?? {};
          final items = myShop['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            totalRevenue += (item as Map<String, dynamic>)['totalPrice'] as num;
          }
        }

        return Row(
          children: [
            _StatCard(
              label: 'Total Orders',
              value: '${myOrders.length}',
              icon: Icons.receipt_long_rounded,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Revenue',
              value: '₦${totalRevenue.toStringAsFixed(0)}',
              icon: Icons.payments_rounded,
              color: AppTheme.success,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return Column(
            children: [
              GestureDetector(
                onTap: item.onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.textSecondary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: AppTheme.divider, indent: 66),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmSignOut(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.error.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                color: AppTheme.error,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditShopSheet(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) {
    final nameCtrl = TextEditingController(
      text: data['shopName'] ?? data['fullName'] ?? '',
    );
    final locationCtrl = TextEditingController(text: data['location'] ?? '');
    final categoryCtrl = TextEditingController(
      text: data['shopCategory'] ?? '',
    );
    final descCtrl = TextEditingController(text: data['shopDescription'] ?? '');

    double? latResult = (data['latitude'] as num?)?.toDouble();
    double? lngResult = (data['longitude'] as num?)?.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Edit Shop Info',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
              decoration: const InputDecoration(
                hintText: 'Shop name',
                prefixIcon: Icon(
                  Icons.store_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setInnerState) => GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                        initialAddress: locationCtrl.text.isNotEmpty
                            ? locationCtrl.text
                            : null,
                      ),
                    ),
                  );
                  if (result != null) {
                    locationCtrl.text = result['address'] ?? '';
                    latResult = result['latitude'] as double?;
                    lngResult = result['longitude'] as double?;
                    setInnerState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          locationCtrl.text.isNotEmpty
                              ? locationCtrl.text
                              : 'Tap to set shop location on map',
                          style: TextStyle(
                            color: locationCtrl.text.isNotEmpty
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.textSecondary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryCtrl,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
              decoration: const InputDecoration(
                hintText: 'Category (e.g. Grocery, Food)',
                prefixIcon: Icon(
                  Icons.category_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'Poppins',
              ),
              decoration: const InputDecoration(
                hintText: 'Short description',
                prefixIcon: Icon(
                  Icons.notes_rounded,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('getit_users')
                      .doc(uid)
                      .update({
                        'shopName': nameCtrl.text.trim(),
                        'location': locationCtrl.text.trim(),
                        'shopCategory': categoryCtrl.text.trim(),
                        'shopDescription': descCtrl.text.trim(),
                      });
                  final vendorData = <String, dynamic>{
                    'id': uid,
                    'name': nameCtrl.text.trim(),
                    'location': locationCtrl.text.trim(),
                    'category': categoryCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'isOpen': true,
                    'imageUrl': '',
                    'rating': 5.0,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  if (latResult != null) vendorData['latitude'] = latResult!;
                  if (lngResult != null) vendorData['longitude'] = lngResult!;
                  await FirebaseFirestore.instance
                      .collection('getit_vendors')
                      .doc(uid)
                      .set(vendorData, SetOptions(merge: true));
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
