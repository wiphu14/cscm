// ============================================================
// EntryModel — model เดียวกับที่ village-entry app บันทึกลง DB
// map จาก response ของ entry_list.php
// ============================================================
class EntryModel {
  final int    visitorId;
  final String visitorCode;
  final String contactName;
  final String phone;
  final String vehicleType;
  final String licensePlate;
  final String houseNumber;
  final String residentName;
  final String purpose;
  final String entryTime;
  final String? photoUrl;
  final String notifyType;   // 'targeted' | 'all'

  const EntryModel({
    required this.visitorId,
    required this.visitorCode,
    required this.contactName,
    required this.phone,
    required this.vehicleType,
    required this.licensePlate,
    required this.houseNumber,
    required this.residentName,
    required this.purpose,
    required this.entryTime,
    this.photoUrl,
    this.notifyType = 'targeted',
  });

  factory EntryModel.fromJson(Map<String, dynamic> json) {
    return EntryModel(
      visitorId:    json['visitor_id']    ?? 0,
      visitorCode:  json['visitor_code']  ?? '',
      contactName:  json['contact_name']  ?? json['full_name'] ?? '',
      phone:        json['phone']         ?? '',
      vehicleType:  json['vehicle_type']  ?? '',
      licensePlate: json['license_plate'] ?? '',
      houseNumber:  json['house_number']  ?? '',
      residentName: json['resident_name'] ?? '',
      purpose:      json['purpose']       ?? '',
      entryTime:    json['entry_time']    ?? json['created_at'] ?? '',
      photoUrl:     json['photo_url'],
      notifyType:   json['notify_type']   ?? 'targeted',
    );
  }

  // FCM data payload → EntryModel (ใช้ตอนแตะ notification)
  factory EntryModel.fromFcmData(Map<String, dynamic> data) {
    return EntryModel(
      visitorId:    int.tryParse(data['visitor_id']   ?? '0') ?? 0,
      visitorCode:  data['visitor_code']  ?? '',
      contactName:  data['contact_name']  ?? '',
      phone:        '',
      vehicleType:  data['vehicle_type']  ?? '',
      licensePlate: data['license_plate'] ?? '',
      houseNumber:  data['house_number']  ?? '',
      residentName: data['resident_name'] ?? '',
      purpose:      data['purpose']       ?? '',
      entryTime:    data['entry_time']    ?? '',
      photoUrl:     data['photo_url'],
      notifyType:   data['notify_type']   ?? 'targeted',
    );
  }
}