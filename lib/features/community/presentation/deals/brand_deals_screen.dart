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

/// Locked Deals and Billing screen for Brands.
/// Replicates the live website `/brand/dashboard/deals` and `/brand/dashboard/billing`.
class BrandDealsScreen extends ConsumerStatefulWidget {
  const BrandDealsScreen({super.key});

  @override
  ConsumerState<BrandDealsScreen> createState() => _BrandDealsScreenState();
}

class _BrandDealsScreenState extends ConsumerState<BrandDealsScreen> {
  late final Razorpay _razorpay;
  bool _isLoading = true;
  bool _isPaying = false;
  int _selectedView = 0; // 0: Locked Deals, 1: Billing
  String? _activeInterestId;

  List<Map<String, dynamic>> _lockedDeals = [];
  List<Map<String, dynamic>> _billingRows = [];

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

      // 1. Fetch live billing rows from /sponsorships/billing
      final billingResponse = await api.dio.get<dynamic>('/sponsorships/billing');
      final rawBilling = _extractList(billingResponse.data);

      // 2. Fetch accepted sponsorship & campaign chats for brand
      final sponsorshipChatsResponse = await api.dio.get<dynamic>(
        '/sponsorships/chats',
        queryParameters: {'role': 'BRAND', 'status': 'ACCEPTED'},
      ).catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final sponsorshipThreads = _extractList(sponsorshipChatsResponse.data);

      // Enrich billing rows with thread metadata (logos, campaign flags)
      final enrichedBilling = rawBilling.map((b) {
        final chat = sponsorshipThreads.firstWhere(
          (c) => c['id']?.toString() == b['sponsorshipInterestId']?.toString(),
          orElse: () => <String, dynamic>{},
        );
        final isCampaign = b['isCampaign'] == true ||
            b['campaignId'] != null ||
            chat['campaignId'] != null;
        return <String, dynamic>{
          ...b,
          'isCampaign': isCampaign,
          'communityLogo': chat['counterpartAvatarUrl'] ?? b['communityLogo'],
        };
      }).toList();

      // 3. Fetch locked deals from sponsorship threads (status == APPROVED)
      final sponsorshipDealResults = await Future.wait(sponsorshipThreads.map((thread) async {
        final threadId = thread['id']?.toString();
        if (threadId == null || threadId.isEmpty) return null;
        try {
          final res = await api.dio.get<dynamic>('/sponsorships/chats/$threadId/deal');
          final deal = _extractMap(res.data);
          if (deal == null || (deal['status'] ?? '').toString().toUpperCase() != 'APPROVED') {
            return null;
          }
          bool hasReport = false;
          try {
            final repRes = await api.dio.get<dynamic>('/sponsorships/chats/$threadId/deal/report');
            if (_extractMap(repRes.data) != null) hasReport = true;
          } catch (_) {}

          final isCampaign = thread['campaignId'] != null;
          return <String, dynamic>{
            ...deal,
            'proposalName': thread['proposalName'] ?? (isCampaign ? 'Campaign Deal' : 'Untitled Project'),
            'communityName': thread['counterpartName'] ?? 'Community',
            'communityLogo': thread['counterpartAvatarUrl'],
            'sponsorshipInterestId': threadId,
            'hasReport': hasReport,
            'isCampaign': isCampaign,
            'campaignId': thread['campaignId'],
            'proposalId': thread['proposalId'] ?? thread['sponsorshipProposalId'],
            'dealKind': 'SPONSORSHIP',
          };
        } catch (_) {
          return null;
        }
      }));

