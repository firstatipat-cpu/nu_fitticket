import 'package:flutter/foundation.dart';

import '../models/account.dart';

/// สถานะผู้ใช้ที่ล็อกอินอยู่ (ใช้ร่วมทุกหน้าจอผ่าน Provider)
/// เจ้าของ: <67317088>
class AppState extends ChangeNotifier {
  Account? _account;

  Account? get account => _account;
  bool get isStaff => _account?.isStaff ?? false;

  void signIn(Account account) {
    _account = account;
    notifyListeners();
  }

  void signOut() {
    _account = null;
    notifyListeners();
  }
}
