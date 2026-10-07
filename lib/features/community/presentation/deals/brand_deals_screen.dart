import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../chat/community_chat_hub.dart';
import '../providers/chat_provider.dart';

class BrandDealsScreen extends ConsumerStatefulWidget {
  const BrandDealsScreen({super.key});

  @override
  ConsumerState<BrandDealsScreen> createState() => _BrandDealsScreenState();
}

class _BrandDealsScreenState extends ConsumerState<BrandDealsScreen> {
  late final Razorpay _razorpay;
  bool _isLoading = true;
  bool _isPaying = false;
  int _selectedView = 0;
  String? _activeInterestId;
  List<Map<String, dynamic>> _billingRows = [];
  List<Map<String, dynamic>> _hubDeals = [];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentFailure);
    _load();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    dynamic data = response;
    if (data is Map && data['data'] != null) data = data['data'];
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Map<String, dynamic>? _extractMap(dynamic response) {
    final data = response is Map ? (response['data'] ?? response) : null;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiClientProvider);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) api.setIdToken(token);
      }

      final billingResponse = await api.dio.get<dynamic>('/sponsorships/billing');
      final billing = _extractList(billingResponse.data);

      final spacesResponse = await api.dio.get<dynamic>(
        '/spaces/chats',
        queryParameters: {'role': 'BRAND', 'status': 'ACCEPTED'},
      );
      final spaceThreads = _extractList(spacesResponse.data);
      final hubDealResults = await Future.wait(spaceThreads.map((thread) async {
        final interestId = thread['id']?.toString();
        if (interestId == null || interestId.isEmpty) return null;
        try {
          final response = await api.dio.get<dynamic>('/spaces/chats/$interestId/deal');
          final deal = _extractMap(response.data);
          if (deal == null || (deal['status'] ?? '').toString().toUpperCase() != 'APPROVED') return null;
          return <String, dynamic>{
            ...deal,
            'interestId': interestId,
            'counterpartName': thread['counterpartName'] ?? 'Community Hub',
            'counterpartAvatarUrl': thread['counterpartAvatarUrl'],
            'dealKind': 'HUB',
          };
        } catch (_) {
          return null;
        }
      }));

      if (!mounted) return;
      setState(() {
        _billingRows = billing;
        _hubDeals = hubDealResults.whereType<Map<String, dynamic>>().toList();
      });
    } catch (error) {
      if (mounted) {
        if (error is DioException) {
          final path = error.requestOptions.uri.path;
          final status = error.response?.statusCode;
          _showMessage(
            'Could not load $path${status == null ? '' : ' (HTTP $status)'}. Please refresh or sign in again.',
            isError: true,
          );
        } else {
          _showMessage('Could not load brand deals: $error', isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startPayment(Map<String, dynamic> row) async {
    final interestId = row['sponsorshipInterestId']?.toString();
    if (interestId == null || interestId.isEmpty || _isPaying) return;

    setState(() {
      _isPaying = true;
      _activeInterestId = interestId;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.post<dynamic>(
        '/sponsorships/chats/$interestId/deal/payment/initiate',
      );
      final order = _extractMap(response.data);
      if (order == null || order['keyId'] == null || order['razorpayOrderId'] == null) {
        throw const FormatException('Payment order response was incomplete.');
      }
      _razorpay.open({
        'key': order['keyId'],
        'amount': order['amount'],
        'currency': order['currency'] ?? 'INR',
        'order_id': order['razorpayOrderId'],
        'name': 'Meetday',
        'description': 'Deal payment · ${(row['projectName'] ?? 'Brand deal')}',
        'theme': {'color': '#EE2C2C'},
      });
    } catch (error) {
      _showMessage('Could not start payment: $error', isError: true);
      setState(() => _isPaying = false);
      _activeInterestId = null;
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final interestId = _activeInterestId;
    if (interestId == null || response.orderId == null || response.paymentId == null || response.signature == null) {
      if (mounted) _showMessage('Payment confirmation was incomplete.', isError: true);
      return;
    }
    try {
      await ref.read(apiClientProvider).dio.post<dynamic>(
        '/sponsorships/chats/$interestId/deal/payment/verify',
        data: {
          'razorpayOrderId': response.orderId,
          'razorpayPaymentId': response.paymentId,
          'razorpaySignature': response.signature,
        },
      );
      if (mounted) _showMessage('Payment verified successfully.');
      await _load();
    } catch (error) {
      if (mounted) _showMessage('Payment verification failed: $error', isError: true);
    } finally {
      _activeInterestId = null;
      if (mounted) setState(() => _isPaying = false);
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    _activeInterestId = null;
    if (!mounted) return;
    setState(() => _isPaying = false);
    _showMessage(response.message ?? 'Payment failed. Please try again.', isError: true);
  }

  Future<void> _showInvoice(Map<String, dynamic> row) async {
    final interestId = row['sponsorshipInterestId']?.toString();
    if (interestId == null || interestId.isEmpty) return;
    try {
      final response = await ref.read(apiClientProvider).dio.get<dynamic>(
        '/sponsorships/chats/$interestId/deal/invoice',
      );
      final data = _extractMap(response.data);
      final url = data?['url']?.toString();
      if (url == null || url.isEmpty) throw const FormatException('Invoice link was empty.');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text((row['projectName'] ?? 'Deal Invoice').toString()),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: SfPdfViewer.network(url),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not open invoice: $error', isError: true);
    }
  }

  void _showBreakdown(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Colors.black, width: 2),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Breakdown', style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _breakdownLine('Deal amount', row['sponsorshipAmount']),
            _breakdownLine('Platform fee', row['platformFeeAmount']),
            _breakdownLine('Transaction fee', row['transactionFeeAmount']),
            _breakdownLine('Tax', row['taxAmount']),
            const Divider(height: 22, thickness: 1.5),
            _breakdownLine('Total', row['totalAmount'] ?? row['sponsorshipAmount'], bold: true),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _breakdownLine(String label, dynamic value, {bool bold = false}) {
    final amount = value == null ? '—' : '₹${_formatAmount(value)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
          Text(amount, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    final number = num.tryParse(amount?.toString() ?? '');
    if (number == null) return '0';
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? MeetdayColors.primaryRed : const Color(0xFF10B981),
      ));
  }

  Widget _dealCard(Map<String, dynamic> row, {bool hub = false}) {
    final name = (row['counterpartName'] ?? row['communityName'] ?? row['brandName'] ?? 'Partner').toString();
    final project = (row['projectName'] ?? row['proposalName'] ?? 'Locked deal').toString();
    final amount = row['totalAmount'] ?? row['sponsorshipAmount'] ?? row['amount'];
    final paid = (row['paymentStatus'] ?? '').toString().toUpperCase() == 'PAID' || row['paid'] == true;
    final interestId = row['sponsorshipInterestId']?.toString() ?? row['interestId']?.toString() ?? '';

    final campaign = !hub &&
        (row['isCampaign'] == true || row['campaignId'] != null);

    return GestureDetector(
      onTap: interestId.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatThreadScreen(
                    thread: UnifiedActiveThread(
                      id: interestId,
                      category: hub
                          ? 'spaces'
                          : (campaign ? 'campaigns' : 'sponsorships'),
                      kind: hub
                          ? 'SPACE_INTEREST'
                          : (campaign ? 'CAMPAIGN' : 'SPONSORSHIP'),
                      counterpartName: name,
                      counterpartAvatarUrl: row['counterpartAvatarUrl']?.toString() ??
                          row['communityLogo']?.toString(),
                      counterpartType: hub ? 'SPACE' : 'COMMUNITY',
                      title: project,
                      rawThread: row,
                    ),
                  ),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hub ? MeetdayColors.accentYellow : (paid ? const Color(0xFFDCFCE7) : const Color(0xFFFFF3CD)),
                  border: Border.all(color: Colors.black, width: 1.3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(hub ? 'HUB' : (paid ? 'PAID' : 'PAYMENT DUE'), style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(project, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('₹${_formatAmount(amount)}', style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w900))),
              TextButton(onPressed: () => _showBreakdown(row), child: const Text('Breakdown')),
              if (!hub && !paid && interestId.isNotEmpty)
                ElevatedButton(
                  onPressed: _isPaying ? null : () => _startPayment(row),
                  style: ElevatedButton.styleFrom(backgroundColor: MeetdayColors.primaryRed, foregroundColor: Colors.white),
                  child: Text(_isPaying && _activeInterestId == interestId ? 'Opening…' : 'Pay'),
                ),
              if (!hub && paid && interestId.isNotEmpty)
                IconButton(tooltip: 'View invoice', onPressed: () => _showInvoice(row), icon: const Icon(Icons.receipt_long_rounded)),
            ],
          ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRows = _selectedView == 0
        ? [..._billingRows, ..._hubDeals]
        : _billingRows;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: MeetdayColors.primaryRed,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Text('Deals & Billing', style: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Locked sponsorships, campaigns, hub deals, and payments.', style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Locked deals'), icon: Icon(Icons.lock_outline_rounded)),
                  ButtonSegment(value: 1, label: Text('Billing'), icon: Icon(Icons.receipt_long_rounded)),
                ],
                selected: {_selectedView},
                onSelectionChanged: (selection) => setState(() => _selectedView = selection.first),
              ),
              const SizedBox(height: 14),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
              else if (activeRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Text(
                    _selectedView == 0 ? 'No locked deals yet.' : 'No billing records yet.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                )
              else
                ...activeRows.map((row) => _dealCard(row, hub: row['dealKind'] == 'HUB')),
            ],
          ),
        ),
      ),
    );
  }
}
