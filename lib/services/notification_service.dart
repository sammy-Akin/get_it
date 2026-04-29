import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.initialize();
  await NotificationService.instance.showOrderNotification(
    title: message.notification?.title ?? 'Get It',
    body: message.notification?.body ?? '',
    payload: message.data['type'] ?? '',
  );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const _orderChannelId = 'getit_orders_v3';
  static const _orderChannelName = 'Order Alerts';
  static const _orderChannelDesc =
      'Critical alerts for new orders and assignments';

  Future<void> initialize() async {
    if (_isInitialized) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createNotificationChannel();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    await _saveFcmToken();

    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

    final channel = AndroidNotificationChannel(
      _orderChannelId,
      _orderChannelName,
      description: _orderChannelDesc,
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('order_alert'),
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF6C63FF),
      showBadge: true,
      vibrationPattern: vibrationPattern,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(channel);
    debugPrint('✅ Channel created: $_orderChannelId');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await showOrderNotification(
      title: message.notification?.title ?? 'Get It',
      body: message.notification?.body ?? '',
      payload: message.data['type'] ?? '',
    );
  }

  Future<void> showOrderNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    final vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

    final androidDetails = AndroidNotificationDetails(
      _orderChannelId,
      _orderChannelName,
      channelDescription: _orderChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('order_alert'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: false,
      styleInformation: const BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'order_alert.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final id = DateTime.now().second + DateTime.now().minute * 60;

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> _saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('getit_users').doc(uid).update({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _onTokenRefresh(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('getit_users').doc(uid).update({
      'fcmToken': token,
    });
  }

  Future<void> clearFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _messaging.deleteToken();
    await FirebaseFirestore.instance.collection('getit_users').doc(uid).update({
      'fcmToken': FieldValue.delete(),
    });
  }
}
