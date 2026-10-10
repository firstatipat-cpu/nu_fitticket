/// หมายเหตุ: นี่คือ URL สาธารณะ ไม่ใช่คีย์ลับ — ห้ามใส่คีย์/โทเคน/รหัสผ่านจริงในไฟล์นี้
const String kDatabaseUrl =
    'https://nu-fitticket-default-rtdb.asia-southeast1.firebasedatabase.app';

/// ราคาตั๋ว NU Fitness (สตางค์) — ตั๋วเดียว ราคาเดียว
const int kTicketPriceCents = 1000;

/// ชื่อสถานที่ที่มีตั๋วขาย
const String kFacilityName = 'NU Fitness';

/// อายุตั๋ว
const Duration kTicketValidity = Duration(days: 1);

/// บัญชีพร้อมเพย์ผู้รับเงิน (ของโรงยิม)
/// ใส่ได้ 3 แบบ: เบอร์มือถือ 10 หลัก · เลขบัตรประชาชน 13 หลัก · e-Wallet 15 หลัก
///
/// ponytail: ค่าเริ่มต้นคือเบอร์ตัวอย่างสำหรับเดโม ต้องเปลี่ยนเป็นของจริงก่อนใช้งาน
/// (ค่าคงที่นี้ไม่ใช่ความลับ — เบอร์พร้อมเพย์เปิดเผยได้)
const String kPromptPayId = '0630921644';

/// ค่า placeholder เดิม — ใช้เทียบเพื่อเตือนว่ายังไม่ได้เปลี่ยนเป็นบัญชีจริง
const String kPromptPaySampleId = '0899999999';
const String kPromptPayName = 'NU FITNESS';
const String kPromptPayCity = 'PHITSANULOK';

/// true = ยังใช้เบอร์ตัวอย่างอยู่ ควรเปลี่ยนก่อนสาธิต
bool get isPromptPaySample => kPromptPayId == kPromptPaySampleId;
