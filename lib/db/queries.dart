import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// คำสั่งอ่าน/เขียนฐานข้อมูลในเครื่อง
/// เจ้าของ: <67316807>
class Queries {
  Queries._();

  // ---- accounts ----

  static Future<Map<String, Object?>?> findAccount(String login) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'login = ?',
      whereArgs: [login],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> insertAccount({
    required String login,
    required String role,
    required String name,
    required String passwordHash,
    required String salt,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('accounts', {
      'login': login,
      'role': role,
      'name': name,
      'password_hash': passwordHash,
      'salt': salt,
    });
  }

  // ---- cache ----

  static Future<void> cachePut(String key, String json) async {
    final db = await AppDatabase.instance.database;
    await db.insert('cache', {
      'key': key,
      'json': json,
      'fetched_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> cacheGet(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'cache',
      columns: ['json'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['json'] as String;
  }

  // ---- outbox ----

  static Future<void> outboxAdd({
    required String path,
    required String body,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('outbox', {
      'path': path,
      'body': body,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, Object?>>> outboxAll() async {
    final db = await AppDatabase.instance.database;
    return db.query('outbox', orderBy: 'id');
  }

  static Future<void> outboxDelete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> outboxCount() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM outbox');
    return rows.first['n']! as int;
  }
}
