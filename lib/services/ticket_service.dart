import 'dart:async';
import 'dart:math';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../config.dart';
import '../models/ticket.dart';
import 'cloud_service.dart';
import 'slip_parser.dart';

/// ผลการออกตั๋ว — `error` != null = ออกตั๋วไม่สำเร็จ ผู้ใช้ต้องได้รับข้อความและไม่ได้ตั๋ว
typedef IssueResult = ({Ticket? ticket, WriteResult write, String? error});

/// ออกตั๋วและค้นหาตั๋ว NU Fitness
/// เจ้าของ: <67310379>
class TicketService {
  TicketService._();

  /// ตัดตัวอักษรที่อ่านสับสนได้ (O/0/I/1) ออก เพื่อให้กรอกรหัสสำรองได้ง่าย
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _random = Random.secure();

  static String newCode() => List.generate(
    6,
    (_) => _alphabet[_random.nextInt(_alphabet.length)],
  ).join();

  /// R1 — ออกตั๋ว NU Fitness ราคา 10 บาท ใช้ได้ถึง 20:00 น. ของวันที่จ่าย
  /// [code] ส่งเข้ามาได้เมื่อต้องการให้รหัสตั๋วตรงกับเลขอ้างอิงใน QR รับเงิน
  ///
  /// ล็อกสลิป **ก่อน** ออกตั๋ว — ถ้าล็อกสลิปไม่ได้แปลว่าสลิปถูกใช้ไปแล้ว
  /// จึงห้ามออกตั๋ว (กันใช้สลิปเดิมขอตั๋วซ้ำ)
  ///
  /// ponytail: สุ่มรหัส 6 ตัว (32^6 ≈ 1e9) ไม่ได้เช็คซ้ำกับคลาวด์ — โอกาสชนกันน้อยมาก
  static Future<IssueResult> issue({
    required String studentId,
    required String studentName,
    String? code,
    String? slipRef,
    String? bankName,
  }) async {
    final ticketCode = code ?? newCode();

    if (slipRef != null) {
      final slipWrite = await CloudService.markSlipUsed(
        reference: slipRef,
        ticketCode: ticketCode,
      );
      if (slipWrite == WriteResult.rejected) {
        return (
          ticket: null,
          write: slipWrite,
          error: 'สลิปนี้ถูกใช้ไปแล้ว — ขอสลิปใบใหม่หรือแจ้งเจ้าหน้าที่',
        );
      }
    }

    final now = DateTime.now();
    final ticket = Ticket(
      code: ticketCode,
      studentId: studentId,
      studentName: studentName,
      priceCents: kTicketPriceCents,
      purchasedAt: now.millisecondsSinceEpoch,
      expiresAt: ticketExpiryFor(now).millisecondsSinceEpoch,
      slipRef: slipRef,
      bankName: bankName,
    );
    final write = await CloudService.saveTicket(ticket);
    if (write == WriteResult.rejected) {
      return (
        ticket: null,
        write: write,
        error: 'บันทึกตั๋วไม่สำเร็จ — รหัสตั๋วชนกับที่มีอยู่ กรุณาลองใหม่',
      );
    }
    return (ticket: ticket, write: write, error: null);
  }

  /// อ่าน QR จากภาพสลิปในคลัง แล้วตรวจว่าเป็นสลิปจริงและยังไม่ถูกใช้
  static Future<SlipResult> verifySlipImage(String imagePath) async {
    final controller = MobileScannerController();
    try {
      final capture = await controller.analyzeImage(imagePath);
      final barcodes = capture?.barcodes ?? const <Barcode>[];
      final raw = barcodes.isEmpty ? null : barcodes.first.rawValue;
      if (raw == null || raw.trim().isEmpty) {
        return const SlipRejected(
          'ไม่พบ QR ในภาพ — เลือกภาพสลิปที่เห็น QR ชัด ๆ',
        );
      }

      final parsed = SlipParser.parse(raw);
      if (parsed is SlipRejected) return parsed;

      final info = (parsed as SlipAccepted).info;
      if ((await CloudService.isSlipUsed(info.reference)).data) {
        return const SlipRejected('สลิปนี้ถูกใช้ไปแล้ว (เลขที่รายการซ้ำ)');
      }
      return parsed;
    } catch (e) {
      return SlipRejected('อ่านภาพสลิปไม่สำเร็จ: $e');
    } finally {
      unawaited(controller.dispose());
    }
  }

  static Future<({Ticket? ticket, bool offline})> byCode(String code) async {
    final read = await CloudService.ticketByCode(code);
    return (ticket: read.data, offline: read.offline);
  }

  /// ตั๋วทั้งหมดของนิสิต เรียงใหม่ไปเก่า
  static Future<({List<Ticket> tickets, bool offline})> ofStudent(
    String studentId,
  ) async {
    final read = await CloudService.tickets();
    final mine = read.data
        .where((ticket) => ticket.studentId == studentId)
        .toList();
    mine.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return (tickets: mine, offline: read.offline);
  }

  /// ตั๋วที่ยังใช้ได้ของนิสิต (ใบล่าสุดที่ยังไม่หมดอายุ) — null ถ้าไม่มี
  static Future<({Ticket? ticket, bool offline})> activeOf(
    String studentId,
  ) async {
    final now = DateTime.now();
    final read = await ofStudent(studentId);
    for (final ticket in read.tickets) {
      if (!ticket.isExpiredAt(now)) {
        return (ticket: ticket, offline: read.offline);
      }
    }
    return (ticket: null, offline: read.offline);
  }
}
