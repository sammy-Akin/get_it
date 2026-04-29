import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';
import '../../screens/map/map_service.dart';
import '../../services/notification_service.dart';
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
  String _locationLabel = 'Detecting location...';

  final _mapService = MapService();
  Timer? _locationTimer;
  StreamSubscription<QuerySnapshot>? _deliverySubscription;

  final Set<String> _notifiedDeliveryIds = {};

  final List<Widget> _screens = [
    const PickerDeliveriesScreen(),
    const PickerEarningsScreen(),
    const PickerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [INIT] PickerHomeScreen uid=$_uid');
    _loadAvailability();
    _initLocation();
    _startLocationUpdates();
    _listenForDeliveryAssignments();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _deliverySubscription?.cancel();
    super.dispose();
  }

  void _listenForDeliveryAssignments() {
    debugPrint('🎧 Starting delivery assignment listener for picker: $_uid');

    final listenerStartTime = Timestamp.now();

    _deliverySubscription = FirebaseFirestore.instance
        .collection('getit_orders')
        .where('pickerId', isEqualTo: _uid)
        .where('status', isEqualTo: 'assigned')
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              '📬 Picker listener fired — ${snapshot.docs.length} assigned doc(s)',
            );

            for (final doc in snapshot.docs) {
              if (_notifiedDeliveryIds.contains(doc.id)) continue;

              final data = doc.data();
              final assignedAt = data['assignedAt'] as Timestamp?;

              if (assignedAt != null &&
                  assignedAt.compareTo(listenerStartTime) <= 0) {
                _notifiedDeliveryIds.add(doc.id);
                debugPrint(
                  '📌 Baseline order silently acknowledged: ${doc.id}',
                );
                continue;
              }

              _notifiedDeliveryIds.add(doc.id);
              debugPrint('🆕 New assignment detected: ${doc.id}');

              final shops = data['shops'] as Map<String, dynamic>? ?? {};
              final firstShop = shops.values.isNotEmpty
                  ? shops.values.first as Map<String, dynamic>
                  : <String, dynamic>{};
              final vendorName = firstShop['shopName'] ?? 'Vendor';
              final address = data['deliveryAddress'] ?? 'Customer location';
              final earning =
                  (data['pickerEarning'] as num?)?.toDouble() ?? 0.0;

              _onDeliveryAssigned(
                vendorName: vendorName,
                address: address,
                earning: earning,
                orderId: doc.id,
              );
            }

            final currentIds = snapshot.docs.map((d) => d.id).toSet();
            _notifiedDeliveryIds.removeWhere((id) => !currentIds.contains(id));
          },
          onError: (error) {
            debugPrint('🚨 Picker delivery listener error: $error');
          },
        );
  }

  void _onDeliveryAssigned({
    required String vendorName,
    required String address,
    required double earning,
    required String orderId,
  }) {
    NotificationService.instance.showOrderNotification(
      title: '🚴 New Delivery!',
      body: 'Pickup from $vendorName',
      payload: 'delivery_assigned',
    );

    if (mounted) {
      _showDeliveryBanner(
        vendorName: vendorName,
        address: address,
        earning: earning,
        orderId: orderId,
      );
    }
  }

  void _showDeliveryBanner({
    required String vendorName,
    required String address,
    required double earning,
    required String orderId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
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
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: AppTheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'New Delivery!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.store_rounded,
                label: 'Pickup',
                value: vendorName,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.location_on_rounded,
                label: 'Deliver to',
                value: address,
              ),
              if (earning > 0) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.payments_rounded,
                  label: 'You earn',
                  value: '₦${earning.toStringAsFixed(0)}',
                  valueColor: AppTheme.success,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _declineDelivery(orderId);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                          color: AppTheme.error.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _acceptDelivery(orderId);
                        setState(() => _currentIndex = 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
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

  Future<void> _acceptDelivery(String orderId) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('getit_orders')
          .doc(orderId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshOrder = await transaction.get(orderRef);
        final currentStatus = freshOrder.data()?['status'] as String?;

        if (currentStatus != 'assigned') {
          throw Exception('Order is no longer available');
        }

        final shops =
            (freshOrder.data()?['shops'] as Map<String, dynamic>?) ?? {};
        final Map<String, dynamic> shopUpdates = {};
        for (final shopId in shops.keys) {
          shopUpdates['shops.$shopId.status'] = 'picked_up';
        }

        transaction.update(orderRef, {
          ...shopUpdates,
          'status': 'picked_up',
          'pickerAcceptedAt': FieldValue.serverTimestamp(),
        });
      });

      await FirebaseFirestore.instance
          .collection('getit_riders')
          .doc(_uid)
          .update({'currentOrderId': orderId});

      debugPrint('✅ Delivery accepted: $orderId');
    } catch (e) {
      debugPrint('🚨 _acceptDelivery error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('no longer available')
                  ? 'Sorry, this order was already taken.'
                  : 'Error: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _declineDelivery(String orderId) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('getit_orders')
          .doc(orderId);

      final doc = await orderRef.get();
      final shops = (doc.data()?['shops'] as Map<String, dynamic>?) ?? {};

      final Map<String, dynamic> shopUpdates = {};
      for (final shopId in shops.keys) {
        shopUpdates['shops.$shopId.status'] = 'ready';
      }

      await orderRef.update({
        ...shopUpdates,
        'pickerId': FieldValue.delete(),
        'status': 'ready_for_pickup',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      // Free up the rider when they decline
      await FirebaseFirestore.instance
          .collection('getit_riders')
          .doc(_uid)
          .update({'currentOrderId': '', 'isAvailable': true});

      _notifiedDeliveryIds.remove(orderId);
      debugPrint('✅ Delivery declined: $orderId');
    } catch (e) {
      debugPrint('🚨 _declineDelivery error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _initLocation() async {
    try {
      final loc = await _mapService.getCurrentLocation();

      // ← Always ensure rider document has required fields
      await FirebaseFirestore.instance
          .collection('getit_riders')
          .doc(_uid)
          .set({
            'latitude': loc.latitude,
            'longitude': loc.longitude,
            'locationUpdatedAt': FieldValue.serverTimestamp(),
            'isAvailable': true,
            'currentOrderId': '',
            'name': FirebaseAuth.instance.currentUser?.displayName ?? '',
          }, SetOptions(merge: true));

      _mapService
          .reverseGeocode(loc)
          .then((address) {
            if (address != null && mounted) {
              final parts = address.split(',');
              setState(() {
                _locationLabel = parts.length >= 2
                    ? '${parts[0].trim()}, ${parts[1].trim()}'
                    : address;
              });
            }
          })
          .catchError((_) {
            if (mounted) setState(() => _locationLabel = 'Location detected');
          });
    } catch (e) {
      if (mounted) setState(() => _locationLabel = 'Location unavailable');
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!_isAvailable) return;
      try {
        final loc = await _mapService.getCurrentLocation();
        await FirebaseFirestore.instance
            .collection('getit_riders')
            .doc(_uid)
            .update({
              'latitude': loc.latitude,
              'longitude': loc.longitude,
              'locationUpdatedAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint('Background location update failed: $e');
      }
    });
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
      if (newStatus) {
        // Going available — get location and clear any stale order
        try {
          final loc = await _mapService.getCurrentLocation();
          await FirebaseFirestore.instance
              .collection('getit_riders')
              .doc(_uid)
              .update({
                'isAvailable': newStatus,
                'currentOrderId': '', // ← clear stale order
                'latitude': loc.latitude,
                'longitude': loc.longitude,
                'locationUpdatedAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {
          await FirebaseFirestore.instance
              .collection('getit_riders')
              .doc(_uid)
              .update({
                'isAvailable': newStatus,
                'currentOrderId': '', // ← clear stale order
              });
        }
      } else {
        await FirebaseFirestore.instance
            .collection('getit_riders')
            .doc(_uid)
            .update({'isAvailable': newStatus});
      }

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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deliveries',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.primary,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _locationLabel,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
