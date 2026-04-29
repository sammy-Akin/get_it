import 'dart:convert';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = true;
  bool _isPlacingOrder = false;

  static const String _paystackPublicKey =
      'pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddress() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('getit_users').doc(uid).get();
        final data = doc.data();
        if (data != null) {
          if (data['deliveryAddress'] != null) {
            _addressController.text = data['deliveryAddress'];
          }
          if (data['phone'] != null) {
            _phoneController.text = data['phone'];
          }

          // Calculate delivery distance if user has saved coords
          if (data['deliveryLat'] != null && data['deliveryLng'] != null) {
            final userLat = (data['deliveryLat'] as num).toDouble();
            final userLng = (data['deliveryLng'] as num).toDouble();
            await _calculateAndSetDeliveryDistance(userLat, userLng);
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _calculateAndSetDeliveryDistance(
    double userLat,
    double userLng,
  ) async {
    try {
      final cart = context.read<CartProvider>();
      final shopIds = cart.cart.itemsByShop.keys.toList();
      if (shopIds.isEmpty) return;

      // Get the first shop's location from Firestore
      final shopDoc = await _firestore
          .collection('getit_vendors')
          .doc(shopIds.first)
          .get();
      final shopData = shopDoc.data();
      if (shopData == null) return;

      final shopLat = (shopData['latitude'] as num?)?.toDouble() ?? 0;
      final shopLng = (shopData['longitude'] as num?)?.toDouble() ?? 0;
      if (shopLat == 0 || shopLng == 0) return;

      final distanceMeters = Geolocator.distanceBetween(
        userLat,
        userLng,
        shopLat,
        shopLng,
      );
      final distanceKm = distanceMeters / 1000;

      cart.setDeliveryDistance(distanceKm);
      debugPrint('Delivery distance: ${distanceKm.toStringAsFixed(2)}km');
    } catch (e) {
      debugPrint('Distance calculation failed: $e');
    }
  }

  Future<void> _pay(CartProvider cart) async {
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
      final email = user.email ?? '${user.uid}@getit.ng';
      final amountKobo = (cart.total * 100).toInt();

      final itemsByShop = cart.cart.itemsByShop;
      final Map<String, dynamic> shopsData = {};
      for (final entry in itemsByShop.entries) {
        shopsData[entry.key] = {
          'shopName': entry.value.first.product.shopName,
          'status': 'pending',
          'items': entry.value
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

      await _firestore.collection('getit_orders').doc(orderId).set({
        'orderId': orderId,
        'customerId': user.uid,
        'customerName': user.displayName ?? '',
        'customerEmail': email,
        'customerPhone': _phoneController.text.trim(),
        'deliveryAddress': _addressController.text.trim(),
        'note': _noteController.text.trim(),
        'paymentMethod': 'paystack',
        'paymentStatus': 'pending',
        'status': 'pending_payment',
        'subtotal': cart.subtotal,
        'serviceCharge': cart.serviceCharge,
        'deliveryFee': cart.deliveryFee,
        'riderIncentive': cart.riderIncentive,
        'total': cart.total,
        'riderId': null,
        'vendorIds': itemsByShop.keys.toList(),
        'shops': shopsData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final response = await http.post(
        Uri.parse(
          'https://us-central1-getit-db879.cloudfunctions.net/initializePayment',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'amount': amountKobo.toString(),
          'reference': orderId,
          'currency': 'NGN',
        }),
      );

      if (response.statusCode != 200) {
        await _firestore.collection('getit_orders').doc(orderId).delete();
        if (mounted) {
          setState(() => _isPlacingOrder = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not initialize payment. Try again.'),
            ),
          );
        }
        return;
      }

      final data = jsonDecode(response.body);
      final checkoutUrl = data['url'] as String;

      if (mounted) setState(() => _isPlacingOrder = false);

      if (!mounted) return;

      if (kIsWeb) {
        await _firestore.collection('getit_users').doc(user.uid).update({
          'pendingOrderId': orderId,
        });
        cart.clear();
        await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.platformDefault,
        );
      } else {
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _PaystackWebView(checkoutUrl: checkoutUrl, orderId: orderId),
          ),
        );

        if (paid == true && mounted) {
          await _firestore.collection('getit_orders').doc(orderId).update({
            'paymentStatus': 'paid',
            'status': 'confirmed',
            'paidAt': FieldValue.serverTimestamp(),
          });
          cart.clear();
          if (mounted) context.go('/order/$orderId');
        } else {
          await _firestore.collection('getit_orders').doc(orderId).delete();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Consumer<CartProvider>(
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
                          _buildSectionTitle('Delivery Address'),
                          const SizedBox(height: 12),
                          _buildAddressSection(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Order Note'),
                          const SizedBox(height: 12),
                          _buildNoteField(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Payment'),
                          const SizedBox(height: 12),
                          _buildPaystackBadge(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Order Summary'),
                          const SizedBox(height: 12),
                          _buildOrderSummary(cart),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                    _buildPayBar(context, cart),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      fontFamily: 'Poppins',
    ),
  );

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
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
          TextField(
            controller: _addressController,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
            ),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'House number, street, estate...',
              prefixIcon: Icon(
                Icons.home_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
            ),
            decoration: const InputDecoration(
              hintText: 'Phone number (for rider)',
              prefixIcon: Icon(
                Icons.phone_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 2,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontFamily: 'Poppins',
        ),
        decoration: const InputDecoration(
          hintText: 'Any special instructions? (optional)',
          prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.textSecondary),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPaystackBadge() {
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
              color: const Color(0xFF00C3F7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00C3F7).withOpacity(0.3),
              ),
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Color(0xFF00C3F7),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay with Paystack',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Card, bank transfer, USSD & more',
                  style: TextStyle(
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
              color: AppTheme.primary,
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          ...cart.cart.itemsByShop.entries.map((entry) {
            final items = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items.first.product.shopName,
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
          _row('Subtotal', '₦${cart.subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _row(
            'Service charge (3%)',
            '₦${cart.serviceCharge.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _row('Delivery fee', '₦${cart.riderIncentive.toStringAsFixed(0)}'),
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

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Row(
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
    ),
  );

  Widget _buildPayBar(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: ElevatedButton(
        onPressed: _isPlacingOrder ? null : () => _pay(cart),
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
                    'Pay with Paystack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '₦${cart.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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

// ─── Paystack WebView — Android only ─────────────────────────────────────────

class _PaystackWebView extends StatefulWidget {
  final String checkoutUrl;
  final String orderId;

  const _PaystackWebView({required this.checkoutUrl, required this.orderId});

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    if (defaultTargetPlatform == TargetPlatform.android) {
      WebViewPlatform.instance ??= AndroidWebViewPlatform();
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('WebView navigating to: $url');

            if (url.contains('getit-db879.web.app/payment/callback') ||
                url.contains('trxref=') ||
                url.contains('reference=')) {
              Navigator.pop(context, true);
              return;
            }

            if (url.contains('paystack.com/close') ||
                url.contains('close=true')) {
              Navigator.pop(context, false);
              return;
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;

            if (url.contains('getit-db879.web.app/payment/callback') ||
                url.contains('trxref=')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Secure Payment',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: AppTheme.success, size: 12),
                SizedBox(width: 4),
                Text(
                  'Secured',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
        ],
      ),
    );
  }
}
