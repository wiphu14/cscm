import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

// ============================================================
// RegisterScreen — ลงทะเบียนครั้งแรกและครั้งเดียว
// บันทึก: house_number, owner_name, phone, village_id, user_id
// ส่งไป register_token.php พร้อม FCM token
// ============================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _houseCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _villageCtrl = TextEditingController(text: '1');

  bool _isLoading = false;
  bool _notifGranted = false;
  int _step = 0; // 0=ขอ permission, 1=กรอกข้อมูล, 2=สำเร็จ

  // ============================================================
  // Step 0 — ขอ permission notification
  // ============================================================
  @override
  void initState() {
    super.initState();
    debugPrint('🟡 [RegisterScreen] initState() called');
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    debugPrint('🟡 [Permission] กำลังตรวจสอบสิทธิ์แจ้งเตือน...');

    if (Platform.isIOS) {
      // iOS — เช็คสถานะจาก Firebase โดยตรง ไม่ใช้ permission_handler
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      debugPrint(
          '🟡 [Permission] iOS authorizationStatus = ${settings.authorizationStatus}');
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) {
        debugPrint('🟢 [Permission] iOS ได้รับสิทธิ์แล้ว → ข้ามไป Step 1');
        setState(() {
          _notifGranted = true;
          _step = 1;
        });
      } else {
        debugPrint('🟠 [Permission] iOS ยังไม่ได้รับสิทธิ์ → อยู่ที่ Step 0');
      }
      return;
    }

    // Android
    final status = await Permission.notification.status;
    debugPrint('🟡 [Permission] status = $status');
    if (status.isGranted) {
      debugPrint('🟢 [Permission] ได้รับสิทธิ์แล้ว → ข้ามไป Step 1');
      setState(() {
        _notifGranted = true;
        _step = 1;
      });
    } else {
      debugPrint('🟠 [Permission] ยังไม่ได้รับสิทธิ์ → อยู่ที่ Step 0');
    }
  }

  Future<void> _requestPermission() async {
    debugPrint('🟡 [Permission] กำลังขอสิทธิ์ Firebase...');
    // iOS — Firebase ขอเอง
    final firebaseSettings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        '🟡 [Permission] Firebase authorizationStatus = ${firebaseSettings.authorizationStatus}');

    if (Platform.isIOS) {
      // iOS — ใช้ผลจาก Firebase โดยตรง ห้ามขอผ่าน permission_handler ซ้ำ
      // (บน iOS ระบบถามได้ครั้งเดียว การขอซ้ำผ่าน permission_handler
      // มักรายงานสถานะผิดเป็น permanentlyDenied ทั้งที่ Firebase authorized แล้ว)
      final granted = firebaseSettings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          firebaseSettings.authorizationStatus ==
              AuthorizationStatus.provisional;
      debugPrint('🟡 [Permission] iOS granted = $granted');

      setState(() {
        _notifGranted = granted;
        if (granted) _step = 1;
      });

      if (!granted) {
        debugPrint('🔴 [Permission] iOS ผู้ใช้ปฏิเสธสิทธิ์แจ้งเตือน');
      }
      return;
    }

    // Android 13+
    debugPrint('🟡 [Permission] กำลังขอสิทธิ์ Android notification...');
    final status = await Permission.notification.request();
    debugPrint(
        '🟡 [Permission] Android status = $status | isGranted = ${status.isGranted}');

    setState(() {
      _notifGranted = status.isGranted;
      if (_notifGranted) _step = 1;
    });

    if (!status.isGranted) {
      debugPrint('🔴 [Permission] ผู้ใช้ปฏิเสธสิทธิ์แจ้งเตือน');
    }
  }

  // ============================================================
  // Step 1 — กรอกข้อมูลและส่ง register_token.php
  // ============================================================
  Future<void> _handleRegister() async {
    debugPrint('🟡 [Register] กดปุ่มลงทะเบียน');

    if (!_formKey.currentState!.validate()) {
      debugPrint('🔴 [Register] Form validation ไม่ผ่าน');
      return;
    }
    debugPrint('🟢 [Register] Form validation ผ่าน');

    setState(() => _isLoading = true);

    try {
      // ---- ดึง / สร้าง user_id ----
      debugPrint('🟡 [Register] กำลังโหลด SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      var userId = prefs.getString('user_id');
      debugPrint('🟡 [Register] user_id เดิม = $userId');

      if (userId == null || userId.isEmpty) {
        userId =
            'resident_v${_villageCtrl.text}_h${_houseCtrl.text}_${const Uuid().v4().substring(0, 8)}';
        debugPrint('🟡 [Register] สร้าง user_id ใหม่ = $userId');
      }

      // ---- ดึง FCM Token ----
      debugPrint('🟡 [Register] กำลังขอ FCM token...');
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        debugPrint('🟢 [Register] FCM token = $fcmToken');
      } catch (fcmErr) {
        debugPrint('🔴 [Register] ดึง FCM token ไม่ได้: $fcmErr');
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint(
            '🔴 [Register] FCM token เป็น null หรือว่าง → อาจเกิดจาก Firebase ตั้งค่าไม่ถูก');
      }

      // ---- ข้อมูลที่จะส่ง ----
      debugPrint('─────────────────────────────────');
      debugPrint('🟡 [Register] ข้อมูลที่จะส่ง:');
      debugPrint('   userId      = $userId');
      debugPrint('   houseNumber = ${_houseCtrl.text.trim()}');
      debugPrint('   villageId   = ${_villageCtrl.text.trim()}');
      debugPrint('   ownerName   = ${_nameCtrl.text.trim()}');
      debugPrint('   phone       = ${_phoneCtrl.text.trim()}');
      debugPrint('   fcmToken    = $fcmToken');
      debugPrint('─────────────────────────────────');

      // ---- เรียก API ----
      debugPrint('🟡 [Register] กำลังเรียก ApiService.registerToken...');
      final stopwatch = Stopwatch()..start();

      final result = await ApiService.registerToken(
        userId: userId,
        houseNumber: _houseCtrl.text.trim(),
        villageId: _villageCtrl.text.trim(),
        ownerName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      stopwatch.stop();
      debugPrint(
          '🟡 [Register] API ใช้เวลา ${stopwatch.elapsedMilliseconds} ms');
      debugPrint('🟡 [Register] ผลลัพธ์จาก API = $result');

      // ---- ตรวจสอบผลลัพธ์ ----
      if (result['success'] == true) {
        debugPrint(
            '🟢 [Register] ลงทะเบียนสำเร็จ กำลังบันทึก SharedPreferences...');

        await prefs.setString('user_id', userId);
        await prefs.setString('house_number', _houseCtrl.text.trim());
        await prefs.setString('village_id', _villageCtrl.text.trim());
        await prefs.setString('owner_name', _nameCtrl.text.trim());
        await prefs.setString('phone', _phoneCtrl.text.trim());
        await prefs.setBool('is_registered', true);

        debugPrint('🟢 [Register] บันทึก SharedPreferences สำเร็จ');
        debugPrint('🟢 [Register] เปลี่ยนไป Step 2 (Success)');

        if (mounted) setState(() => _step = 2);

        await Future.delayed(const Duration(seconds: 2));
        debugPrint('🟢 [Register] กำลัง navigate ไป /home');
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        final errMsg = result['message'] ?? 'ลงทะเบียนไม่สำเร็จ กรุณาลองใหม่';
        debugPrint(
            '🔴 [Register] API ตอบกลับ success=false → message: $errMsg');
        if (mounted) _showError(errMsg);
      }
    } catch (e, stack) {
      debugPrint('🔴 [Register] Exception: $e');
      debugPrint('🔴 [Register] StackTrace:\n$stack');
      if (mounted) _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('🟡 [Register] _handleRegister() เสร็จสิ้น');
    }
  }

  void _showError(String msg) {
    debugPrint('🔴 [UI] แสดง error SnackBar: $msg');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.prompt()),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    debugPrint('🟡 [RegisterScreen] dispose() called');
    _houseCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _villageCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    debugPrint('🟡 [RegisterScreen] build() step=$_step');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.home_rounded,
                    size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'ลงทะเบียนลูกบ้าน',
                style: GoogleFonts.prompt(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D47A1),
                ),
              ),
              Text(
                'ทำเพียงครั้งเดียว เพื่อรับแจ้งเตือนเมื่อมีคนเข้าบ้านคุณ',
                style: GoogleFonts.prompt(
                  fontSize: 13,
                  color: Colors.blueGrey.shade600,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 32),

              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: 28),

              // Step content
              if (_step == 0) _buildPermissionStep(),
              if (_step == 1) _buildFormStep(),
              if (_step == 2) _buildSuccessStep(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Step indicator ----
  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(3, (i) {
        final active = i == _step;
        final complete = i < _step;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: complete || active
                        ? const Color(0xFF1565C0)
                        : const Color(0xFFBBDEFB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  // ============================================================
  // Step 0: ขอ permission
  // ============================================================
  Widget _buildPermissionStep() {
    return _buildCard(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.notifications_rounded,
                size: 44, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 20),
          Text(
            'อนุญาตการแจ้งเตือน',
            style: GoogleFonts.prompt(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'แอปต้องการสิทธิ์แจ้งเตือน\nเพื่อส่ง Push Notification\nเมื่อมีคนเข้าบ้านคุณ',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 14,
              color: Colors.blueGrey.shade600,
              height: 1.6,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text('อนุญาตการแจ้งเตือน',
                  style: GoogleFonts.prompt(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Step 1: กรอกข้อมูล
  // ============================================================
  Widget _buildFormStep() {
    return Form(
      key: _formKey,
      child: _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('ข้อมูลบ้านของคุณ', Icons.home_outlined),
            const SizedBox(height: 16),

            // บ้านเลขที่ — สำคัญที่สุด
            _buildField(
              controller: _houseCtrl,
              label: 'บ้านเลขที่ *',
              hint: 'เช่น 1, 2, 10/1',
              icon: Icons.home_rounded,
              inputType: TextInputType.text,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'กรุณากรอกบ้านเลขที่'
                  : null,
              highlight: true, // เน้นพิเศษ
            ),
            const SizedBox(height: 12),

            // รหัสหมู่บ้าน
            _buildField(
              controller: _villageCtrl,
              label: 'รหัสหมู่บ้าน',
              hint: 'เช่น 1',
              icon: Icons.location_city_rounded,
              inputType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'กรุณากรอกรหัสหมู่บ้าน'
                  : null,
            ),
            const SizedBox(height: 20),

            _buildSectionLabel('ข้อมูลส่วนตัว', Icons.person_outline_rounded),
            const SizedBox(height: 16),

            _buildField(
              controller: _nameCtrl,
              label: 'ชื่อเจ้าของบ้าน',
              hint: 'กรอกชื่อ-นามสกุล',
              icon: Icons.person_outline_rounded,
              inputType: TextInputType.name,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _phoneCtrl,
              label: 'เบอร์โทรศัพท์',
              hint: 'เช่น 089-123-4567',
              icon: Icons.phone_outlined,
              inputType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF2E7D32), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'บ้านเลขที่ต้องตรงกับข้อมูลในระบบ\nเพื่อรับแจ้งเตือนได้ถูกต้อง',
                      style: GoogleFonts.prompt(
                        fontSize: 12,
                        color: const Color(0xFF2E7D32),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        'ลงทะเบียนและรับแจ้งเตือน',
                        style: GoogleFonts.prompt(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Step 2: สำเร็จ
  // ============================================================
  Widget _buildSuccessStep() {
    return _buildCard(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 52, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 20),
          Text(
            'ลงทะเบียนสำเร็จ!',
            style: GoogleFonts.prompt(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'บ้านเลขที่ ${_houseCtrl.text.trim()}\nพร้อมรับการแจ้งเตือนแล้ว',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 15,
              color: Colors.green.shade700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 8),
          Text(
            'กำลังเข้าสู่แอป...',
            style: GoogleFonts.prompt(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ---- Reusable widgets ----
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.prompt(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1565C0),
            )),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
    bool highlight = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: validator,
      style: GoogleFonts.prompt(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.prompt(
          color: highlight ? const Color(0xFF1565C0) : Colors.blueGrey,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
        ),
        hintStyle: GoogleFonts.prompt(color: Colors.grey.shade400),
        prefixIcon: Icon(icon,
            color: highlight ? const Color(0xFF1565C0) : Colors.blueGrey),
        filled: true,
        fillColor:
            highlight ? const Color(0xFFE3F2FD) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color:
                highlight ? const Color(0xFF90CAF9) : Colors.blueGrey.shade100,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color:
                highlight ? const Color(0xFF90CAF9) : Colors.blueGrey.shade100,
            width: highlight ? 1.5 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
