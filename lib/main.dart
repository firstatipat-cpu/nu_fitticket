import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/login_page.dart';
import 'services/cloud_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // พื้นหลังส่วนหัว/แอปบาร์เป็นสีเข้มทั้งหมด → ใช้ไอคอน status bar สีสว่าง
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  // ส่งรายการที่ค้างในคิวขึ้นคลาวด์ถ้ามี (ไม่ต้องรอ)
  unawaited(CloudService.flushOutbox());
  runApp(const NuFitTicketApp());
}

class NuFitTicketApp extends StatelessWidget {
  const NuFitTicketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'NU FitTicket',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('th'),
        supportedLocales: const [Locale('th'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LoginPage(),
      ),
    );
  }
}
