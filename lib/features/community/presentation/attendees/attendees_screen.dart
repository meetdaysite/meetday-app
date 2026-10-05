import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendeesScreen extends ConsumerStatefulWidget {
  const AttendeesScreen({super.key});

  @override
  ConsumerState<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends ConsumerState<AttendeesScreen> {
  final searchController = TextEditingController();
  String selectedEvent = 'All Events';
  String selectedStatus = 'All';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendees = [
      {'name': 'Aman Singh', 'email': 'aman@example.com', 'status': 'checked', 'date': '12 Oct'},
      {'name': 'Priya Sharma', 'email': 'priya@example.com', 'status': 'checked', 'date': '12 Oct'},
      {'name': 'Rajesh Kumar', 'email': 'rajesh@example.com', 'status': 'unchecked', 'date': '13 Oct'},
      {'name': 'Neha Patel', 'email': 'neha@example.com', 'status': 'checked', 'date': '12 Oct'},
      {'name': 'Vikram Desai', 'email': 'vikram@example.com', 'status': 'unchecked', 'date': '14 Oct'},
    ];

    final filtered = attendees
        .where((a) => selectedStatus == 'All' || a['status'] == (selectedStatus == 'Checked' ? 'checked' : 'unchecked'))
        .where((a) => a['name']!.toLowerCase().contains(searchController.text.toLowerCase()))
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
                  'Attendees',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage and check-in attendees',
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
                // TODO: Navigate to QR scanner
              },
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Scan QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEE2C2C),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Search
        TextField(
          controller: searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search attendees...',
            prefixIcon: const Icon(Icons.search),
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              DropdownButton<String>(
                value: selectedEvent,
                items: ['All Events', 'Block Party', 'Creator Night', 'Pop-Up']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => selectedEvent = v!),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: selectedStatus,
                items: ['All', 'Checked', 'Unchecked']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => selectedStatus = v!),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Export list
                },
                icon: const Icon(Icons.download),
                label: const Text('Export'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stats
        Row(
          children: [
            Expanded(
              child: _StatBox(label: 'Total', value: '${filtered.length}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: 'Checked In',
                value: '${filtered.where((a) => a['status'] == 'checked').length}',
                color: const Color(0xFF12B76A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: 'Pending',
                value: '${filtered.where((a) => a['status'] == 'unchecked').length}',
                color: const Color(0xFFF0A12B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Attendees list
        ...filtered.map((attendee) => _AttendeeCard(attendee: attendee)).toList(),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    this.color = const Color(0xFF2673E8),
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  const _AttendeeCard({required this.attendee});

  final Map<String, dynamic> attendee;

  @override
  Widget build(BuildContext context) {
    final isChecked = attendee['status'] == 'checked';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              (attendee['name'] as String)[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendee['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attendee['email'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFFDCFCE7) : const Color(0xFFFFF2C8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isChecked ? 'Checked' : 'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isChecked ? const Color(0xFF12B76A) : const Color(0xFFF0A12B),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                attendee['date'] as String,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              // TODO: Mark check-in
            },
            icon: Icon(
              isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isChecked ? const Color(0xFF12B76A) : const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}
