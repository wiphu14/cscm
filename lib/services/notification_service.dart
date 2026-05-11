import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============================================================
// NotificationService — แก้ไขสำหรับ flutter_local_notifications v17+
// API เปลี่ยนจาก positional → named parameters
// ============================================================

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ============================================================
  // initialize
  // ============================================================
  static Future<void> initialize() async {
    if (_initialized) return;

    // Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'entry_alert',
      'แจ้งเตือนผู้เข้าบ้าน',
      description: 'แจ้งเตือนเมื่อมีผู้มาหาที่บ้านเลขที่ของคุณ',
      importance: Importance.max,
      playSound: true,
    );

    // ============================================================
    // FIX: v17+ initialize() ใช้ named parameter 'settings'
    // เดิม: _notifications.initialize(initSettings)
    // ใหม่: _notifications.initialize(settings: initSettings)
    // ============================================================
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _notifications.initialize(
      settings: initSettings,   // <-- named parameter 'settings'
    );

    // สร้าง channel บน Android 8+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  // ============================================================
  // showLocalNotification
  // ============================================================
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'entry_alert',
      'แจ้งเตือนผู้เข้าบ้าน',
      channelDescription: 'แจ้งเตือนเมื่อมีผู้มาหาที่บ้านเลขที่ของคุณ',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ============================================================
    // FIX: v17+ show() ใช้ named parameters ทั้งหมด
    // เดิม: _notifications.show(id, title, body, details, payload: ...)
    // ใหม่: _notifications.show(id: ..., title: ..., body: ..., notificationDetails: ..., payload: ...)
    // ============================================================
    await _notifications.show(
      id:                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title:               title,
      body:                body,
      notificationDetails: notifDetails,
      payload:             data != null ? jsonEncode(data) : null,
    );
  }
}