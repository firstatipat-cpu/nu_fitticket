import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../db/queries.dart';
import '../models/entry.dart';
import '../models/ticket.dart';

/// ผลของการอ่านจากคลาวด์ — `offline` = ต้องใช้ข้อมูลในเครื่องแทน
typedef CloudRead<T> = ({T data, bool offline});

/// ผลของการเขียนขึ้นคลาวด์
/// - ok = เขียนสำเร็จ
/// - queued = เน็ต/เซิร์ฟเวอร์มีปัญหา พักไว้ในคิวแล้วรอซิงก์
/// - rejected = คลาวด์ปฏิเสธถาวร (กฎ create-only ชนคีย์ที่มีอยู่) = ไม่มีการบันทึก
enum WriteResult { ok, queued, rejected }

/// คุยกับ Firebase Realtime Database ผ่าน REST
/// + แคชข้อมูลล่าสุดในเครื่อง + คิวการเขียนที่ยังซิงก์ไม่ได้
/// เจ้าของ: <67316807>
///
/// ใช้ REST ตรง ๆ จึงไม่ต้องใช้ SDK/ไฟล์ config — มีแค่ URL ของฐานข้อมูล
class CloudService {
  CloudService._();

  static const _timeout = Duration(seconds: 8);

  /// อ่านโหนดเดิมซ้ำภายใน 5 วินาทีไม่ต้องยิงเน็ตใหม่ (ลดการดึงข้อมูลซ้ำ)
  /// เขียนข้อมูลใดลงโหนดนั้น = แคชนั้นหมดอายุทันที
  static const _readTtl = Duration(seconds: 5);

  static final Map<String, ({DateTime at, Map<String, dynamic> data})> _memory =
      {};

  static bool get isConfigured => !kDatabaseUrl.contains('REPLACE');

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
  static Future<CloudRead<Map<String, dynamic>>> _readNode(String node) async {
    final cached = _memory[node];
    if (cached != null && DateTime.now().difference(cached.at) < _readTtl) {
      return (data: cached.data, offline: false);
    }

    if (isConfigured) {
      try {
        final res = await http.get(_uri(node)).timeout(_timeout);
        if (res.statusCode == 200) {
          final data = _decode(res.body);
          await Queries.cachePut(node, res.body);
          _memory[node] = (at: DateTime.now(), data: data);
          return (data: data, offline: false);
        }
        // เซิร์ฟเวอร์ตอบแต่ไม่ใช่ 200 (เช่น 401/403 จากกฎ) → ใช้แคชและติดธงไว้
      } catch (_) {
        // เงียบไว้ แล้วตกไปอ่านแคช
      }
    }
    return (data: await _cachedNode(node), offline: true);
  }

  /// อ่านแคชของโหนดตอนออฟไลน์: รวมรายการที่เพิ่งเขียนแต่ละคีย์ (ที่เก็บไว้แยกคีย์)
  /// เข้าไปด้วย เพื่อให้เห็นข้อมูลใหม่แม้ยังไม่ได้ซิงก์
  static Future<Map<String, dynamic>> _cachedNode(String node) async {
    final cached = await Queries.cacheGet(node);
    final map = cached == null ? <String, dynamic>{} : _decode(cached);
    final prefix = '$node/';
    for (final row in await Queries.cacheRowsWithPrefix(prefix)) {
      final key = row['key'] as String;
      map[key.substring(prefix.length)] = _decode(row['json'] as String);
    }
    if (map.isNotEmpty) await Queries.cachePut(node, jsonEncode(map));
    return map;
  }

