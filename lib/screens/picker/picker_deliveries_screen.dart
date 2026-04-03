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

class _AvailableDeliveries extends StatelessWidget {
  final String pickerId;
  const _AvailableDeliveries({required this.pickerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('status', isEqualTo: 'ready_for_pickup')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        // Filter out orders already assigned to a picker
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['riderId'] == null || data['riderId'] == '';
        }).toList();

        if (docs.isEmpty) {
          return _buildEmpty(
            'No available deliveries',
            'Orders ready for pickup will appear here',
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

class _MyDeliveries extends StatelessWidget {
  final String pickerId;
  const _MyDeliveries({required this.pickerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('riderId', isEqualTo: pickerId)
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

  Future<void> _acceptDelivery(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('getit_orders')
        .doc(orderId)
        .update({
          'riderId': pickerId,
          'riderName': user?.displayName ?? 'Picker',
          'status': 'rider_assigned',
        });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Delivery accepted! ₦150 will be credited on completion.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _updateStatus(String status) async {
    final update = <String, dynamic>{'status': status};
    if (status == 'delivered') {
      update['deliveredAt'] = FieldValue.serverTimestamp();
    }
    await FirebaseFirestore.instance
        .collection('getit_orders')
        .doc(orderId)
        .update(update);
  }

  @override
  Widget build(BuildContext context) {
    final shops = data['shops'] as Map<String, dynamic>? ?? {};
    final status = data['status'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

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
                // Status + Incentive
                Row(
                  children: [
                    if (!isAvailable) ...[
                      _buildStatusBadge(status),
                      const SizedBox(width: 8),
                    ],
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
                  final shopStatus = shop['status'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.primary,
                            size: 18,
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
                        if (shopStatus == 'ready')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Ready',
                              style: TextStyle(
                                color: AppTheme.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
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
                        data['deliveryAddress'] ?? 'Address not set',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),

                // Order total
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order Total',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      '₦${(data['total'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildActionButton(context, status),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'rider_assigned':
        color = Colors.orange;
        label = 'Assigned';
        break;
      case 'out_for_delivery':
        color = AppTheme.primary;
        label = 'On the way';
        break;
      case 'delivered':
        color = AppTheme.success;
        label = 'Delivered';
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String status) {
    if (isAvailable) {
      return ElevatedButton(
        onPressed: () => _acceptDelivery(context),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Accept Delivery — Earn ₦150',
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delivery_dining_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'Picked Up — Start Delivery',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
              ),
            ],
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 18),
              SizedBox(width: 8),
              Text(
                'Mark as Delivered',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
              ),
            ],
          ),
        );
      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
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
