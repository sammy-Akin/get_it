import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';

class VendorEarningsScreen extends StatelessWidget {
  const VendorEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'Earnings',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('getit_vendors')
            .doc(uid)
            .snapshots(),
        builder: (context, vendorSnap) {
          final vendorData =
              vendorSnap.data?.data() as Map<String, dynamic>? ?? {};
          final totalEarnings =
              (vendorData['totalEarnings'] as num?)?.toDouble() ?? 0;
          final withdrawnAmount =
              (vendorData['withdrawnAmount'] as num?)?.toDouble() ?? 0;
          final availableBalance = totalEarnings - withdrawnAmount;
          final bankAccount =
              vendorData['bankAccount'] as Map<String, dynamic>?;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('getit_orders')
                .where('status', isEqualTo: 'delivered')
                .snapshots(),
            builder: (context, ordersSnap) {
              final allDocs = ordersSnap.data?.docs ?? [];

              // Filter orders that contain this vendor
              final myOrders = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final shops = data['shops'] as Map<String, dynamic>? ?? {};
                return shops.containsKey(uid);
              }).toList();

              // Sort by date
              myOrders.sort((a, b) {
                final aT = (a.data() as Map)['createdAt'] as Timestamp?;
                final bT = (b.data() as Map)['createdAt'] as Timestamp?;
                if (aT == null || bT == null) return 0;
                return bT.compareTo(aT);
              });

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Earnings Card ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary,
                          AppTheme.primary.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₦${availableBalance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _EarningStat(
                              label: 'Total Earned',
                              value: '₦${totalEarnings.toStringAsFixed(0)}',
                            ),
                            const SizedBox(width: 24),
                            _EarningStat(
                              label: 'Withdrawn',
                              value: '₦${withdrawnAmount.toStringAsFixed(0)}',
                            ),
                            const SizedBox(width: 24),
                            _EarningStat(
                              label: 'Orders',
                              value: '${myOrders.length}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: availableBalance < 100
                              ? null
                              : () => _showWithdrawSheet(
                                  context,
                                  uid,
                                  availableBalance,
                                  bankAccount,
                                ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: availableBalance < 100
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                availableBalance < 100
                                    ? 'Minimum withdrawal is ₦100'
                                    : 'Withdraw to Bank',
                                style: TextStyle(
                                  color: availableBalance < 100
                                      ? Colors.white70
                                      : AppTheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Bank Account Card ───────────────────────────────
                  _buildBankAccountCard(context, uid, bankAccount),

                  const SizedBox(height: 16),

                  // ── Stats ───────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        label: 'Completed',
                        value: '${myOrders.length}',
                        icon: Icons.receipt_long_rounded,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'This Week',
                        value: '₦${_weeklyEarnings(myOrders, uid)}',
                        icon: Icons.calendar_today_rounded,
                        color: AppTheme.success,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Order History',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (myOrders.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              color: AppTheme.textSecondary,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No completed orders yet',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ...myOrders.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = data['createdAt'] as Timestamp?;
                    final shops = data['shops'] as Map<String, dynamic>? ?? {};
                    final myShop = shops[uid] as Map<String, dynamic>? ?? {};
                    final items = myShop['items'] as List<dynamic>? ?? [];

                    double myTotal = 0;
                    for (final item in items) {
                      myTotal +=
                          (item as Map<String, dynamic>)['totalPrice'] as num;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.success,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${doc.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  '${items.length} item${items.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
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
                          ),
                          Text(
                            '+₦${myTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBankAccountCard(
    BuildContext context,
    String uid,
    Map<String, dynamic>? bankAccount,
  ) {
    final hasBankAccount =
        bankAccount != null && bankAccount['accountNumber'] != null;

    return GestureDetector(
      onTap: () => _showBankAccountSheet(context, uid, bankAccount),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasBankAccount
                ? AppTheme.success.withOpacity(0.4)
                : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasBankAccount
                    ? AppTheme.success.withOpacity(0.12)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: hasBankAccount
                    ? AppTheme.success
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
                    hasBankAccount ? 'Bank Account' : 'Add Bank Account',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    hasBankAccount
                        ? '${bankAccount['bankName']} • ${bankAccount['accountNumber']}'
                        : 'Required for withdrawals',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (hasBankAccount && bankAccount['accountName'] != null)
                    Text(
                      bankAccount['accountName'],
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              hasBankAccount ? Icons.edit_outlined : Icons.add_rounded,
              color: AppTheme.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showBankAccountSheet(
    BuildContext context,
    String uid,
    Map<String, dynamic>? existing,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _VendorBankAccountSheet(uid: uid, existing: existing),
    );
  }

  void _showWithdrawSheet(
    BuildContext context,
    String uid,
    double availableBalance,
    Map<String, dynamic>? bankAccount,
  ) {
    if (bankAccount == null || bankAccount['accountNumber'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your bank account first'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _VendorWithdrawSheet(
        uid: uid,
        availableBalance: availableBalance,
        bankAccount: bankAccount,
      ),
    );
  }

  String _weeklyEarnings(List<QueryDocumentSnapshot> orders, String uid) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    double total = 0;
    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final ts = data['createdAt'] as Timestamp?;
      if (ts == null || ts.toDate().isBefore(weekStart)) continue;
      final shops = data['shops'] as Map<String, dynamic>? ?? {};
      final myShop = shops[uid] as Map<String, dynamic>? ?? {};
      final items = myShop['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        total += (item as Map<String, dynamic>)['totalPrice'] as num;
      }
    }
    return total.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── Vendor Bank Account Sheet ────────────────────────────────────────────────

class _VendorBankAccountSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic>? existing;

  const _VendorBankAccountSheet({required this.uid, this.existing});

  @override
  State<_VendorBankAccountSheet> createState() =>
      _VendorBankAccountSheetState();
}

class _VendorBankAccountSheetState extends State<_VendorBankAccountSheet> {
  final _accountNumberCtrl = TextEditingController();
  final _bankSearchCtrl = TextEditingController();

  List<Map<String, String>> _banks = [];
  List<Map<String, String>> _filteredBanks = [];
  bool _isFetchingBanks = false;
  bool _showBankSearch = false;

  String? _selectedBankCode;
  String? _selectedBankName;
  String? _resolvedAccountName;
  bool _isResolving = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
    if (widget.existing != null) {
      _accountNumberCtrl.text = widget.existing!['accountNumber'] ?? '';
      _selectedBankCode = widget.existing!['bankCode'];
      _selectedBankName = widget.existing!['bankName'];
      _resolvedAccountName = widget.existing!['accountName'];
    }
    _bankSearchCtrl.addListener(_filterBanks);
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _bankSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBanks() async {
    setState(() => _isFetchingBanks = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.paystack.co/bank?country=nigeria&perPage=100'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List bankList = data['data'] as List;
        final parsed = bankList
            .where((b) => b['active'] == true && b['is_deleted'] == false)
            .map<Map<String, String>>(
              (b) => {'name': b['name'] as String, 'code': b['code'] as String},
            )
            .toList();
        parsed.sort((a, b) => a['name']!.compareTo(b['name']!));
        if (mounted) {
          setState(() {
            _banks = parsed;
            _filteredBanks = parsed;
            _isFetchingBanks = false;
          });
        }
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }

  void _useFallback() {
    final fallback = [
      {'name': 'Access Bank', 'code': '044'},
      {'name': 'GTBank', 'code': '058'},
      {'name': 'First Bank', 'code': '011'},
      {'name': 'Zenith Bank', 'code': '057'},
      {'name': 'UBA', 'code': '033'},
      {'name': 'Kuda Bank', 'code': '50211'},
      {'name': 'OPay', 'code': '100004'},
      {'name': 'PalmPay', 'code': '100033'},
      {'name': 'Moniepoint', 'code': '50515'},
    ];
    if (mounted) {
      setState(() {
        _banks = fallback;
        _filteredBanks = fallback;
        _isFetchingBanks = false;
      });
    }
  }

  void _filterBanks() {
    final query = _bankSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredBanks = _banks
          .where((b) => b['name']!.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _resolveAccount() async {
    if (_selectedBankCode == null || _accountNumberCtrl.text.length != 10) {
      setState(
        () => _error = 'Select a bank and enter a 10-digit account number',
      );
      return;
    }
    setState(() {
      _isResolving = true;
      _error = null;
      _resolvedAccountName = null;
    });
    try {
      final response = await http.post(
        Uri.parse(
          'https://us-central1-getit-db879.cloudfunctions.net/resolveAccount',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountNumber': _accountNumberCtrl.text.trim(),
          'bankCode': _selectedBankCode,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _resolvedAccountName = data['accountName'];
          _isResolving = false;
        });
      } else {
        setState(() {
          _error = 'Could not verify account. Check the details.';
          _isResolving = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Network error. Try again.';
        _isResolving = false;
      });
    }
  }

  Future<void> _save() async {
    if (_resolvedAccountName == null) {
      setState(() => _error = 'Please verify your account first');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('getit_vendors')
          .doc(widget.uid)
          .update({
            'bankAccount': {
              'accountNumber': _accountNumberCtrl.text.trim(),
              'bankCode': _selectedBankCode,
              'bankName': _selectedBankName,
              'accountName': _resolvedAccountName,
            },
          });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() {
        _error = 'Failed to save. Try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bank Account',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your account to receive withdrawals',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),

          // Bank selector
          if (_isFetchingBanks)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading banks…',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontFamily: 'Poppins',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            GestureDetector(
              onTap: () => setState(() => _showBankSearch = !_showBankSearch),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedBankCode != null
                        ? AppTheme.primary.withOpacity(0.5)
                        : AppTheme.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_rounded,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedBankName ?? 'Select Bank',
                        style: TextStyle(
                          color: _selectedBankName != null
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      _showBankSearch
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_showBankSearch) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: _bankSearchCtrl,
                        autofocus: true,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search bank…',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.divider),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _filteredBanks.length,
                        itemBuilder: (context, index) {
                          final bank = _filteredBanks[index];
                          final isSelected = bank['code'] == _selectedBankCode;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedBankCode = bank['code'];
                                _selectedBankName = bank['name'];
                                _showBankSearch = false;
                                _resolvedAccountName = null;
                                _bankSearchCtrl.clear();
                                _error = null;
                              });
                              if (_accountNumberCtrl.text.length == 10) {
                                _resolveAccount();
                              }
                            },
                            child: Container(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.08)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      bank['name']!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textPrimary,
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_rounded,
                                      color: AppTheme.primary,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),

          // Account number
          TextField(
            controller: _accountNumberCtrl,
            keyboardType: TextInputType.number,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
              letterSpacing: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Account number (10 digits)',
              counterText: '',
              prefixIcon: const Icon(
                Icons.credit_card_rounded,
                color: AppTheme.textSecondary,
              ),
              suffixIcon: _isResolving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  : _resolvedAccountName != null
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.success,
                      size: 20,
                    )
                  : null,
            ),
            onChanged: (value) {
              if (_resolvedAccountName != null) {
                setState(() => _resolvedAccountName = null);
              }
              if (value.length == 10 && _selectedBankCode != null) {
                _resolveAccount();
              }
            },
          ),

          // Resolved name
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _resolvedAccountName != null
                ? Padding(
                    key: const ValueKey('resolved'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.success.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.success,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Account verified',
                                  style: TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 11,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  _resolvedAccountName!,
                                  style: const TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 15,
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
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.error,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isSaving || _resolvedAccountName == null ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Bank Account',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Vendor Withdraw Sheet ────────────────────────────────────────────────────

class _VendorWithdrawSheet extends StatefulWidget {
  final String uid;
  final double availableBalance;
  final Map<String, dynamic> bankAccount;

  const _VendorWithdrawSheet({
    required this.uid,
    required this.availableBalance,
    required this.bankAccount,
  });

  @override
  State<_VendorWithdrawSheet> createState() => _VendorWithdrawSheetState();
}

class _VendorWithdrawSheetState extends State<_VendorWithdrawSheet> {
  final _amountCtrl = TextEditingController();
  bool _isWithdrawing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.availableBalance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 100) {
      setState(() => _error = 'Minimum withdrawal is ₦100');
      return;
    }
    if (amount > widget.availableBalance) {
      setState(() => _error = 'Amount exceeds available balance');
      return;
    }
    setState(() {
      _isWithdrawing = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(
          'https://us-central1-getit-db879.cloudfunctions.net/withdrawVendorEarnings',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vendorId': widget.uid,
          'amount': amount,
          'accountNumber': widget.bankAccount['accountNumber'],
          'bankCode': widget.bankAccount['bankCode'],
          'accountName': widget.bankAccount['accountName'],
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✓ ₦${amount.toStringAsFixed(0)} sent to ${widget.bankAccount['bankName']}',
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['error'] ?? 'Withdrawal failed. Try again.';
          _isWithdrawing = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Network error. Try again.';
        _isWithdrawing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Withdraw Earnings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available: ₦${widget.availableBalance.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),

          // Bank info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bankAccount['accountName'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        '${widget.bankAccount['bankName']} • ${widget.bankAccount['accountNumber']}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              prefixText: '₦',
              prefixStyle: TextStyle(
                color: AppTheme.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
              hintText: '0',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isWithdrawing ? null : _withdraw,
            child: _isWithdrawing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Withdraw Now',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _EarningStat extends StatelessWidget {
  final String label;
  final String value;
  const _EarningStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
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
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
