import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';

final communityEarningsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(apiClientProvider).getRequest('/host/earnings');
  if (data is! Map) throw const FormatException('Invalid earnings response.');
  return Map<String, dynamic>.from(data);
});

final communityPayoutsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (int, String)>((ref, query) async {
  final response = await ref.watch(apiClientProvider).dio.get<dynamic>('/host/payouts',
    queryParameters: {'page': query.$1, 'limit': 20, if (query.$2 != 'ALL') 'status': query.$2});
  final raw = response.data;
  final data = raw is Map && raw['data'] is Map ? raw['data'] : raw;
  if (data is! Map) throw const FormatException('Invalid payouts response.');
  return Map<String, dynamic>.from(data);
});

final communityEventEarningsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).getRequest('/host/earnings/events');
  if (data is! List) throw const FormatException('Invalid event earnings response.');
  return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
});

String communityMoney(dynamic value) => 'INR ${(num.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});
  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  int _page = 1;
  String _status = 'ALL';
  Future<void> _detail(String id) async {
    try {
      final data = await ref.read(apiClientProvider).getRequest('/host/payouts/${Uri.encodeComponent(id)}');
      if (!mounted || data is! Map) return;
      await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        builder: (context) => SizedBox(height: MediaQuery.of(context).size.height * .8,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Payout details', style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800)),
            for (final entry in const {'status': 'Status', 'grossRevenue': 'Gross revenue', 'platformFee': 'Platform fee',
              'tdsAmount': 'TDS', 'netPayoutAmount': 'Net payout', 'createdAt': 'Created', 'completedAt': 'Completed'}.entries)
              ListTile(title: Text(entry.value), subtitle: Text((data[entry.key] ?? '').toString())),
            for (final item in (data['lineItems'] as List? ?? const []).whereType<Map>())
              ListTile(title: Text((item['order'] is Map ? item['order']['bookingId'] : item['id'] ?? 'Order').toString()),
                subtitle: Text(communityMoney(item['netAmount'] ?? item['hostGross']))),
            for (final item in (data['history'] as List? ?? const []).whereType<Map>())
              ListTile(title: Text((item['status'] ?? '').toString()), subtitle: Text((item['createdAt'] ?? '').toString())),
          ])));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load payout details.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(communityEarningsProvider);
    final payouts = ref.watch(communityPayoutsProvider((_page, _status)));
    return Scaffold(appBar: AppBar(title: const Text('Revenue & payouts')), body: RefreshIndicator(
      onRefresh: () async { ref.invalidate(communityEarningsProvider); ref.invalidate(communityPayoutsProvider);
        await ref.read(communityPayoutsProvider((_page, _status)).future); },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        ...earnings.when<List<Widget>>(loading: () => [const Center(child: CircularProgressIndicator())],
          error: (error, stack) => [ListTile(title: const Text('Could not load earnings'), trailing: TextButton(
            onPressed: () => ref.invalidate(communityEarningsProvider), child: const Text('Retry')))],
          data: (data) => [for (final entry in const {'totalEarned': 'Paid out', 'totalPending': 'Pending', 'totalTdsDeducted': 'TDS deducted'}.entries)
            ListTile(title: Text(entry.value), trailing: Text(communityMoney(data[entry.key])))]),
        DropdownMenu<String>(initialSelection: 'ALL', label: const Text('Status'), expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: ['ALL', 'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'].map((value) => DropdownMenuEntry(value: value, label: value)).toList(),
          onSelected: (value) => setState(() { _status = value ?? 'ALL'; _page = 1; })),
        ...payouts.when<List<Widget>>(loading: () => [const Center(child: CircularProgressIndicator())],
          error: (error, stack) => [ListTile(title: const Text('Could not load payouts'), trailing: TextButton(
            onPressed: () => ref.invalidate(communityPayoutsProvider((_page, _status))), child: const Text('Retry')))],
          data: (data) {
            final rows = (data['data'] as List? ?? const []).whereType<Map>().toList();
            final total = (data['total'] as num?)?.toInt() ?? rows.length;
            return [if (rows.isEmpty) const ListTile(title: Text('No payouts yet')),
              for (final row in rows) ListTile(title: Text((row['event'] is Map ? row['event']['title'] : 'Payout').toString()),
                subtitle: Text((row['status'] ?? '').toString()), trailing: Text(communityMoney(row['netPayoutAmount'])),
                onTap: () => _detail(row['id'].toString())),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(tooltip: 'Previous page', icon: const Icon(Icons.chevron_left_rounded), onPressed: _page == 1 ? null : () => setState(() => _page--)),
                Text('Page $_page'), IconButton(tooltip: 'Next page', icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _page * 20 >= total ? null : () => setState(() => _page++)),
              ]),
            ];
          }),
      ]),
    ));
  }
}