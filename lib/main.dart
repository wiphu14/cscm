import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';

// ============================================================
// Background handler — ต้องเป็น top-level function
// รับ notification ตอนแอปปิดอยู่ (terminated/background)
// ============================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // notification แสดงอัตโนมัติโดย FCM system tray
  debugPrint('📬 Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. Notification channels (Android 8+)
  await NotificationService.initialize();

  // 4. ตรวจว่าลงทะเบียนแล้วหรือยัง
  final prefs       = await SharedPreferences.getInstance();
  final isRegistered = prefs.getBool('is_registered') ?? false;

  runApp(ResidentAlertApp(isRegistered: isRegistered));
}

class ResidentAlertApp extends StatefulWidget {
  final bool isRegistered;
  const ResidentAlertApp({super.key, required this.isRegistered});

  @override
  State<ResidentAlertApp> createState() => _ResidentAlertAppState();
}

class _ResidentAlertAppState extends State<ResidentAlertApp> {
  @override
  void initState() {
    super.initState();
    _setupFcmListeners();
  }

  void _setupFcmListeners() {
    // แอปเปิดอยู่ foreground → แสดง notification ด้วย NotificationService
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Foreground message: ${message.notification?.title}');
      NotificationService.showLocalNotification(
        title: message.notification?.title ?? 'มีผู้เข้าหมู่บ้าน',
        body:  message.notification?.body  ?? '',
        data:  message.data,
      );
    });

    // แตะ notification ขณะแอปอยู่ background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Opened from background: ${message.data}');
      // navigate ไป home ได้ตรงนี้ถ้าต้องการ
    });

    // refresh token
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('🔑 Token refreshed');
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('is_registered') == true) {
        await ApiService.refreshToken(newToken);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alert Entry — ลูกบ้าน',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        textTheme:      GoogleFonts.promptTextTheme(),
        useMaterial3:   true,
        scaffoldBackgroundColor: const Color(0xFFF0F7FF),
      ),
      // เริ่มที่ SplashScreen เสมอ — มันจะ redirect เอง
      home: const SplashScreen(),
      routes: {
        '/register': (_) => const RegisterScreen(),
        '/home':     (_) => const HomeScreen(),
      },
    );
  }
}