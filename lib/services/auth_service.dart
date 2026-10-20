import 'dart:convert';

import '../db/queries.dart';
import '../models/account.dart';
import 'password.dart';

/// ล็อกอิน (ในเครื่อง) และสมัครบัญชีนิสิต
/// เจ้าของ: <67317088>
class AuthService {
  AuthService._();

  /// key ในตาราง cache ที่เก็บบัญชีเจ้าหน้าที่ที่ "จำไว้บนเครื่องนี้"
  /// (ใช้กับโหมดประตู เพื่อไม่ต้องล็อกอินทุกครั้งที่เปิดแอป)
  static const sessionKey = 'session_staff';

  /// ตรวจรูปแบบข้อมูลสมัคร — ฟังก์ชันบริสุทธิ์ เทสต์ได้โดยไม่ต้องมีฐานข้อมูล
  /// คืน null = ผ่าน
  static String? validateInput({
    required String studentId,
    required String name,
    required String password,
  }) {
    final id = studentId.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(id)) return 'รหัสนิสิตต้องเป็นเลข 8 หลัก';
    if (name.trim().isEmpty) return 'กรุณากรอกชื่อ';
    if (password.length < 6) return 'รหัสผ่านต้องยาวอย่างน้อย 6 ตัว';
    return null;
  }

  static Future<Account?> login(
    String loginId,
    String password,
    AccountRole role,
  ) async {
    final row = await Queries.findAccount(loginId.trim());
    if (row == null) return null;

    final roleName = role == AccountRole.staff ? 'staff' : 'student';
    if (row['role'] != roleName) return null;
    if (hashPassword(password, row['salt']! as String) !=
        row['password_hash']) {
      return null;
    }

    return Account.fromMap(row);
  }

  /// คืน null เมื่อสำเร็จ ไม่ฉะนั้นคืนข้อความแจ้งข้อผิดพลาด
  static Future<String?> registerStudent({
    required String studentId,
    required String name,
    required String password,
  }) async {
    final invalid = validateInput(
      studentId: studentId,
      name: name,
      password: password,
    );
    if (invalid != null) return invalid;

    final id = studentId.trim();
    if (await Queries.findAccount(id) != null) {
      return 'รหัสนิสิตนี้มีบัญชีอยู่แล้ว';
    }

    final salt = newSalt();
    await Queries.insertAccount(
      login: id,
      role: 'student',
      name: name.trim(),
      passwordHash: hashPassword(password, salt),
      salt: salt,
    );
    return null;
  }

  /// จำบัญชีเจ้าหน้าที่ไว้บนเครื่องนี้ (ไม่เก็บรหัสผ่าน) — ใช้เปิดโหมดประตูได้โดยไม่ต้องล็อกอิน
  static Future<void> rememberStaff(Account account) => Queries.cachePut(
    sessionKey,
    jsonEncode({'login': account.login, 'name': account.name}),
  );

  /// บัญชีเจ้าหน้าที่ที่จำไว้บนเครื่องนี้ (null = ยังไม่เคยจำ)
  static Future<Account?> rememberedStaff() async {
    final raw = await Queries.cacheGet(sessionKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Account(
        login: map['login'] as String,
        name: map['name'] as String,
        role: AccountRole.staff,
      );
    } catch (_) {
      return null;
    }
  }
}
