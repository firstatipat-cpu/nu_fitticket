import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/cloud_service.dart';
import '../services/report_export.dart';
import '../theme/app_theme.dart';

/// R5 — เลือกช่วงวันที่และส่งออก CSV ของบันทึกการเข้าใช้
/// เจ้าของ: <รหัสนิสิตคนที่ 3>
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late DateTimeRange _range = _defaultRange();
  int? _count;
  bool _busy = false;
  String? _error;

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  DateTime get _endExclusive => _range.end.add(const Duration(days: 1));

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _count = null;
      _error = null;
    });
  }

  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final entries = await ReportExport.entriesBetween(
      _range.start,
      _endExclusive,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _count = entries.length;
    });
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ReportExport.exportAndShare(
        start: _range.start,
        end: _endExclusive,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'ส่งออกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d/M/yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('รายงานการเข้าใช้')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            leading: const Icon(Icons.date_range, color: AppColors.orange),
            title: const Text('ช่วงวันที่'),
            subtitle: Text(
              '${format.format(_range.start)} - ${format.format(_range.end)}',
            ),
            trailing: const Icon(Icons.edit, color: AppColors.orange),
            onTap: _busy ? null : _pickRange,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _preview,
            icon: const Icon(Icons.search),
            label: const Text('ตรวจสอบจำนวนรายการ'),
          ),
          if (_count != null) ...[
            const SizedBox(height: 12),
            Text('พบ $_count รายการในช่วงที่เลือก'),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.download),
            label: const Text('ส่งออก CSV'),
          ),
          if (!CloudService.isConfigured) ...[
            const SizedBox(height: 12),
            const Text(
              'ยังไม่ได้ตั้งค่า Firebase — รายงานจะว่าง',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 24),
          const Text(
            'ไฟล์ CSV มีคอลัมน์: วันที่, เวลา, รหัสนิสิต, ชื่อ, รหัสตั๋ว, สถานที่, ราคา (บาท)',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
