import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
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
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_OrdersList(isActive: true), _OrdersList(isActive: false)],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final bool isActive;

  const _OrdersList({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final activeStatuses = [
      'pending',
      'confirmed',
      'rider_assigned',
      'out_for_delivery',
    ];
    final pastStatuses = ['delivered', 'cancelled'];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('customerId', isEqualTo: uid)
          .where('status', whereIn: isActive ? activeStatuses : pastStatuses)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context, isActive);
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final data = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;
            return _OrderCard(data: data, orderId: orderId);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isActive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Icon(
              isActive
                  ? Icons.delivery_dining_outlined
                  : Icons.receipt_long_outlined,
              color: AppTheme.textSecondary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isActive ? 'No active orders' : 'No past orders',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? 'Your active orders will appear here'
                : 'Your completed orders will appear here',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          if (isActive) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Order Now'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;

  const _OrderCard({required this.data, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final shops = data['shops'] as Map<String, dynamic>? ?? {};
    final createdAt = data['createdAt'] as Timestamp?;
    final statusConfig = _getStatusConfig(status);

    // Collect all item names
    final List<String> itemNames = [];
    for (final shop in shops.values) {
      final items = (shop as Map<String, dynamic>)['items'] as List? ?? [];
      for (final item in items) {
        itemNames.add(
          '${(item as Map<String, dynamic>)['name']} x${item['quantity']}',
        );
      }
    }

    return GestureDetector(
      onTap: () => context.push('/order/$orderId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Order ID + date
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

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (statusConfig['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusConfig['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusConfig['label'] as String,
                          style: TextStyle(
                            color: statusConfig['color'] as Color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.divider),

            // Items summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  // Shop count icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemNames.take(2).join(', ') +
                              (itemNames.length > 2
                                  ? ' +${itemNames.length - 2} more'
                                  : ''),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${shops.length} shop${shops.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Total + arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₦${(data['total'] as num).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppTheme.textSecondary,
                        size: 12,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Track button for active orders
            if (_isActive(status)) ...[
              const Divider(height: 1, color: AppTheme.divider),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusConfig['label'] as String,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Track Order →',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isActive(String status) {
    return [
      'pending',
      'confirmed',
      'rider_assigned',
      'out_for_delivery',
    ].contains(status);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return {'label': 'Order Placed', 'color': Colors.orange};
      case 'confirmed':
        return {'label': 'Confirmed', 'color': AppTheme.primary};
      case 'rider_assigned':
        return {'label': 'Rider Assigned', 'color': AppTheme.primary};
      case 'out_for_delivery':
        return {'label': 'On the Way', 'color': AppTheme.primary};
      case 'delivered':
        return {'label': 'Delivered', 'color': AppTheme.success};
      case 'cancelled':
        return {'label': 'Cancelled', 'color': AppTheme.error};
      default:
        return {'label': 'Processing', 'color': AppTheme.textSecondary};
    }
  }
}
