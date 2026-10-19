import '../models/entry.dart';
import '../models/ticket.dart';
import 'cloud_service.dart';

enum GateFailure { notFound, expired }

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

  /// ตรวจรหัสตั๋ว (จาก QR หรือกรอกเอง) แล้วบันทึกการเข้าใช้
  /// นับคนละ 1 ครั้งต่อวัน — สแกนซ้ำวันเดิมจะไม่เพิ่มรายการใหม่
  static Future<GateResult> checkIn(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return const GateRejected(GateFailure.notFound);

    final ticket = await CloudService.ticketByCode(wanted);
    if (ticket == null) return const GateRejected(GateFailure.notFound);

    final now = DateTime.now();
    if (ticket.isExpiredAt(now)) {
      return GateRejected(GateFailure.expired, ticket: ticket);
    }

    final today = dateKey(now);
    final entries = await CloudService.entries();
    final alreadyToday = entries.any(
      (entry) => entry.studentId == ticket.studentId && entry.date == today,
    );

    if (!alreadyToday) {
      await CloudService.saveEntry(
        Entry(
          id: '${now.millisecondsSinceEpoch}-${ticket.code}',
          code: ticket.code,
          studentId: ticket.studentId,
          studentName: ticket.studentName,
          priceCents: ticket.priceCents,
          ts: now.millisecondsSinceEpoch,
          date: today,
        ),
      );
    }

    return GateAccepted(ticket: ticket, alreadyToday: alreadyToday);
  }
}
