import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';

class PickerDeliveriesScreen extends StatefulWidget {
  const PickerDeliveriesScreen({super.key});

  @override
  State<PickerDeliveriesScreen> createState() => _PickerDeliveriesScreenState();
}

class _PickerDeliveriesScreenState extends State<PickerDeliveriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'Deliveries',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'My Deliveries'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AvailableDeliveries(pickerId: _uid),
          _MyDeliveries(pickerId: _uid),
        ],
      ),
    );
  }
}

// Available orders (confirmed by all shops, no rider yet)
class _AvailableDeliveries extends StatelessWidget {
  final String pickerId;
  const _AvailableDeliveries({required this.pickerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('status', isEqualTo: 'confirmed')
          .where('riderId', isNull: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmpty(
            'No available deliveries',
            'New orders will appear here when shops confirm them',
            Icons.delivery_dining_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _DeliveryCard(
              orderId: docs[index].id,
              data: data,
              pickerId: pickerId,
              isAvailable: true,
            );
          },
        );
      },
    );
  }
}

// Orders this picker has accepted
class _MyDeliveries extends StatelessWidget {
  final String pickerId;
  const _MyDeliveries({required this.pickerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('riderId', isEqualTo: pickerId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmpty(
            'No active deliveries',
            'Accept a delivery from the Available tab',
            Icons.inbox_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _DeliveryCard(
              orderId: docs[index].id,
              data: data,
              pickerId: pickerId,
              isAvailable: false,
            );
          },
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final String pickerId;
  final bool isAvailable;

  const _DeliveryCard({
    required this.orderId,
    required this.data,
    required this.pickerId,
    required this.isAvailable,
  });

  Future<void> _acceptDelivery() async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('getit_orders')
        .doc(orderId)
        .update({
          'riderId': pickerId,
          'riderName': user?.displayName ?? 'Picker',
          'status': 'rider_assigned',
        });
  }

  Future<void> _updateStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('getit_orders')
        .doc(orderId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    final shops = data['shops'] as Map<String, dynamic>? ?? {};
    final status = data['status'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    // Count total items
    int totalItems = 0;
    for (final shop in shops.values) {
      final items = (shop as Map<String, dynamic>)['items'] as List? ?? [];
      totalItems += items.length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable
              ? AppTheme.primary.withOpacity(0.4)
              : AppTheme.cardBorder,
          width: isAvailable ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${orderId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt.toDate()),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),
                  ],
                ),
                // Incentive badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '₦150',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.divider),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Shops to pick up from
                ...shops.entries.map((entry) {
                  final shop = entry.value as Map<String, dynamic>;
                  final shopName = shop['shopName'] ?? 'Shop';
                  final items = shop['items'] as List? ?? [];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.primary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                '${items.length} item(s)',
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
                  );
                }),

                const Divider(color: AppTheme.divider),

                // Delivery address
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data['deliveryAddress'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if ((data['landmark'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Near ${data['landmark']}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildActionButton(status),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String status) {
    if (isAvailable) {
      return ElevatedButton(
        onPressed: _acceptDelivery,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Accept Delivery',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
      );
    }

    switch (status) {
      case 'rider_assigned':
        return ElevatedButton(
          onPressed: () => _updateStatus('out_for_delivery'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Picked Up — Start Delivery',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
        );
      case 'out_for_delivery':
        return ElevatedButton(
          onPressed: () => _updateStatus('delivered'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            backgroundColor: AppTheme.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Mark as Delivered',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
        );
      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text(
              '✓ Delivered — ₦150 earned',
              style: TextStyle(
                color: AppTheme.success,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

Widget _buildEmpty(String title, String subtitle, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    ),
  );
}
