// ============================================================
// firebase_options.dart — Android Only
// ไฟล์นี้: lib/firebase_options.dart
//
// ใส่ค่าจริงจาก google-services.json ที่ดาวน์โหลดจาก
// Firebase Console แทนที่ YOUR_... ทุกตัวด้านล่าง
// ============================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web platform is not configured. '
        'Run: flutterfire configure --platforms=android',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS is not configured in this build. '
          'Add iOS app in Firebase Console if needed.',
        );
      default:
        throw UnsupportedError(
          'Platform ${defaultTargetPlatform.name} is not supported.',
        );
    }
  }

  // ============================================================
  // ANDROID
  // ดูค่าทั้งหมดจาก google-services.json ที่ดาวน์โหลดมา:
  //
  //   apiKey            ← client[0].api_key[0].current_key
  //   appId             ← client[0].client_info.mobilesdk_app_id
  //   messagingSenderId ← project_info.project_number
  //   projectId         ← project_info.project_id
  //   storageBucket     ← project_info.storage_bucket
  // ============================================================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'YOUR_ANDROID_API_KEY',
    appId:             'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
  );
}