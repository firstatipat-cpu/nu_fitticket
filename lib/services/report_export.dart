import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/entry.dart';
import '../config.dart';
import 'cloud_service.dart';

/// R5 — สร้างและส่งออกไฟล์รายงาน CSV จากบันทึกการเข้าใช้
/// เจ้าของ: <67314858>
class ReportExport {
  ReportExport._();

  static Future<List<Entry>> entriesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final all = await CloudService.entries();
    final inRange = all
        .where((entry) => entry.ts >= startMs && entry.ts < endMs)
        .toList();
    inRange.sort((a, b) => b.ts.compareTo(a.ts));
    return inRange;
  }

  static String buildCsv(List<Entry> entries) {
    final date = DateFormat('yyyy-MM-dd');
    final time = DateFormat('HH:mm');
    final rows = <List<Object?>>[
      [
        'วันที่',
        'เวลา',
        'รหัสนิสิต',
        'ชื่อ',
        'รหัสตั๋ว',
        'สถานที่',
        'ราคา (บาท)',
      ],
      for (final entry in entries)
        [
          date.format(entry.time),
          time.format(entry.time),
          _safe(entry.studentId),
          _safe(entry.studentName),
          _safe(entry.code),
          _safe(kFacilityName),
          (entry.priceCents / 100).toStringAsFixed(2),
        ],
    ];
    // BOM นำหน้าเพื่อให้ Excel อ่านภาษาไทยถูก
    return '\uFEFF${CsvEncoder().convert(rows)}';
  }

  /// กัน CSV formula injection: ค่าที่ขึ้นต้นด้วย = + - @ จะกลายเป็นสูตรใน Excel
  /// ครอบทุกช่องที่มาจากผู้ใช้/คลาวด์ (ข้อมูลตั๋วบนคลาวด์ปลอมได้ — SPEC §10.3)
  static String _safe(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return text;
    const risky = {'=', '+', '-', '@'};
    return risky.contains(text[0]) ? "'$text" : text;
  }

  static Future<File> writeCsv({
    required DateTime start,
    required DateTime end,
  }) async {
    final dir = await getTemporaryDirectory();
    final name = 'nu_fitticket_${DateFormat('yyyyMMdd').format(start)}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(buildCsv(await entriesBetween(start, end)));
    return file;
  }

  static Future<void> exportAndShare({
    required DateTime start,
    required DateTime end,
  }) async {
    final file = await writeCsv(start: start, end: end);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'รายงานการเข้าใช้ NU FitTicket',
        text:
            'รายงานการเข้าใช้ ${DateFormat('d/M/yyyy').format(start)} - ${DateFormat('d/M/yyyy').format(end)}',
      ),
    );
  }
}
