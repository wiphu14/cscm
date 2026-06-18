// ============================================================
// entry_model.dart
// Model ข้อมูลผู้เข้าบ้าน
// เพิ่ม: logId, contactConfirmed, copyWith()
// ============================================================

class EntryModel {
  final int    logId;           // entry_logs.log_id
  final int    visitorId;
  final String contactName;
  final String licensePlate;
  final String vehicleType;
  final String purpose;
  final String houseNumber;
  final String residentName;
  final String phone;
  final String entryTime;
  final String exitTime;
  final String duration;
  final String status;
  final String visitorCode;
  final String notifyType;
  final bool   contactConfirmed; // ✅ ยืนยันติดต่อสำเร็จแล้วหรือยัง

  const EntryModel({
    this.logId          = 0,
    this.visitorId      = 0,
    this.contactName    = '',
    this.licensePlate   = '',
    this.vehicleType    = '',
    this.purpose        = '',
    this.houseNumber    = '',
    this.residentName   = '',
    this.phone          = '',
    this.entryTime      = '',
    this.exitTime       = '',
    this.duration       = '',
    this.status         = 'inside',
    this.visitorCode    = '',
    this.notifyType     = 'targeted',
    this.contactConfirmed = false,
  });

  // ---- จาก JSON (API response) ----
  factory EntryModel.fromJson(Map<String, dynamic> json) {
    return EntryModel(
      logId          : json['log_id']            is int
                          ? json['log_id'] as int
                          : int.tryParse('${json['log_id'] ?? 0}') ?? 0,
      visitorId      : json['visitor_id']        is int
                          ? json['visitor_id'] as int
                          : int.tryParse('${json['visitor_id'] ?? 0}') ?? 0,
      contactName    : '${json['contact_name']   ?? json['full_name'] ?? 'ไม่ระบุ'}',
      licensePlate   : '${json['license_plate']  ?? '-'}',
      vehicleType    : '${json['vehicle_type']   ?? ''}',
      purpose        : '${json['purpose']        ?? ''}',
      houseNumber    : '${json['house_number']   ?? ''}',
      residentName   : '${json['resident_name']  ?? ''}',
      phone          : '${json['phone']          ?? ''}',
      entryTime      : '${json['entry_time']     ?? ''}',
      exitTime       : '${json['exit_time']      ?? ''}',
      duration       : '${json['duration']       ?? ''}',
      status         : '${json['status']         ?? 'inside'}',
      visitorCode    : '${json['visitor_code']   ?? ''}',
      notifyType     : '${json['notify_type']    ?? 'targeted'}',
      contactConfirmed: json['contact_confirmed'] == true ||
                        json['contact_confirmed'] == 1  ||
                        json['contact_confirmed'] == '1',
    );
  }

  // ---- จาก FCM data payload ----
  factory EntryModel.fromFcmData(Map<String, dynamic> data) {
    return EntryModel(
      logId         : int.tryParse('${data['log_id']        ?? '0'}') ?? 0,
      visitorId     : int.tryParse('${data['visitor_id']    ?? '0'}') ?? 0,
      contactName   : '${data['contact_name']  ?? data['visitor_name'] ?? 'ผู้มาติดต่อ'}',
      licensePlate  : '${data['license_plate'] ?? '-'}',
      vehicleType   : '${data['vehicle_type']  ?? ''}',
      purpose       : '${data['purpose']       ?? ''}',
      houseNumber   : '${data['house_number']  ?? ''}',
      residentName  : '${data['resident_name'] ?? ''}',
      phone         : '${data['phone']         ?? ''}',
      entryTime     : '${data['entry_time']    ?? DateTime.now().toIso8601String()}',
      exitTime      : '',
      duration      : '',
      status        : 'inside',
      visitorCode   : '${data['visitor_code']  ?? ''}',
      notifyType    : '${data['notify_type']   ?? 'targeted'}',
      contactConfirmed: false,
    );
  }

  // ---- copyWith — อัปเดตบางฟิลด์ ----
  EntryModel copyWith({
    int?    logId,
    int?    visitorId,
    String? contactName,
    String? licensePlate,
    String? vehicleType,
    String? purpose,
    String? houseNumber,
    String? residentName,
    String? phone,
    String? entryTime,
    String? exitTime,
    String? duration,
    String? status,
    String? visitorCode,
    String? notifyType,
    bool?   contactConfirmed,
  }) {
    return EntryModel(
      logId          : logId           ?? this.logId,
      visitorId      : visitorId       ?? this.visitorId,
      contactName    : contactName     ?? this.contactName,
      licensePlate   : licensePlate    ?? this.licensePlate,
      vehicleType    : vehicleType     ?? this.vehicleType,
      purpose        : purpose         ?? this.purpose,
      houseNumber    : houseNumber     ?? this.houseNumber,
      residentName   : residentName    ?? this.residentName,
      phone          : phone           ?? this.phone,
      entryTime      : entryTime       ?? this.entryTime,
      exitTime       : exitTime        ?? this.exitTime,
      duration       : duration        ?? this.duration,
      status         : status          ?? this.status,
      visitorCode    : visitorCode     ?? this.visitorCode,
      notifyType     : notifyType      ?? this.notifyType,
      contactConfirmed: contactConfirmed ?? this.contactConfirmed,
    );
  }
}