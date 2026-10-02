import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/meetday_colors.dart';
import 'proposal_components.dart';

class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.community,
    this.activeProposals = const [],
    this.onProposalClick,
  });

  final Map<String, dynamic> community;
  final List<Map<String, dynamic>> activeProposals;
  final ValueChanged<String>? onProposalClick;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  void _openImageDialog(String imageUrl, String? title, String? description) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded, size: 20, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(5, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.0,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.black38),
                          ),
                        ),
                      ),
                      if (title != null && title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            title,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111111),
                            ),
                          ),
                        ),
                      if (description != null && description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            description,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF525252),
                              height: 1.45,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label link copied to clipboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.community;
    final name = (c['name'] ?? c['title'] ?? 'Community').toString();
    final logoUrl = c['logoUrl'] as String?;
    final secondaryImageUrl = c['secondaryImageUrl'] as String?;
    final about = (c['about'] ?? '').toString();
    final size = (c['size'] ?? c['memberCount'] ?? '—').toString();
    final avgGuestCount = (c['avgGuestCount'] ?? '').toString();
    final experiencesPerYear = (c['experiencesPerYear'] ?? '').toString();

    final categories = (c['categories'] as List?)?.whereType<Map>().toList() ?? [];
    final operatingCities = (c['operatingCities'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final socialLinks = c['socialLinks'] is Map ? c['socialLinks'] as Map : null;
    final pastEvents = (c['pastEvents'] as List?)?.whereType<Map>().toList() ?? [];
    final brandsWorkedWith = (c['brandsWorkedWith'] as List?)?.whereType<Map>().toList() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        backgroundColor: MeetdayColors.primaryRed,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: SvgPicture.asset(
                'assets/logo/meetday-white.svg',
                height: 20,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          // Back Link Breadcrumb
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 13,
                  color: Color(0x99000000),
                ),
                const SizedBox(width: 5),
                Text(
                  'Back to Communities',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0x99000000),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Main Profile Details Neo-Brutalist Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 3),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Logo Avatar + Name + Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1:1 Community Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.black, width: 2.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15.5),
                        child: (logoUrl != null && logoUrl.isNotEmpty)
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _fallbackLogo(name),
                              )
                            : _fallbackLogo(name),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Name and stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: const Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Badges Row
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _statPill(size, 'Members'),
                              if (avgGuestCount.isNotEmpty && avgGuestCount != '—')
                                _statPill(avgGuestCount, 'Avg Guests'),
                              if (experiencesPerYear.isNotEmpty && experiencesPerYear != '—')
                                _statPill(experiencesPerYear, 'Events / Yr'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // About The Community
                if (about.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'About The Community',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0x99000000),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x1F000000), width: 1.5),
                    ),
                    child: Text(
                      about,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],

                // Experience Categories
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Experience Categories',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0x99000000),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categories.map((cat) {
                      final catName = (cat['name'] ?? '').toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          catName,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Operating Cities
                if (operatingCities.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Operating Cities',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0x99000000),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: operatingCities.map((city) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 1.2),
                        ),
                        child: Text(
                          city,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Digital Presence / Social Links
                if (socialLinks != null && socialLinks.values.any((v) => v != null && v.toString().trim().isNotEmpty)) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Digital Presence',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0x99000000),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (socialLinks['instagram'] != null && socialLinks['instagram'].toString().trim().isNotEmpty)
                        _socialChip('Instagram', socialLinks['instagram'].toString()),
                      if (socialLinks['linkedin'] != null && socialLinks['linkedin'].toString().trim().isNotEmpty)
                        _socialChip('LinkedIn', socialLinks['linkedin'].toString()),
                      if (socialLinks['youtube'] != null && socialLinks['youtube'].toString().trim().isNotEmpty)
                        _socialChip('YouTube', socialLinks['youtube'].toString()),
                      if (socialLinks['website'] != null && socialLinks['website'].toString().trim().isNotEmpty)
                        _socialChip('Website', socialLinks['website'].toString()),
                    ],
                  ),
                ],

                // Associated Brands
                if (brandsWorkedWith.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Associated Brands',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0x99000000),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: brandsWorkedWith.map((brand) {
                      final brandName = (brand['name'] ?? 'Brand').toString();
                      final brandLogo = brand['logoUrl'] as String?;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (brandLogo != null && brandLogo.isNotEmpty)
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(right: 6),
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: Image.network(
                                  brandLogo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_rounded, size: 16),
                                ),
                              ),
                            Text(
                              brandName,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
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

          // Community Poster (Secondary Image)
          if (secondaryImageUrl != null && secondaryImageUrl.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'Community Poster',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openImageDialog(secondaryImageUrl, '$name Poster', null),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 3),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          secondaryImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                      Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
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
                            const Icon(Icons.zoom_in_rounded, size: 15, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              'Zoom Poster',
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
                  ],
                ),
              ),
            ),
          ),
          ],

          // Past Experiences Gallery
          if (pastEvents.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Past Experiences',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: MeetdayColors.accentYellow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 1.2),
                  ),
                  child: Text(
                    '${pastEvents.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: pastEvents.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (ctx, idx) {
                  final event = pastEvents[idx];
                  final eventName = (event['name'] ?? 'Experience #${idx + 1}').toString();
                  final eventDesc = (event['description'] ?? '').toString();
                  final eventImages = (event['imageUrls'] as List?)?.map((u) => u.toString()).toList() ?? [];
                  final firstImage = eventImages.isNotEmpty ? eventImages.first : null;

                  return GestureDetector(
                    onTap: () {
                      if (firstImage != null) {
                        _openImageDialog(firstImage, eventName, eventDesc);
                      }
                    },
                    child: Container(
                      width: 160,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Expanded(
                            child: Container(
                              color: const Color(0xFFF1F5F9),
                              child: firstImage != null
                                  ? Image.network(
                                      firstImage,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child: Icon(Icons.photo_rounded, size: 36, color: Colors.black26),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.photo_rounded, size: 36, color: Colors.black26),
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eventName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                if (eventDesc.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    eventDesc,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(0xFF64748B),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                },
              ),
            ),
          ],

          // Active Proposals Section
          const SizedBox(height: 24),
          Text(
            'Active Proposals',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.activeProposals.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black26, width: 2, strokeAlign: BorderSide.strokeAlignCenter),
              ),
              child: Center(
                child: Text(
                  'No active proposals from this community yet.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black45,
                  ),
                ),
              ),
            )
          else
            ...widget.activeProposals.map((p) {
              final title = (p['title'] ?? p['name'] ?? 'Proposal').toString();
              final dateLabel = (p['dateLabel'] ?? '').toString();
              final hasCash = p['hasCash'] == true;
              final hasBarter = p['hasBarter'] == true;
              final propId = (p['id'] ?? '').toString();
              return GestureDetector(
                onTap: () {
                  if (widget.onProposalClick != null) {
                    widget.onProposalClick!(propId);
                  } else {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => ProposalDetailDialog(proposal: p),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 2.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2.5, 2.5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111111),
                            ),
                          ),
                          if (dateLabel.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              dateLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF667085),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasCash) ...[
                      const SizedBox(width: 4),
                      _badgeTag('CASH', const Color(0xFFDCFCE7), Colors.black),
                    ],
                    if (hasBarter) ...[
                      const SizedBox(width: 4),
                      _badgeTag('BARTER', MeetdayColors.accentYellow, Colors.black),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statPill(String val, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: MeetdayColors.accentYellow,
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
            val,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0x99000000),
          ),
        ),
      ],
    );
  }

  Widget _socialChip(String platform, String url) {
    return GestureDetector(
      onTap: () => _copyToClipboard(url, platform),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x33000000), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              platform,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MeetdayColors.primaryRed,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.copy_rounded,
              size: 12,
              color: MeetdayColors.primaryRed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: textCol,
        ),
      ),
    );
  }

  Widget _fallbackLogo(String name) {
    final initials = name.length > 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    return Container(
      color: MeetdayColors.accentYellow,
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
