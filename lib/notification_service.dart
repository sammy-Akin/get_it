// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   final _messaging = FirebaseMessaging.instance;
//   final _localNotifications = FlutterLocalNotificationsPlugin();

//   static const _channelId = 'getit_orders';
//   static const _channelName = 'Get It Orders';
//   static const _channelDesc = 'Notifications for new orders and deliveries';

//   Future<void> initialize() async {
//     // Web doesn't support local notifications
//     if (kIsWeb) {
//       await _requestPermission();
//       await _saveToken();
//       _listenToMessages();
//       return;
//     }

//     await _requestPermission();
//     await _setupLocalNotifications();
//     await _saveToken();
//     _listenToMessages();
//   }

//   Future<void> _requestPermission() async {
//     await _messaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//   }

//   Future<void> _setupLocalNotifications() async {
//     // Android notification channel with sound
//     const androidChannel = AndroidNotificationChannel(
//       _channelId,
//       _channelName,
//       description: _channelDesc,
//       importance: Importance.max,
//       playSound: true,
//       sound: RawResourceAndroidNotificationSound('order_sound'),
//       enableVibration: true,
//     );

//     await _localNotifications
//         .resolvePlatformSpecificImplementation
//             AndroidFlutterLocalNotificationsPlugin>()
//         ?.createNotificationChannel(androidChannel);

//     const initSettings = InitializationSettings(
//       android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//     );

//     await _localNotifications.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: (details) {
//         // Handle notification tap
//       },
//     );
//   }

//   Future<void> _saveToken() async {
//     try {
//       final uid = FirebaseAuth.instance.currentUser?.uid;
//       if (uid == null) return;

//       String? token;
//       if (kIsWeb) {
//         // For web, use VAPID key from Firebase Console
//         // Settings → Cloud Messaging → Web Push certificates
//         token = await _messaging.getToken(
//           vapidKey: 'YOUR_VAPID_KEY_HERE',
//         );
//       } else {
//         token = await _messaging.getToken();
//       }

//       if (token != null) {
//         await FirebaseFirestore.instance
//             .collection('getit_users')
//             .doc(uid)
//             .update({'fcmToken': token});
//         debugPrint('FCM Token saved: $token');
//       }

//       // Refresh token listener
//       _messaging.onTokenRefresh.listen((newToken) async {
//         final currentUid = FirebaseAuth.instance.currentUser?.uid;
//         if (currentUid != null) {
//           await FirebaseFirestore.instance
//               .collection('getit_users')
//               .doc(currentUid)
//               .update({'fcmToken': newToken});
//         }
//       });
//     } catch (e) {
//       debugPrint('Error saving FCM token: $e');
//     }
//   }

//   void _listenToMessages() {
//     // Foreground messages
//     FirebaseMessaging.onMessage.listen((message) {
//       if (kIsWeb) return; // Web handles notifications natively
//       _showLocalNotification(message);
//     });

//     // Background message handler is set at top level
//   }

//   Future<void> _showLocalNotification(RemoteMessage message) async {
//     if (kIsWeb) return;

//     final notification = message.notification;
//     if (notification == null) return;

//     final androidDetails = AndroidNotificationDetails(
//       _channelId,
//       _channelName,
//       channelDescription: _channelDesc,
//       importance: Importance.max,
//       priority: Priority.high,
//       playSound: true,
//       sound: const RawResourceAndroidNotificationSound('order_sound'),
//       enableVibration: true,
//       icon: '@mipmap/ic_launcher',
//     );

//     await _localNotifications.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       notification.title,
//       notification.body,
//       NotificationDetails(android: androidDetails),
//     );
//   }
// }

// // Must be top-level function for background messages
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   debugPrint('Background message: ${message.messageId}');
// }