  /// เขียนค่าที่โหนดย่อย — สำเร็จคืน ok · พักในคิวคืน queued · ถูกปฏิเสธถาวรคืน rejected
  static Future<WriteResult> _writeChild(
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
          await Queries.cachePut(path, jsonEncode(body));
          _memory.remove(node);
          return WriteResult.ok;
        }
        // 400/401/403 = คลาวด์ปฏิเสธถาวร (กฎ create-only ชนคีย์ที่มีอยู่ /
        // path ผิดกฎฐานข้อมูล) — ไม่พักลงคิว (ลองซ้ำไม่มีทางสำเร็จ) และไม่แก้แคช
        // เพราะข้อมูลนี้ไม่ได้ถูกบันทึกจริง — ถ้าแก้แคชจะทำให้ผู้ใช้เห็นข้อมูล
        // ที่หายไปเงียบ ๆ
        if (res.statusCode == 400 ||
            res.statusCode == 401 ||
            res.statusCode == 403) {
          return WriteResult.rejected;
        }
        // (429/5xx/เน็ตหลุด) → พักลงคิวรอซิงก์ตามปกติ
      } catch (_) {
        // ตกไปพักคิว
      }
    }
    await Queries.outboxAdd(path: path, body: jsonEncode(body));
    await Queries.cachePut(path, jsonEncode(body));
    _memory.remove(node);
    return WriteResult.queued;
  }

  // ---- ตั๋ว ----

  static Future<WriteResult> saveTicket(Ticket ticket) =>
      _writeChild('/tickets', ticket.code, ticket.toJson());

  static Future<CloudRead<List<Ticket>>> tickets() async {
    final read = await _readNode('/tickets');
    return (
      data: [
        for (final entry in read.data.entries)
          if (entry.value is Map)
            Ticket.fromNode(
              entry.key,
              (entry.value as Map).cast<String, Object?>(),
            ),
      ],
      offline: read.offline,
    );
  }

  /// อ่านรายคีย์ (GET /tickets/<code>.json) — ไม่ดึงตั๋วทั้งตารางมาค้นในเครื่อง
  static Future<CloudRead<Ticket?>> ticketByCode(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.isEmpty) return (data: null, offline: false);
    final read = await _readNode('/tickets/$wanted');
    return (
      data: read.data.isEmpty ? null : Ticket.fromNode(wanted, read.data),
      offline: read.offline,
    );
  }

  // ---- การเข้าใช้ ----

  static Future<WriteResult> saveEntry(Entry entry) =>
      _writeChild('/entries', entry.id, entry.toJson());

  static Future<CloudRead<List<Entry>>> entries() async {
    final read = await _readNode('/entries');
    return (
      data: [
        for (final entry in read.data.entries)
          if (entry.value is Map)
            Entry.fromNode(
              entry.key,
              (entry.value as Map).cast<String, Object?>(),
            ),
      ],
      offline: read.offline,
    );
  }

  /// อ่านรายคีย์ของบันทึกการเข้าใช้ 1 รายการ (GET `/entries/<id>.json`)
  /// ใช้เช็คว่า "คนนี้เข้าใช้วันนี้แล้วหรือยัง" โดยไม่ต้องดึงทั้งโหนด
  static Future<CloudRead<Entry?>> entryById(String id) async {
    final read = await _readNode('/entries/$id');
    return (
      data: read.data.isEmpty ? null : Entry.fromNode(id, read.data),
      offline: read.offline,
    );
  }

  // ---- สลิป (กันใช้สลิปซ้ำ) ----

  /// สลิปเลขที่รายการนี้เคยถูกใช้แล้วหรือยัง (อ่านรายคีย์ ไม่ดึงทั้งโหนด)
  static Future<CloudRead<bool>> isSlipUsed(String reference) async {
    final read = await _readNode('/slips/$reference');
    return (data: read.data.isNotEmpty, offline: read.offline);
  }

  static Future<WriteResult> markSlipUsed({
    required String reference,
    required String ticketCode,
  }) => _writeChild('/slips', reference, {
    'ticket_code': ticketCode,
    'ts': DateTime.now().millisecondsSinceEpoch,
  });

  // ---- คิวรอซิงก์ ----

  static Future<int> pendingCount() => Queries.outboxCount();

  /// ส่งรายการที่ค้างในคิวขึ้นคลาวด์ — คืนจำนวนที่ส่งสำเร็จและจำนวนที่ถูกตัดทิ้ง
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
          // คลาวด์ปฏิเสธถาวร (create-only ชนคีย์ที่มีอยู่แล้ว) —
          // ลองซ้ำไม่มีทางสำเร็จ จึงตัดทิ้ง (429/5xx ยังคงลองรอบหน้า)
          await Queries.outboxDelete(row['id']! as int);
          dropped++;
        }
      } on FormatException {
        // path รูปแบบ URL ถาวร (เช่น เลขที่รายการสลิปปลอมมีอักขระแปลก)
        await Queries.outboxDelete(row['id']! as int);
        dropped++;
      } catch (_) {
        // ยังไม่พร้อม รอรอบหน้า
      }
    }
    return (sent: sent, dropped: dropped);
  }
}
