import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import 'picker_deliveries_screen.dart';
import 'picker_earnings_screen.dart';
import 'picker_profile_screen.dart';

class PickerHomeScreen extends StatefulWidget {
  const PickerHomeScreen({super.key});

  @override
  State<PickerHomeScreen> createState() => _PickerHomeScreenState();
}

class _PickerHomeScreenState extends State<PickerHomeScreen> {
  int _currentIndex = 0;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isAvailable = true;
  bool _isToggling = false;

  final List<Widget> _screens = [
    const PickerDeliveriesScreen(),
    const PickerEarningsScreen(),
    const PickerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('getit_riders')
          .doc(_uid)
          .get();
      if (mounted) {
        setState(() => _isAvailable = doc.data()?['isAvailable'] ?? true);
      }
    } catch (_) {}
  }

  Future<void> _toggleAvailability() async {
    setState(() => _isToggling = true);
    try {
      final newStatus = !_isAvailable;
      await FirebaseFirestore.instance
          .collection('getit_riders')
          .doc(_uid)
          .update({'isAvailable': newStatus});
      if (mounted) setState(() => _isAvailable = newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? '🟢 You are now Available for deliveries'
                  : '🔴 You are now Unavailable',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: AppTheme.background,
              automaticallyImplyLeading: false,
              title: const Text(
                'Deliveries',
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
                    onTap: _isToggling ? null : _toggleAvailability,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isAvailable
                            ? AppTheme.success.withOpacity(0.12)
                            : AppTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isAvailable
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
                                color: _isAvailable
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
                                    color: _isAvailable
                                        ? AppTheme.success
                                        : AppTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isAvailable ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    color: _isAvailable
                                        ? AppTheme.success
                                        : AppTheme.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
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
              icon: Icon(Icons.delivery_dining_outlined),
              activeIcon: Icon(Icons.delivery_dining_rounded),
              label: 'Deliveries',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
