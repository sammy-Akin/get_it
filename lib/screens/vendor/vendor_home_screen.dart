import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import 'vendor_orders_screen.dart';
import 'vendor_products_screen.dart';
import 'vendor_profile_screen.dart';

class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  int _currentIndex = 0;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isOpen = true;
  bool _isToggling = false;

  StreamSubscription<QuerySnapshot>? _orderSubscription;
  String? _lastKnownLatestOrderId; // tracks last seen order

  final List<Widget> _screens = [
    const VendorOrdersScreen(),
    const VendorProductsScreen(),
    const VendorProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadShopStatus();
    _listenForNewOrders();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  /// Listens for new orders in real-time.
  /// On first load, sets baseline. After that, any new order triggers alert.
  void _listenForNewOrders() {
    debugPrint('🔍 Starting order listener for vendor: $_uid');

    _orderSubscription = FirebaseFirestore.instance
        .collection('getit_orders')
        .where('vendorIds', arrayContains: _uid)
        .where('paymentStatus', isEqualTo: 'paid')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              '📦 Snapshot received. Docs count: ${snapshot.docs.length}',
            );

            if (snapshot.docs.isEmpty) {
              debugPrint('❌ No docs — listener works but no matching orders');
              return;
            }

            final latestDoc = snapshot.docs.first;
            final latestId = latestDoc.id;
            debugPrint('✅ Latest order id: $latestId');
            debugPrint('📋 Order data: ${latestDoc.data()}');

            if (_lastKnownLatestOrderId == null) {
              _lastKnownLatestOrderId = latestId;
              debugPrint('🔖 Baseline set: $latestId');
              return;
            }

            if (latestId != _lastKnownLatestOrderId) {
              debugPrint('🆕 NEW ORDER DETECTED: $latestId');
              _lastKnownLatestOrderId = latestId;
              final data = latestDoc.data();
              final buyerName = data['customerName'] ?? 'A customer';
              final total = (data['total'] as num?)?.toDouble() ?? 0.0;
              _onNewOrderReceived(
                buyerName: buyerName,
                total: total,
                orderId: latestId,
              );
            } else {
              debugPrint('🔁 Same order as baseline, no alert needed');
            }
          },
          onError: (error) {
            debugPrint('🚨 LISTENER ERROR: $error');
          },
        );
  }

  void _onNewOrderReceived({
    required String buyerName,
    required double total,
    required String orderId,
  }) {
    // 1. Show local notification (sound + vibration) even if app is open
    NotificationService.instance.showOrderNotification(
      title: '🛍️ New Order!',
      body: '$buyerName • ₦${total.toStringAsFixed(0)}',
      payload: 'new_order',
    );

    // 2. Show in-app persistent banner — can't be dismissed without action
    if (mounted) {
      _showNewOrderBanner(buyerName: buyerName, total: total, orderId: orderId);
    }
  }

  void _showNewOrderBanner({
    required String buyerName,
    required double total,
    required String orderId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false, // must tap a button
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false, // back button won't dismiss
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: AppTheme.success,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'New Order!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                buyerName,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₦${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Switch to orders tab
                        setState(() => _currentIndex = 0);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _acceptOrder(orderId);
                        setState(() => _currentIndex = 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('getit_orders')
          .doc(orderId)
          .update({
            'shops.$_uid.status': 'confirmed', // ← update shop-level status
            'status': 'confirmed', // ← change this
            'acceptedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadShopStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('getit_vendors')
          .doc(_uid)
          .get();
      if (mounted) {
        setState(() => _isOpen = doc.data()?['isOpen'] ?? true);
      }
    } catch (_) {}
  }

  Future<void> _toggleShopStatus() async {
    setState(() => _isToggling = true);
    try {
      final newStatus = !_isOpen;
      await FirebaseFirestore.instance
          .collection('getit_vendors')
          .doc(_uid)
          .update({'isOpen': newStatus});
      if (mounted) setState(() => _isOpen = newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? '🟢 Your shop is now Open'
                  : '🔴 Your shop is now Closed',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: newStatus ? AppTheme.success : AppTheme.error,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  void _confirmToggle() {
    if (_isOpen) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Close your shop?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Customers won\'t see your shop or products until you open again.',
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
                _toggleShopStatus();
              },
              child: const Text(
                'Close Shop',
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
    } else {
      _toggleShopStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: AppTheme.background,
              automaticallyImplyLeading: false,
              title: const Text(
                'Orders',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: _isToggling ? null : _confirmToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isOpen
                            ? AppTheme.success.withOpacity(0.12)
                            : AppTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isOpen
                              ? AppTheme.success.withOpacity(0.4)
                              : AppTheme.error.withOpacity(0.4),
                        ),
                      ),
                      child: _isToggling
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _isOpen
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isOpen
                                        ? AppTheme.success
                                        : AppTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOpen ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    color: _isOpen
                                        ? AppTheme.success
                                        : AppTheme.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _isOpen
                                      ? AppTheme.success
                                      : AppTheme.error,
                                  size: 16,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppTheme.surface,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.store_outlined),
              activeIcon: Icon(Icons.store_rounded),
              label: 'Shop',
            ),
          ],
        ),
      ),
    );
  }
}
