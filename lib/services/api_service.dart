import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ============================================================
// ApiService — HTTP calls เชื่อมกับ PHP backend
// เดียวกับที่ village-entry app ใช้
// ============================================================
class ApiService {
  // เปลี่ยนให้ตรงกับ server จริง (เดียวกับ entry_save.php)
  static const String baseUrl = 'https://yourserver.com/api';

  // ============================================================
  // 1. ลงทะเบียน FCM token + บ้านเลขที่ (ครั้งแรก)
  // เรียก register_token.php
  // ============================================================
  static Future<Map<String, dynamic>> registerToken({
    required String userId,
    required String houseNumber,
    required String villageId,
    required String ownerName,
    required String phone,
  }) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) throw Exception('ไม่สามารถดึง FCM token ได้');

      final response = await http.post(
        Uri.parse('$baseUrl/register_token.php'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'user_id':      userId,
          'fcm_token':    token,
          'house_number': houseNumber,
          'village_id':   villageId,
          'owner_name':   ownerName,
          'phone':        phone,
          'device_type':  Platform.isIOS ? 'ios' : 'android',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Server error ${response.statusCode}'};
    } catch (e) {
      debugPrint('🔴 registerToken error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================
  // 2. Refresh token เมื่อ Firebase สร้าง token ใหม่
  // ============================================================
  static Future<void> refreshToken(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await http.post(
        Uri.parse('$baseUrl/register_token.php'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'user_id':      prefs.getString('user_id')      ?? '',
          'fcm_token':    newToken,
          'house_number': prefs.getString('house_number') ?? '',
          'village_id':   prefs.getString('village_id')   ?? '1',
          'owner_name':   prefs.getString('owner_name')   ?? '',
          'phone':        prefs.getString('phone')        ?? '',
          'device_type':  Platform.isIOS ? 'ios' : 'android',
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('🔴 refreshToken error: $e');
    }
  }

  // ============================================================
  // 3. ดึงประวัติผู้เข้าของบ้านตัวเอง
  // PHP endpoint: entry_list.php?house_number=1&village_id=1
  // ============================================================
  static Future<List<Map<String, dynamic>>> getMyEntries() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final houseNumber = prefs.getString('house_number') ?? '';
      final villageId   = prefs.getString('village_id')   ?? '1';

      final uri = Uri.parse('$baseUrl/entry_list.php').replace(
        queryParameters: {
          'house_number': houseNumber,
          'village_id':   villageId,
          'limit':        '50',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
        if (data is Map && data['data'] is List) {
          return (data['data'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      debugPrint('🔴 getMyEntries error: $e');
      return [];
    }
  }

  // ============================================================
  // 4. อัปเดตข้อมูลบ้าน (ชื่อ, เบอร์) ใน residents table
  // ============================================================
  static Future<bool> updateProfile({
    required String ownerName,
    required String phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('$baseUrl/register_token.php'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'user_id':      prefs.getString('user_id')      ?? '',
          'fcm_token':    await FirebaseMessaging.instance.getToken() ?? '',
          'house_number': prefs.getString('house_number') ?? '',
          'village_id':   prefs.getString('village_id')   ?? '1',
          'owner_name':   ownerName,
          'phone':        phone,
          'device_type':  Platform.isIOS ? 'ios' : 'android',
        }),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}