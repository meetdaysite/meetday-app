import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/events_provider.dart';

class AttendeesScreen extends ConsumerStatefulWidget {
  const AttendeesScreen({super.key, this.eventId});
  final String? eventId;
  @override
  ConsumerState<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends ConsumerState<AttendeesScreen> {
  String? _eventId;
  int _eventPage = 1;
  int _page = 1;
  String _search = '';
  String _status = 'ALL';
  bool _exporting = false;
  @override
  void initState() { super.initState(); _eventId = widget.eventId; }

  List<Map> _filtered(List rows) => rows.whereType<Map>().where((row) {
    final checked = row['isCheckedIn'] == true;
    if (_status == 'CHECKED' && !checked || _status == 'PENDING' && checked) return false;
    return '${row['firstName'] ?? ''} ${row['lastName'] ?? ''} ${row['bookingId'] ?? ''} ${row['email'] ?? ''}'
        .toLowerCase().contains(_search);
  }).toList();

  String _csv(dynamic value) {
    final text = (value ?? '').toString();
    final safe = RegExp(r'^[=+@\-\t\r]').hasMatch(text) ? "'$text" : text;
    return '"${safe.replaceAll('"', '""')}"';
  }

  Future<void> _export() async {
    if (_eventId == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = <Map>[];
      int page = 1;
      while (true) {
        final data = await ref.read(communityEventAttendeesProvider((_eventId!, page)).future);
        final batch = data['attendees'] as List? ?? const [];
        rows.addAll(batch.whereType<Map>());
        if (batch.isEmpty || rows.length >= ((data['total'] as num?)?.toInt() ?? rows.length)) break;
        page++;
      }
      final csv = [
        'Name,Booking ID,Ticket,Checked In,Booking Date,Amount Paid',
        ..._filtered(rows).map((row) => [
          '${row['firstName'] ?? ''} ${row['lastName'] ?? ''}'.trim(), row['bookingId'], row['ticketType'],
          row['isCheckedIn'] == true ? 'Yes' : 'No', row['bookingDate'], row['amountPaid'],
        ].map(_csv).join(',')),
      ].join('\r\n');
      await FilePicker.saveFile(fileName: 'attendees-$_eventId.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)), mimeType: 'text/csv');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not export attendees.')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(communityOwnedEventsProvider(_eventPage));
    final attendees = _eventId == null ? null : ref.watch(communityEventAttendeesProvider((_eventId!, _page)));
    return Scaffold(appBar: AppBar(title: const Text('Attendees'), actions: [
      IconButton(tooltip: 'Export attendees', icon: const Icon(Icons.download_rounded), onPressed: _eventId == null || _exporting ? null : _export),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.eventId == null) ...events.when<List<Widget>>(
        loading: () => [const Center(child: CircularProgressIndicator())],
        error: (error, stack) => [ListTile(title: const Text('Could not load events'), trailing: TextButton(
          onPressed: () => ref.invalidate(communityOwnedEventsProvider(_eventPage)), child: const Text('Retry')))],
        data: (data) => [DropdownMenu<String>(label: const Text('Event'), expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: (data['events'] as List? ?? const []).whereType<Map>().map((event) => DropdownMenuEntry(
            value: event['id'].toString(), label: (event['title'] ?? 'Untitled event').toString())).toList(),
          onSelected: (id) => setState(() { _eventId = id; _page = 1; })),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(tooltip: 'Previous events', icon: const Icon(Icons.chevron_left_rounded), onPressed: _eventPage == 1 ? null : () => setState(() => _eventPage--)),
            Text('Events page $_eventPage'),
            IconButton(tooltip: 'Next events', icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _eventPage * 20 >= ((data['total'] as num?)?.toInt() ?? 0) ? null : () => setState(() => _eventPage++)),
          ]),
        ],
      ),
      TextField(decoration: const InputDecoration(hintText: 'Search attendee or booking', prefixIcon: Icon(Icons.search_rounded)),
        onChanged: (value) => setState(() => _search = value.trim().toLowerCase())),
      const SizedBox(height: 12),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'ALL', label: Text('All')),
        ButtonSegment(value: 'CHECKED', label: Text('Checked in')), ButtonSegment(value: 'PENDING', label: Text('Pending'))],
        selected: {_status}, onSelectionChanged: (value) => setState(() => _status = value.single)),
      if (_exporting) const LinearProgressIndicator(),
      if (attendees == null) const ListTile(title: Text('Select an event'))
      else ...attendees.when<List<Widget>>(
        loading: () => [const Center(child: CircularProgressIndicator())],
        error: (error, stack) => [ListTile(title: const Text('Could not load attendees'), trailing: TextButton(
          onPressed: () => ref.invalidate(communityEventAttendeesProvider((_eventId!, _page))), child: const Text('Retry')))],
        data: (data) {
          final rows = _filtered(data['attendees'] as List? ?? const []);
          return [
            Text('Total registrations: ${data['total'] ?? 0}'),
            if (rows.isEmpty) const ListTile(title: Text('No attendees found')),
            for (final row in rows) ListTile(leading: Icon(row['isCheckedIn'] == true ? Icons.how_to_reg_rounded : Icons.person_outline_rounded),
              title: Text('${row['firstName'] ?? ''} ${row['lastName'] ?? ''}'.trim()),
              subtitle: Text('${row['bookingId'] ?? ''}\n${row['ticketType'] ?? ''}'), isThreeLine: true,
              trailing: Text(row['isCheckedIn'] == true ? 'Checked in' : 'Pending')),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Previous attendees', icon: const Icon(Icons.chevron_left_rounded), onPressed: _page == 1 ? null : () => setState(() => _page--)),
              Text('Page $_page'),
              IconButton(tooltip: 'Next attendees', icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _page * 50 >= ((data['total'] as num?)?.toInt() ?? rows.length) ? null : () => setState(() => _page++)),
            ]),
          ];
        },
      ),
    ]));
  }
}