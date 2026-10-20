import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entry.dart';
import '../models/ticket.dart';
import '../services/cloud_service.dart';
import '../services/gate_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';
import 'report_page.dart';
import 'scan_ticket_page.dart';
import 'gate_kiosk_page.dart';

/// R4 — ภาพรวมวันนี้: ยอดขายตั๋ว + คนที่เข้าใช้ (ไม่ต้องนับเอง)
/// เจ้าของ: <67314858>
class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _DashData {
  const _DashData({
    required this.ticketsToday,
    required this.entriesToday,
    required this.pending,
    required this.offline,
  });

  final List<Ticket> ticketsToday;
  final List<Entry> entriesToday;
  final int pending;

  /// ข้อมูลที่แสดงเป็นข้อมูลจากเครื่อง (ดึงจากคลาวด์ไม่สำเร็จ)
  final bool offline;
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  _DashData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _compute();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final sync = await CloudService.flushOutbox();
    if (!mounted) return;
    // แจ้งเมื่อมีรายการที่คลาวด์ปฏิเสธถาวร (เช่น สลิปที่ถูกใช้ไปแล้ว)
    // ไม่ให้ผู้ใช้ไม่รู้ว่า "รอซิงก์" ลดลงเพราะตัดทิ้ง ไม่ใช่เพราะส่งสำเร็จ
    if (sync.dropped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ตัด ${sync.dropped} รายการที่คลาวด์ปฏิเสธออกจากคิว (เช่น สลิปที่ใช้ไปแล้ว)',
          ),
        ),
      );
    }
    await _load();
  }

  Future<_DashData> _compute() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final today = GateService.dateKey(now);

    final tickets = await CloudService.tickets();
    // สแลปธงออฟไลน์หลังอ่านแต่ละโหนด — ไม่งั้นรอบที่สำเร็จทีหลังจะล้างธงของรอบที่ล้ม
    final ticketsOffline = CloudService.lastReadOffline;
    final entries = await CloudService.entries();

    return _DashData(
      ticketsToday: tickets
          .where((t) => t.purchasedAt >= startMs && t.purchasedAt < endMs)
          .toList(),
      entriesToday: entries.where((e) => e.date == today).toList(),
      pending: await CloudService.pendingCount(),
      offline: ticketsOffline || CloudService.lastReadOffline,
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text('ต้องเข้าสู่ระบบใหม่เพื่อใช้งานต่อ'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    context.read<AppState>().signOut();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ภาพรวมวันนี้'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout),
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: _buildBody(time),
    );
  }

  Widget _buildBody(DateFormat time) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final data = _data!;
    final totalCents = data.ticketsToday.fold<int>(
      0,
      (sum, t) => sum + t.priceCents,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!CloudService.isConfigured)
            Card(
              color: AppColors.danger.withValues(alpha: 0.10),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, color: AppColors.danger),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ยังไม่ได้ตั้งค่า Firebase — แก้ kDatabaseUrl ใน lib/config.dart '
                        'เพื่อให้เห็นข้อมูลข้ามเครื่อง',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (data.offline)
            Card(
              color: AppColors.orange.withValues(alpha: 0.10),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: AppColors.orangeDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ออฟไลน์อยู่ — กำลังแสดงข้อมูลล่าสุดที่บันทึกไว้ในเครื่อง',
                        style: TextStyle(
                          color: AppColors.orangeDark,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              _StatCard(
                icon: Icons.confirmation_number,
                label: 'ตั๋วขายวันนี้',
                value: '${data.ticketsToday.length} ใบ',
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.payments,
                label: 'ยอดขายวันนี้',
                value: '${(totalCents / 100).toStringAsFixed(2)} บาท',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                icon: Icons.groups,
                label: 'คนที่เข้าใช้วันนี้',
                value: '${data.entriesToday.where((e) => e.paid).length} คน',
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.cloud_upload,
                label: 'รอซิงก์',
                value: '${data.pending} รายการ',
                highlight: data.pending > 0,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.report_gmailerrorred,
            label: 'เดินผ่านประตูโดยยังไม่ชำระ',
            value: '${data.entriesToday.where((e) => !e.paid).length} คน',
            highlight: data.entriesToday.any((e) => !e.paid),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('สแกนตั๋ว'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScanTicketPage()),
                    );
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('รายงาน / CSV'),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ReportPage())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.phonelink_ring),
              label: const Text('โหมดประตู — สแกนเอง ไม่ต้องมีคนเฝ้า'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GateKioskPage()),
                );
                _load();
              },
            ),
          ),
          const Divider(height: 32),
          Text(
            'รายชื่อที่เข้าใช้วันนี้',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (data.entriesToday.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'ยังไม่มีผู้เข้าใช้',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          for (final entry in data.entriesToday)
            ListTile(
              dense: true,
              leading: Icon(
                entry.paid ? Icons.person : Icons.person_off,
                color: entry.paid ? AppColors.orange : AppColors.danger,
              ),
              title: Text('${entry.studentId} — ${entry.studentName}'),
              subtitle: Text(
                entry.paid
                    ? 'รหัสตั๋ว ${entry.code}'
                    : 'รหัสตั๋ว ${entry.code} · เดินผ่านโดยยังไม่ชำระ',
              ),
              trailing: Text(time.format(entry.time)),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.danger : AppColors.orange;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: highlight ? AppColors.danger : AppColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
