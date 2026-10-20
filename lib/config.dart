/// หมายเหตุ: นี่คือ URL สาธารณะ ไม่ใช่คีย์ลับ — ห้ามใส่คีย์/โทเคน/รหัสผ่านจริงในไฟล์นี้
/// เจ้าของ: <67316807>
const String kDatabaseUrl =
    'https://nu-fitticket-default-rtdb.asia-southeast1.firebasedatabase.app';

/// ราคาตั๋ว NU Fitness (สตางค์) — ตั๋วเดียว ราคาเดียว
const int kTicketPriceCents = 1000;

/// ชื่อสถานที่ที่มีตั๋วขาย
const String kFacilityName = 'NU Fitness';

/// ชั่วโมงที่ตั๋วหมดอายุ (20:00 น. ของวันที่จ่ายเงิน)
const int kTicketExpiryHour = 20;

/// เวลาหมดอายุของตั๋วที่จ่ายตอน [purchasedAt] — 20:00 น. ของวันนั้น
/// จ่ายหลัง 20:00 → ใช้ได้ถึง 20:00 น. ของวันถัดไป
DateTime ticketExpiryFor(DateTime purchasedAt) {
  final expiry = DateTime(
    purchasedAt.year,
    purchasedAt.month,
    purchasedAt.day,
    kTicketExpiryHour,
  );
  return purchasedAt.isBefore(expiry)
      ? expiry
      : expiry.add(const Duration(days: 1));
}

/// บัญชีพร้อมเพย์ผู้รับเงิน (ของโรงยิม)
/// ใส่ได้ 3 แบบ: เบอร์มือถือ 10 หลัก · เลขบัตรประชาชน 13 หลัก · e-Wallet 15 หลัก
///
/// ponytail: ค่าเริ่มต้นคือเบอร์ตัวอย่างสำหรับเดโม ต้องเปลี่ยนเป็นของจริงก่อนใช้งาน
/// (ค่าคงที่นี้ไม่ใช่ความลับ — เบอร์พร้อมเพย์เปิดเผยได้)
const String kPromptPayId = '0630921644';

/// ชื่อร้าน/เมืองที่ใส่ใน QR พร้อมเพย์ (ค่าคงที่ ไม่ใช่ความลับ)
const String kPromptPayName = 'NU FITNESS';
const String kPromptPayCity = 'PHITSANULOK';
