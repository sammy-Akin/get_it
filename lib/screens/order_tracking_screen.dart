import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

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
          'Track Order',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/orders'),
            child: const Text(
              'My Orders',
              style: TextStyle(color: AppTheme.primary, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('getit_orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState(context);
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending';
          final shops = data['shops'] as Map<String, dynamic>? ?? {};

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Order confirmed banner
              _buildStatusBanner(status),
              const SizedBox(height: 24),

              // Live status tracker
              _buildStatusTracker(status),
              const SizedBox(height: 24),

              // Rider info (when assigned)
              if (data['riderId'] != null) ...[
                _buildRiderCard(data),
                const SizedBox(height: 24),
              ],

              // Delivery address
              _buildDeliveryAddress(data),
              const SizedBox(height: 24),

              // Order details
              _buildOrderDetails(shops, data),
              const SizedBox(height: 24),

              // Payment info
              _buildPaymentInfo(data),
              const SizedBox(height: 32),

              // Back to home button (if delivered)
              if (status == 'delivered')
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Back to Home'),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (config['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (config['color'] as Color).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              config['icon'] as IconData,
              color: config['color'] as Color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config['title'] as String,
                  style: TextStyle(
                    color: config['color'] as Color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config['subtitle'] as String,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTracker(String status) {
    final steps = [
      {
        'id': 'pending',
        'label': 'Order Placed',
        'subtitle': 'We received your order',
        'icon': Icons.receipt_long_rounded,
      },
      {
        'id': 'confirmed',
        'label': 'Shop Confirmed',
        'subtitle': 'Shops are preparing your items',
        'icon': Icons.storefront_rounded,
      },
      {
        'id': 'rider_assigned',
        'label': 'Rider Assigned',
        'subtitle': 'A rider is on the way to pick up',
        'icon': Icons.delivery_dining_rounded,
      },
      {
        'id': 'out_for_delivery',
        'label': 'Out for Delivery',
        'subtitle': 'Your order is on its way',
        'icon': Icons.near_me_rounded,
      },
      {
        'id': 'delivered',
        'label': 'Delivered',
        'subtitle': 'Enjoy your order!',
        'icon': Icons.check_circle_rounded,
      },
    ];

    final statusOrder = [
      'pending',
      'confirmed',
      'rider_assigned',
      'out_for_delivery',
      'delivered',
    ];

    final currentIndex = statusOrder.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isDone = index <= currentIndex;
            final isActive = index == currentIndex;
            final isLast = index == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + line
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppTheme.primary
                            : AppTheme.surfaceLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? AppTheme.primary
                              : AppTheme.cardBorder,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        color: isDone ? Colors.white : AppTheme.textSecondary,
                        size: 18,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: index < currentIndex
                            ? AppTheme.primary
                            : AppTheme.divider,
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Text
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['label'] as String,
                          style: TextStyle(
                            color: isDone
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (isActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              step['subtitle'] as String,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Active pulse indicator
                if (isActive && status != 'delivered')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRiderCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['riderName'] ?? 'Your Rider',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Text(
                  'Your delivery rider',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          // Call button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.call_rounded,
                color: AppTheme.success,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['deliveryAddress'] ?? '',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                if ((data['landmark'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Near ${data['landmark']}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
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

  Widget _buildOrderDetails(
    Map<String, dynamic> shops,
    Map<String, dynamic> data,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Details',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                '#${orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items per shop
          ...shops.entries.map((entry) {
            final shopData = entry.value as Map<String, dynamic>;
            final items = shopData['items'] as List<dynamic>? ?? [];
            final shopStatus = shopData['status'] ?? 'pending';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: AppTheme.textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          shopData['shopName'] ?? '',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    _buildShopStatusBadge(shopStatus),
                  ],
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${itemMap['name']} x${itemMap['quantity']}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₦${(itemMap['totalPrice'] as num).toStringAsFixed(0)}',
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
                const Divider(color: AppTheme.divider),
              ],
            );
          }),

          // Totals
          _buildTotalRow(
            'Subtotal',
            '₦${(data['subtotal'] as num).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 6),
          _buildTotalRow(
            'Delivery fee',
            '₦${(data['deliveryFee'] as num).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 6),
          _buildTotalRow('Rider incentive', '₦150'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppTheme.divider),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                '₦${(data['total'] as num).toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'confirmed':
        color = AppTheme.primary;
        label = 'Confirmed';
        break;
      case 'ready':
        color = Colors.orange;
        label = 'Ready';
        break;
      case 'picked_up':
        color = AppTheme.success;
        label = 'Picked Up';
        break;
      default:
        color = AppTheme.textSecondary;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildPaymentInfo(Map<String, dynamic> data) {
    final method = data['paymentMethod'] ?? 'cash';
    final methodLabel = method == 'cash'
        ? 'Cash on Delivery'
        : method == 'transfer'
        ? 'Bank Transfer'
        : 'Debit Card';

    return Container(
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
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  methodLabel,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: data['paymentStatus'] == 'paid'
                  ? AppTheme.success.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              data['paymentStatus'] == 'paid' ? 'Paid' : 'Pending',
              style: TextStyle(
                color: data['paymentStatus'] == 'paid'
                    ? AppTheme.success
                    : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.textSecondary,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Order not found',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This order may have been removed',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return {
          'title': 'Order Placed!',
          'subtitle': 'Waiting for shops to confirm your order',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.orange,
        };
      case 'confirmed':
        return {
          'title': 'Order Confirmed!',
          'subtitle': 'Shops are preparing your items',
          'icon': Icons.storefront_rounded,
          'color': AppTheme.primary,
        };
      case 'rider_assigned':
        return {
          'title': 'Rider Assigned!',
          'subtitle': 'Your rider is heading to the shop',
          'icon': Icons.delivery_dining_rounded,
          'color': AppTheme.primary,
        };
      case 'out_for_delivery':
        return {
          'title': 'On the Way!',
          'subtitle': 'Your order is heading to you',
          'icon': Icons.near_me_rounded,
          'color': AppTheme.primary,
        };
      case 'delivered':
        return {
          'title': 'Delivered! 🎉',
          'subtitle': 'Enjoy your order',
          'icon': Icons.check_circle_rounded,
          'color': AppTheme.success,
        };
      case 'cancelled':
        return {
          'title': 'Order Cancelled',
          'subtitle': 'This order was cancelled',
          'icon': Icons.cancel_outlined,
          'color': AppTheme.error,
        };
      default:
        return {
          'title': 'Processing...',
          'subtitle': 'Please wait',
          'icon': Icons.hourglass_empty_rounded,
          'color': AppTheme.textSecondary,
        };
    }
  }
}
