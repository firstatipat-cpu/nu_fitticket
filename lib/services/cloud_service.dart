import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../db/queries.dart';
import '../models/entry.dart';
import '../models/ticket.dart';

/// คุยกับ Firebase Realtime Database ผ่าน REST
/// + แคชข้อมูลล่าสุดในเครื่อง + คิวการเขียนที่ยังซิงก์ไม่ได้
/// เจ้าของ: <รหัสนิสิตคนที่ 4>
///
/// ใช้ REST ตรง ๆ จึงไม่ต้องมี SDK/ไฟล์ config/คีย์ — มีแค่ URL ของฐานข้อมูล
class CloudService {
  CloudService._();

  static const _timeout = Duration(seconds: 8);

  static bool get isConfigured => !kDatabaseUrl.contains('REPLACE');

  /// true เมื่อการอ่านครั้งล่าสุดต้องย้อนไปใช้ข้อมูลในเครื่อง (ออฟไลน์/เน็ตมีปัญหา)
  static bool lastReadOffline = false;

  static Uri _uri(String path) {
    // กัน URL ที่มี / ต่อท้าย (จะทำให้เกิด // ในพาธ)
    final base = kDatabaseUrl.endsWith('/')
        ? kDatabaseUrl.substring(0, kDatabaseUrl.length - 1)
        : kDatabaseUrl;
    return Uri.parse('$base$path.json');
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  /// อ่านทั้งโหนด คืน map (คีย์ → ข้อมูล) พร้อมแคชไว้ใช้ตอนออฟไลน์
  static Future<Map<String, dynamic>> _readNode(String node) async {
    if (isConfigured) {
      try {
        final res = await http.get(_uri(node)).timeout(_timeout);
        if (res.statusCode == 200) {
          await Queries.cachePut(node, res.body);
          lastReadOffline = false;
          return _decode(res.body);
        }
        // เซิร์ฟเวอร์ตอบแต่ไม่ใช่ 200 (เช่น 401/403 จากกฎ) → ใช้แคชและติดธงไว้
        lastReadOffline = true;
      } catch (_) {
        // เงียบไว้ แล้วตกไปอ่านแคช
        lastReadOffline = true;
      }
    }
    final cached = await Queries.cacheGet(node);
    return cached == null ? <String, dynamic>{} : _decode(cached);
  }

  /// เขียนค่าที่โหนดย่อย — สำเร็จคืน true, ถ้าล้มเหลวพักไว้ใน outbox แล้วคืน false
  static Future<bool> _writeChild(
    String node,
    String key,
    Map<String, Object?> body,
  ) async {
    final path = '$node/$key';
    if (isConfigured) {
      try {
        final res = await http
            .put(
              _uri(path),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(_timeout);
        if (res.statusCode == 200) {
          await _mergeCache(node, key, body);
          return true;
        }
        // 400/401/403 = คลาวด์ปฏิเสธถาวร (กฎ create-only ชนคีย์ที่มีอยู่ /
        // path ผิดกฎฐานข้อมูล) — ไม่พักลงคิว เพราะลองซ้ำไม่มีทางสำเร็จ
        // (429/5xx/เน็ตหลุด ยังเข้าคิวรอซิงก์ตามปกติ)
        if (res.statusCode == 400 ||
            res.statusCode == 401 ||
            res.statusCode == 403) {
          await _mergeCache(node, key, body);
          return false;
        }
      } catch (_) {
        // ตกไปพักคิว
      }
    }
    await Queries.outboxAdd(path: path, body: jsonEncode(body));
    await _mergeCache(node, key, body); // ให้หน้าจอเห็นทันทีระหว่างรอซิงก์
    return false;
  }

  static Future<void> _mergeCache(
    String node,
    String key,
    Map<String, Object?> body,
  ) async {
    final cached = await Queries.cacheGet(node);
    final map = cached == null ? <String, dynamic>{} : _decode(cached);
    map[key] = body;
    await Queries.cachePut(node, jsonEncode(map));
    // เขียนแคชรายคีย์ด้วย เพื่อให้การอ่านรายคีย์ (เช่น /tickets/<code>) เห็นข้อมูลใหม่
    await Queries.cachePut('$node/$key', jsonEncode(body));
  }

  // ---- ตั๋ว ----

  static Future<bool> saveTicket(Ticket ticket) =>
      _writeChild('/tickets', ticket.code, ticket.toJson());

  static Future<List<Ticket>> tickets() async {
    final node = await _readNode('/tickets');
    return [
      for (final entry in node.entries)
        if (entry.value is Map)
          Ticket.fromNode(
            entry.key,
            (entry.value as Map).cast<String, Object?>(),
          ),
    ];
  }

  /// อ่านรายคีย์ (GET /tickets/<code>.json) — ไม่ดึงตั๋วทั้งตารางมาค้นในเครื่อง
  static Future<Ticket?> ticketByCode(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return null;
    final node = await _readNode('/tickets/$wanted');
    return node.isEmpty ? null : Ticket.fromNode(wanted, node);
  }

  // ---- การเข้าใช้ ----

  static Future<bool> saveEntry(Entry entry) =>
      _writeChild('/entries', entry.id, entry.toJson());

  static Future<List<Entry>> entries() async {
    final node = await _readNode('/entries');
    return [
      for (final entry in node.entries)
        if (entry.value is Map)
          Entry.fromNode(
            entry.key,
            (entry.value as Map).cast<String, Object?>(),
          ),
    ];
  }

  // ---- สลิป (กันใช้สลิปซ้ำ) ----

  /// สลิปเลขที่รายการนี้เคยถูกใช้แล้วหรือยัง (อ่านรายคีย์ ไม่ดึงทั้งตาราง)
  static Future<bool> isSlipUsed(String reference) async {
    return (await _readNode('/slips/$reference')).isNotEmpty;
  }

  static Future<bool> markSlipUsed({
    required String reference,
    required String ticketCode,
  }) => _writeChild('/slips', reference, {
    'ticket_code': ticketCode,
    'ts': DateTime.now().millisecondsSinceEpoch,
  });

  // ---- คิวรอซิงก์ ----

  static Future<int> pendingCount() => Queries.outboxCount();

  /// ส่งรายการที่ค้างในคิวขึ้นคลาวด์ — คืนจำนวนที่ส่งสำเร็จและที่ถูกตัดทิ้ง
  static Future<({int sent, int dropped})> flushOutbox() async {
    if (!isConfigured) return (sent: 0, dropped: 0);
    var sent = 0;
    var dropped = 0;
    for (final row in await Queries.outboxAll()) {
      try {
        final res = await http
            .put(
              _uri(row['path']! as String),
              headers: const {'Content-Type': 'application/json'},
              body: row['body']! as String,
            )
            .timeout(_timeout);
        if (res.statusCode == 200) {
          await Queries.outboxDelete(row['id']! as int);
          sent++;
        } else if (res.statusCode == 400 ||
            res.statusCode == 401 ||
            res.statusCode == 403) {
          // คลาวด์ปฏิเสธถาวร (create-only ชนคีย์ที่มีอยู่ / path ผิดกฎ) —
          // ลองซ้ำไม่มีทางสำเร็จ จึงตัดทิ้ง (429/5xx ยังคงลองรอบหน้า)
          await Queries.outboxDelete(row['id']! as int);
          dropped++;
        }
      } on FormatException {
        // path ผิดรูปแบบ URL ถาวร (เช่น เลขที่รายการสลิปปลอมมีอักขระแปลก)
        await Queries.outboxDelete(row['id']! as int);
        dropped++;
      } catch (_) {
        // ยังไม่พร้อม ส่งรอบหน้า
      }
    }
    return (sent: sent, dropped: dropped);
  }
}
