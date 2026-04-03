import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
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

  final List<Widget> _screens = [
    const VendorOrdersScreen(),
    const VendorProductsScreen(),
    const VendorProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadShopStatus();
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
      // Closing — show confirmation
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
      // Opening — no confirmation needed
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
                // Open/Close toggle in app bar
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
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.receipt_long_outlined),
              activeIcon: const Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Products',
            ),
            const BottomNavigationBarItem(
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
