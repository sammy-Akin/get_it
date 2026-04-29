import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OrderNotificationTrigger {
  static final _firestore = FirebaseFirestore.instance;

  // Update this to your deployed Cloud Function URL
  static const _cloudFnUrl =
      'https://us-central1-getit-db879.cloudfunctions.net/sendNotification';

  static Future<void> notifyVendorNewOrder({
    required String vendorUid,
    required String orderId,
    required String buyerName,
    required double orderTotal,
  }) async {
    await _sendToUser(
      uid: vendorUid,
      title: '🛍️ New Order!',
      body: '$buyerName placed an order • ₦${orderTotal.toStringAsFixed(0)}',
      data: {'type': 'new_order', 'orderId': orderId},
    );
  }

  static Future<void> notifyPickerAssigned({
    required String pickerUid,
    required String orderId,
    required String vendorName,
    required String deliveryAddress,
  }) async {
    await _sendToUser(
      uid: pickerUid,
      title: '🚴 New Delivery Assigned!',
      body: 'Pickup from $vendorName → $deliveryAddress',
      data: {'type': 'delivery_assigned', 'orderId': orderId},
    );
  }

  static Future<void> _sendToUser({
    required String uid,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final doc = await _firestore.collection('getit_users').doc(uid).get();
      final token = doc.data()?['fcmToken'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('No FCM token for user $uid');
        return;
      }
      await _sendViaCloudFunction(
        token: token,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('notifyUser error: $e');
    }
  }

  static Future<void> _sendViaCloudFunction({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_cloudFnUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          'data': data,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('Cloud function error: ${response.body}');
      }
    } catch (e) {
      debugPrint('sendViaCloudFunction error: $e');
    }
  }
}
