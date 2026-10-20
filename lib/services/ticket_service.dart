import 'dart:math';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../config.dart';
import '../models/ticket.dart';
import 'cloud_service.dart';
import 'slip_parser.dart';

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
  /// ponytail: สุ่มรหัส 6 ตัว (32^6 ≈ 1e9) ไม่ได้เช็คซ้ำกับคลาวด์ — โอกาสชนกันน้อยมาก
  static Future<Ticket> issue({
    required String studentId,
    required String studentName,
    String? code,
    String? slipRef,
  }) async {
    final now = DateTime.now();
    final ticket = Ticket(
      code: code ?? newCode(),
      studentId: studentId,
      studentName: studentName,
      priceCents: kTicketPriceCents,
      purchasedAt: now.millisecondsSinceEpoch,
      expiresAt: ticketExpiryFor(now).millisecondsSinceEpoch,
      slipRef: slipRef,
    );
    await CloudService.saveTicket(ticket);
    if (slipRef != null) {
      await CloudService.markSlipUsed(
        reference: slipRef,
        ticketCode: ticket.code,
      );
    }
    return ticket;
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
      if (await CloudService.isSlipUsed(info.reference)) {
        return const SlipRejected('สลิปนี้ถูกใช้ไปแล้ว (เลขที่รายการซ้ำ)');
      }
      return parsed;
    } catch (e) {
      return SlipRejected('อ่านภาพสลิปไม่สำเร็จ: $e');
    } finally {
      controller.dispose();
    }
  }

  static Future<Ticket?> byCode(String code) => CloudService.ticketByCode(code);

  /// ตั๋วทั้งหมดของนิสิต เรียงใหม่ไปเก่า
  static Future<List<Ticket>> ofStudent(String studentId) async {
    final all = await CloudService.tickets();
    final mine = all.where((ticket) => ticket.studentId == studentId).toList();
    mine.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return mine;
  }

  /// ตั๋วที่ยังใช้ได้ของนิสิต (ใบล่าสุดที่ยังไม่หมดอายุ) — null ถ้าไม่มี
  static Future<Ticket?> activeOf(String studentId) async {
    final now = DateTime.now();
    for (final ticket in await ofStudent(studentId)) {
      if (!ticket.isExpiredAt(now)) return ticket;
    }
    return null;
  }
}
