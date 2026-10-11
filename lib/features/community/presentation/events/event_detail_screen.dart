import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../attendees/attendees_screen.dart';
import '../attendees/qr_scanner_screen.dart';
import '../providers/events_provider.dart';
import 'create_event_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _busy = false;

  Future<void> _action(bool delete) async {
    if (_busy) return;
    if (delete) {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Delete event?'), content: const Text('This cannot be undone.'), actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ));
      if (confirm != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      if (delete) await api.dio.delete<dynamic>('/events/${widget.eventId}');
      else await api.dio.patch<dynamic>('/events/${widget.eventId}/submit');
      ref.invalidate(communityOwnedEventsProvider);
      ref.invalidate(communityOwnedEventProvider(widget.eventId));
      if (delete && mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(delete ? 'Could not delete event.' : 'Could not submit event. Complete required fields first.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(communityOwnedEventProvider(widget.eventId));
    return Scaffold(appBar: AppBar(title: const Text('Event details')), body: event.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Could not load event'), TextButton(onPressed: () => ref.invalidate(communityOwnedEventProvider(widget.eventId)), child: const Text('Retry')),
      ])),
      data: (data) {
        final status = (data['status'] ?? 'DRAFT').toString();
        final media = (data['media'] as List? ?? const []).whereType<Map>().toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text((data['title'] ?? 'Untitled event').toString(), style: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w800)),
          Text((data['displayStatus'] ?? status).toString()),
          if (data['adminRejectionRemark'] != null) Text(data['adminRejectionRemark'].toString()),
          if (data['pendingRevision'] != null) const ListTile(leading: Icon(Icons.pending_actions_rounded), title: Text('Content revision awaiting review')),
          for (final item in media)
            if (item['url'] != null && item['type'] != 'VIDEO') Padding(padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.network(item['url'].toString(), height: 220, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))),
          for (final entry in const {'description': 'Description', 'eventDate': 'Start date', 'endDate': 'End date',
            'startTime': 'Start time', 'endTime': 'End time', 'venueName': 'Venue', 'fullAddress': 'Address', 'city': 'City',
            'eventType': 'Type', 'languages': 'Languages', 'whatToExpect': 'What to expect', 'whoShouldAttend': 'Who should attend',
            'ageRestriction': 'Age restriction', 'specialInstructions': 'Special instructions'}.entries)
            if (data[entry.key] != null) ListTile(contentPadding: EdgeInsets.zero, title: Text(entry.value),
              subtitle: Text(data[entry.key] is List ? (data[entry.key] as List).join(', ') : data[entry.key].toString())),
          for (final ticket in (data['tickets'] as List? ?? const []).whereType<Map>())
            ListTile(title: Text((ticket['name'] ?? 'Ticket').toString()),
              subtitle: Text('Capacity: ${ticket['totalCapacity']}'), trailing: Text('INR ${ticket['price'] ?? 0}')),
          if (['DRAFT', 'REJECTED', 'PUBLISHED'].contains(status)) OutlinedButton.icon(
            onPressed: _busy ? null : () async {
              await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => CreateEventScreen(initialEvent: data)));
              if (mounted) ref.invalidate(communityOwnedEventProvider(widget.eventId));
            }, icon: const Icon(Icons.edit_outlined), label: const Text('Edit event')),
          if (status == 'DRAFT') ElevatedButton.icon(onPressed: _busy ? null : () => _action(false),
            icon: const Icon(Icons.send_rounded), label: const Text('Submit for review')),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
            builder: (_) => AttendeesScreen(eventId: widget.eventId))), icon: const Icon(Icons.people_outline_rounded), label: const Text('Attendees')),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
            builder: (_) => StaffScannerScreen(eventId: widget.eventId))), icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Staff scanners')),
          if (['DRAFT', 'REJECTED'].contains(status)) TextButton.icon(onPressed: _busy ? null : () => _action(true),
            icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete event')),
          if (_busy) const LinearProgressIndicator(),
        ]);
      },
    ));
  }
}