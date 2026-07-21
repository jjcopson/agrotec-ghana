import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'supabase_service.dart';
import '../constants/app_constants.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showLocalNotification(message);
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Init local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showLocalNotification(message);
    });

    // Save FCM token
    final token = await _fcm.getToken();
    if (token != null && SupabaseService.isLoggedIn) {
      await _saveFcmToken(token);
    }

    _fcm.onTokenRefresh.listen((token) async {
      if (SupabaseService.isLoggedIn) {
        await _saveFcmToken(token);
      }
    });
  }

  static Future<void> _saveFcmToken(String token) async {
    await SupabaseService.client
        .from('users')
        .update({'fcm_token': token})
        .eq('id', SupabaseService.currentUserId!);
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'agrotech_channel',
      'Agrotech Ghana',
      channelDescription: 'Agrotech Ghana notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Agrotech Ghana',
      message.notification?.body ?? '',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Send SMS via Arkesel
  static Future<void> sendSms({
    required String phone,
    required String message,
  }) async {
    try {
      final dio = Dio();
      await dio.post(
        'https://sms.arkesel.com/sms/api',
        queryParameters: {
          'action': 'send-sms',
          'api_key': AppConstants.arkeselApiKey,
          'to': phone,
          'from': AppConstants.arkeselSenderId,
          'sms': message,
        },
      );
    } catch (e) {
      // Log but don't throw — SMS failure shouldn't crash the app
    }
  }

  /// Create in-app notification in Supabase
  static Future<void> createInAppNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? referenceId,
    String? referenceType,
  }) async {
    await SupabaseService.client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'reference_id': referenceId,
      'reference_type': referenceType,
    });
  }
}
