import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/nu_header.dart';
import 'register_page.dart';
import 'staff_dashboard.dart';
import 'student_home.dart';

/// ล็อกอินสองบทบาท: นิสิต / เจ้าหน้าที่
/// เจ้าของ: <67317088>
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _staffMode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final role = _staffMode ? AccountRole.staff : AccountRole.student;
    try {
      final account = await AuthService.login(_id.text, _password.text, role);
      if (!mounted) return;

      if (account == null) {
        setState(() {
          _busy = false;
          _error = _staffMode
              ? 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'
              : 'รหัสนิสิตหรือรหัสผ่านไม่ถูกต้อง';
        });
        return;
      }

      context.read<AppState>().signIn(account);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => account.isStaff
              ? const StaffDashboardPage()
              : const StudentHomePage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'เข้าสู่ระบบไม่สำเร็จ: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            const NUHeader(
              title: 'NARESUAN\nUNIVERSITY',
              subtitle: 'ซื้อตั๋ว NU Fitness ด้วยแอป โชว์ตั๋วเข้าใช้ได้เลย',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('นิสิต'),
                                icon: Icon(Icons.school),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('เจ้าหน้าที่'),
                                icon: Icon(Icons.badge),
                              ),
                            ],
                            selected: {_staffMode},
                            onSelectionChanged: _busy
                                ? null
                                : (selection) => setState(() {
                                    _staffMode = selection.first;
                                    _error = null;
                                  }),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _id,
                            keyboardType: _staffMode
                                ? TextInputType.text
                                : TextInputType.number,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: _staffMode
                                  ? 'ชื่อผู้ใช้'
                                  : 'รหัสนิสิต (8 หลัก)',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            enabled: !_busy,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: 'รหัสผ่าน',
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('เข้าสู่ระบบ'),
                  ),
                  if (!_staffMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                        child: const Text('สมัครใหม่ด้วยรหัสนิสิต'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'บัญชีทดสอบ\nstaff01 / test1234  (เจ้าหน้าที่)\n67000001 / test1234  (นิสิต)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
