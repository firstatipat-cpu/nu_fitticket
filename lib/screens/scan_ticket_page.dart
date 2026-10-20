import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/gate_service.dart';
import '../theme/app_theme.dart';
import '../widget/scan_widgets.dart';

/// R4 — สแกน QR ตั๋ว หรือกรอกรหัสสำรอง แล้วบันทึกการเข้าใช้
/// เจ้าของ: <67314858>
class ScanTicketPage extends StatefulWidget {
  const ScanTicketPage({super.key});

  @override
  State<ScanTicketPage> createState() => _ScanTicketPageState();
}

class _ScanTicketPageState extends State<ScanTicketPage> {
  final _controller = MobileScannerController();
  final _manual = TextEditingController();

  bool _locked = false; // หยุดรับผลซ้ำหลังได้คำตอบแล้ว
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _check(String rawCode) async {
    if (_locked) return;
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _locked = true);
    try {
      await _controller.stop();
    } catch (_) {
      // กล้องอาจไม่ได้เปิดอยู่ (โหมดกรอกรหัส) — ไม่เป็นไร
    }

    final outcome = await GateService.checkIn(code);
    if (!mounted) return;

    final shown = GateService.describe(
      outcome.result,
      offline: outcome.offline,
    );

    setState(() {
      _message = '${shown.success ? '✓' : '✕'} ${shown.title}\n${shown.detail}';
      _success = shown.success;
    });
  }

  void _reset() {
    setState(() {
      _message = null;
      _locked = false;
    });
    // กล้องอาจเปิดไม่ได้ (เช่น ยังไม่ได้ให้สิทธิ์) — จับไว้ไม่ให้ exception หลุดมือ
    // ผู้ใช้ยังใช้ช่องกรอกรหัสตั๋วด้านล่างได้อยู่
    unawaited(_controller.start().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกนตั๋ว'),
        actions: [
          // อ่านสถานะจริงจาก controller — ไม่เก็บธงเอง เพื่อไม่ให้ไอคอนหลอกผู้ใช้
          // (toggleTorch ไม่ทำอะไรถ้ากล้องไม่ได้ทำงานอยู่)
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) => IconButton(
              tooltip: 'ไฟฉาย',
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
              onPressed:
                  state.isRunning && state.torchState != TorchState.unavailable
                  ? _controller.toggleTorch
                  : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 260,
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    final value = barcode.rawValue;
                    if (value != null && value.trim().isNotEmpty) {
                      _check(value);
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
          if (_message != null) ...[
            Card(
              color: (_success ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: (_success ? AppColors.success : AppColors.danger)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _success ? Icons.check_circle : Icons.cancel,
                      color: _success ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _success
                              ? AppColors.success
                              : AppColors.danger,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('สแกนต่อ'),
              onPressed: _reset,
            ),
          ],
          const Divider(height: 32),
          const Text('วิธีสำรอง: กรอกรหัสตั๋ว'),
          const SizedBox(height: 8),
          ManualCodeField(
            controller: _manual,
            enabled: !_locked,
            onSubmit: _check,
          ),
        ],
      ),
    );
  }
}
