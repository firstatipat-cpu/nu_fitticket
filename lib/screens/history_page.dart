import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/ticket.dart';
import '../services/ticket_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// ประวัติการซื้อตั๋วของนิสิต
/// เจ้าของ: <67316807>
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Ticket> _tickets = const [];
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
      final tickets = await TicketService.ofStudent(
        context.read<AppState>().account!.login,
      );
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดประวัติไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d/M/yyyy HH:mm');
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติการซื้อตั๋ว')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(format, now)),
    );
  }

  Widget _buildBody(DateFormat format, DateTime now) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_tickets.isEmpty) {
      // ต้องเป็นรายการที่เลื่อนได้ เพื่อให้ pull-to-refresh ทำงาน
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('ยังไม่เคยซื้อตั๋ว')),
        ],
      );
    }

    return ListView.separated(
      itemCount: _tickets.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final expired = ticket.isExpiredAt(now);
        return ListTile(
          leading: Icon(
            expired ? Icons.event_busy : Icons.confirmation_number,
            color: expired ? AppColors.muted : AppColors.orange,
          ),
          title: Text('$kFacilityName · รหัส ${ticket.code}'),
          subtitle: Text(
            'ซื้อเมื่อ ${format.format(ticket.purchasedTime)} · '
            '${ticket.isPaid ? 'ชำระแล้ว' : 'ยังไม่ยืนยันการชำระ'}',
          ),
          trailing: Text(
            '${ticket.priceBaht.toStringAsFixed(0)} ฿',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}
