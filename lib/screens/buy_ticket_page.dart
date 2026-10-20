import 'dart:async';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../services/promptpay.dart';
import '../services/slip_parser.dart';
import '../services/ticket_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'ticket_page.dart';

/// R1 — ซื้อตั๋ว: โชว์ QR พร้อมเพย์จริง แล้วให้นิสิตแนบสลิปเพื่อยืนยันการโอน
/// เจ้าของ: <67310379>
///
/// แอปตรวจสลิปเองทั้งหมด (ไม่ต้องให้เจ้าหน้าที่สแกนอะไร):
///   ชนิดเอกสาร KBank · CRC ถูกต้อง · เลขที่รายการยังไม่ถูกใช้
/// ตรวจไม่ได้: จำนวนเงิน และผู้รับ (ไม่มีอยู่ใน QR ของสลิป)
class BuyTicketPage extends StatefulWidget {
  const BuyTicketPage({super.key});

  @override
  State<BuyTicketPage> createState() => _BuyTicketPageState();
}

class _BuyTicketPageState extends State<BuyTicketPage> {
  /// สร้างรหัสตั๋วล่วงหน้า เพื่อให้ตรงกับเลขอ้างอิงใน QR รับเงิน
  final String _code = TicketService.newCode();

  /// ใช้จับภาพ QR เป็น PNG เพื่อแชร์ให้แอปธนาคาร (บางแอปสแกน QR จากรูปในแกลเลอรีได้)
  final _qrKey = GlobalKey();

  bool _busy = false;
  bool _failed = false;
  String? _error;

  /// แชร์รูป QR ให้แอปอื่น (เช่น แอปธนาคาร) — เปิดด้วยเมนูแชร์ของเครื่อง
  Future<void> _shareQr() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ImageByteFormat.png);
      if (data == null) throw StateError('สร้างรูปไม่สำเร็จ');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'nu-fitticket-qr-$_code.png',
            ),
          ],
          subject: 'QR พร้อมเพย์ $kFacilityName $_amount บาท',
          text:
              'QR พร้อมเพย์ $_amount บาท (รหัสอ้างอิง $_code) — เปิดในแอปธนาคารแล้วเลือก "สแกนจากรูป"',
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'แชร์ QR ไม่สำเร็จ: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  String get _amount => (kTicketPriceCents / 100).toStringAsFixed(2);

  String get _payload => PromptPay.payload(
    id: kPromptPayId,
    amount: _amount,
    ref: _code,
    merchantName: kPromptPayName,
    merchantCity: kPromptPayCity,
  );

  Future<void> _attachSlip() async {
    setState(() {
      _busy = true;
      _failed = false;
      _error = null;
    });

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final result = await TicketService.verifySlipImage(picked.path);
      if (!mounted) return;

      switch (result) {
        case SlipRejected(:final reason):
          setState(() {
            _busy = false;
            _failed = true;
            _error = reason;
          });
        case SlipAccepted(:final info):
          final account = context.read<AppState>().account!;
          final result = await TicketService.issue(
            studentId: account.login,
            studentName: account.name,
            code: _code,
            slipRef: info.reference,
            bankName: info.bankName,
          );
          if (!mounted) return;
          if (result.error != null || result.ticket == null) {
            setState(() {
              _busy = false;
              _failed = true;
              _error = result.error ?? 'ออกตั๋วไม่สำเร็จ';
            });
            return;
          }
          unawaited(
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => TicketPage(ticket: result.ticket!),
              ),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
        _error = 'แนบสลิปไม่สำเร็จ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ซื้อตั๋ว')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    kFacilityName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ตั๋วถึง 20:00 น. · $_amount บาท',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: RepaintBoundary(
                      key: _qrKey,
                      child: QrImageView(
                        data: _payload,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('แชร์ QR ให้แอปธนาคาร'),
                    onPressed: _busy ? null : _shareQr,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ถ้าแอปธนาคารของคุณสแกน QR จากรูปได้ ให้แชร์รูปนี้ไปเปิดในแอปธนาคาร '
                    '(ปุ่มเลือกรูปในหน้าสแกน) · ถ้าไม่ได้ ให้ใช้กล้องของอีกเครื่องสแกนหน้าจอนี้',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'สแกนด้วยแอปธนาคารเพื่อโอน $_amount บาท',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'พร้อมเพย์ $kPromptPayId · อ้างอิง $_code',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (PromptPay.idError(kPromptPayId) != null) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.orange.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.orangeDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        PromptPay.idError(kPromptPayId) ??
                            'ยังใช้เบอร์พร้อมเพย์ตัวอย่าง — เปลี่ยน kPromptPayId ใน lib/config.dart '
                                'เป็นบัญชีที่มีอยู่จริงก่อนสาธิต',
                        style: const TextStyle(
                          color: AppColors.orangeDark,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_failed)
            Card(
              color: AppColors.danger.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error ?? 'แนบสลิปไม่สำเร็จ กรุณาลองใหม่',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _attachSlip,
            icon: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(
              _busy ? 'กำลังตรวจสลิป...' : 'แนบสลิปเพื่อยืนยันการโอน',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'วิธีใช้: 1) สแกน QR ด้านบนด้วยแอปธนาคารเพื่อโอนเงิน  2) แคปหน้าสลิปเก็บไว้  '
            '3) กดปุ่มด้านบนแล้วเลือกภาพสลิปนั้น\n\n'
            'แอปจะตรวจว่าเป็นสลิปโอนของธนาคารจริง ข้อมูลไม่ถูกแก้ (CRC) และเลขที่รายการยังไม่เคยใช้ — '
            'แต่ QR บนสลิปไม่มีจำนวนเงินและผู้รับ จึงยืนยันยอดเงินให้อัตโนมัติไม่ได้',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}
