import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nu_fitticket/models/entry.dart';
import 'package:nu_fitticket/models/ticket.dart';
import 'package:nu_fitticket/services/gate_service.dart';
import 'package:nu_fitticket/services/password.dart';
import 'package:nu_fitticket/services/promptpay.dart';
import 'package:nu_fitticket/services/report_export.dart';
import 'package:nu_fitticket/services/slip_parser.dart';
import 'package:nu_fitticket/services/ticket_service.dart';

/// เทสต์ที่รันได้โดยไม่ต้องมีอุปกรณ์/เครือข่าย/ฐานข้อมูล
/// เจ้าของ: <67316807>
void main() {
  group('แฮชรหัสผ่าน', () {
    test('รหัสเดิม+ซอลต์เดิม ได้ค่าเดิม', () {
      final salt = newSalt();
      expect(hashPassword('test1234', salt), hashPassword('test1234', salt));
    });

    test('ซอลต์ต่างกัน ได้ค่าไม่ซ้ำกัน', () {
      expect(
        hashPassword('test1234', newSalt()),
        isNot(hashPassword('test1234', newSalt())),
      );
    });
  });

  group('รหัสตั๋ว', () {
    test('ยาว 6 ตัว และไม่ใช้ตัวอักษรที่อ่านสับสน', () {
      for (var i = 0; i < 50; i++) {
        final code = TicketService.newCode();
        expect(code.length, 6);
        expect(
          RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code),
          isTrue,
        );
      }
    });
  });

  group('อายุตั๋ว', () {
    final now = DateTime(2026, 10, 8, 12, 0).millisecondsSinceEpoch;
    final ticket = Ticket(
      code: 'AB3K7Q',
      studentId: '67000001',
      studentName: 'นิสิตตัวอย่าง',
      priceCents: 1000,
      purchasedAt: now,
      expiresAt: DateTime(2026, 10, 9, 12, 0).millisecondsSinceEpoch,
    );

    test('ยังใช้ได้ก่อนหมดอายุ', () {
      expect(ticket.isExpiredAt(DateTime(2026, 10, 9, 11, 59)), isFalse);
    });

    test('ใช้ไม่ได้หลังหมดอายุ', () {
      expect(ticket.isExpiredAt(DateTime(2026, 10, 9, 12, 1)), isTrue);
    });
  });

  group('GateService.dateKey', () {
    test('จัดรูปแบบเป็น yyyy-MM-dd', () {
      expect(GateService.dateKey(DateTime(2026, 10, 8, 23, 59)), '2026-10-08');
    });
  });

  group('R5 — ไฟล์ CSV', () {
    final entry = Entry(
      id: 'e1',
      code: 'AB3K7Q',
      studentId: '67000001',
      studentName: 'นิสิตตัวอย่าง',
      priceCents: 1000,
      ts: DateTime(2026, 10, 20, 17, 30).millisecondsSinceEpoch,
      date: '2026-10-20',
    );

    test('มีหัวตาราง BOM และข้อมูลครบ', () {
      final csv = ReportExport.buildCsv([entry]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(
        csv,
        contains('วันที่,เวลา,รหัสนิสิต,ชื่อ,รหัสตั๋ว,สถานที่,ราคา (บาท)'),
      );
      expect(csv, contains('67000001'));
      expect(csv, contains('AB3K7Q'));
      expect(csv, contains('NU Fitness'));
      expect(csv, contains('10.00'));
      expect(csv, contains('17:30'));
    });

    test('ช่วงที่ไม่มีข้อมูล ยังได้ไฟล์ที่มีแต่หัวตาราง', () {
      final csv = ReportExport.buildCsv(const []);
      expect(csv.trim(), endsWith('ราคา (บาท)'));
    });
  });

  group('QR พร้อมเพย์ (EMVCo)', () {
    // ค่าอ้างอิงคำนวณจาก implementation อิสระ (Python) แล้วเทียบทีละไบต์
    test('CRC16-CCITT ได้ค่าตรวจสอบมาตรฐาน 0x29B1', () {
      expect(PromptPay.crc16('123456789'), 0x29B1);
    });

    test('เบอร์มือถือ + ระบุยอด + เลขอ้างอิง (62/05)', () {
      expect(
        PromptPay.payload(id: '0899999999', amount: '10.00', ref: 'AB3K7Q'),
        '00020101021229370016A000000677010111011300668999999995303764540510.00'
        '5802TH5910NU FITNESS6011PHITSANULOK62100506AB3K7Q6304868A',
      );
    });

    test('ไม่ระบุยอด → tag 01 = 11 (static) และไม่มี tag 54', () {
      final payload = PromptPay.payload(id: '0899999999');
      expect(payload, startsWith('000201010211'));
      expect(payload, isNot(contains('5405')));
    });

    test('จำนวนเงินทศนิยม 2 ตำแหน่งเสมอ', () {
      expect(
        PromptPay.payload(id: '0899999999', amount: '10.00'),
        contains('540510.00'),
      );
    });

    test('ความยาว TLV นับเป็นไบต์ จึงรองรับชื่อร้านภาษาไทย', () {
      const name = 'ศูนย์กีฬา';
      final payload = PromptPay.payload(
        id: '0899999999',
        amount: '10.00',
        merchantName: name,
      );
      final byteLength = utf8.encode(name).length;

      expect(byteLength, isNot(name.length)); // ไทย 1 ตัว ใช้หลายไบต์
      expect(
        payload,
        contains('59${byteLength.toString().padLeft(2, '0')}$name'),
      );

      // CRC ที่ต่อท้ายต้องตรวจผ่าน
      final crcField = payload.substring(payload.length - 4);
      expect(
        PromptPay.crc16(payload.substring(0, payload.length - 4)),
        int.parse(crcField, radix: 16),
      );
    });
  });

  group('ตรวจสลิปโอนเงินจาก QR', () {
    // สลิปจริงจาก KBank: โอน 1.00 บาท เลขที่รายการ 0462815o9863ramooV3k
    const realKbankSlip =
        '00410006000001010300402200462815o9863ramooV3k5102TH910497AE';

    // ค่าอ้างอิงจากไลบรารี promptparse
    const promptparseVector =
        '004000060000010103002021900021231231212000115102TH91049C30';

    test('สลิป KBank จริงผ่าน ได้เลขที่รายการ + รู้ว่าเป็น KBank', () {
      final result = SlipParser.parse(realKbankSlip);
      expect(result, isA<SlipAccepted>());
      final info = (result as SlipAccepted).info;
      expect(info.reference, '0462815o9863ramooV3k');
      expect(info.sendingBankCode, '004');
      expect(info.bankName, contains('KBank'));
    });

    test('ค่าอ้างอิงจาก promptparse ผ่าน ได้ธนาคารกรุงเทพ (002)', () {
      final result = SlipParser.parse(promptparseVector);
      expect(result, isA<SlipAccepted>());
      expect((result as SlipAccepted).info.sendingBankCode, '002');
    });

    test('แก้ตัวอักษรในสลิป 1 ตัว แล้ว CRC ไม่ผ่าน', () {
      const tampered =
          '00410006000001010300402200462815o9863ramooV3X5102TH910497AE';
      expect(SlipParser.parse(tampered), isA<SlipRejected>());
    });

    test('QR อย่างอื่น (ไม่ใช่สลิปธนาคาร) ถูกปฏิเสธ', () {
      expect(
        SlipParser.parse('00020101021229370016A000000677010111'),
        isA<SlipRejected>(),
      );
    });

    test('ข้อมูลสั้นเกินไปถูกปฏิเสธ', () {
      expect(SlipParser.parse('0041'), isA<SlipRejected>());
    });
  });

  group('ความปลอดภัยและการกันข้อมูลพัง', () {
    test('ชื่อที่ขึ้นต้นด้วย = ถูกกันไม่ให้เป็นสูตรใน Excel', () {
      final entry = Entry(
        id: 'e2',
        code: 'AB3K7Q',
        studentId: '67000002',
        studentName: '=HYPERLINK("http://x")',
        priceCents: 1000,
        ts: DateTime(2026, 10, 20, 17, 30).millisecondsSinceEpoch,
        date: '2026-10-20',
      );
      final csv = ReportExport.buildCsv([entry]);
      expect(csv, contains("'=HYPERLINK"));
    });

    test('รหัสนิสิตจากคลาวด์ (ปลอมได้) ที่ขึ้นต้นด้วย = กันเหมือนกัน', () {
      final entry = Entry(
        id: 'e3',
        code: 'AB3K7Q',
        studentId: '=SUM(1+1)',
        studentName: 'นิสิตตัวอย่าง',
        priceCents: 1000,
        ts: DateTime(2026, 10, 20, 17, 30).millisecondsSinceEpoch,
        date: '2026-10-20',
      );
      expect(ReportExport.buildCsv([entry]), contains("'=SUM"));
    });

    test('PromptPay idError ตรวจรูปแบบ ID', () {
      expect(PromptPay.idError('0630921644'), isNull);
      expect(PromptPay.idError('1234567890123'), isNull);
      expect(PromptPay.idError('123456789012345'), isNull);
      expect(PromptPay.idError('12345'), isNotNull);
      expect(PromptPay.idError('9123456789'), isNotNull); // ไม่ขึ้นต้น 0
    });

    test('ค่าที่ยาวเกิน 99 ไบต์ถูกตัดให้พอดีกับความยาว TLV', () {
      final name = List.filled(25, '😀').join(); // 25 runes = 100 ไบต์
      final kept = List.filled(24, '😀').join(); // 96 ไบต์
      final payload = PromptPay.payload(
        id: '0899999999',
        amount: '10.00',
        merchantName: name,
      );

      expect(payload, contains('5996$kept'));

      // หลังตัดแล้ว CRC ต้องยังถูกต้อง
      final crcField = payload.substring(payload.length - 4);
      expect(
        PromptPay.crc16(payload.substring(0, payload.length - 4)),
        int.parse(crcField, radix: 16),
      );
    });
  });
}
