import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// FcmHandlerGuard
// ใช้ใน main.dart หรือ screen เครื่องที่ 1 (Sunmi ป้อม รปภ.)
//
// วิธีใช้งาน:
//   1. เรียก FcmHandlerGuard.init(context) ตอน initState
//   2. ส่ง callback onContactConfirmed เพื่ออัปเดต UI รายการ
//
// ตัวอย่างใน visitor_entry_screen.dart หรือ dashboard_screen.dart:
//   FcmHandlerGuard.listen(
//     context: context,
//     onContactConfirmed: (data) {
//       setState(() {
//         // อัปเดต status ใน list ตาม log_id
//         final logId = int.tryParse(data['log_id'] ?? '0') ?? 0;
//         final idx = _entries.indexWhere((e) => e.logId == logId);
//         if (idx >= 0) _entries[idx] = _entries[idx].copyWith(contactConfirmed: true);
//       });
//     },
//   );
// ============================================================

typedef ContactConfirmedCallback = void Function(Map<String, dynamic> data);

class FcmHandlerGuard {
  FcmHandlerGuard._();

  // ============================================================
  // listen — รับ FCM foreground และ handle "contact_confirmed"
  // ============================================================
  static void listen({
    required BuildContext context,
    ContactConfirmedCallback? onContactConfirmed,
  }) {
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (!context.mounted) return;

      final type = msg.data['type'] ?? '';

      if (type == 'contact_confirmed') {
        // เรียก callback เพื่ออัปเดต UI
        onContactConfirmed?.call(msg.data);

        // แสดง Pop-up แจ้งเตือนที่ป้อม รปภ.
        _showConfirmedDialog(context, msg.data);
      }
    });
  }

  // ============================================================
  // _showConfirmedDialog — แสดง dialog ป็อปอัป ที่เครื่องที่ 1
  // ============================================================
  static void _showConfirmedDialog(
      BuildContext context, Map<String, dynamic> data) {
    final houseNumber = data['house_number'] ?? '';
    final visitorName = data['visitor_name'] ?? data['contact_name'] ?? 'ผู้มาติดต่อ';
    final licensePlate = data['license_plate'] ?? '';
    final confirmedBy = data['confirmed_by'] ?? 'ลูกบ้าน';
    final note = data['note'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon สีเขียว
              Container(
                width: 72, height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                '✅ ติดต่อสำเร็จแล้ว!',
                style: GoogleFonts.prompt(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E7D32)),
              ),
              const SizedBox(height: 8),
              if (houseNumber.isNotEmpty) ...[
                Text(
                  'บ้านเลขที่ $houseNumber',
                  style: GoogleFonts.prompt(
                      fontSize: 14, color: const Color(0xFF0D47A1),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                visitorName,
                style: GoogleFonts.prompt(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              if (licensePlate.isNotEmpty && licensePlate != '-') ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_rounded,
                        size: 14, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 4),
                    Text(licensePlate,
                        style: GoogleFonts.prompt(
                            fontSize: 13, color: const Color(0xFF1E88E5))),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ยืนยันโดย: $confirmedBy',
                  style: GoogleFonts.prompt(
                      fontSize: 12, color: const Color(0xFF558B2F)),
                ),
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'หมายเหตุ: $note',
                  style: GoogleFonts.prompt(
                      fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('รับทราบ',
                      style: GoogleFonts.prompt(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // showSnackbar — ทางเลือกแทน dialog (แบบเบาๆ ไม่ขัดจอ)
  // ============================================================
  static void showConfirmedSnackbar(
      BuildContext context, Map<String, dynamic> data) {
    final houseNumber = data['house_number'] ?? '';
    final visitorName = data['visitor_name'] ?? data['contact_name'] ?? 'ผู้มาติดต่อ';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ ติดต่อสำเร็จ${houseNumber.isNotEmpty ? " บ้าน $houseNumber" : ""}',
                    style: GoogleFonts.prompt(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  Text(
                    visitorName,
                    style: GoogleFonts.prompt(
                        fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}