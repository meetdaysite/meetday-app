import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'create_event_screen.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  String selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final events = [
      {
        'id': '1',
        'title': 'The Block Party',
        'date': '12-14 Oct',
        'location': 'Marine Drive, Mumbai',
        'guests': '1200',
        'registered': '1000',
        'status': 'published',
        'description': 'A weekend music and food festival for creators',
      },
      {
        'id': '2',
        'title': 'Creator Night',
        'date': '24 Oct',
        'location': 'Arena Hall, Bengaluru',
        'guests': '650',
        'registered': '580',
        'status': 'published',
        'description': 'An intimate creator-led networking night',
      },
      {
        'id': '3',
        'title': 'Weekend Pop-Up',
        'date': '9 Nov',
        'location': 'Skyline Courtyard, Hyderabad',
        'guests': '850',
        'registered': '720',
        'status': 'draft',
        'description': 'A premium community pop-up',
      },
    ];

    final filtered = events
        .where((e) => selectedStatus == 'All' || e['status'] == selectedStatus.toLowerCase())
        .toList();


        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Events',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage and create community events',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateEventScreen()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEE2C2C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: selectedStatus == 'All',
                    onTap: () => setState(() => selectedStatus = 'All'),
                  ),
                  _FilterChip(
                    label: 'Published',
                    selected: selectedStatus == 'Published',
                    onTap: () => setState(() => selectedStatus = 'Published'),
                  ),
                  _FilterChip(
                    label: 'Draft',
                    selected: selectedStatus == 'Draft',
                    onTap: () => setState(() => selectedStatus = 'Draft'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...filtered.map((event) => _EventCard(event: event)).toList(),
            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No events found',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
          ],
        );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEE2C2C) : Colors.white,
            border: Border.all(
              color: selected ? const Color(0xFFEE2C2C) : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final isPublished = event['status'] == 'published';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event['location'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPublished
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFF2C8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPublished ? 'Published' : 'Draft',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isPublished
                        ? const Color(0xFF12B76A)
                        : const Color(0xFFF0A12B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event['description'] as String,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5565),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF667085)),
                  const SizedBox(width: 4),
                  Text(
                    event['date'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.people, size: 14, color: Color(0xFF667085)),
                  const SizedBox(width: 4),
                  Text(
                    '${event['registered']}/${event['guests']} guests',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
