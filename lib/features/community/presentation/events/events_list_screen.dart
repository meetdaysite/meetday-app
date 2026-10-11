import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/events_provider.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  int _page = 1;
  String _search = '';
  String _status = 'ALL';

  Future<void> _create() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const CreateEventScreen()));
    if (mounted) ref.invalidate(communityOwnedEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(communityOwnedEventsProvider(_page));
    return Scaffold(appBar: AppBar(title: const Text('Events'), actions: [
      IconButton(tooltip: 'Create event', onPressed: _create, icon: const Icon(Icons.add_rounded)),
    ]), body: RefreshIndicator(onRefresh: () async {
      ref.invalidate(communityOwnedEventsProvider);
      await ref.read(communityOwnedEventsProvider(_page).future);
    }, child: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(decoration: const InputDecoration(hintText: 'Search events', prefixIcon: Icon(Icons.search_rounded)),
        onChanged: (value) => setState(() => _search = value.trim().toLowerCase())),
      const SizedBox(height: 12),
      DropdownMenu<String>(initialSelection: 'ALL', label: const Text('Status'), expandedInsets: EdgeInsets.zero,
        dropdownMenuEntries: ['ALL', 'DRAFT', 'UNDER_REVIEW', 'PUBLISHED', 'REJECTED', 'COMPLETED']
            .map((status) => DropdownMenuEntry(value: status, label: status)).toList(),
        onSelected: (status) => setState(() => _status = status ?? 'ALL')),
      const SizedBox(height: 16),
      ...events.when<List<Widget>>(
        loading: () => [const Center(child: CircularProgressIndicator())],
        error: (error, stack) => [ListTile(title: const Text('Could not load events'), trailing: TextButton(
          onPressed: () => ref.invalidate(communityOwnedEventsProvider(_page)), child: const Text('Retry')))],
        data: (data) {
          final rows = (data['events'] as List? ?? const []).whereType<Map>().where((event) =>
            (_status == 'ALL' || event['status'] == _status) &&
            (event['title'] ?? '').toString().toLowerCase().contains(_search)).toList();
          final total = (data['total'] as num?)?.toInt() ?? rows.length;
          return [
            if (rows.isEmpty) const ListTile(title: Text('No events found')),
            for (final event in rows) Card(child: ListTile(
              leading: const Icon(Icons.event_rounded),
              title: Text((event['title'] ?? 'Untitled event').toString(), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              subtitle: Text('${event['displayStatus'] ?? event['status']}\n${event['eventDate'] ?? ''} ${event['venueName'] ?? ''}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event['id'].toString())));
                if (mounted) ref.invalidate(communityOwnedEventsProvider);
              },
            )),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Previous page', icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _page == 1 ? null : () => setState(() => _page--)),
              Text('Page $_page'),
              IconButton(tooltip: 'Next page', icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _page * 20 >= total ? null : () => setState(() => _page++)),
            ]),
          ];
        },
      ),
    ])));
  }
}