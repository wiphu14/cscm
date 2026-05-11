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
  final _formKey     = GlobalKey<FormState>();
  final _houseCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _villageCtrl = TextEditingController(text: '1');

  bool _isLoading  = false;
  bool _notifGranted = false;
  int  _step       = 0; // 0=ขอ permission, 1=กรอกข้อมูล, 2=สำเร็จ

  // ============================================================
  // Step 0 — ขอ permission notification
  // ============================================================
  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      setState(() { _notifGranted = true; _step = 1; });
    }
  }

  Future<void> _requestPermission() async {
    // iOS — Firebase ขอเอง
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    // Android 13+
    final status = await Permission.notification.request();
    setState(() {
      _notifGranted = status.isGranted;
      if (_notifGranted) _step = 1;
    });
  }

  // ============================================================
  // Step 1 — กรอกข้อมูลและส่ง register_token.php
  // ============================================================
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // สร้าง unique user_id สำหรับเครื่องนี้
      final prefs  = await SharedPreferences.getInstance();
      var userId   = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) {
        userId = 'resident_v${_villageCtrl.text}_h${_houseCtrl.text}_${const Uuid().v4().substring(0, 8)}';
      }

      final result = await ApiService.registerToken(
        userId:      userId,
        houseNumber: _houseCtrl.text.trim(),
        villageId:   _villageCtrl.text.trim(),
        ownerName:   _nameCtrl.text.trim(),
        phone:       _phoneCtrl.text.trim(),
      );

      if (result['success'] == true) {
        // บันทึกข้อมูลใน SharedPreferences
        await prefs.setString('user_id',      userId);
        await prefs.setString('house_number', _houseCtrl.text.trim());
        await prefs.setString('village_id',   _villageCtrl.text.trim());
        await prefs.setString('owner_name',   _nameCtrl.text.trim());
        await prefs.setString('phone',        _phoneCtrl.text.trim());
        await prefs.setBool  ('is_registered', true);

        if (mounted) setState(() => _step = 2);

        // ไป HomeScreen หลัง 2 วินาที
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (mounted) {
          _showError(result['message'] ?? 'ลงทะเบียนไม่สำเร็จ กรุณาลองใหม่');
        }
      }
    } catch (e) {
      if (mounted) _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.prompt()),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _houseCtrl.dispose(); _nameCtrl.dispose();
    _phoneCtrl.dispose(); _villageCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
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
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.home_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'ลงทะเบียนลูกบ้าน',
                style: GoogleFonts.prompt(
                  fontSize: 26, fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D47A1),
                ),
              ),
              Text(
                'ทำเพียงครั้งเดียว เพื่อรับแจ้งเตือนเมื่อมีคนเข้าบ้านคุณ',
                style: GoogleFonts.prompt(
                  fontSize: 13, color: Colors.blueGrey.shade600,
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
        final active   = i == _step;
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
            width: 80, height: 80,
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
              fontSize: 18, fontWeight: FontWeight.w600,
              color: const Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'แอปต้องการสิทธิ์แจ้งเตือน\nเพื่อส่ง Push Notification\nเมื่อมีคนเข้าบ้านคุณ',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 14, color: Colors.blueGrey.shade600,
              height: 1.6, fontWeight: FontWeight.w300,
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
                  style: GoogleFonts.prompt(fontSize: 15, fontWeight: FontWeight.w600)),
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
              label:      'บ้านเลขที่ *',
              hint:       'เช่น 1, 2, 10/1',
              icon:       Icons.home_rounded,
              inputType:  TextInputType.text,
              validator:  (v) => (v == null || v.trim().isEmpty)
                  ? 'กรุณากรอกบ้านเลขที่'
                  : null,
              highlight:  true,   // เน้นพิเศษ
            ),
            const SizedBox(height: 12),

            // รหัสหมู่บ้าน
            _buildField(
              controller: _villageCtrl,
              label:      'รหัสหมู่บ้าน',
              hint:       'เช่น 1',
              icon:       Icons.location_city_rounded,
              inputType:  TextInputType.number,
              validator:  (v) => (v == null || v.trim().isEmpty)
                  ? 'กรุณากรอกรหัสหมู่บ้าน'
                  : null,
            ),
            const SizedBox(height: 20),

            _buildSectionLabel('ข้อมูลส่วนตัว', Icons.person_outline_rounded),
            const SizedBox(height: 16),

            _buildField(
              controller: _nameCtrl,
              label:      'ชื่อเจ้าของบ้าน',
              hint:       'กรอกชื่อ-นามสกุล',
              icon:       Icons.person_outline_rounded,
              inputType:  TextInputType.name,
              validator:  (v) => (v == null || v.trim().isEmpty)
                  ? 'กรุณากรอกชื่อ'
                  : null,
            ),
            const SizedBox(height: 12),

            _buildField(
              controller: _phoneCtrl,
              label:      'เบอร์โทรศัพท์',
              hint:       'เช่น 089-123-4567',
              icon:       Icons.phone_outlined,
              inputType:  TextInputType.phone,
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
                        fontSize: 12, color: const Color(0xFF2E7D32),
                        height: 1.5, fontWeight: FontWeight.w400,
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
                        width: 22, height: 22,
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
            width: 88, height: 88,
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
              fontSize: 22, fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'บ้านเลขที่ ${_houseCtrl.text.trim()}\nพร้อมรับการแจ้งเตือนแล้ว',
            textAlign: TextAlign.center,
            style: GoogleFonts.prompt(
              fontSize: 15, color: Colors.green.shade700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24, height: 24,
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
        Text(label, style: GoogleFonts.prompt(
          fontSize: 14, fontWeight: FontWeight.w600,
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
      controller:   controller,
      keyboardType: inputType,
      validator:    validator,
      style:        GoogleFonts.prompt(fontSize: 15),
      decoration: InputDecoration(
        labelText:    label,
        hintText:     hint,
        labelStyle:   GoogleFonts.prompt(
          color: highlight ? const Color(0xFF1565C0) : Colors.blueGrey,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
        ),
        hintStyle:    GoogleFonts.prompt(color: Colors.grey.shade400),
        prefixIcon:   Icon(icon,
            color: highlight ? const Color(0xFF1565C0) : Colors.blueGrey),
        filled:       true,
        fillColor:    highlight
            ? const Color(0xFFE3F2FD)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: highlight
                ? const Color(0xFF90CAF9)
                : Colors.blueGrey.shade100,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: highlight
                ? const Color(0xFF90CAF9)
                : Colors.blueGrey.shade100,
            width: highlight ? 1.5 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF1565C0), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }
}