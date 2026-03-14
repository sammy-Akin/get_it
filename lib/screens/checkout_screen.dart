import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();

  String _selectedPayment = 'cash';
  bool _isPlacingOrder = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'cash',
      'label': 'Cash on Delivery',
      'subtitle': 'Pay when your order arrives',
      'icon': Icons.payments_outlined,
    },
    {
      'id': 'transfer',
      'label': 'Bank Transfer',
      'subtitle': 'Pay via bank transfer',
      'icon': Icons.account_balance_outlined,
    },
    {
      'id': 'card',
      'label': 'Debit Card',
      'subtitle': 'Pay with your card',
      'icon': Icons.credit_card_outlined,
    },
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your delivery address')),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final user = _auth.currentUser!;
      final orderId = _firestore.collection('getit_orders').doc().id;
      final itemsByShop = cart.cart.itemsByShop;

      // Build shops sub-map
      final Map<String, dynamic> shopsData = {};
      for (final entry in itemsByShop.entries) {
        final shopId = entry.key;
        final items = entry.value;
        shopsData[shopId] = {
          'shopName': items.first.product.shopName,
          'status': 'pending',
          'items': items
              .map(
                (item) => {
                  'productId': item.product.id,
                  'name': item.product.name,
                  'price': item.product.price,
                  'quantity': item.quantity,
                  'totalPrice': item.totalPrice,
                },
              )
              .toList(),
        };
      }

      // Create order document
      await _firestore.collection('getit_orders').doc(orderId).set({
        'orderId': orderId,
        'customerId': user.uid,
        'customerName': user.displayName ?? '',
        'customerEmail': user.email ?? '',
        'deliveryAddress': _addressController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'paymentMethod': _selectedPayment,
        'paymentStatus': 'pending',
        'status': 'pending',
        'subtotal': cart.subtotal,
        'deliveryFee': cart.deliveryFee,
        'riderIncentive': 150,
        'total': cart.total,
        'riderId': null,
        'shops': shopsData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear the cart
      cart.clear();

      if (mounted) {
        context.go('/order/$orderId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    // Delivery address section
                    _buildSectionTitle('Delivery Address'),
                    const SizedBox(height: 12),
                    _buildAddressFields(),

                    const SizedBox(height: 24),

                    // Payment method section
                    _buildSectionTitle('Payment Method'),
                    const SizedBox(height: 12),
                    _buildPaymentMethods(),

                    const SizedBox(height: 24),

                    // Order summary
                    _buildSectionTitle('Order Summary'),
                    const SizedBox(height: 12),
                    _buildOrderSummary(cart),

                    const SizedBox(height: 100),
                  ],
                ),
              ),

              // Place order button
              _buildPlaceOrderBar(context, cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildAddressFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          // Location icon row
          Row(
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
              const Expanded(
                child: Text(
                  'Where should we deliver?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Address field
          TextField(
            controller: _addressController,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
            ),
            decoration: const InputDecoration(
              hintText: 'House number & street name',
              prefixIcon: Icon(
                Icons.home_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Landmark field
          TextField(
            controller: _landmarkController,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
            ),
            decoration: const InputDecoration(
              hintText: 'Landmark (optional)',
              prefixIcon: Icon(
                Icons.place_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      children: _paymentMethods.map((method) {
        final isSelected = _selectedPayment == method['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = method['id']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.08)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.15)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    method['icon'] as IconData,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['label'],
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        method['subtitle'],
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                      width: 2,
                    ),
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final itemsByShop = cart.cart.itemsByShop;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          // Items per shop
          ...itemsByShop.entries.map((entry) {
            final items = entry.value;
            final shopName = items.first.product.shopName;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.product.name} x${item.quantity}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₦${item.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: AppTheme.divider),
              ],
            );
          }),

          const SizedBox(height: 4),

          // Fees
          _buildSummaryRow('Subtotal', '₦${cart.subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Delivery fee',
            '₦${cart.deliveryFee.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow('Rider incentive', '₦150'),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppTheme.divider),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                '₦${cart.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
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

  Widget _buildSummaryRow(String label, String value) {
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

  Widget _buildPlaceOrderBar(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: ElevatedButton(
        onPressed: _isPlacingOrder ? null : () => _placeOrder(cart),
        child: _isPlacingOrder
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Place Order',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '₦${cart.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
