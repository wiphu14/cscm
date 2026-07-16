// ============================================================
// firebase_options.dart — Android + iOS
// ไฟล์นี้: lib/firebase_options.dart
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
        return ios; // ← เพิ่ม iOS support
      default:
        throw UnsupportedError(
          'Platform ${defaultTargetPlatform.name} is not supported.',
        );
    }
  }

  // ============================================================
  // ANDROID — ค่าเดิม ไม่มีการเปลี่ยนแปลง
  // ============================================================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyAS424g5dNHzhr8yxX4bKbcx_16RzMeJok',
    appId:             '1:897687107250:android:43e1e450cfdb463af53bab',
    messagingSenderId: '897687107250',
    projectId:         'etscm1',
    storageBucket:     'etscm1.firebasestorage.app',
  );

  // ============================================================
  // iOS — ค่าจาก GoogleService-Info.plist
  // ============================================================
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyDD9Bthr-13NW7MrwDCqnnCUXkDhMW_Q7A',
    appId:             '1:897687107250:ios:dcc9690af9df184cf53bab',
    messagingSenderId: '897687107250',
    projectId:         'etscm1',
    storageBucket:     'etscm1.firebasestorage.app',
    iosBundleId:       'com.nutrada.residentalert',
  );
}