import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/meetday_colors.dart';
import 'proposal/proposal_form_screen.dart';
import 'proposal/proposal_pdf_viewer_screen.dart';

export 'proposal/proposal_form_screen.dart';
export 'proposal/proposal_pdf_viewer_screen.dart';

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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Image (Strict 1:1 Aspect Ratio Square for all cards)
              SizedBox(
                width: 120,
                height: 120,
                child: AspectRatio(
                  aspectRatio: 1.0,
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
              ),

              // Right Info Content
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
    this.onEdit,
    this.onDelete,
    this.isBrand = false,
    this.onChatStarted,
  });

  final Map<String, dynamic> proposal;
  final VoidCallback? onSubmitApproval;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isBrand;
  final VoidCallback? onChatStarted;

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final cleaned = raw.split('T').first;
    final parts = cleaned.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return raw;
  }

  static String _formatDocSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static void _openImagePopup(BuildContext context, String imageUrl, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                children: [
                  InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Icon(Icons.broken_image_rounded, size: 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MeetdayColors.primaryRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(2, 2)),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = (proposal['id'] ?? '').toString();
    final name = (proposal['name'] ?? proposal['title'] ?? 'Proposal').toString();
    final about = (proposal['about'] ?? '').toString();
    final imageUrl = proposal['imageUrl'] as String?;
    final eventDate = (proposal['eventDate'] ?? proposal['dateLabel'] ?? '').toString();
    final eventEndDate = (proposal['eventEndDate'] ?? '').toString();
    final venue = (proposal['venue'] ?? '').toString();
    final venues = (proposal['venues'] as List?)?.map((e) => e.toString()).toList() ?? (venue.isNotEmpty ? [venue] : <String>[]);
    final city = (proposal['city'] ?? '').toString();
    final venueCities = (proposal['venueCities'] as List?)?.map((e) => e.toString()).toList() ?? (city.isNotEmpty ? [city] : <String>[]);
    final guestCount = (proposal['guestCount'] ?? '').toString();
    final ageGroup = (proposal['ageGroup'] ?? '').toString();
    final audience = (proposal['audienceProfile'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final tiers = (proposal['sponsorTiers'] as List?) ?? [];
    final status = (proposal['status'] ?? 'DRAFT').toString().toUpperCase();
    final sponsorshipType = (proposal['sponsorshipType'] ?? 'CASH').toString().toUpperCase();
    final adminRejectionRemark = proposal['adminRejectionRemark'] as String?;
    final videoUrl = proposal['videoUrl'] as String?;
    final docName = (proposal['docName'] ?? 'Proposal Document.pdf').toString();
    final docType = (proposal['docType'] ?? 'PDF').toString();
    final docSize = proposal['docSize'] as int?;
    final docUrl = proposal['docUrl'] as String?;

    final startDisplay = _formatDate(eventDate);
    final endDisplay = _formatDate(eventEndDate);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFC),
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
          children: [
            // Top Navigation & Close Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8F3),
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: MeetdayColors.primaryRed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Back to Sponsorships',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MeetdayColors.primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Project Overview & Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(status),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons Row (Share, Edit, Submit, Delete)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (status == 'PUBLISHED')
                          GestureDetector(
                            onTap: () {
                              final shareUrl = 'https://app.meetday.ai/brand/proposal/$id';
                              Clipboard.setData(ClipboardData(text: shareUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Link copied! Share it with brands.',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.black, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.share_outlined, size: 12, color: Colors.black),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SHARE',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (onEdit != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              onEdit!();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: MeetdayColors.primaryRed,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.black, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                'EDIT DETAILS',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if ((status == 'DRAFT' || status == 'REJECTED') && onSubmitApproval != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              onSubmitApproval!();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C32D1),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.black, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                'SUBMIT FOR APPROVAL',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (onDelete != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              onDelete!();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.black, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                'DELETE',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: MeetdayColors.primaryRed,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Admin Rejection Remark Banner
                    if (status == 'REJECTED' && adminRejectionRemark != null && adminRejectionRemark.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Rejected by admin: ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ),
                                    TextSpan(
                                      text: adminRejectionRemark,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Top Image + Metadata Section (exact frontend mobile layout)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Thumbnail (70x70) - Clickable to open full popup
                        GestureDetector(
                          onTap: (imageUrl != null && imageUrl.isNotEmpty)
                              ? () => _openImagePopup(context, imageUrl, name)
                              : null,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                (imageUrl != null && imageUrl.isNotEmpty)
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => _monogramFallback(name),
                                      )
                                    : _monogramFallback(name),
                                if (imageUrl != null && imageUrl.isNotEmpty)
                                  Positioned(
                                    bottom: 2,
                                    right: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Metadata Card (#FFF8F3)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8F3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Start & End Dates
                                Row(
                                  children: [
                                    if (startDisplay.isNotEmpty)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'START',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF525252),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: _redBadge(startDisplay),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (endDisplay.isNotEmpty && endDisplay != startDisplay)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'END',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF525252),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: _redBadge(endDisplay),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                // Venue & City
                                if (venues.isNotEmpty || venueCities.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'VENUE & CITY',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF525252),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...List.generate(
                                    venues.length > venueCities.length ? venues.length : (venueCities.isNotEmpty ? venueCities.length : 1),
                                    (idx) {
                                      final v = idx < venues.length ? venues[idx] : '';
                                      final c = idx < venueCities.length ? venueCities[idx] : '';
                                      if (v.isEmpty && c.isEmpty) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            if (c.isNotEmpty) ...[
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: _redBadge(c),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            if (v.isNotEmpty)
                                              Expanded(
                                                child: Text(
                                                  v,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF262626),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1, color: Colors.black12),
                                ),

                                // Guests & Age Group
                                Row(
                                  children: [
                                    if (guestCount.isNotEmpty)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'GUESTS',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF525252),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: _redBadge('$guestCount Guests'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (ageGroup.isNotEmpty)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'AGE GROUP',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF525252),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: _redBadge('$ageGroup Years'),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                // Proposal Video URL (if present)
                                if (videoUrl != null && videoUrl.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'PROPOSAL VIDEO',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF525252),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: videoUrl));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Video link copied: $videoUrl'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6C32D1),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.black, width: 1.2),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                                        ],
                                      ),
                                      child: Text(
                                        'Watch Video ↗',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                // Audience Tags
                                if (audience.isNotEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Divider(height: 1, color: Colors.black12),
                                  ),
                                  Text(
                                    'AUDIENCE',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF525252),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 5,
                                    runSpacing: 5,
                                    children: audience.map((a) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5C343),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: Colors.black, width: 1.2),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                                          ],
                                        ),
                                        child: Text(
                                          a.toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // About the Project Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About the Project',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            about.isNotEmpty ? about : 'No description provided.',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              height: 1.5,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Sponsor Pricing Tiers & Barter Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sponsorshipType == 'BARTER'
                                      ? 'Sponsorship Type'
                                      : (sponsorshipType == 'BOTH'
                                          ? 'Sponsor Pricing Tiers & Barter'
                                          : 'Sponsor Pricing Tiers'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (sponsorshipType == 'CASH' || sponsorshipType == 'BOTH')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(left: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.black, width: 1.1),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                                        ],
                                      ),
                                      child: Text(
                                        'CASH',
                                        style: GoogleFonts.poppins(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                  if (sponsorshipType == 'BARTER' || sponsorshipType == 'BOTH')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(left: 4),
                                      decoration: BoxDecoration(
                                        color: MeetdayColors.accentYellow,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.black, width: 1.1),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                                        ],
                                      ),
                                      child: Text(
                                        'BARTER',
                                        style: GoogleFonts.poppins(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (sponsorshipType == 'BARTER')
                            Text(
                              'Open to product, service, or venue barter collaborations.',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF525252),
                              ),
                            ),
                          if (tiers.isNotEmpty && sponsorshipType != 'BARTER') ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tiers.map((t) {
                                final tName = (t['name'] ?? '').toString();
                                final tPrice = (t['price'] ?? '').toString();
                                final formattedPrice = tPrice.startsWith('₹') ? tPrice : '₹$tPrice';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8F3),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black, width: 1.2),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '$tName: ',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF525252),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        formattedPrice,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: MeetdayColors.primaryRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Document Preview Card (Opens directly in-app via ProposalPdfViewerScreen)
                    GestureDetector(
                      onTap: () {
                        if ((docUrl != null && docUrl.isNotEmpty) || id.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProposalPdfViewerScreen(
                                proposalId: id.isNotEmpty ? id : null,
                                pdfUrl: docUrl ?? '',
                                title: docName,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No PDF document attached to this proposal.',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: Colors.black,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Document Preview',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8F3),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black, width: 1.2),
                                  ),
                                  child: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: MeetdayColors.primaryRed),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        docName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        [
                                          docType.toUpperCase(),
                                          if (docSize != null && docSize > 0) _formatDocSize(docSize),
                                        ].where((s) => s.isNotEmpty).join(' • '),
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF667085),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ((docUrl != null && docUrl.isNotEmpty) || id.isNotEmpty) ? MeetdayColors.primaryRed : const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.black, width: 1.2),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility_rounded,
                                        size: 13,
                                        color: ((docUrl != null && docUrl.isNotEmpty) || id.isNotEmpty) ? Colors.white : Colors.black45,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Open PDF',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: ((docUrl != null && docUrl.isNotEmpty) || id.isNotEmpty) ? Colors.white : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isBrand && onEdit == null && onSubmitApproval == null) ...[
                      const SizedBox(height: 14),
                      Builder(
                        builder: (btnCtx) => GestureDetector(
                          onTap: () async {
                            final id = (proposal['id'] ?? '').toString();
                            if (id.isEmpty) return;
                            try {
                              final res = await ApiClient.instance.markSponsorshipInterest(id);
                              final already = res['alreadyInterested'] == true;
                              if (btnCtx.mounted) {
                                ScaffoldMessenger.of(btnCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      already
                                          ? "You've already expressed interest in this proposal"
                                          : '✅ Interest sent to the host and admin team!',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                onChatStarted?.call();
                              }
                            } catch (e) {
                              if (btnCtx.mounted) {
                                ScaffoldMessenger.of(btnCtx).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to express interest: $e'),
                                    backgroundColor: MeetdayColors.primaryRed,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: MeetdayColors.accentYellow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2.5, 2.5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star_rounded, size: 18, color: Colors.black),
                                const SizedBox(width: 6),
                                Text(
                                  'EXPRESS INTEREST ➔',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _redBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: MeetdayColors.primaryRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  static Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFF4ADE80);
    Color fg = Colors.black;
    String label = status;

    if (status == 'PUBLISHED') {
      bg = const Color(0xFF4ADE80);
      label = 'LIVE';
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

  static Widget _monogramFallback(String name) {
    final initials = name.length > 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    return Container(
      color: MeetdayColors.primaryRed,
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Create Proposal Modal / Screen ──────────────────────────────────────────

class CreateProposalModal extends StatelessWidget {
  const CreateProposalModal({
    super.key,
    required this.onSuccess,
    this.initialProposal,
  });

  final VoidCallback onSuccess;
  final Map<String, dynamic>? initialProposal;

  @override
  Widget build(BuildContext context) {
    return ProposalFormScreen(
      initialProposal: initialProposal,
      onSuccess: onSuccess,
    );
  }
}

