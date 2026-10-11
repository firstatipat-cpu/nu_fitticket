import 'promptpay.dart';

/// รหัสธนาคารผู้ส่ง (มาตรฐาน ธปท.) → ชื่อธนาคาร
const _bankNames = <String, String>{
  '002': 'ธ.กรุงเทพ (BBL)',
  '004': 'ธ.กสิกรไทย (KBank)',
  '006': 'ธ.กรุงไทย (KTB)',
  '011': 'ธ.ทหารไทยธนชาต (TTB)',
  '014': 'ธ.ไทยพาณิชย์ (SCB)',
  '030': 'ธ.ออมสิน (GSB)',
  '034': 'ธ.เพื่อการเกษตรและสหกรณ์ (BAAC)',
  '069': 'ธ.เกียรติธนาคาร (KKP)',
};

/// ผลการอ่านสลิปที่ผ่านการตรวจ
class SlipInfo {
  const SlipInfo({
    required this.reference,
    required this.sendingBankCode,
    required this.apiType,
  });

  /// เลขที่รายการบนสลิป — ใช้เป็นคีย์กันสลิปซ้ำ
  final String reference;

  /// รหัสธนาคารผู้ส่ง (รหัสธนาคารตามมาตรฐาน ธปท.)
  final String sendingBankCode;

  /// ชนิด API ของสลิป (ปัจจุบันมีค่าเดียว)
  final String apiType;

  /// ชื่อธนาคารผู้ส่ง (ถ้ารู้จัก)
  String get bankName =>
      _bankNames[sendingBankCode] ?? 'ธนาคาร $sendingBankCode';
}

sealed class SlipResult {
  const SlipResult();
}

class SlipAccepted extends SlipResult {
  const SlipAccepted(this.info);
  final SlipInfo info;
}

class SlipRejected extends SlipResult {
  const SlipRejected(this.reason);
  final String reason;
}

/// อ่านและตรวจ "สลิปโอนเงิน" จาก QR บนสลิป (Slip Verify QR ของธนาคารไทย)
/// เจ้าของ: <รหัสนิสิตคนที่ 3>
///
/// ใช้ซองเดียวกัน **ทุกธนาคาร** — ต่างกันแค่รหัสธนาคารผู้ส่งใน tag 00/01:
/// ```
/// 00 (nested) → 00 = ชนิด API ("000001") · 01 = รหัสธนาคารผู้ส่ง · 02 = เลขที่รายการ
/// 51 = "TH"
/// 91 = CRC16-CCITT 4 ตัว จากข้อความก่อนหน้า
/// ```
///
/// ตรวจได้: โครงสร้างถูกต้อง · ข้อความไม่ถูกแก้ (CRC) · ได้เลขที่รายการไปกันซ้ำ
/// ตรวจไม่ได้: จำนวนเงิน และผู้รับ ไม่มีอยู่ใน QR (ต้องเรียก API ของธนาคาร)
///
/// อ้างอิง: สเปก EMVCo TLV + ซอง Slip Verify ที่ใช้ร่วมกันของธนาคารไทย
class SlipParser {
  SlipParser._();

  /// ชนิด API ของสลิปโอนเงิน (ทุกธนาคารใช้ค่าเดียวกัน)
  static const _slipVerifyApiType = '000001';

  /// ชนิด API ของสลิป TrueMoney (โครงสร้างชั้นในต่างออกไป)
  static const _trueMoneyApiType = '01';

  static SlipResult parse(String payload) {
    final raw = payload.trim();
    if (raw.length < 12) return const SlipRejected('ข้อมูลสลิปสั้นเกินไป');

    // 4 ตัวท้ายคือ CRC — บางแอปตัดเลข 0 ข้างหน้าออก จึงลองไล่ความยาวถอยหลัง
    final body = _bodyWithValidCrc(raw);
    if (body == null) {
      return const SlipRejected('สลิปไม่ผ่านการตรวจสอบ — ข้อมูลอาจถูกแก้ไข');
    }

    final outer = _tags(body);
    if (outer['51'] != 'TH') {
      return const SlipRejected('ไม่ใช่สลิปของธนาคารไทย');
    }

    final inner = _tags(outer['00'] ?? '');
    final apiType = inner['00'];
    final bankCode = inner['01'];
    final reference = inner['02'];

    if (apiType == _trueMoneyApiType) {
      return const SlipRejected('เป็นสลิป TrueMoney ซึ่งยังไม่รองรับ');
    }
    if (apiType != _slipVerifyApiType) {
      return const SlipRejected('ไม่ใช่ QR สลิปโอนเงินของธนาคาร');
    }
    if (bankCode == null || bankCode.length != 3) {
      return const SlipRejected('สลิปไม่ระบุธนาคารผู้ส่ง');
    }
    if (reference == null || reference.trim().isEmpty) {
      return const SlipRejected('สลิปไม่มีเลขที่รายการ');
    }

    return SlipAccepted(
      SlipInfo(
        reference: reference.trim(),
        sendingBankCode: bankCode,
        apiType: apiType!,
      ),
    );
  }

  /// คืนเนื้อความ (ตัด CRC ออก) ถ้า CRC ตรง — ไม่ตรงคืน null
  ///
  /// เผื่อกรณีแอปธนาคารตัดเลข 0 ข้างหน้าของ CRC ทิ้ง (ความยาวเหลือ 1–3 ตัว)
  static String? _bodyWithValidCrc(String raw) {
    for (final crcLength in const [4, 3, 2, 1]) {
      final cut = raw.length - crcLength;
      if (cut < 8) continue;

      final tail = raw.substring(cut).toUpperCase();
      if (!RegExp(r'^[0-9A-F]+$').hasMatch(tail)) continue;

      final body = raw.substring(0, cut);
      final expected = PromptPay.crc16(
        body,
      ).toRadixString(16).toUpperCase().padLeft(4, '0');

      // ตรงทั้ง 4 ตัว หรือตรงแบบที่ตัดเลข 0 ข้างหน้าออกแล้ว
      if (tail == expected ||
          tail == expected.replaceFirst(RegExp(r'^0+'), '')) {
        return body;
      }
    }
    return null;
  }

  /// แยก TLV ระดับเดียว: tag(2) + length(2 หลัก) + value
  static Map<String, String> _tags(String data) {
    final out = <String, String>{};
    var i = 0;
    while (i + 4 <= data.length) {
      final tag = data.substring(i, i + 2);
      final length = int.tryParse(data.substring(i + 2, i + 4));
      if (length == null || i + 4 + length > data.length) break;
      out[tag] = data.substring(i + 4, i + 4 + length);
      i += 4 + length;
    }
    return out;
  }
}