      // 4. Fetch space chats & deals
      final spacesResponse = await api.dio.get<dynamic>(
        '/spaces/chats',
        queryParameters: {'role': 'BRAND', 'status': 'ACCEPTED'},
      ).catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: []));
      final spaceThreads = _extractList(spacesResponse.data);

      final hubDealResults = await Future.wait(spaceThreads.map((thread) async {
        final threadId = thread['id']?.toString();
        if (threadId == null || threadId.isEmpty) return null;
        try {
          final response = await api.dio.get<dynamic>('/spaces/chats/$threadId/deal');
          final deal = _extractMap(response.data);
          if (deal == null || (deal['status'] ?? '').toString().toUpperCase() != 'APPROVED') {
            return null;
          }
          bool hasReport = false;
          try {
            final repRes = await api.dio.get<dynamic>('/spaces/chats/$threadId/deal/report');
            if (_extractMap(repRes.data) != null) hasReport = true;
          } catch (_) {}

          return <String, dynamic>{
            ...deal,
            'interestId': threadId,
            'counterpartName': thread['counterpartName'] ?? 'Community Hub',
            'counterpartAvatarUrl': thread['counterpartAvatarUrl'],
            'dealKind': 'HUB',
            'hasReport': hasReport,
          };
        } catch (_) {
          return null;
        }
      }));

      final combinedLockedDeals = [
        ...sponsorshipDealResults.whereType<Map<String, dynamic>>(),
        ...hubDealResults.whereType<Map<String, dynamic>>(),
      ];

      // If deals endpoint returned items, also add any from billing that are not in locked deals
      for (final b in enrichedBilling) {
        final id = b['sponsorshipInterestId']?.toString();
        if (id != null && !combinedLockedDeals.any((d) => (d['sponsorshipInterestId'] ?? d['interestId'])?.toString() == id)) {
          combinedLockedDeals.add({
            ...b,
            'dealKind': 'SPONSORSHIP',
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _billingRows = enrichedBilling;
        _lockedDeals = combinedLockedDeals;
      });
    } catch (error) {
      if (mounted) {
        _showMessage('Could not load brand deals: $error', isError: true);
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
      if (mounted) _showMessage('Payment verified successfully!');
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
              backgroundColor: MeetdayColors.primaryRed,
              title: Text(
                (row['projectName'] ?? 'Deal Invoice').toString(),
                style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, color: Colors.white),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Breakdown',
                  style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _breakdownLine('Deal Amount', row['sponsorshipAmount']),
            if (row['platformFeeAmount'] != null)
              _breakdownLine('Platform Fee', row['platformFeeAmount']),
            if (row['transactionFeeAmount'] != null)
              _breakdownLine('Transaction Fee (3%)', row['transactionFeeAmount']),
            if (row['taxAmount'] != null)
              _breakdownLine('Tax (GST)', row['taxAmount']),
            const Divider(height: 24, thickness: 1.5, color: Colors.black12),
            _breakdownLine('Total Amount', row['totalAmount'] ?? row['sponsorshipAmount'], bold: true),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  void _showDealTermsModal(Map<String, dynamic> deal) {
    final deliverables = (deal['deliverables'] is List)
        ? (deal['deliverables'] as List).map((d) => d.toString()).toList()
        : <String>[];
    final terms = deal['terms'] ?? deal['paymentTerms'] ?? deal['description'] ?? 'Standard Meetday locked deal terms.';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Locked Deal Terms',
                  style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              (deal['projectName'] ?? deal['proposalName'] ?? 'Sponsorship Deal').toString(),
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text('Deliverables', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 6),
            if (deliverables.isNotEmpty)
              ...deliverables.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Expanded(child: Text(d, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87))),
                      ],
                    ),
                  ))
            else
              Text('Deliverables as agreed in the chat thread.', style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54)),
            const SizedBox(height: 12),
            Text('Terms & Notes', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 4),
            Text(terms.toString(), style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeetdayColors.accentYellow,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close Terms', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
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
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
              color: bold ? Colors.black : Colors.black87,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: Colors.black,
            ),
          ),
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
        content: Text(message, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? MeetdayColors.primaryRed : const Color(0xFF10B981),
      ));
  }

  Widget _dealCard(Map<String, dynamic> row, {bool hub = false}) {
    final name = (row['counterpartName'] ?? row['communityName'] ?? row['brandName'] ?? 'Partner').toString();
    final project = (row['projectName'] ?? row['proposalName'] ?? 'Locked deal').toString();
    final amount = row['totalAmount'] ?? row['sponsorshipAmount'] ?? row['amount'];
    final paid = (row['paymentStatus'] ?? '').toString().toUpperCase() == 'PAID' || row['paid'] == true;
    final interestId = row['sponsorshipInterestId']?.toString() ?? row['interestId']?.toString() ?? '';
    final hasReport = row['hasReport'] == true;
    final isCampaign = !hub && (row['isCampaign'] == true || row['campaignId'] != null);

    return GestureDetector(
      onTap: interestId.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatThreadScreen(
                    thread: UnifiedActiveThread(
                      id: interestId,
                      category: hub ? 'spaces' : (isCampaign ? 'campaigns' : 'sponsorships'),
                      kind: hub ? 'SPACE_INTEREST' : (isCampaign ? 'CAMPAIGN' : 'SPONSORSHIP'),
                      counterpartName: name,
                      counterpartAvatarUrl: row['counterpartAvatarUrl']?.toString() ?? row['communityLogo']?.toString(),
                      counterpartType: hub ? 'SPACE' : 'COMMUNITY',
                      title: project,
                      rawThread: row,
                    ),
                  ),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Type Tag + Status Badge
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: row['counterpartAvatarUrl'] != null || row['communityLogo'] != null
                      ? Image.network(
                          (row['counterpartAvatarUrl'] ?? row['communityLogo']).toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900)),
                          ),
                        )
                      : Center(
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P',
                              style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900)),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.bricolageGrotesque(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                      Text(
                        hub ? 'COMMUNITY HUB' : (isCampaign ? 'BRAND CAMPAIGN' : 'SPONSORSHIP'),
                        style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black45, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: hub ? MeetdayColors.accentYellow : (paid ? const Color(0xFFDCFCE7) : const Color(0xFFFFF3CD)),
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                    ],
                  ),
                  child: Text(
                    hub ? 'HUB DEAL' : (paid ? 'PAID' : 'PAYMENT DUE'),
                    style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Project / Proposal Name
            Text(
              project,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
            ),
            const SizedBox(height: 12),

            // Bottom Row: Deal Amount & Action Buttons
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amount', style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.black45)),
                      Text(
                        '₹${_formatAmount(amount)}',
                        style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                    ],
                  ),
                ),

                // Button: Terms / Breakdown
                GestureDetector(
                  onTap: () {
                    if (_selectedView == 1) {
                      _showBreakdown(row);
                    } else {
                      _showDealTermsModal(row);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: MeetdayColors.accentYellow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                      ],
                    ),
                    child: Text(
                      _selectedView == 1 ? 'Breakdown' : 'Locked Deal',
                      style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                  ),
                ),

                // Button: Report (if available in Locked Deals)
                if (_selectedView == 0 && hasReport)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                      ],
                    ),
                    child: Text(
                      'Report',
                      style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                  ),

                // Button: Pay (in Billing if unpaid)
                if (_selectedView == 1 && !hub && !paid && interestId.isNotEmpty)
                  GestureDetector(
                    onTap: _isPaying ? null : () => _startPayment(row),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                        ],
                      ),
                      child: Text(
                        _isPaying && _activeInterestId == interestId ? 'Opening…' : 'Pay Now',
                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),

                // Button: Invoice (in Billing if paid)
                if (_selectedView == 1 && !hub && paid && interestId.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showInvoice(row),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                        ],
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRows = _selectedView == 0 ? _lockedDeals : _billingRows;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: MeetdayColors.primaryRed,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              // Header
              Text(
                'Deals & Billing',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track approved sponsorship deals, agreements, and payment records.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 16),

              // Neo-Brutalist Custom Segmented Selector (Replaces Material 3 SegmentedButton)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedView = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedView == 0 ? MeetdayColors.accentYellow : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: _selectedView == 0 ? Border.all(color: Colors.black, width: 1.5) : null,
                            boxShadow: _selectedView == 0
                                ? const [BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_rounded, size: 16, color: Colors.black),
                              const SizedBox(width: 6),
                              Text(
                                'Locked Deals (${_lockedDeals.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: _selectedView == 0 ? FontWeight.w900 : FontWeight.w600,
                                  color: _selectedView == 0 ? Colors.black : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedView = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedView == 1 ? MeetdayColors.accentYellow : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: _selectedView == 1 ? Border.all(color: Colors.black, width: 1.5) : null,
                            boxShadow: _selectedView == 1
                                ? const [BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.black),
                              const SizedBox(width: 6),
                              Text(
                                'Billing (${_billingRows.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: _selectedView == 1 ? FontWeight.w900 : FontWeight.w600,
                                  color: _selectedView == 1 ? Colors.black : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content List
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
                  ),
                )
              else if (activeRows.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedView == 0 ? Icons.lock_open_rounded : Icons.receipt_long_rounded,
                        size: 40,
                        color: Colors.black38,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedView == 0 ? 'No locked deals yet' : 'No billing records yet',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedView == 0
                            ? 'When you and a community reach agreement and approve terms, the locked deal appears here.'
                            : 'Invoices and billing receipts for completed deals will be listed here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    ],
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
