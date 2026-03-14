import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          'Orders',
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
            Tab(text: 'New'),
            Tab(text: 'Active'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrdersList(vendorId: _uid!, statusFilter: ['pending']),
          _OrdersList(
            vendorId: _uid!,
            statusFilter: ['confirmed', 'rider_assigned', 'out_for_delivery'],
          ),
          _OrdersList(
            vendorId: _uid!,
            statusFilter: ['delivered', 'cancelled'],
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final String vendorId;
  final List<String> statusFilter;

  const _OrdersList({required this.vendorId, required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('status', whereIn: statusFilter)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        // Filter orders that contain this vendor's shop
        final allDocs = snapshot.data?.docs ?? [];
        final vendorOrders = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shops = data['shops'] as Map<String, dynamic>? ?? {};
          return shops.containsKey(vendorId);
        }).toList();

        if (vendorOrders.isEmpty) {
          return _buildEmpty(statusFilter.first);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vendorOrders.length,
          itemBuilder: (context, index) {
            final doc = vendorOrders[index];
            final data = doc.data() as Map<String, dynamic>;
            return _VendorOrderCard(
              orderId: doc.id,
              data: data,
              vendorId: vendorId,
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty(String status) {
    final isNew = status == 'pending';
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
            child: Icon(
              isNew
                  ? Icons.notifications_none_rounded
                  : Icons.receipt_long_outlined,
              color: AppTheme.textSecondary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isNew ? 'No new orders' : 'Nothing here yet',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isNew ? 'New orders will appear here' : 'Orders will show up here',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final String vendorId;

  const _VendorOrderCard({
    required this.orderId,
    required this.data,
    required this.vendorId,
  });

  Future<void> _updateShopStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('getit_orders')
        .doc(orderId)
        .update({'shops.$vendorId.status': status});

    // If confirmed, check if all shops confirmed → update order status
    if (status == 'confirmed') {
      final doc = await FirebaseFirestore.instance
          .collection('getit_orders')
          .doc(orderId)
          .get();
      final shops = (doc.data()?['shops'] as Map<String, dynamic>?) ?? {};
      final allConfirmed = shops.values.every(
        (s) => (s as Map)['status'] == 'confirmed',
      );
      if (allConfirmed) {
        await FirebaseFirestore.instance
            .collection('getit_orders')
            .doc(orderId)
            .update({'status': 'confirmed'});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = data['shops'] as Map<String, dynamic>? ?? {};
    final myShop = shops[vendorId] as Map<String, dynamic>? ?? {};
    final items = myShop['items'] as List<dynamic>? ?? [];
    final shopStatus = myShop['status'] ?? 'pending';
    final createdAt = data['createdAt'] as Timestamp?;
    final isPending = shopStatus == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? AppTheme.primary.withOpacity(0.4)
              : AppTheme.cardBorder,
          width: isPending ? 1.5 : 1,
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
                _buildStatusBadge(shopStatus),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.divider),

          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...items.map((item) {
                  final i = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${i['quantity']}x',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              i['name'] ?? '',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₦${(i['totalPrice'] as num).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Delivery address
                const Divider(color: AppTheme.divider),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data['deliveryAddress'] ?? '',
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
            ),
          ),

          // Action buttons for pending orders
          if (isPending) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateShopStatus('cancelled'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: const BorderSide(color: AppTheme.error),
                        foregroundColor: AppTheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _updateShopStatus('confirmed'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Accept Order',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Mark ready button for confirmed orders
          if (shopStatus == 'confirmed') ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () => _updateShopStatus('ready'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: AppTheme.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Mark as Ready',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'New Order';
        break;
      case 'confirmed':
        color = AppTheme.primary;
        label = 'Preparing';
        break;
      case 'ready':
        color = AppTheme.success;
        label = 'Ready';
        break;
      case 'picked_up':
        color = AppTheme.success;
        label = 'Picked Up';
        break;
      case 'cancelled':
        color = AppTheme.error;
        label = 'Rejected';
        break;
      default:
        color = AppTheme.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
