import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/entry_model.dart';
import '../services/api_service.dart';
import 'settings_screen.dart';

// ============================================================
// HomeScreen — หน้าหลัก หลังลงทะเบียนแล้ว
// - แสดงบ้านเลขที่และสถานะการแจ้งเตือน
// - รายการผู้เข้าล่าสุดของบ้านตัวเอง
// - real-time update เมื่อรับ FCM foreground
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _houseNumber  = '';
  String _ownerName    = '';
  String _villageId    = '1';
  bool   _isLoading    = true;
  bool   _hasNewAlert  = false;

  List<EntryModel> _entries     = [];
  EntryModel?      _latestAlert; // alert ที่เพิ่งได้รับ (foreground)

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadEntries();
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

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getMyEntries();
    setState(() {
      _entries   = data.map(EntryModel.fromJson).toList();
      _isLoading = false;
    });
  }

  // ============================================================
  // รับ FCM ตอน foreground — เพิ่มที่ด้านบนของรายการทันที
  // ============================================================
  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (!mounted) return;
      final entry = EntryModel.fromFcmData(msg.data);
      setState(() {
        _latestAlert = entry;
        _hasNewAlert = true;
        _entries.insert(0, entry); // เพิ่มด้านบนรายการ
      });
      // auto dismiss alert banner หลัง 8 วินาที
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _latestAlert = null);
      });
    });
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
            SliverToBoxAdapter(child: _buildSectionTitle()),
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1565C0)),
                    ),
                  )
                : _entries.isEmpty
                    ? SliverFillRemaining(child: _buildEmpty())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _buildEntryCard(_entries[i], i == 0 && _hasNewAlert),
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
        // badge เมื่อมี alert ใหม่
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
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: Colors.white),
                ),
                Text(
                  _ownerName.isNotEmpty ? _ownerName : 'ลูกบ้าน',
                  style: GoogleFonts.prompt(
                    fontSize: 13, color: Colors.white70,
                    fontWeight: FontWeight.w300),
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
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: Colors.white),
              ),
              Text(
                'ผู้เข้า',
                style: GoogleFonts.prompt(
                  fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Alert Banner (foreground) ----
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
                  Text(
                    '⚠️ มีคนมาหาบ้านคุณ!',
                    style: GoogleFonts.prompt(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.white),
                  ),
                  Text(
                    '${e.contactName}  ${e.licensePlate.isNotEmpty ? "| ${e.licensePlate}" : ""}',
                    style: GoogleFonts.prompt(
                      fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                  if (e.purpose.isNotEmpty)
                    Text(e.purpose,
                        style: GoogleFonts.prompt(
                          fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() { _latestAlert = null; _hasNewAlert = false; }),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Section title ----
  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
            child: Text(
              'รีเฟรช',
              style: GoogleFonts.prompt(
                fontSize: 12, color: const Color(0xFF1E88E5)),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Entry card ----
  Widget _buildEntryCard(EntryModel e, bool isNew) {
    final timeStr = _formatTime(e.entryTime);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isNew
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // avatar / photo
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: isNew
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 30,
                color: isNew
                    ? const Color(0xFF1565C0)
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 12),

            // Info
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
                      if (isNew)
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

                  // ทะเบียน + จุดหมาย
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

                  // tags
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: [
                      if (e.vehicleType.isNotEmpty)
                        _buildTag(e.vehicleType, const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                      if (e.purpose.isNotEmpty)
                        _buildTag(e.purpose, const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                    ],
                  ),
                ],
              ),
            ),

            // เวลา
            Text(
              timeStr,
              style: GoogleFonts.prompt(
                fontSize: 11, color: Colors.blueGrey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: GoogleFonts.prompt(
            fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  // ---- Empty state ----
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 12),
          Text('ยังไม่มีผู้เข้าบ้านเลขที่ $_houseNumber',
              style: GoogleFonts.prompt(
                fontSize: 14, color: Colors.blueGrey.shade400)),
          const SizedBox(height: 6),
          Text('ดึงข้อมูลลงเพื่อรีเฟรช',
              style: GoogleFonts.prompt(
                fontSize: 12, color: Colors.blueGrey.shade300)),
        ],
      ),
    );
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
      if (diff.inHours < 24)   return '${diff.inHours} ชม.ที่แล้ว';
      return '${dt.day}/${dt.month}/${dt.year + 543}';
    } catch (_) {
      return raw;
    }
  }
}