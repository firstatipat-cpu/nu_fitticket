import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widget/nu_header.dart';
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

  /// บัญชีเจ้าหน้าที่ที่เคยล็อกอินบนเครื่องนี้ (ใช้เปิดโหมดประตูได้โดยไม่ต้องล็อกอิน)
  Account? _remembered;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
    // แก้ข้อความผิดพลาดทิ้งทันทีที่ผู้ใช้เริ่มพิมพ์ใหม่ (ไม่ให้ข้อความเก่าค้างรบกวน)
    _id.addListener(_clearError);
    _password.addListener(_clearError);
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _loadRemembered() async {
    final account = await AuthService.rememberedStaff();
    if (!mounted) return;
    setState(() => _remembered = account);
  }

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  /// เปิดโหมดประตูโดยไม่ต้องใส่รหัสผ่าน (เครื่องประตูเป็นของโรงยิมที่ล็อกอินไว้แล้ว)
  void _openKiosk() {
    final account = _remembered;
    if (account == null) return;
    context.read<AppState>().signIn(account);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
    );
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
      if (account.isStaff) {
        // จำบัญชีไว้บนเครื่องนี้ เพื่อเปิดโหมดประตูได้โดยไม่ต้องล็อกอินทุกครั้ง
        await AuthService.rememberStaff(account);
        if (!mounted) return;
      }
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => account.isStaff
                ? const StaffDashboardPage()
                : const StudentHomePage(),
          ),
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
              title: 'NU\nFitTicket',
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
                  if (_remembered != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.phonelink_ring),
                      label: const Text('โหมดประตู — เปิดโดยไม่ต้องล็อกอิน'),
                      onPressed: _busy ? null : _openKiosk,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'เครื่องนี้เคยล็อกอินเป็น ${_remembered!.name} — ใช้เปิดโหมดประตูได้เลย',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
