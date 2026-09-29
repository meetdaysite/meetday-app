import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/meetday_colors.dart';

// ── Proposal List Item Card ──────────────────────────────────────────────────

class ProposalListItemCard extends StatelessWidget {
  const ProposalListItemCard({
    super.key,
    required this.proposal,
    required this.onTap,
  });

  final Map<String, dynamic> proposal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (proposal['name'] ?? proposal['title'] ?? 'Proposal').toString();
    final imageUrl = proposal['imageUrl'] as String?;
    final dateLabel = (proposal['dateLabel'] ?? '').toString();
    final venue = (proposal['venue'] ?? '').toString();
    final city = (proposal['city'] ?? '').toString();
    final guestCount = (proposal['guestCount'] ?? '').toString();
    final status = (proposal['status'] ?? 'DRAFT').toString();
    final hasCash = proposal['hasCash'] == true;
    final hasBarter = proposal['hasBarter'] == true;

    final locationParts = [venue, city].where((s) => s.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Image (110 width)
              SizedBox(
                width: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          right: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      child: (imageUrl != null && imageUrl.isNotEmpty)
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _fallbackMonogram(name),
                            )
                          : _fallbackMonogram(name),
                    ),
                    // Status Badge over image
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _buildStatusPill(status),
                    ),
                  ],
                ),
              ),

              // Right Info Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: const Color(0xFF111111),
                            ),
                          ),
                          if (locationParts.isNotEmpty || guestCount.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (locationParts.isNotEmpty) locationParts,
                                if (guestCount.isNotEmpty) '$guestCount Guests',
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Badges Row: Date + Cash/Barter
                      Row(
                        children: [
                          if (dateLabel.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C32D1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 1.2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                dateLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                          if (hasCash)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 1.1),
                              ),
                              child: Text(
                                'CASH',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ),
                          if (hasBarter)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MeetdayColors.accentYellow,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 1.1),
                              ),
                              child: Text(
                                'BARTER',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
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
        ),
      ),
    );
  }

  Widget _fallbackMonogram(String name) {
    final initials = name.length > 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFFFFBEB)),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = const Color(0xFFDCFCE7);
    Color fg = Colors.black;
    String label = status;

    if (status == 'PUBLISHED') {
      bg = const Color(0xFF4ADE80);
      label = 'LIVE';
    } else if (status == 'UNDER_REVIEW') {
      bg = const Color(0xFFFFC940);
      label = 'REVIEW';
    } else if (status == 'DRAFT') {
      bg = const Color(0xFFF1F5F9);
      label = 'DRAFT';
    } else if (status == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'REJECTED';
    } else if (status == 'COMPLETED') {
      bg = const Color(0xFF1E293B);
      fg = Colors.white;
      label = 'DONE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.black, width: 1.1),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(1, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

// ── Proposal Detail Dialog ───────────────────────────────────────────────────

class ProposalDetailDialog extends StatelessWidget {
  const ProposalDetailDialog({
    super.key,
    required this.proposal,
    this.onSubmitApproval,
  });

  final Map<String, dynamic> proposal;
  final VoidCallback? onSubmitApproval;

  @override
  Widget build(BuildContext context) {
    final name = (proposal['name'] ?? proposal['title'] ?? 'Proposal').toString();
    final about = (proposal['about'] ?? '').toString();
    final imageUrl = proposal['imageUrl'] as String?;
    final dateLabel = (proposal['dateLabel'] ?? '').toString();
    final venue = (proposal['venue'] ?? '').toString();
    final city = (proposal['city'] ?? '').toString();
    final guestCount = (proposal['guestCount'] ?? '').toString();
    final ageGroup = (proposal['ageGroup'] ?? '').toString();
    final audience = (proposal['audienceProfile'] as List?) ?? [];
    final tiers = (proposal['sponsorTiers'] as List?) ?? [];
    final status = (proposal['status'] ?? 'DRAFT').toString();
    final isDraftOrRejected = status == 'DRAFT' || status == 'REJECTED';
    final location = [venue, city].where((s) => s.isNotEmpty).join(', ');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8F3),
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'PROPOSAL DETAILS',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Banner if available
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                    // Title
                    Text(
                      name,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _statusBadge(status),
                        if (dateLabel.isNotEmpty)
                          _pillTag(dateLabel, const Color(0xFF6C32D1), Colors.white),
                        if (guestCount.isNotEmpty)
                          _pillTag('$guestCount Guests', MeetdayColors.primaryRed, Colors.white),
                        if (ageGroup.isNotEmpty)
                          _pillTag('Age: $ageGroup', const Color(0xFFF5C343), Colors.black),
                      ],
                    ),

                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: MeetdayColors.primaryRed),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF525252),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0x22000000)),
                    const SizedBox(height: 12),

                    // About
                    Text(
                      'About The Project',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      about.isNotEmpty ? about : 'No description provided for this proposal.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        height: 1.4,
                        color: const Color(0xFF4B5563),
                      ),
                    ),

                    // Audience profile
                    if (audience.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Target Audience',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: audience.map((a) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black, width: 1.2),
                            ),
                            child: Text(
                              a.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Sponsor Tiers
                    if (tiers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Sponsor Pricing Tiers',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...tiers.map((t) {
                        final tName = (t['name'] ?? '').toString();
                        final tPrice = (t['price'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black, width: 1.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tName,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                tPrice.startsWith('₹') ? tPrice : '₹$tPrice',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: MeetdayColors.primaryRed,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8F3),
                border: Border(top: BorderSide(color: Colors.black, width: 2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'CLOSE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isDraftOrRejected && onSubmitApproval != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onSubmitApproval,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C32D1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(2, 2),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'SUBMIT APPROVAL',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg = const Color(0xFF4ADE80);
    Color fg = Colors.black;
    String label = status;

    if (status == 'PUBLISHED') {
      bg = const Color(0xFF4ADE80);
      label = 'LIVE / APPROVED';
    } else if (status == 'UNDER_REVIEW') {
      bg = const Color(0xFFFFC940);
      label = 'UNDER REVIEW';
    } else if (status == 'DRAFT') {
      bg = const Color(0xFFF1F5F9);
      label = 'DRAFT';
    } else if (status == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'REJECTED';
    } else if (status == 'COMPLETED') {
      bg = const Color(0xFF1E293B);
      fg = Colors.white;
      label = 'COMPLETED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

// ── Create Proposal Modal Bottom Sheet ──────────────────────────────────────

class CreateProposalModal extends ConsumerStatefulWidget {
  const CreateProposalModal({
    super.key,
    required this.onSuccess,
  });

  final VoidCallback onSuccess;

  @override
  ConsumerState<CreateProposalModal> createState() => _CreateProposalModalState();
}

class _CreateProposalModalState extends ConsumerState<CreateProposalModal> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _guestsController = TextEditingController(text: '100');
  final _ageGroupController = TextEditingController(text: '18-40');
  final _priceController = TextEditingController(text: '50000');
  final _tierNameController = TextEditingController(text: 'Title Sponsor');

  final DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  String _sponsorshipType = 'BOTH'; // 'CASH', 'BARTER', 'BOTH'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _venueController.dispose();
    _cityController.dispose();
    _guestsController.dispose();
    _ageGroupController.dispose();
    _priceController.dispose();
    _tierNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave({required bool submitForApproval}) async {
    final name = _nameController.text.trim();
    final about = _aboutController.text.trim();
    final venue = _venueController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a proposal/project name')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final api = ref.read(apiClientProvider);

      final payload = <String, dynamic>{
        'name': name,
        'about': about.isNotEmpty ? about : 'Community sponsorship proposal for $name',
        'eventDate': _selectedDate.toIso8601String(),
        'eventEndDate': _selectedDate.toIso8601String(),
        'venues': [venue.isNotEmpty ? venue : 'Community Hub'],
        'venueCities': [city.isNotEmpty ? city : 'Bengaluru'],
        'guestCount': _guestsController.text.trim().isNotEmpty
            ? _guestsController.text.trim()
            : '100',
        'ageGroup': _ageGroupController.text.trim().isNotEmpty
            ? _ageGroupController.text.trim()
            : '18-40',
        'audienceProfile': ['Creators', 'Founders', 'Community Members'],
        'sponsorshipType': _sponsorshipType,
        'sponsorTiers': _sponsorshipType == 'BARTER'
            ? []
            : [
                {
                  'name': _tierNameController.text.trim().isNotEmpty
                      ? _tierNameController.text.trim()
                      : 'Title Sponsor',
                  'price': _priceController.text.trim().isNotEmpty
                      ? _priceController.text.trim()
                      : '50000',
                }
              ],
      };

      // 1. Create proposal
      final response = await api.dio.post<dynamic>(
        '/sponsorships',
        data: payload,
      );

      String? createdId;
      if (response.data is Map) {
        final data = response.data['data'];
        if (data is Map && data['id'] != null) {
          createdId = data['id'].toString();
        }
      }

      // 2. Submit for approval if requested
      if (submitForApproval && createdId != null) {
        await api.dio.post<dynamic>('/sponsorships/$createdId/submit');
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submitForApproval
                  ? 'Proposal submitted for admin review!'
                  : 'Proposal saved as draft!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 16,
        right: 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.black, width: 3),
          left: BorderSide(color: Colors.black, width: 3),
          right: BorderSide(color: Colors.black, width: 3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CREATE PROPOSAL',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.black),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Scrollable inputs
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Proposal / Event Title *'),
                  _textField(_nameController, 'e.g. NextGen Web3 Creators Summit'),

                  const SizedBox(height: 10),
                  _fieldLabel('About The Project'),
                  _textField(
                    _aboutController,
                    'Describe the event purpose, theme, and audience...',
                    maxLines: 3,
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Venue'),
                            _textField(_venueController, 'e.g. Indie Hub'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('City'),
                            _textField(_cityController, 'e.g. Bengaluru'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Guest Count'),
                            _textField(_guestsController, 'e.g. 100'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Age Group'),
                            _textField(_ageGroupController, 'e.g. 18-35'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  _fieldLabel('Sponsorship Type'),
                  Row(
                    children: [
                      _radioOption('BOTH', 'Both'),
                      const SizedBox(width: 8),
                      _radioOption('CASH', 'Cash Only'),
                      const SizedBox(width: 8),
                      _radioOption('BARTER', 'Barter Only'),
                    ],
                  ),

                  if (_sponsorshipType != 'BARTER') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Tier Name'),
                              _textField(_tierNameController, 'e.g. Title Sponsor'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Price (₹)'),
                              _textField(_priceController, 'e.g. 50000'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),

          // Submit Actions
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _handleSave(submitForApproval: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'SAVE AS DRAFT',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _handleSave(submitForApproval: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'SUBMIT APPROVAL',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111111),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _radioOption(String value, String label) {
    final isSelected = _sponsorshipType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sponsorshipType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 1.4),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
