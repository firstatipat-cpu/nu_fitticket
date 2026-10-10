import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'student_home.dart';

/// สมัครบัญชีนิสิตใหม่ด้วยรหัสนิสิต
/// เจ้าของ: <67317088>
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final error = await AuthService.registerStudent(
        studentId: _id.text,
        name: _name.text,
        password: _password.text,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _busy = false;
          _error = error;
        });
        return;
      }

      final account = await AuthService.login(
        _id.text,
        _password.text,
        AccountRole.student,
      );
      if (!mounted) return;
      if (account == null) {
        setState(() {
          _busy = false;
          _error = 'สมัครแล้ว แต่เข้าสู่ระบบไม่สำเร็จ กรุณาเข้าสู่ระบบใหม่';
        });
        return;
      }

      context.read<AppState>().signIn(account);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentHomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'สมัครไม่สำเร็จ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'บัญชีนี้ใช้ซื้อตั๋วและโชว์ตั๋วเข้าใช้กับเจ้าหน้าที่',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _id,
              keyboardType: TextInputType.number,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'รหัสนิสิต (8 หลัก)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'ชื่อ-นามสกุล',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัว)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _register,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('สมัครและเข้าใช้งาน'),
            ),
          ],
        ),
      ),
    );
  }
}
