import '../models/entry.dart';
import '../models/ticket.dart';
import 'cloud_service.dart';

enum GateFailure { notFound, expired, unpaid, saveFailed }

sealed class GateResult {
  const GateResult();
}

class GateAccepted extends GateResult {
  const GateAccepted({required this.ticket, required this.alreadyToday});

  final Ticket ticket;

  /// true = วันนี้เคยบันทึกไว้แล้ว (ยังเข้าได้ แต่นับเป็นคนเดิม 1 ครั้ง)
  final bool alreadyToday;
}

class GateRejected extends GateResult {
  const GateRejected(this.failure, {this.ticket, this.writeFailed = false});

  final GateFailure failure;
  final Ticket? ticket;

  /// true = บันทึกลงคลาวด์ไม่สำเร็จจริง (ข้อมูลหาย) → ต้องแจ้งผู้ใช้ ไม่ใช่แค่ปฏิเสธตั๋ว
  final bool writeFailed;
}

/// ผลการตรวจที่ประตู + สถานะว่าอ่านจากเครื่อง (ออฟไลน์) หรือจากคลาวด์
typedef GateOutcome = ({GateResult result, bool offline});

/// R2/R4 — ตรวจตั๋วที่ประตูและบันทึกการเข้าใช้
/// เจ้าของ: <67314858>
class GateService {
  GateService._();

  static String dateKey(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// id ของบันทึกการเข้าใช้ — 1 คน 1 วัน
  /// (id คงที่ = เช็คว่าเข้าวันนี้แล้วหรือยังได้ด้วยการอ่านรายคีย์เดียว ไม่ต้องดึงทั้งโหนด)
  static String entryIdFor(String studentId, String date) =>
      '${studentId}_$date';

  /// id ของบันทึก "เดินผ่านประตูโดยยังไม่ชำระ" — 1 คน 1 วัน
  static String unpaidEntryIdFor(String studentId, String date) =>
      '${studentId}_${date}_unpaid';

  /// ตัดสินใจให้เข้าใช้หรือไม่ จากข้อมูลตั๋วล้วน (ไม่ต้องต่อเน็ต — เอาไปเทสต์ได้)
  /// null = ผ่าน (เข้าได้) · ไม่งั้นคือเหตุผลที่ปฏิเสธ
  static GateFailure? rejectionFor(Ticket? ticket, DateTime now) {
    if (ticket == null) return GateFailure.notFound;
    if (ticket.isExpiredAt(now)) return GateFailure.expired;
    if (!ticket.isPaid) return GateFailure.unpaid;
    return null;
  }

  /// ตรวจรหัสตั๋ว (จาก QR หรือกรอกเอง) แล้วบันทึกการเข้าใช้
  /// นับคนละ 1 ครั้งต่อวัน — สแกนซ้ำวันเดิมจะไม่เพิ่มรายการใหม่
  static Future<GateOutcome> checkIn(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) {
      return (result: const GateRejected(GateFailure.notFound), offline: false);
    }

    final ticketRead = await CloudService.ticketByCode(wanted);
    final ticket = ticketRead.data;
    final now = DateTime.now();
    final today = dateKey(now);

    final failure = rejectionFor(ticket, now);
    if (failure == GateFailure.notFound || failure == GateFailure.expired) {
      return (
        result: GateRejected(failure!, ticket: ticket),
        offline: ticketRead.offline,
      );
    }

    // ยังไม่ชำระเงิน — บันทึก 1 แถวต่อคนต่อวัน (id คงที่) ให้รายงานย้อนหลังได้ว่า
    // ใครเดินผ่านประตูโดยยังไม่ชำระ (ความต้องการจากการสัมภาษณ์ 20 ต.ค. 2569)
    if (failure == GateFailure.unpaid) {
      final write = await CloudService.saveEntry(
        Entry(
          id: unpaidEntryIdFor(ticket!.studentId, today),
          code: ticket.code,
          studentId: ticket.studentId,
          studentName: ticket.studentName,
          priceCents: ticket.priceCents,
          ts: now.millisecondsSinceEpoch,
          date: today,
          paid: false,
        ),
      );
      // ถูกปฏิเสธ = มีแถวนี้อยู่แล้ว (บันทึกไว้ตั้งแต่ครั้งก่อน) → ไม่ใช่ข้อมูลหาย
      final unpaidId = unpaidEntryIdFor(ticket.studentId, today);
      return (
        result: GateRejected(
          GateFailure.unpaid,
          ticket: ticket,
          writeFailed:
              write == WriteResult.rejected && !await _isStored(unpaidId),
        ),
        offline: ticketRead.offline,
      );
    }

    final valid = ticket!;
    final entryId = entryIdFor(valid.studentId, today);

    // เช็คว่าเข้าวันนี้แล้วหรือยัง — อ่านรายคีย์เดียว ไม่ต้องดึงทั้งโหนด
    final existing = await CloudService.entryById(entryId);
    if (existing.data != null) {
      return (
        result: GateAccepted(ticket: valid, alreadyToday: true),
        offline: ticketRead.offline || existing.offline,
      );
    }

    final write = await CloudService.saveEntry(
      Entry(
        id: entryId,
        code: valid.code,
        studentId: valid.studentId,
        studentName: valid.studentName,
        priceCents: valid.priceCents,
        ts: now.millisecondsSinceEpoch,
        date: today,
      ),
    );

    if (write == WriteResult.rejected) {
      // อีกเครื่องอาจเพิ่งเขียนแถวเดียวกัน → เช็คซ้ำก่อนบอกว่าบันทึกไม่สำเร็จ
      final again = await CloudService.entryById(entryId);
      if (again.data != null) {
        return (
          result: GateAccepted(ticket: valid, alreadyToday: true),
          offline: ticketRead.offline,
        );
      }
      return (
        result: GateRejected(
          GateFailure.saveFailed,
          ticket: valid,
          writeFailed: true,
        ),
        offline: ticketRead.offline,
      );
    }

    return (
      result: GateAccepted(ticket: valid, alreadyToday: false),
      offline: ticketRead.offline,
    );
  }

