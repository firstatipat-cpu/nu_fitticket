import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/gate_service.dart';
import '../theme/app_theme.dart';
import '../widget/payment_badge.dart';
import '../widget/scan_widgets.dart';

/// R4 — โหมดประตู: ตั้งเครื่องไว้ที่ประตู นิสิตสแกน QR ตัวเอง ไม่ต้องมีเจ้าหน้าที่นั่งเฝ้า
/// เจ้าของ: <67314858>
class GateKioskPage extends StatefulWidget {
  const GateKioskPage({super.key});

  @override
  State<GateKioskPage> createState() => _GateKioskPageState();
}

class _KioskResult {
  const _KioskResult({
    required this.ok,
    required this.title,
    required this.detail,
    this.paid,
  });

  final bool ok;
  final String title;
  final String detail;

  /// null = ไม่เกี่ยวกับการชำระเงิน (เช่น ไม่พบตั๋ว)
  final bool? paid;
}

class _GateKioskPageState extends State<GateKioskPage> {
  final _controller = MobileScannerController();
  final _manual = TextEditingController();

  bool _busy = false;
  _KioskResult? _result;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    if (_busy) return;
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _controller.stop();
    } catch (_) {
      // กล้องอาจไม่ได้เปิดอยู่ — ไม่เป็นไร
    }

    final outcome = await GateService.checkIn(code);
    if (!mounted) return;

    final shown = GateService.describe(
      outcome.result,
      offline: outcome.offline,
    );
    final paid = switch (outcome.result) {
      GateAccepted(:final ticket) => ticket.isPaid,
      GateRejected(:final failure) =>
        failure == GateFailure.unpaid ? false : null,
    };

    setState(() {
      _result = _KioskResult(
        ok: shown.success,
        title: shown.success ? 'เข้าได้' : shown.title,
        detail: shown.detail,
        paid: paid,
      );
      _busy = false;
    });

    // กลับสู่สถานะพร้อมสแกนเองใน 4 วินาที (ไม่ต้องมีคนกด)
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _result = null);
      unawaited(_controller.start().catchError((_) {}));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('โหมดประตู'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(22),
          child: Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'สแกนเอง ไม่ต้องมีเจ้าหน้าที่นั่งเฝ้า',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 240,
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    final value = barcode.rawValue;
                    if (value != null && value.trim().isNotEmpty) {
                      _handle(value);
                      return;
                    }
                  }
                },
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'เปิดกล้องไม่ได้ (${error.errorCode})\n'
                      'ให้ใช้ช่องกรอกรหัสตั๋วด้านล่างแทน',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ManualCodeField(
            controller: _manual,
            enabled: !_busy,
            onSubmit: _handle,
            hint: 'กรอกรหัสตั๋วสำรอง (6 ตัว)',
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final result = _result;
    final color = result == null
        ? AppColors.charcoal
        : result.ok
        ? AppColors.success
        : AppColors.danger;

    return Card(
      color: result == null ? Colors.white : color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: result == null ? AppColors.line : color.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(
          children: [
            Icon(
              result == null
                  ? Icons.qr_code_scanner
                  : result.ok
                  ? Icons.check_circle
                  : Icons.cancel,
              size: 64,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              result?.title ?? 'พร้อมสแกน',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            if (result != null && result.detail.isNotEmpty)
              Text(
                result.detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            if (result?.paid != null) ...[
              const SizedBox(height: 10),
              PaymentBadge(paid: result!.paid!),
            ],
          ],
        ),
      ),
    );
  }
}
