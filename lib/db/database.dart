import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../services/password.dart';
import 'schema.dart';

/// เปิดฐานข้อมูลในเครื่องและใส่บัญชีตั้งต้น
/// เจ้าของ: <67316807>
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'nu_fitticket.db');
    return openDatabase(
      path,
      // v3 = ทดสอบเส้นทางการอัปเกรดจริง (สคีมาเดิม แต่ path migration เปลี่ยน)
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedAccounts(db);
      },
      // ห้ามลบ `accounts`: บัญชีที่นิสิตสมัครเองต้องไม่หาย — ทิ้งเฉพาะแคช/คิว
      // และตารางของสคีมาเก่า (v1) ที่เลิกใช้แล้ว
      onUpgrade: (db, oldVersion, newVersion) async {
        for (final table in const [
          'cache',
          'outbox',
          'students',
          'staff',
          'facilities',
          'entries',
          'topups',
        ]) {
          await db.execute('DROP TABLE IF EXISTS $table');
        }
        await _createTables(db); // IF NOT EXISTS → `accounts` เดิมยังอยู่
        await _seedAccounts(db); // seed เฉพาะเมื่อยังไม่มีบัญชี
      },
    );
  }

  Future<void> _createTables(Database db) async {
    for (final sql in Schema.createTables) {
      await db.execute(sql);
    }
  }

  /// บัญชีตั้งต้นในเครื่อง — ฝั่งนิสิตสมัครเองได้ แต่เจ้าหน้าที่ใช้บัญชีที่ฝังมา
  /// ข้ามถ้ามีบัญชีอยู่แล้ว เพื่อไม่ให้ทับบัญชีที่ผู้ใช้สมัครเองตอนอัปเกรดสคีมา
  Future<void> _seedAccounts(Database db) async {
    final existing = await db.query('accounts', limit: 1);
    if (existing.isNotEmpty) return;
    final staffSalt = newSalt();
    await db.insert('accounts', {
      'login': Schema.seedStaffLogin,
      'role': 'staff',
      'name': Schema.seedStaffName,
      'password_hash': hashPassword(Schema.seedPassword, staffSalt),
      'salt': staffSalt,
    });

    final studentSalt = newSalt();
    await db.insert('accounts', {
      'login': Schema.seedStudentLogin,
      'role': 'student',
      'name': Schema.seedStudentName,
      'password_hash': hashPassword(Schema.seedPassword, studentSalt),
      'salt': studentSalt,
    });
  }
}
