import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// ตัวช่วยแฮชรหัสผ่าน — ไม่เก็บรหัสผ่านดิบลงฐานข้อมูล
/// เจ้าของ: <67317088>
///
/// ponytail: SHA-256 + salt พอสำหรับงานรายวิชา (ไม่มีคีย์จริง) โปรดักชันจริงใช้ bcrypt/argon2
String newSalt() {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
}

String hashPassword(String password, String salt) =>
    sha256.convert(utf8.encode('$salt$password')).toString();
