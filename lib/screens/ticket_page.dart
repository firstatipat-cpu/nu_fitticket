import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config.dart';
import '../models/ticket.dart';
import '../theme/app_theme.dart';
import '../widget/payment_badge.dart';

/// ตั๋วที่นิสิตโชว์ให้เจ้าหน้าที่ — มี QR และรหัสสำรองให้กรอกได้
/// เจ้าของ: <67317088>
class TicketPage extends StatelessWidget {
  const TicketPage({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d/M/yyyy HH:mm');
    final expired = ticket.isExpiredAt(DateTime.now());
    final expiryColor = expired ? AppColors.danger : AppColors.success;

    return Scaffold(
      appBar: AppBar(title: const Text('ตั๋วของฉัน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // จุดเด่นหนึ่งเดียวของแอป: สถานะการชำระ อ่านออกจากไกล ๆ
          PaymentStatusBand(
            paid: ticket.isPaid,
            detail: ticket.isPaid
                ? (ticket.bankName == null
                      ? 'ยืนยันแล้ว${ticket.slipRef == null ? '' : ' · เลขที่ ${ticket.slipRef}'}'
                      : 'ยืนยันแล้ว · ${ticket.bankName}')
                : 'ยังไม่ยืนยัน — แนบสลิปการโอนเพื่อใช้งานตั๋วนี้',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kFacilityName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ตั๋วใช้ได้ถึง 20:00 น. ของวันที่ซื้อ',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: expiryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          expired ? 'หมดอายุ' : 'ใช้ได้',
                          style: TextStyle(
                            color: expiryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: QrImageView(
                      data: ticket.code,
                      version: QrVersions.auto,
                      size: 210,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'รหัสตั๋ว (ใช้กรอกสำรองได้)',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.code,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      height: 1.2,
                    ),
                  ),
                  const Divider(height: 28),
                  _Row(label: 'ชื่อ', value: ticket.studentName),
                  _Row(label: 'รหัสนิสิต', value: ticket.studentId),
                  _Row(
                    label: 'การชำระเงิน',
                    value: ticket.isPaid ? 'ชำระแล้ว' : 'ยังไม่ชำระ',
                  ),
                  if (ticket.slipRef != null)
                    _Row(label: 'เลขที่รายการ', value: ticket.slipRef!),
                  if (ticket.bankName != null)
                    _Row(label: 'ธนาคารผู้ส่ง', value: ticket.bankName!),
                  _Row(
                    label: 'ซื้อเมื่อ',
                    value: format.format(ticket.purchasedTime),
                  ),
                  _Row(
                    label: 'ใช้ได้ถึง',
                    value: format.format(ticket.expiryTime),
                  ),
                  _Row(
                    label: 'ราคา',
                    value: '${ticket.priceBaht.toStringAsFixed(0)} บาท',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'โชว์หน้านี้ให้เจ้าหน้าที่ดูก่อนเข้าใช้ — เจ้าหน้าที่จะสแกน QR หรือกรอกรหัสตั๋ว',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
