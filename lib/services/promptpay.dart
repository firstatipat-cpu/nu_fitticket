import 'dart:convert';

/// สร้าง QR พร้อมเพย์ตามมาตรฐาน EMVCo MPM (สแกนจ่ายได้จริงด้วยแอปธนาคารไทย)
/// เจ้าของ: <67310379>
///
/// โครงสร้าง TLV: tag(2) + ความยาวเป็น "ไบต์"(2) + value  (UTF-8)
/// ปิดท้ายด้วย tag 63 = "6304" + CRC16-CCITT-FALSE 4 ตัวอักษร
///
/// หมายเหตุ: QR นี้ทำให้เงินโอนเข้าบัญชีผู้รับจริง แต่แอปยืนยันการโอนเองไม่ได้
/// (พร้อมเพย์แบบโอนบุคคลไม่มี callback) จึงต้องมีการตรวจสลิป
class PromptPay {
  PromptPay._();

  /// [id] = เบอร์มือถือ 10 หลัก / เลขบัตรประชาชน 13 หลัก / e-Wallet 15 หลัก
  /// [amount] เว้นว่างได้ = QR แบบคงที่ (ผู้จ่ายกรอกยอดเอง)
  /// [ref] เลขอ้างอิงของเรา (ไม่เกิน 20 ตัว) → ใส่ใน tag 62/05 Reference Label
  static String payload({
    required String id,
    String? amount,
    String? ref,
    String merchantName = 'NU FITNESS',
    String merchantCity = 'PHITSANULOK',
  }) {
    final merchant =
        _tlv('00', 'A000000677010111') + _tlv(_idTag(id), _formatId(id));
    final hasAmount = amount != null && amount.isNotEmpty;

    final buffer = StringBuffer()
      ..write(_tlv('00', '01')) // payload format indicator
      // 11 = ใช้ซ้ำได้ (ไม่ระบุยอด) · 12 = ใช้ครั้งเดียว (ระบุยอด)
      ..write(_tlv('01', hasAmount ? '12' : '11'))
      ..write(_tlv('29', merchant))
      ..write(_tlv('53', '764')); // สกุลเงิน THB

    if (hasAmount) buffer.write(_tlv('54', amount));

    buffer
      ..write(_tlv('58', 'TH'))
      ..write(_tlv('59', _clip(merchantName, 25)))
      ..write(_tlv('60', _clip(merchantCity, 15)));

    if (ref != null && ref.isNotEmpty) {
      // 62/05 = Reference Label (เลขอ้างอิงของผู้ขาย)
      buffer.write(_tlv('62', _tlv('05', _clip(ref.toUpperCase(), 20))));
    }

    buffer.write('6304');
    final crc = crc16(buffer.toString());
    return '$buffer${crc.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  }

  static String _idTag(String id) => switch (id.length) {
    13 => '02', // เลขบัตรประชาชน
    15 => '03', // e-Wallet
    _ => '01', // เบอร์มือถือ
  };

  static String _formatId(String id) {
    if (id.length == 13 || id.length == 15) return id;
    final digits = id.replaceAll(RegExp(r'\D'), '');
    final withoutLeadingZero = digits.startsWith('0')
        ? digits.substring(1)
        : digits;
    return '0066$withoutLeadingZero';
  }

  /// ความยาวใน TLV เป็น **ไบต์** (UTF-8) ไม่ใช่จำนวนตัวอักษร — สำคัญเมื่อมีอักษรไทย
  /// ความยาวมีได้ 2 หลัก ถ้าเกิน 99 ไบต์จะตัดให้พอดี (ไม่ผ่าไบต์กลางตัวอักษร)
  static String _tlv(String tag, String value) {
    var text = value;
    var bytes = utf8.encode(text).length;
    if (bytes > 99) {
      text = _fitBytes(text, 99);
      bytes = utf8.encode(text).length;
    }
    return '$tag${bytes.toString().padLeft(2, '0')}$text';
  }

  /// ตัดข้อความให้ไม่เกิน [maxBytes] ไบต์ โดยไม่ผ่าตัวอักษรกลางทาง
  static String _fitBytes(String value, int maxBytes) {
    final buffer = StringBuffer();
    var used = 0;
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (used + size > maxBytes) break;
      used += size;
      buffer.write(char);
    }
    return buffer.toString();
  }

  /// คืนข้อความอธิบายถ้า PromptPay ID ดูไม่ถูกต้อง (null = ใช้ได้)
  /// เช็คเผื่อพิมพ์ผิด เพราะ ID ผิด = เงินเข้าบัญชีคนอื่น
  static String? idError(String id) {
    final digits = id.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 || digits.length == 15) return null;
    if (digits.length == 10 && digits.startsWith('0')) return null;
    return 'พร้อมเพย์ ID ต้องเป็นเบอร์มือถือ 10 หลัก (ขึ้นต้น 0) · '
        'เลขบัตรประชาชน 13 หลัก · หรือ e-Wallet 15 หลัก';
  }

  /// ตัดตามจำนวน "ตัวอักษร" (rune) ไม่ใช่ code unit เพื่อไม่ให้ผ่าครึ่งอักขระ
  static String _clip(String value, int maxChars) {
    final runes = value.runes;
    if (runes.length <= maxChars) return value;
    return String.fromCharCodes(runes.take(maxChars));
  }

  /// CRC16-CCITT (False): poly 0x1021, init 0xFFFF, ไม่ reverse, xorout 0
  /// คำนวณบน **ไบต์ UTF-8** ค่าตรวจสอบมาตรฐาน: crc16('123456789') == 0x29B1
  static int crc16(String data) {
    var crc = 0xFFFF;
    for (final byte in utf8.encode(data)) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }
}
