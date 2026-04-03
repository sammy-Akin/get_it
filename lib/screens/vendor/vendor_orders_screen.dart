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
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
          _VendorOrdersList(
            vendorId: _uid,
            shopStatuses: const ['pending'],
            emptyMessage: 'No new orders',
            emptySubtext: 'New orders will appear here',
            emptyIcon: Icons.notifications_none_rounded,
          ),
          _VendorOrdersList(
            vendorId: _uid,
            shopStatuses: const ['confirmed', 'ready'],
            emptyMessage: 'No active orders',
            emptySubtext: 'Accepted orders will show here',
            emptyIcon: Icons.storefront_outlined,
          ),
          _VendorOrdersList(
            vendorId: _uid,
            shopStatuses: const ['picked_up', 'cancelled'],
            emptyMessage: 'No completed orders',
            emptySubtext: 'Fulfilled orders will show here',
            emptyIcon: Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }
}

class _VendorOrdersList extends StatelessWidget {
  final String vendorId;
  final List<String> shopStatuses;
  final String emptyMessage;
  final String emptySubtext;
  final IconData emptyIcon;

  const _VendorOrdersList({
    required this.vendorId,
    required this.shopStatuses,
    required this.emptyMessage,
    required this.emptySubtext,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    // ── KEY FIX ──────────────────────────────────────────────────────────────
    // Removed .orderBy('createdAt') because combining it with
    // .where('paymentStatus') requires a composite Firestore index.
    // Without the index the query silently returns nothing.
    // We sort client-side instead — same result, no index needed.
    // ─────────────────────────────────────────────────────────────────────────
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('getit_orders')
          .where('paymentStatus', isEqualTo: 'paid')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Filter: must contain this vendor AND shop status matches
        final vendorOrders = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shops = data['shops'] as Map<String, dynamic>? ?? {};
          if (!shops.containsKey(vendorId)) return false;
          final myShop = shops[vendorId] as Map<String, dynamic>? ?? {};
          final shopStatus = myShop['status'] ?? 'pending';
          return shopStatuses.contains(shopStatus);
        }).toList();

        // Sort client-side by createdAt descending
        vendorOrders.sort((a, b) {
          final aT = (a.data() as Map)['createdAt'] as Timestamp?;
          final bT = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aT == null || bT == null) return 0;
          return bT.compareTo(aT);
        });

        if (vendorOrders.isEmpty) {
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
                    emptyIcon,
                    color: AppTheme.textSecondary,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  emptySubtext,
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
}

class _VendorOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final String vendorId;

  const _VendorOrderCard({
    required this.orderId,
    required this.data,
    required this.vendorId,
  });

  @override
  State<_VendorOrderCard> createState() => _VendorOrderCardState();
}

class _VendorOrderCardState extends State<_VendorOrderCard> {
  bool _isUpdating = false;

  Future<void> _updateShopStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final orderRef = firestore.collection('getit_orders').doc(widget.orderId);

      await orderRef.update({'shops.${widget.vendorId}.status': newStatus});

      if (newStatus == 'confirmed') {
        final shops = widget.data['shops'] as Map<String, dynamic>? ?? {};
        final myShop = shops[widget.vendorId] as Map<String, dynamic>? ?? {};
        final items = myShop['items'] as List<dynamic>? ?? [];

        final batch = firestore.batch();
        for (final item in items) {
          final i = item as Map<String, dynamic>;
          final productId = i['productId'] as String?;
          final quantity = (i['quantity'] as num).toInt();
          if (productId != null) {
            batch.update(
              firestore.collection('getit_products').doc(productId),
              {'stockQty': FieldValue.increment(-quantity)},
            );
          }
        }
        await batch.commit();

        for (final item in items) {
          final i = item as Map<String, dynamic>;
          final productId = i['productId'] as String?;
          if (productId != null) {
            final productDoc = await firestore
                .collection('getit_products')
                .doc(productId)
                .get();
            final newQty =
                (productDoc.data()?['stockQty'] as num?)?.toInt() ?? 0;
            if (newQty <= 0) {
              await firestore
                  .collection('getit_products')
                  .doc(productId)
                  .update({'isAvailable': false, 'stockQty': 0});
            }
          }
        }

        final freshDoc = await orderRef.get();
        final allShops =
            (freshDoc.data()?['shops'] as Map<String, dynamic>?) ?? {};
        final allConfirmed = allShops.values.every(
          (s) => (s as Map<String, dynamic>)['status'] == 'confirmed',
        );
        if (allConfirmed) {
          await orderRef.update({'status': 'confirmed'});
        }
      }

      if (newStatus == 'cancelled') {
        await orderRef.update({'status': 'cancelled'});
      }

      if (newStatus == 'ready') {
        final freshDoc = await orderRef.get();
        final allShops =
            (freshDoc.data()?['shops'] as Map<String, dynamic>?) ?? {};
        final allReady = allShops.values.every(
          (s) => (s as Map<String, dynamic>)['status'] == 'ready',
        );
        if (allReady) {
          await orderRef.update({'status': 'ready_for_pickup'});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reject Order?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'The customer will be notified. This cannot be undone.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateShopStatus('cancelled');
            },
            child: const Text(
              'Reject',
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

  @override
  Widget build(BuildContext context) {
    final shops = widget.data['shops'] as Map<String, dynamic>? ?? {};
    final myShop = shops[widget.vendorId] as Map<String, dynamic>? ?? {};
    final items = myShop['items'] as List<dynamic>? ?? [];
    final shopStatus = myShop['status'] ?? 'pending';
    final createdAt = widget.data['createdAt'] as Timestamp?;
    final isPending = shopStatus == 'pending';
    final isConfirmed = shopStatus == 'confirmed';

    double myTotal = 0;
    for (final item in items) {
      myTotal += (item as Map<String, dynamic>)['totalPrice'] as num;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? Colors.orange.withOpacity(0.5)
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
                      '#${widget.orderId.substring(0, 8).toUpperCase()}',
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
                _StatusBadge(status: shopStatus),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.divider),

          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                ...items.map((item) {
                  final i = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
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
                        Expanded(
                          child: Text(
                            i['name'] ?? '',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            ),
                          ),
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
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppTheme.divider)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your earnings',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        '₦${myTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Delivery address
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.data['deliveryAddress'] ?? '',
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
          ),

          // Actions
          if (isPending) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUpdating ? null : _showRejectDialog,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        side: const BorderSide(color: AppTheme.error),
                        foregroundColor: AppTheme.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () => _updateShopStatus('confirmed'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Accept Order',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isConfirmed) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: _isUpdating
                    ? null
                    : () => _updateShopStatus('ready'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  backgroundColor: AppTheme.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Mark Ready for Pickup',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],

          if (shopStatus == 'ready') ...[
            const Divider(height: 1, color: AppTheme.divider),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: AppTheme.success,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Waiting for rider to pick up',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 13,
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
    );
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = '🔔 New Order';
        break;
      case 'confirmed':
        color = AppTheme.primary;
        label = 'Preparing';
        break;
      case 'ready':
        color = AppTheme.success;
        label = '✓ Ready';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
