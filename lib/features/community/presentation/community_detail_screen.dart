import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/meetday_colors.dart';
import '../../auth/domain/account_role.dart';
import '../../auth/state/auth_provider.dart';
import 'community_dashboard_screen.dart';
import 'providers/chat_provider.dart';
import 'profile/profile_screen.dart';
import 'proposal_components.dart';
import 'providers/dashboard_provider.dart';
import 'providers/profile_provider.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.community,
    this.activeProposals = const [],
    this.onProposalClick,
    this.isBrandPreview = false,
    this.onSelectTab,
    this.currentTabIndex = 2,
  });

  final Map<String, dynamic> community;
  final List<Map<String, dynamic>> activeProposals;
  final ValueChanged<String>? onProposalClick;
  final bool isBrandPreview;
  final ValueChanged<int>? onSelectTab;
  final int currentTabIndex;

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  bool _isSendingCollaboration = false;

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

  Future<void> _sendCollaborationRequest(String targetCommunityId) async {
    if (_isSendingCollaboration) return;
    setState(() => _isSendingCollaboration = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post<dynamic>(
        '/community-collaboration/interest/$targetCommunityId',
      );
      final responseData = response.data is Map
          ? (response.data['data'] is Map ? response.data['data'] : response.data)
          : null;
      final alreadyInterested = responseData is Map && responseData['alreadyInterested'] == true;

      ref.invalidate(chatHubProvider);
      ref.invalidate(communityCollaborationCommunitiesProvider);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alreadyInterested
              ? 'A collaboration request or channel already exists. Check your chat hub.'
              : 'Collaboration request sent. The community can accept it in their chat hub.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop();
      widget.onSelectTab?.call(5);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send collaboration request: $error'),
          backgroundColor: MeetdayColors.primaryRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingCollaboration = false);
    }
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
    final canCollaborate = !widget.isBrandPreview &&
      ref.watch(authControllerProvider).role == AccountRole.community;

    final categories = (c['categories'] as List?)?.whereType<Map>().toList() ?? [];
    final operatingCities = (c['operatingCities'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final socialLinks = c['socialLinks'] is Map ? c['socialLinks'] as Map : null;
    final pastEvents = (c['pastEvents'] as List?)?.whereType<Map>().toList() ?? [];
    final brandsWorkedWith = (c['brandsWorkedWith'] as List?)?.whereType<Map>().toList() ?? [];

    final hostData = ref.watch(hostProfileProvider).asData?.value;
    final commData = ref.watch(communityProfileProvider).asData?.value;
    final unreadCount = ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;
    final avatarUrl = (hostData?['avatarUrl'] ?? commData?['logoUrl']) as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        backgroundColor: MeetdayColors.primaryRed,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(
                      onSelectTab: widget.onSelectTab,
                      currentTabIndex: widget.currentTabIndex,
                    ),
                  ),
                );
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.person_rounded, size: 20),
                        )
                      : const Icon(Icons.person_rounded, size: 20),
                ),
              ),
            ),
          ),
        ),
        title: GestureDetector(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.onSelectTab?.call(0);
          },
          behavior: HitTestBehavior.opaque,
          child: SvgPicture.asset(
            'assets/logo/meetday-white.svg',
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  widget.onSelectTab?.call(6);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, color: Colors.black, size: 20),
                      if (unreadCount > 0)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: MeetdayColors.primaryRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MeetdayMobileBottomBar(
        currentIndex: widget.isBrandPreview ? -1 : widget.currentTabIndex,
        onTap: (tabIndex) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          widget.onSelectTab?.call(tabIndex);
        },
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
                  widget.isBrandPreview ? 'Back to Profile' : 'Back to Communities',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0x99000000),
                  ),
                ),
              ],
            ),
          ),

          if (widget.isBrandPreview) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Brand Preview Mode',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'BRAND VIEW',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: MeetdayColors.accentYellow,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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

                if (canCollaborate) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingCollaboration
                          ? null
                          : () => _sendCollaborationRequest((c['id'] ?? '').toString()),
                      icon: _isSendingCollaboration
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.handshake_rounded, size: 18),
                      label: Text(_isSendingCollaboration ? 'Sending...' : 'COLLABORATE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeetdayColors.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
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

          // Active Proposals Section: ONLY displayed on Brand side (when user is Brand or in brand preview)
          if (widget.isBrandPreview || ref.watch(authControllerProvider).role == AccountRole.brand) ...[
            Builder(builder: (context) {
              final publishedProposals = ref.watch(publishedProposalsProvider).asData?.value ?? [];
              final effectiveProposals = widget.activeProposals.isNotEmpty
                  ? widget.activeProposals
                  : getCommunityMatchingProposals(widget.community, publishedProposals);

              final approvedProposals = effectiveProposals.where((p) {
                final status = (p['status'] ?? '').toString().toUpperCase();
                return status == 'PUBLISHED' || status == 'APPROVED';
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (approvedProposals.isEmpty)
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
                          'No approved proposals from this community yet.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    )
                  else
                    ...approvedProposals.map((p) {
                      final propId = (p['id'] ?? '').toString();
                      return ProposalListItemCard(
                        proposal: p,
                        onTap: () {
                          if (widget.onProposalClick != null) {
                            widget.onProposalClick!(propId);
                          } else {
                            showDialog<void>(
                              context: context,
                              barrierColor: Colors.black.withAlpha(200),
                              builder: (ctx) => ProposalDetailDialog(
                                proposal: p,
                                isBrand: true,
                                onChatStarted: () {
                                  widget.onSelectTab?.call(5);
                                },
                              ),
                            );
                          }
                        },
                      );
                    }),
                ],
              );
            }),
          ],
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
