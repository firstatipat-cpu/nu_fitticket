import '../db/queries.dart';
import '../models/account.dart';
import 'password.dart';

/// ล็อกอิน (ในเครื่อง) และสมัครบัญชีนิสิต
/// เจ้าของ: <67317088>
class AuthService {
  AuthService._();

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
    final id = studentId.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(id)) return 'รหัสนิสิตต้องเป็นเลข 8 หลัก';
    if (name.trim().isEmpty) return 'กรุณากรอกชื่อ';
    if (password.length < 6) return 'รหัสผ่านต้องยาวอย่างน้อย 6 ตัว';
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
}
