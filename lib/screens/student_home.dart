import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/ticket.dart';
import '../services/ticket_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'buy_ticket_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import 'ticket_page.dart';

/// หน้าหลักของนิสิต: ตั๋วที่ใช้ได้ + ทางไปซื้อตั๋ว/ดูประวัติ
/// เจ้าของ: <67317088>
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  Ticket? _ticket;
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
      final ticket = await TicketService.activeOf(
        context.read<AppState>().account!.login,
      );
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
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

  Future<void> _buy() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BuyTicketPage()));
    await _load();
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text('ต้องเข้าสู่ระบบใหม่เพื่อซื้อตั๋วอีกครั้ง'),
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
    final account = context.watch<AppState>().account!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NU FitTicket'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout),
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(account.login),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              )
            else if (_ticket == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ยังไม่มีตั๋วที่ใช้ได้',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ตั๋ว $kFacilityName ราคา ${(kTicketPriceCents / 100).toStringAsFixed(0)} บาท ใช้ได้ 1 วัน',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.confirmation_number),
                        label: const Text('ซื้อตั๋ว 10 บาท'),
                        onPressed: _buy,
                      ),
                    ],
                  ),
                ),
              )
            else
              _ActiveTicketCard(ticket: _ticket!),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_shopping_cart),
                    title: const Text('ซื้อตั๋ว NU Fitness'),
                    subtitle: Text(
                      '${(kTicketPriceCents / 100).toStringAsFixed(0)} บาท · ใช้ได้ 1 วัน',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _buy,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('ประวัติการซื้อตั๋ว'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HistoryPage()),
                      );
                      await _load();
                    },
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

class _ActiveTicketCard extends StatelessWidget {
  const _ActiveTicketCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d/M/yyyy HH:mm');
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.orange, AppColors.orangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33F26F21),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.confirmation_number, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'ตั๋วที่ใช้ได้',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            kFacilityName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ใช้ได้ถึง ${format.format(ticket.expiryTime)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                ticket.isPaid ? Icons.verified : Icons.error_outline,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                ticket.isPaid ? 'ชำระแล้ว' : 'ยังไม่ยืนยันการชำระเงิน',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.orangeDark,
            ),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('เปิดตั๋วโชว์เจ้าหน้าที่'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TicketPage(ticket: ticket)),
            ),
          ),
        ],
      ),
    );
  }
}
