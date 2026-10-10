import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ส่วนหัวแบบแบรนด์ NU — พื้นเข้มขอบล่างเว้าเป็นวงกลม
/// เจ้าของ: <67317088>
///
/// ใช้เป็นลูกแรกของ body เพื่อให้พื้นเทาด้านหลังโผล่ผ่านรอยเว้า
/// เนื้อหาชิดบนเพื่อไม่ให้รอยเว้ากัดข้อความ
class NUHeader extends StatelessWidget {
  const NUHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.height = 320,
    this.dip = 56,
  });

  final String title;
  final String? subtitle;
  final double height;

  /// ความลึกของรอยเว้ากลางขอบล่าง
  final double dip;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ArcClipper(dip: dip),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.charcoal,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  height: 68,
                  width: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.orange, width: 4),
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 38,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcClipper extends CustomClipper<Path> {
  const _ArcClipper({required this.dip});

  final double dip;

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height)
      ..quadraticBezierTo(
        size.width / 2,
        size.height - dip * 2,
        size.width,
        size.height,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ArcClipper oldClipper) => oldClipper.dip != dip;
}
