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
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle : Icons.error_outline,
            size: compact ? 12 : 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            paid ? 'ชำระแล้ว' : 'ยังไม่ชำระ',
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
