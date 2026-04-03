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

    // Fetch all customer orders then filter client-side
    // This avoids needing a composite index for whereIn + orderBy
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('customerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context);
        }

        final activeStatuses = [
          'pending',
          'pending_payment',
          'confirmed',
          'rider_assigned',
          'out_for_delivery',
        ];
        final pastStatuses = ['delivered', 'cancelled'];

        final allOrders = snapshot.data!.docs;

        // Filter & sort client-side
        final filtered = allOrders.where((doc) {
          final status =
              (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
          return isActive
              ? activeStatuses.contains(status)
              : pastStatuses.contains(status);
        }).toList();

        // Sort by createdAt descending
        filtered.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (filtered.isEmpty) return _buildEmptyState(context);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final data = filtered[index].data() as Map<String, dynamic>;
            final orderId = filtered[index].id;
            return _OrderCard(data: data, orderId: orderId);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                : 'Completed orders will show up here',
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
    final total = (data['total'] as num?)?.toStringAsFixed(0) ?? '0';

    // Collect all item names
    final List<String> itemNames = [];
    int totalItems = 0;
    for (final shop in shops.values) {
      final items = (shop as Map<String, dynamic>)['items'] as List? ?? [];
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        itemNames.add('${m['name']}');
        totalItems += (m['quantity'] as num).toInt();
      }
    }

    final isActive = _isActiveStatus(status);

    return GestureDetector(
      onTap: () => context.push('/order/$orderId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withOpacity(0.3)
                : AppTheme.cardBorder,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // Header row
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

            // Items + total
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primary.withOpacity(0.1)
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isActive
                          ? Icons.delivery_dining_rounded
                          : Icons.shopping_bag_outlined,
                      color: isActive
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      size: 22,
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
                          '$totalItems item${totalItems > 1 ? 's' : ''} · ${shops.length} shop${shops.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₦$total',
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

            // Active order footer — track button
            if (isActive) ...[
              const Divider(height: 1, color: AppTheme.divider),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        color: AppTheme.primary,
                        size: 14,
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
              ),
            ],

            // Delivered — reorder button
            if (status == 'delivered') ...[
              const Divider(height: 1, color: AppTheme.divider),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.success,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Delivered',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: const Text(
                        'Order Again →',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
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

  bool _isActiveStatus(String status) => [
    'pending',
    'pending_payment',
    'confirmed',
    'rider_assigned',
    'out_for_delivery',
  ].contains(status);

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending_payment':
        return {'label': 'Payment Pending', 'color': Colors.orange};
      case 'pending':
        return {'label': 'Order Placed', 'color': Colors.orange};
      case 'confirmed':
        return {'label': 'Confirmed', 'color': AppTheme.primary};
      case 'rider_assigned':
        return {'label': 'Rider Assigned', 'color': AppTheme.primary};
      case 'out_for_delivery':
        return {'label': 'On the Way 🚀', 'color': AppTheme.primary};
      case 'delivered':
        return {'label': 'Delivered', 'color': AppTheme.success};
      case 'cancelled':
        return {'label': 'Cancelled', 'color': AppTheme.error};
      default:
        return {'label': 'Processing', 'color': AppTheme.textSecondary};
    }
  }
}
