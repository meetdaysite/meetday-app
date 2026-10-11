import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_client.dart';

final staffScannerSessionsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final data = await ref.watch(apiClientProvider).getRequest('/events/${Uri.encodeComponent(eventId)}/scanner-sessions');
  if (data is! List) throw const FormatException('Invalid scanner sessions response.');
  return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
});

class StaffScannerScreen extends ConsumerStatefulWidget {
  const StaffScannerScreen({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<StaffScannerScreen> createState() => _StaffScannerScreenState();
}

class _StaffScannerScreenState extends ConsumerState<StaffScannerScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _label = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _invite() async {
    if (_name.text.trim().isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = 'Enter staff name and a valid email.'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(apiClientProvider).postRequest('/events/${widget.eventId}/scanner-sessions', {
        'name': _name.text.trim(), 'email': _email.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_label.text.trim().isNotEmpty) 'label': _label.text.trim(),
      });
      ref.invalidate(staffScannerSessionsProvider(widget.eventId));
      _name.clear(); _email.clear(); _phone.clear(); _label.clear();
    } catch (_) { if (mounted) setState(() => _error = 'Could not invite scanner staff.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _revoke(String id) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Revoke scanner access?'), actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiClientProvider).dio.patch<dynamic>('/events/${widget.eventId}/scanner-sessions/$id/deactivate');
      ref.invalidate(staffScannerSessionsProvider(widget.eventId));
    } catch (_) { if (mounted) setState(() => _error = 'Could not revoke scanner access.'); }
  }

  @override
  void dispose() { _name.dispose(); _email.dispose(); _phone.dispose(); _label.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(staffScannerSessionsProvider(widget.eventId));
    return Scaffold(appBar: AppBar(title: const Text('Staff scanners')), body: ListView(padding: const EdgeInsets.all(16), children: [
      if (_error != null) Text(_error!),
      for (final entry in {_name: 'Staff name', _email: 'Staff email', _phone: 'Phone (optional)', _label: 'Gate label (optional)'}.entries)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: entry.key,
          enabled: !_busy, decoration: InputDecoration(labelText: entry.value))),
      ElevatedButton.icon(onPressed: _busy ? null : _invite, icon: const Icon(Icons.person_add_alt_rounded), label: const Text('Invite scanner staff')),
      ...sessions.when<List<Widget>>(
        loading: () => [const Center(child: CircularProgressIndicator())],
        error: (error, stack) => [ListTile(title: const Text('Could not load scanners'), trailing: TextButton(
          onPressed: () => ref.invalidate(staffScannerSessionsProvider(widget.eventId)), child: const Text('Retry')))],
        data: (rows) => [if (rows.isEmpty) const ListTile(title: Text('No scanner staff yet')),
          for (final row in rows) ListTile(title: Text((row['staffName'] ?? '').toString()),
            subtitle: Text('${row['staffEmail'] ?? ''}\nCheck-ins: ${row['checkInCount'] ?? 0}'), isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Open scanner', icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: row['isActive'] != true ? null : () async {
                  final uri = Uri.tryParse((row['scannerUrl'] ?? '').toString());
                  if (uri == null || uri.scheme != 'https') return;
                  try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
                  catch (_) { if (mounted) setState(() => _error = 'Could not open scanner.'); }
                }),
              IconButton(tooltip: 'Revoke scanner', icon: const Icon(Icons.block_rounded),
                onPressed: row['isActive'] != true ? null : () => _revoke(row['id'].toString())),
            ])),
        ],
      ),
    ]));
  }
}

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  List<String> scannedCodes = [];

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Check-In'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF101828),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        if (!scannedCodes.contains(barcode.rawValue)) {
                          setState(() => scannedCodes.add(barcode.rawValue!));
                          _showCheckInDialog(barcode.rawValue!);
                        }
                      }
                    }
                  },
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Point camera at QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF7F7F6),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanned (${scannedCodes.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: scannedCodes.isEmpty
                        ? Center(
                            child: Text(
                              'No codes scanned yet',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: scannedCodes.length,
                            itemBuilder: (context, index) => Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Color(0xFF12B76A),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Attendee ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => scannedCodes.removeAt(index));
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      color: Color(0xFFE5484D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Submit check-ins
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${scannedCodes.length} attendees checked in!')),
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEE2C2C),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckInDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check-In Successful'),
        content: const Text('Attendee has been checked in!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
