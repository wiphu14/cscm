import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

// ============================================================
// SettingsScreen — จัดการข้อมูลบ้านและ re-register token
// ============================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _houseNumber = '';
  String _villageId   = '1';
  String _userId      = '';
  bool   _isSaving    = false;
  bool   _saved       = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _houseNumber        = prefs.getString('house_number') ?? '';
      _villageId          = prefs.getString('village_id')   ?? '1';
      _userId             = prefs.getString('user_id')      ?? '';
      _nameCtrl.text  = prefs.getString('owner_name')   ?? '';
      _phoneCtrl.text = prefs.getString('phone')        ?? '';
    });
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; _saved = false; });
    final ok = await ApiService.updateProfile(
      ownerName: _nameCtrl.text.trim(),
      phone:     _phoneCtrl.text.trim(),
    );
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('owner_name', _nameCtrl.text.trim());
      await prefs.setString('phone',      _phoneCtrl.text.trim());
    }
    if (mounted) {
      setState(() { _isSaving = false; _saved = ok; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ บันทึกสำเร็จ' : '❌ บันทึกไม่สำเร็จ',
            style: GoogleFonts.prompt()),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _clearAndReRegister() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ลงทะเบียนใหม่?', style: GoogleFonts.prompt(fontWeight: FontWeight.w600)),
        content: Text(
          'จะล้างข้อมูลเดิมและพาไปหน้าลงทะเบียนใหม่\nบ้านเลขที่จะต้องกรอกใหม่',
          style: GoogleFonts.prompt(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: GoogleFonts.prompt()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('ลงทะเบียนใหม่',
                style: GoogleFonts.prompt(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/register', (_) => false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: AppBar(
        title: Text('ตั้งค่า',
            style: GoogleFonts.prompt(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // -- ข้อมูลบ้าน (read-only) --
            _buildSection(
              title: 'ข้อมูลการลงทะเบียน',
              icon:  Icons.home_rounded,
              child: Column(
                children: [
                  _buildInfoRow('บ้านเลขที่',   _houseNumber,
                      icon: Icons.home_outlined, highlight: true),
                  const Divider(height: 20),
                  _buildInfoRow('รหัสหมู่บ้าน', _villageId,
                      icon: Icons.location_city_outlined),
                  const Divider(height: 20),
                  _buildInfoRow('User ID',       _userId,
                      icon: Icons.fingerprint_rounded, monospace: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // -- แก้ไขข้อมูลส่วนตัว --
            _buildSection(
              title: 'แก้ไขข้อมูล',
              icon:  Icons.edit_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditField(_nameCtrl,  'ชื่อเจ้าของบ้าน', Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildEditField(_phoneCtrl, 'เบอร์โทรศัพท์',    Icons.phone_outlined,
                      inputType: TextInputType.phone),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : Icon(_saved ? Icons.check_rounded : Icons.save_rounded),
                      label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึกการเปลี่ยนแปลง',
                          style: GoogleFonts.prompt(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            // -- ลงทะเบียนใหม่ --
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _clearAndReRegister,
                icon: const Icon(Icons.refresh_rounded, color: Colors.red),
                label: Text('ลงทะเบียนใหม่ (เปลี่ยนบ้านเลขที่)',
                    style: GoogleFonts.prompt(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'v1.0.0 — Alert Entry Resident App',
                style: GoogleFonts.prompt(
                  fontSize: 11, color: Colors.blueGrey.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Text(title, style: GoogleFonts.prompt(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0))),
              ],
            ),
          ),
          const Divider(height: 16, indent: 16, endIndent: 16),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {
    required IconData icon,
    bool highlight = false,
    bool monospace = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16,
            color: highlight ? const Color(0xFF1565C0) : Colors.blueGrey),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.prompt(
              fontSize: 11, color: Colors.blueGrey.shade500)),
            Text(
              value.isEmpty ? '—' : value,
              style: monospace
                  ? GoogleFonts.sourceCodePro(
                      fontSize: 12, color: Colors.blueGrey.shade700)
                  : GoogleFonts.prompt(
                      fontSize: highlight ? 18 : 14,
                      fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                      color: highlight
                          ? const Color(0xFF0D47A1)
                          : Colors.blueGrey.shade700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
  }) {
    return TextFormField(
      controller:   ctrl,
      keyboardType: inputType,
      style:        GoogleFonts.prompt(fontSize: 14),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: GoogleFonts.prompt(color: Colors.blueGrey),
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        filled:     true,
        fillColor:  const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}