  /// มีแถวนี้อยู่จริงในคลาวด์หรือไม่ (ใช้ยืนยันว่าเขียนสำเร็จจริง ไม่ใช่แค่ถูกปฏิเสธ)
  static Future<bool> _isStored(String id) async =>
      (await CloudService.entryById(id)).data != null;

  /// แปลงผลการตรวจเป็นข้อความที่แสดงผู้ใช้ (ใช้ร่วมกันทุกหน้าที่สแกนตั๋ว
  /// เพื่อไม่ให้ข้อความสองที่ต่างกัน)
  static ({bool success, String title, String detail}) describe(
    GateResult result, {
    bool offline = false,
  }) {
    final offlineNote = offline
        ? ' (ออฟไลน์อยู่ — ตรวจจากข้อมูลในเครื่องเท่านั้น)'
        : '';
    switch (result) {
      case GateAccepted(:final ticket, :final alreadyToday):
        return (
          success: true,
          title: 'เข้าได้',
          detail:
              '${ticket.studentName} (${ticket.studentId})'
              ' · ${ticket.isPaid ? 'ชำระแล้ว · สลิป ${ticket.slipRef}' : 'ยังไม่ชำระเงิน'}'
              '${alreadyToday ? ' · วันนี้บันทึกไว้แล้ว นับเป็นคนเดิม 1 ครั้ง' : ''}'
              '$offlineNote',
        );
      case GateRejected(:final failure, :final ticket):
        return switch (failure) {
          GateFailure.notFound => (
            success: false,
            title: 'ไม่พบตั๋วรหัสนี้',
            detail: 'ตรวจรหัสอีกครั้ง$offlineNote',
          ),
          GateFailure.expired => (
            success: false,
            title: 'ตั๋วหมดอายุแล้ว',
            detail: ticket == null
                ? ''
                : '${ticket.studentName} · หมดเมื่อ ${ticket.expiryTime}',
          ),
          GateFailure.unpaid => (
            success: false,
            title: 'ยังไม่ชำระเงิน',
            detail: ticket == null
                ? 'ให้นิสิตแนบสลิปในแอปก่อนเข้าใช้'
                : '${ticket.studentName} · ให้แนบสลิปก่อนเข้าใช้',
          ),
          GateFailure.saveFailed => (
            success: false,
            title: 'บันทึกการเข้าใช้ไม่สำเร็จ',
            detail:
                'คลาวด์ปฏิเสธการเขียน — ข้อมูลยังไม่ถูกบันทึก กรุณาแจ้งผู้ดูแลระบบ',
          ),
        };
    }
  }
}
