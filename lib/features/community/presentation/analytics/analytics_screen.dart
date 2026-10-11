import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../payouts/payouts_screen.dart';
import '../providers/profile_provider.dart';
import '../providers/dashboard_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _months = 6;
  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(communityEventEarningsProvider);
    final profile = ref.watch(communityProfileProvider);
    final proposals = ref.watch(dashboardProposalsProvider);
    return Scaffold(appBar: AppBar(title: const Text('Insights')), body: RefreshIndicator(onRefresh: () async {
      ref.invalidate(communityEventEarningsProvider); ref.invalidate(communityProfileProvider);
      ref.invalidate(dashboardProposalsProvider); await ref.read(communityEventEarningsProvider.future);
    }, child: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownMenu<int>(initialSelection: _months, label: const Text('Period'),
        dropdownMenuEntries: [3, 6, 12].map((months) => DropdownMenuEntry(value: months, label: 'Last $months months')).toList(),
        onSelected: (value) => setState(() => _months = value ?? 6)),
      ListTile(title: const Text('Community size'), trailing: Text((profile.asData?.value['size'] ?? 'Not available').toString())),
      ListTile(title: const Text('Proposals'), trailing: Text(proposals.asData?.value.length.toString() ?? 'Not available')),
      if (profile.hasError || proposals.hasError) const ListTile(title: Text('Some community metrics could not be loaded')),
      ...earnings.when<List<Widget>>(loading: () => [const Center(child: CircularProgressIndicator())],
        error: (error, stack) => [ListTile(title: const Text('Could not load event earnings'), trailing: TextButton(
          onPressed: () => ref.invalidate(communityEventEarningsProvider), child: const Text('Retry')))],
        data: (rows) {
          final now = DateTime.now();
          final cutoff = DateTime(now.year, now.month - _months + 1);
          final selected = rows.where((row) {
            final date = DateTime.tryParse((row['completedAt'] ?? (row['event'] is Map ? row['event']['eventDate'] : null) ?? '').toString());
            return date != null && !date.isBefore(cutoff) && !date.isAfter(now);
          }).toList();
          final monthly = <String, num>{};
          num total = 0;
          for (final row in selected.where((row) => row['status'] == 'COMPLETED')) {
            final date = DateTime.parse((row['completedAt'] ?? row['event']['eventDate']).toString());
            final amount = num.tryParse(row['netPayoutAmount']?.toString() ?? '') ?? 0;
            final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            monthly[key] = (monthly[key] ?? 0) + amount; total += amount;
          }
          final keys = monthly.keys.toList()..sort();
          return [
            ListTile(title: const Text('Paid event revenue'), trailing: Text(communityMoney(total))),
            ListTile(title: const Text('Event payout records'), trailing: Text(selected.length.toString())),
            const Divider(),
            const ListTile(title: Text('Monthly paid revenue')),
            if (keys.isEmpty) const ListTile(title: Text('No paid event revenue in this period')),
            for (final key in keys) ListTile(title: Text(key), trailing: Text(communityMoney(monthly[key]))),
            const Divider(),
            for (final row in selected) ListTile(title: Text((row['event'] is Map ? row['event']['title'] : 'Event').toString()),
              subtitle: Text((row['status'] ?? '').toString()), trailing: Text(communityMoney(row['netPayoutAmount']))),
          ];
        }),
    ])));
  }
}