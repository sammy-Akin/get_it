// lib/screens/payment_callback_screen.dart
//
// Paystack redirects here after web payment:
//   https://getit-db879.web.app/payment/callback?trxref=ORDER_ID&reference=ORDER_ID
//
// This screen:
//   1. Reads the reference from the URL
//   2. Calls verifyPayment Cloud Function
//   3. If paid → confirms order → goes to tracking
//   4. If not paid → deletes pending order → goes back to home

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import '../core/theme.dart';

class PaymentCallbackScreen extends StatefulWidget {
  const PaymentCallbackScreen({super.key});

  @override
  State<PaymentCallbackScreen> createState() => _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends State<PaymentCallbackScreen> {
  String _message = 'Verifying payment...';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // 1. Get reference from URL query params
      String? reference;

      if (kIsWeb) {
        final uri = Uri.parse(html.window.location.href);
        reference =
            uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
      }

      if (reference == null || reference.isEmpty) {
        setState(() {
          _message = 'Invalid payment reference.';
          _isError = true;
        });
        return;
      }

      debugPrint('Payment callback reference: $reference');

      // 2. Verify with Cloud Function
      final response = await http.post(
        Uri.parse(
          'https://us-central1-getit-db879.cloudfunctions.net/verifyPayment',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reference': reference}),
      );

      final data = jsonDecode(response.body);
      final paid = data['paid'] == true;

      if (paid) {
        // 3. Confirm order in Firestore
        await FirebaseFirestore.instance
            .collection('getit_orders')
            .doc(reference)
            .update({
              'paymentStatus': 'paid',
              'status': 'confirmed',
              'paidAt': FieldValue.serverTimestamp(),
            });

        // 4. Clear pendingOrderId from user doc
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('getit_users')
              .doc(uid)
              .update({'pendingOrderId': FieldValue.delete()});
        }

        setState(() => _message = 'Payment confirmed! Redirecting...');

        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go('/order/$reference');
      } else {
        // Payment failed or cancelled — delete the pending order
        await FirebaseFirestore.instance
            .collection('getit_orders')
            .doc(reference)
            .delete();

        setState(() {
          _message = 'Payment was not completed.';
          _isError = true;
        });

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/home');
      }
    } catch (e) {
      debugPrint('Payment callback error: $e');
      setState(() {
        _message = 'Something went wrong. Please check your orders.';
        _isError = true;
      });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) context.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isError) ...[
                const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 24),
              ] else ...[
                Icon(
                  _isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded,
                  color: _isError ? AppTheme.error : AppTheme.success,
                  size: 64,
                ),
                const SizedBox(height: 24),
              ],
              Text(
                _message,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
