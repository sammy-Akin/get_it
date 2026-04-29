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
            Tab(text: 'Waiting'),
            Tab(text: 'My Deliveries'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WaitingForAssignment(pickerId: _uid),
          _MyDeliveries(pickerId: _uid),
        ],
      ),
    );
  }
}

// ─── Waiting tab — replaces the old _AvailableDeliveries ─────────────────────
// Pickers are assigned by the vendor, NOT by self-selecting from a list.
// This tab shows a clear waiting state so the picker knows what to expect.

class _WaitingForAssignment extends StatelessWidget {
  final String pickerId;
  const _WaitingForAssignment({required this.pickerId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                color: AppTheme.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Waiting for assignment',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You will receive a notification when a vendor assigns a delivery to you. Make sure you are marked as Available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontFamily: 'Poppins',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── My Deliveries tab ────────────────────────────────────────────────────────

class _MyDeliveries extends StatelessWidget {
  final String pickerId;
  const _MyDeliveries({required this.pickerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('pickerId', isEqualTo: pickerId) // ✅ was 'riderId' — fixed
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint(
          '📦 MyDeliveries snapshot: ${snapshot.data?.docs.length} docs for pickerId=$pickerId',
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmpty(
            'No active deliveries',
            'Accepted deliveries will appear here',
            Icons.inbox_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            debugPrint(
              '📋 Delivery card — orderId: ${docs[index].id}, status: ${data['status']}',
            );
            return _DeliveryCard(
              orderId: docs[index].id,
              data: data,
              pickerId: pickerId,
            );
          },
        );
      },
    );
  }
}

// ─── Delivery Card ────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final String pickerId;

  const _DeliveryCard({
    required this.orderId,
    required this.data,
    required this.pickerId,
  });

  /// Updates the top-level order status AND all shop-level statuses so the
  /// vendor screen reflects the correct state in real time.
  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    debugPrint(
      '🔄 _updateStatus called: orderId=$orderId, newStatus=$newStatus',
    );
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('getit_orders')
          .doc(orderId);

      final doc = await orderRef.get();
      final shops = (doc.data()?['shops'] as Map<String, dynamic>?) ?? {};

      final Map<String, dynamic> updates = {'status': newStatus};

      if (newStatus == 'out_for_delivery') {
        for (final shopId in shops.keys) {
          updates['shops.$shopId.status'] = 'picked_up';
        }
      }

      if (newStatus == 'delivered') {
        updates['deliveredAt'] = FieldValue.serverTimestamp();
        for (final shopId in shops.keys) {
          updates['shops.$shopId.status'] = 'picked_up';
        }
      }

      await orderRef.update(updates);
      debugPrint('✅ Order $orderId updated to: $newStatus');

      if (newStatus == 'delivered') {
        await FirebaseFirestore.instance
            .collection('getit_riders')
            .doc(pickerId)
            .update({
              'currentOrderId': '',
              'isAvailable': true, // ← reset to available after delivery
              'totalDeliveries': FieldValue.increment(1),
              'totalEarnings': FieldValue.increment(150),
            });
        debugPrint('✅ Picker freed up and set available after delivery');
      }
    } catch (e) {
      debugPrint('🚨 _updateStatus error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
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
                Row(
                  children: [
                    _buildStatusBadge(status),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₦${(data['pickerEarning'] as num?)?.toStringAsFixed(0) ?? '150'}',
                        style: const TextStyle(
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

          // ── Shops ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                        if (shopStatus == 'ready' || shopStatus == 'picked_up')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              shopStatus == 'picked_up' ? 'Picked Up' : 'Ready',
                              style: const TextStyle(
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

          // ── Action button ─────────────────────────────────────────
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
      case 'assigned':
      case 'picked_up':
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
    switch (status) {
      case 'assigned':
      case 'picked_up':
        // ✅ Picker taps this to confirm they have physically collected the order
        return ElevatedButton(
          onPressed: () => _updateStatus(context, 'out_for_delivery'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delivery_dining_rounded,
                size: 18,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Picked Up — Start Delivery',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case 'out_for_delivery':
        return ElevatedButton(
          onPressed: () => _updateStatus(context, 'delivered'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            backgroundColor: AppTheme.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Mark as Delivered',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: const Center(
            child: Text(
              '✓ Delivered — Earnings credited',
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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── Empty state helper ───────────────────────────────────────────────────────

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
