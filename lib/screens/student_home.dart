import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/ticket.dart';
import '../services/ticket_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widget/payment_badge.dart';
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
      final account = context.read<AppState>().account;
      if (account == null) return; // ออกจากระบบแล้ว — หน้านี้กำลังถูกแทนที่
      final read = await TicketService.activeOf(account.login);
      if (!mounted) return;
      setState(() {
        _ticket = read.ticket;
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
    unawaited(
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AppState>().account;
    if (account == null) {
      // ออกจากระบบแล้ว (บัญชีถูกล้างก่อนเปลี่ยนหน้า) — ห้ามแตะ account! ตรงนี้
      return const Scaffold(body: SizedBox.shrink());
    }

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
            // แถวผู้ใช้ — ไม่ต้องมีการ์ด ให้เบาลง
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        account.login,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ตั๋ว $kFacilityName ราคา ${(kTicketPriceCents / 100).toStringAsFixed(0)} บาท ใช้ได้ถึง 20:00 น.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        icon: const Icon(Icons.confirmation_number),
                        label: Text(
                          'ซื้อตั๋ว ${(kTicketPriceCents / 100).toStringAsFixed(0)} บาท',
                        ),
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
                      '${(kTicketPriceCents / 100).toStringAsFixed(0)} บาท · ใช้ได้ถึง 20:00 น.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // จุดเด่นหนึ่งเดียวของแอป: สถานะการชำระ
        PaymentStatusBand(
          paid: ticket.isPaid,
          detail: ticket.isPaid
              ? 'ใช้ได้ถึง ${format.format(ticket.expiryTime)}'
              : 'ยังไม่ยืนยัน — แนบสลิปการโอนเพื่อใช้งานตั๋วนี้',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        kFacilityName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${ticket.priceBaht.toStringAsFixed(0)} บาท',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ticket.code,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ใช้ได้ถึง ${format.format(ticket.expiryTime)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('เปิดตั๋วโชว์เจ้าหน้าที่'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TicketPage(ticket: ticket),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
