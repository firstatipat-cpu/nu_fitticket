import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// แท็กสถานะการชำระเงิน ใช้ร่วมกันทุกหน้าจอ (ตั๋ว · ประวัติ · ประตู · รายงาน)
/// เจ้าของ: <67317088>
class PaymentBadge extends StatelessWidget {
  const PaymentBadge({super.key, required this.paid, this.compact = false});

  /// true = ชำระแล้ว · false = ยังไม่ชำระ
  final bool paid;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.success : AppColors.danger;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle : Icons.error_outline,
            size: compact ? 13 : 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            paid ? 'ชำระแล้ว' : 'ยังไม่ชำระ',
            style: TextStyle(
              color: color,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// แถบสถานะการชำระ — จุดเด่นหนึ่งเดียวของแอป ใช้รูปเดียวกันทุกหน้า
/// (หน้าตั๋ว · หน้าแรกนิสิต · หน้าประตู) เพื่อให้อ่านออกจากไกล ๆ ว่า "จ่ายแล้วหรือยัง"
/// เจ้าของ: <67317088>
class PaymentStatusBand extends StatelessWidget {
  const PaymentStatusBand({
    super.key,
    required this.paid,
    this.detail,
    this.large = false,
  });

  /// true = ชำระแล้ว · false = ยังไม่ชำระ
  final bool paid;

  /// บรรทัดรายละเอียดใต้สถานะ (เช่น เวลาที่ยืนยัน · หมายเลขสลิป)
  final String? detail;

  /// ขนาดใหญ่สำหรับหน้าที่ต้องมองเห็นจากไกล (หน้าประตู)
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = paid ? AppColors.success : AppColors.danger;
    final label = paid ? 'ชำระแล้ว' : 'ยังไม่ชำระ';
    final icon = paid ? Icons.check_circle : Icons.error_outline;

    return Semantics(
      label: 'สถานะการชำระ: $label${detail == null ? '' : ' · $detail'}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: large ? 18 : 14,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: large ? 44 : 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: large ? 26 : 22, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: large ? 24 : 20,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: TextStyle(
                        color: AppColors.ink.withValues(alpha: 0.75),
                        fontSize: large ? 14 : 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
