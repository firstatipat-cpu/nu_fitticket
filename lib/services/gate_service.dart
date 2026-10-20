import '../models/entry.dart';
import '../models/ticket.dart';
import 'cloud_service.dart';

enum GateFailure { notFound, expired, unpaid }

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
  const GateRejected(this.failure, {this.ticket});

  final GateFailure failure;
  final Ticket? ticket;
}

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
  static Future<GateResult> checkIn(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return const GateRejected(GateFailure.notFound);

    final ticket = await CloudService.ticketByCode(wanted);
    final now = DateTime.now();
    final today = dateKey(now);

    final failure = rejectionFor(ticket, now);
    if (failure != null) {
      // ยังไม่ชำระเงิน — บันทึกความพยายามเข้าใช้ไว้ (paid=false) เพื่อให้รายงานเห็นว่า
      // ใครเดินผ่านประตูโดยยังไม่ชำระ (ความต้องการจากการสัมภาษณ์ 20 ต.ค. 2569)
      if (failure == GateFailure.unpaid && ticket != null) {
        await CloudService.saveEntry(
          Entry(
            id: '${now.millisecondsSinceEpoch}-${ticket.code}-unpaid',
            code: ticket.code,
            studentId: ticket.studentId,
            studentName: ticket.studentName,
            priceCents: ticket.priceCents,
            ts: now.millisecondsSinceEpoch,
            date: today,
            paid: false,
          ),
        );
      }
      return GateRejected(failure, ticket: ticket);
    }

    final valid = ticket!;
    final entries = await CloudService.entries();
    // นับเฉพาะคนที่ชำระแล้ว — คนที่เดินผ่านโดยไม่จ่ายไม่นับเป็นผู้เข้าใช้
    final alreadyToday = entries.any(
      (entry) =>
          entry.paid &&
          entry.studentId == valid.studentId &&
          entry.date == today,
    );

    if (!alreadyToday) {
      await CloudService.saveEntry(
        Entry(
          id: '${now.millisecondsSinceEpoch}-${valid.code}',
          code: valid.code,
          studentId: valid.studentId,
          studentName: valid.studentName,
          priceCents: valid.priceCents,
          ts: now.millisecondsSinceEpoch,
          date: today,
        ),
      );
    }

    return GateAccepted(ticket: valid, alreadyToday: alreadyToday);
  }
}
