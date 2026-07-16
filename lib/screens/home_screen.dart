import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/entry_model.dart';
import '../services/api_service.dart';
import 'settings_screen.dart';

// ============================================================
// HomeScreen — หน้าหลัก หลังลงทะเบียนแล้ว (เครื่องที่ 2 ลูกบ้าน)
// - แสดงประวัติผู้เข้าเฉพาะวันนี้
// - เปลี่ยนวันได้ด้วยปุ่ม < >
// - real-time update เมื่อรับ FCM foreground
// - ปุ่ม "ติดต่อสำเร็จ" ส่งแจ้งกลับไปเครื่องที่ 1
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _houseNumber = '';
  String _ownerName   = '';
  String _villageId   = '1';
  bool   _isLoading   = true;
  bool   _hasNewAlert = false;

  // วันที่ที่แสดงอยู่ตอนนี้ (เริ่มต้นเป็นวันนี้)
  DateTime _selectedDate = DateTime.now();

  List<EntryModel> _entries     = [];
  EntryModel?      _latestAlert;

  // track log_id ที่กำลัง confirm อยู่ (กันกด 2 ครั้ง)
  final Set<int> _confirmingIds = {};

  // ============================================================
  // Init
  // ============================================================
  @override
  void initState() {
    super.initState();
    _loadProfile().then((_) => _loadEntries());
    _listenForegroundMessages();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _houseNumber = prefs.getString('house_number') ?? '';
      _ownerName   = prefs.getString('owner_name')   ?? '';
      _villageId   = prefs.getString('village_id')   ?? '1';
    });
  }

  // ============================================================
  // โหลดข้อมูลตามวันที่เลือก
  // ============================================================
  Future<void> _loadEntries() async {
    if (_houseNumber.isEmpty) return;
    setState(() => _isLoading = true);

    final dateStr = _formatDateParam(_selectedDate);
    final data    = await ApiService.getMyEntries(
      date:        dateStr,
      houseNumber: _houseNumber,
      villageId:   _villageId,
    );

    setState(() {
      _entries   = data.map(EntryModel.fromJson).toList();
      _isLoading = false;
      if (!_isToday(_selectedDate)) _hasNewAlert = false;
    });
  }

  // ============================================================
  // รับ FCM ตอน foreground
  // ============================================================
  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (!mounted) return;

      // ถ้าเป็น FCM ประเภท "contact_confirmed" → แสดง Snackbar ที่เครื่องที่ 2 ด้วย
      if (msg.data['type'] == 'contact_confirmed') {
        // ไม่ต้องทำอะไรพิเศษที่เครื่องที่ 2
        return;
      }

      final entry = EntryModel.fromFcmData(msg.data);
      setState(() {
        _latestAlert = entry;
        _hasNewAlert = true;
        if (_isToday(_selectedDate)) {
          _entries.insert(0, entry);
        }
      });
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _latestAlert = null);
      });
    });
  }

  // ============================================================
  // เปลี่ยนวัน
  // ============================================================
  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (newDate.isAfter(DateTime.now())) return;
    setState(() => _selectedDate = newDate);
    _loadEntries();
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _formatDateParam(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateDisplay(DateTime d) {
    const thMonths = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final year = d.year + 543;
    return '${d.day} ${thMonths[d.month]} $year';
  }

  // ============================================================
  // กด "ติดต่อสำเร็จ" — แสดง dialog ยืนยัน
  // ============================================================
  Future<void> _onConfirmContact(EntryModel entry) async {
    if (_confirmingIds.contains(entry.logId)) return;

    // แสดง dialog ยืนยัน
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF2E7D32), size: 28),
            const SizedBox(width: 8),
            Text('ยืนยันการติดต่อ',
                style: GoogleFonts.prompt(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ยืนยันว่าได้ติดต่อกับ',
                style: GoogleFonts.prompt(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(entry.contactName,
                style: GoogleFonts.prompt(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D47A1))),
            if (entry.licensePlate.isNotEmpty && entry.licensePlate != '-') ...[
              const SizedBox(height: 2),
              Text('ทะเบียน ${entry.licensePlate}',
                  style: GoogleFonts.prompt(
                      fontSize: 13, color: const Color(0xFF1E88E5))),
            ],
            const SizedBox(height: 12),
            Text('ระบบจะแจ้งป้อม รปภ. ว่าติดต่อสำเร็จแล้ว',
                style: GoogleFonts.prompt(
                    fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก',
                style: GoogleFonts.prompt(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ยืนยัน',
                style: GoogleFonts.prompt(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ส่ง API confirm
    setState(() => _confirmingIds.add(entry.logId));

    try {
      final result = await ApiService.confirmContact(
        logId:      entry.logId,
        villageId:  _villageId,
        houseNumber: _houseNumber,
        confirmedBy: _ownerName.isNotEmpty ? _ownerName : 'ลูกบ้าน',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // อัปเดต UI ทันที — เปลี่ยน status ของ entry นั้น
        setState(() {
          final idx = _entries.indexWhere((e) => e.logId == entry.logId);
          if (idx >= 0) {
            _entries[idx] = _entries[idx].copyWith(contactConfirmed: true);
          }
          // ถ้า latestAlert เป็นรายการเดียวกัน ล้างออก
          if (_latestAlert?.logId == entry.logId) {
            _latestAlert = null;
            _hasNewAlert = false;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ แจ้งป้อม รปภ. ว่าติดต่อสำเร็จแล้ว',
                    style: GoogleFonts.prompt(
                        fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            content: Text(
              'เกิดข้อผิดพลาด: ${result['message'] ?? 'ไม่ทราบสาเหตุ'}',
              style: GoogleFonts.prompt(fontSize: 13, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('เกิดข้อผิดพลาด: $e',
                style: GoogleFonts.prompt(fontSize: 13, color: Colors.white)),
          ),
        );
      }
    } finally {
      setState(() => _confirmingIds.remove(entry.logId));
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: RefreshIndicator(
        onRefresh: _loadEntries,
        color: const Color(0xFF1565C0),
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(child: _buildHouseCard()),
            if (_latestAlert != null)
              SliverToBoxAdapter(child: _buildAlertBanner()),
            SliverToBoxAdapter(child: _buildDateSelector()),
            SliverToBoxAdapter(child: _buildSectionTitle()),
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                    ),
                  )
                : _entries.isEmpty
                    ? SliverFillRemaining(child: _buildEmpty())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildEntryCard(
                            _entries[i],
                            i == 0 && _hasNewAlert && _isToday(_selectedDate),
                          ),
                          childCount: _entries.length,
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  // ---- App Bar ----
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned:          true,
      expandedHeight:  0,
      backgroundColor: const Color(0xFF1565C0),
      elevation:       0,
      title: Text(
        '🔔 Alert Entry',
        style: GoogleFonts.prompt(
          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      actions: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {},
            ),
            if (_hasNewAlert)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ).then((_) => _loadProfile()),
        ),
      ],
    );
  }

  // ---- House Card ----
  Widget _buildHouseCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.home_rounded, size: 34, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'บ้านเลขที่ $_houseNumber',
                  style: GoogleFonts.prompt(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  _ownerName.isNotEmpty ? _ownerName : 'ลูกบ้าน',
                  style: GoogleFonts.prompt(
                    fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF69F0AE), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'พร้อมรับแจ้งเตือน',
                      style: GoogleFonts.prompt(
                        fontSize: 12, color: const Color(0xFF69F0AE),
                        fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${_entries.length}',
                style: GoogleFonts.prompt(
                  fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Text(
                'ผู้เข้า',
                style: GoogleFonts.prompt(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Date Selector ----
  Widget _buildDateSelector() {
    final isToday = _isToday(_selectedDate);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1565C0)),
            onPressed: () => _changeDate(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Column(
            children: [
              Text(
                _formatDateDisplay(_selectedDate),
                style: GoogleFonts.prompt(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D47A1)),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'วันนี้',
                    style: GoogleFonts.prompt(
                      fontSize: 10, color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isToday ? Colors.grey.shade300 : const Color(0xFF1565C0),
            ),
            onPressed: isToday ? null : () => _changeDate(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ---- Alert Banner ----
  Widget _buildAlertBanner() {
    final e = _latestAlert!;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(e.visitorId),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5722),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ มีคนมาหาบ้านคุณ!',
                      style: GoogleFonts.prompt(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(
                    '${e.contactName}  ${e.licensePlate.isNotEmpty ? "| ${e.licensePlate}" : ""}',
                    style: GoogleFonts.prompt(
                      fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                  if (e.purpose.isNotEmpty)
                    Text(e.purpose,
                        style: GoogleFonts.prompt(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
            // ปุ่มติดต่อสำเร็จบน Banner
            GestureDetector(
              onTap: () => _onConfirmContact(e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('✅ สำเร็จ',
                    style: GoogleFonts.prompt(
                        fontSize: 11, color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _latestAlert = null;
                _hasNewAlert = false;
              }),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Section Title ----
  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ประวัติผู้เข้าบ้านเลขที่ $_houseNumber',
            style: GoogleFonts.prompt(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: const Color(0xFF0D47A1)),
          ),
          GestureDetector(
            onTap: _loadEntries,
            child: Text('รีเฟรช',
                style: GoogleFonts.prompt(
                  fontSize: 12, color: const Color(0xFF1E88E5))),
          ),
        ],
      ),
    );
  }

  // ---- Entry Card ----
  Widget _buildEntryCard(EntryModel e, bool isNew) {
    final timeStr = _formatTime(e.entryTime);
    final isConfirmed     = e.contactConfirmed;
    final isConfirming    = _confirmingIds.contains(e.logId);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isConfirmed
            ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
            : isNew
                ? Border.all(color: const Color(0xFF1E88E5), width: 1.5)
                : Border.all(color: const Color(0xFFBBDEFB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: isConfirmed
                        ? const Color(0xFFE8F5E9)
                        : isNew
                            ? const Color(0xFFE3F2FD)
                            : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isConfirmed
                        ? Icons.check_circle_rounded
                        : Icons.person_rounded,
                    size: 30,
                    color: isConfirmed
                        ? const Color(0xFF2E7D32)
                        : isNew
                            ? const Color(0xFF1565C0)
                            : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.contactName,
                              style: GoogleFonts.prompt(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: const Color(0xFF0D47A1)),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Badge: ติดต่อสำเร็จ / ใหม่
                          if (isConfirmed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('✅ ติดต่อแล้ว',
                                  style: GoogleFonts.prompt(
                                    fontSize: 10, color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            )
                          else if (isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5722),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('ใหม่',
                                  style: GoogleFonts.prompt(
                                    fontSize: 10, color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (e.licensePlate.isNotEmpty && e.licensePlate != '-')
                        Row(children: [
                          const Icon(Icons.directions_car_rounded,
                              size: 12, color: Color(0xFF1E88E5)),
                          const SizedBox(width: 4),
                          Text(e.licensePlate,
                              style: GoogleFonts.prompt(
                                fontSize: 12, color: const Color(0xFF1E88E5),
                                fontWeight: FontWeight.w500)),
                        ]),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: [
                          if (e.vehicleType.isNotEmpty)
                            _buildTag(e.vehicleType,
                                const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                          if (e.purpose.isNotEmpty)
                            _buildTag(e.purpose,
                                const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(timeStr,
                    style: GoogleFonts.prompt(
                      fontSize: 11, color: Colors.blueGrey.shade400)),
              ],
            ),
            // ปุ่ม "ติดต่อสำเร็จ" — แสดงเฉพาะเมื่อยังไม่ได้ยืนยัน
            if (!isConfirmed) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirming
                        ? Colors.grey.shade300
                        : const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isConfirming ? null : () => _onConfirmContact(e),
                  icon: isConfirming
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    isConfirming ? 'กำลังส่ง...' : 'ติดต่อสำเร็จ',
                    style: GoogleFonts.prompt(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: GoogleFonts.prompt(
            fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  // ---- Empty State ----
  Widget _buildEmpty() {
    final isToday = _isToday(_selectedDate);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 12),
          Text(
            'ไม่มีผู้เข้าบ้านเลขที่ $_houseNumber',
            style: GoogleFonts.prompt(fontSize: 14, color: Colors.blueGrey.shade400),
          ),
          const SizedBox(height: 4),
          Text(
            'วันที่ ${_formatDateDisplay(_selectedDate)}',
            style: GoogleFonts.prompt(fontSize: 12, color: Colors.blueGrey.shade300),
          ),
          if (isToday) ...[
            const SizedBox(height: 6),
            Text(
              'ดึงข้อมูลลงเพื่อรีเฟรช',
              style: GoogleFonts.prompt(fontSize: 12, color: Colors.blueGrey.shade300),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final dt   = DateTime.parse(raw).toLocal();
      final now  = DateTime.now();
      final diff = now.difference(dt);
      if (_isToday(_selectedDate)) {
        if (diff.inMinutes < 1)  return 'เพิ่งเข้า';
        if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
        if (diff.inHours   < 24) return '${diff.inHours} ชม.ที่แล้ว';
      }
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
    } catch (_) {
      return raw;
    }
  }
}