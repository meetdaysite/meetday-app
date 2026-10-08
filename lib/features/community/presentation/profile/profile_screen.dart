import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../../../auth/domain/account_role.dart';
import '../../../auth/state/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/dashboard_provider.dart';
import '../community_dashboard_screen.dart';
import '../community_detail_screen.dart';

const Map<String, String> _genderLabels = {
  'MALE': 'Male',
  'FEMALE': 'Female',
  'NON_BINARY': 'Non-binary',
  'PREFER_NOT_TO_SAY': 'Prefer not to say',
};

/// Community Profile Screen replicating the exact layout, data fetching, and Neo-Brutalist
/// design system from meetday-frontend (/community/dashboard/profile).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.initialOpenPanel,
    this.onSelectTab,
    this.currentTabIndex = 0,
  });

  final String? initialOpenPanel;
  final ValueChanged<int>? onSelectTab;
  final int currentTabIndex;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationSounds = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSoundPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialOpenPanel == 'community') {
        _openCommunityDetails();
      } else if (widget.initialOpenPanel == 'kyc') {
        _openVerifications();
      }
    });
  }

  String get _notificationSoundKey {
    final auth = ref.read(authControllerProvider);
    return notificationSoundPreferenceKey(auth.role, auth.uid);
  }

  Future<void> _loadNotificationSoundPreference() async {
    final value = await const FlutterSecureStorage().read(
      key: _notificationSoundKey,
    );
    if (mounted && value != null) {
      setState(() => _notificationSounds = value != 'false');
    }
  }

  Future<void> _setNotificationSoundPreference(bool enabled) async {
    setState(() => _notificationSounds = enabled);
    try {
      await const FlutterSecureStorage().write(
        key: _notificationSoundKey,
        value: enabled.toString(),
      );
    } catch (_) {
      // Keep the current session's setting even if secure storage is unavailable.
    }
  }

  Future<void> _refreshAll() async {
    final isBrand = ref.read(authControllerProvider).role == AccountRole.brand;
    if (isBrand) {
      ref.invalidate(brandProfileProvider);
      ref.invalidate(brandTeamMembersProvider);
    } else {
      ref.invalidate(hostProfileProvider);
      ref.invalidate(communityProfileProvider);
      ref.invalidate(teamMembersProvider);
    }
  }

  void _openBrandPreview() {
    final communityAsync = ref.read(communityProfileProvider);
    final hostAsync = ref.read(hostProfileProvider);
    final community = Map<String, dynamic>.from(
      communityAsync.asData?.value ?? <String, dynamic>{},
    );
    final host = Map<String, dynamic>.from(
      hostAsync.asData?.value ?? <String, dynamic>{},
    );

    final mergedCommunity = <String, dynamic>{
      ...community,
      'name':
          community['name'] ??
          host['communityName'] ??
          host['displayName'] ??
          'Community',
      'logoUrl': community['logoUrl'] ?? host['avatarUrl'],
      'secondaryImageUrl': community['secondaryImageUrl'],
      'about': community['about'] ?? host['bio'] ?? '',
      'size': community['size'] ?? '1,000 - 5,000',
      'avgGuestCount': community['avgGuestCount'] ?? '0',
      'experiencesPerYear': community['experiencesPerYear'] ?? '0',
      'operatingCities':
          host['operatingCities'] ?? community['operatingCities'] ?? [],
      'socialLinks': host['socialLinks'] ?? community['socialLinks'] ?? {},
      'categories': community['categories'] ?? [],
      'pastEvents': community['pastEvents'] ?? [],
      'brandsWorkedWith': community['brandsWorkedWith'] ?? [],
    };

    final published = ref.read(publishedProposalsProvider).asData?.value ?? [];
    final myProps = ref.read(dashboardProposalsProvider).asData?.value ?? [];
    final combined = [...myProps, ...published];
    final matching = getCommunityMatchingProposals(mergedCommunity, combined);
    final allProposals = matching.isNotEmpty ? matching : myProps;
    final approvedProposals = allProposals.where((p) {
      final status = (p['status'] ?? '').toString().toUpperCase();
      return status == 'PUBLISHED' || status == 'APPROVED';
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityDetailScreen(
          community: mergedCommunity,
          activeProposals: approvedProposals,
          isBrandPreview: true,
          onSelectTab: widget.onSelectTab,
          currentTabIndex: -1,
        ),
      ),
    );
  }

  void _openCommunityDetails() {
    final communityAsync = ref.read(communityProfileProvider);
    final hostAsync = ref.read(hostProfileProvider);
    final community = communityAsync.asData?.value ?? <String, dynamic>{};
    final host = hostAsync.asData?.value ?? <String, dynamic>{};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommunityProfileDetailsSheet(
        community: community,
        hostProfile: host,
        onEdit: () {
          Navigator.of(context).pop();
          _openEditProfile();
        },
        onBrandPreview: _openBrandPreview,
      ),
    );
  }

  void _openVerifications() {
    final hostAsync = ref.read(hostProfileProvider);
    final host = hostAsync.asData?.value ?? <String, dynamic>{};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerificationsDetailsSheet(hostProfile: host),
    );
  }

  void _openTeamMembers() {
    final hostAsync = ref.read(hostProfileProvider);
    final host = hostAsync.asData?.value ?? <String, dynamic>{};
    final communityName = (host['communityName'] ?? 'Your Community')
        .toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeamMembersSheet(communityName: communityName),
    );
  }

  void _openEditProfile() {
    final hostAsync = ref.read(hostProfileProvider);
    final host = hostAsync.asData?.value ?? <String, dynamic>{};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(hostProfile: host),
    );
  }

  void _openEditBrandProfile(Map<String, dynamic> brandProfile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBrandProfileSheet(brandProfile: brandProfile),
    );
  }

  void _openBrandTeamMembers(String brandName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TeamMembersSheet(communityName: brandName, isBrand: true),
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Log Out',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to log out of Meetday?',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogCtx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2.5),
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
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.of(dialogCtx).pop();
                      await ref.read(authControllerProvider.notifier).signOut();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2.5),
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
                          'LOG OUT',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
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
      ),
    );
  }

  void _confirmDeleteAccount() {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Delete Account',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MeetdayColors.primaryRed,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is irreversible. All your community data, proposals, and chats will be permanently removed.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Reason for leaving (optional)',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black38,
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: MeetdayColors.primaryRed,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MeetdayColors.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                final api = ref.read(apiClientProvider);
                await api.deleteAccount(reason: reasonController.text.trim());
                if (mounted) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete account: $e'),
                      backgroundColor: MeetdayColors.primaryRed,
                    ),
                  );
                }
              }
            },
            child: Text(
              'DELETE',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRole = ref.watch(authControllerProvider).role;
    final isBrand = authRole == AccountRole.brand;

    final brandAsync = isBrand ? ref.watch(brandProfileProvider) : null;
    final hostAsync = isBrand ? null : ref.watch(hostProfileProvider);
    final communityAsync = isBrand ? null : ref.watch(communityProfileProvider);

    final host = hostAsync?.asData?.value ?? <String, dynamic>{};
    final community = communityAsync?.asData?.value ?? <String, dynamic>{};
    final brand = brandAsync?.asData?.value ?? <String, dynamic>{};

    final isLoading = isBrand
        ? (brandAsync?.isLoading ?? false)
        : ((hostAsync?.isLoading ?? false) ||
              (communityAsync?.isLoading ?? false));
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;

    // Rep / Brand details
    final displayName = isBrand
        ? (brand['brandName'] ?? brand['displayName'] ?? 'Brand').toString()
        : (host['displayName'] ?? host['legalName'] ?? 'Host').toString();
    final avatarUrl = isBrand
        ? (brand['logoUrl'] as String?)
        : (host['avatarUrl'] as String?);
    final email = isBrand
        ? (brand['workEmail'] ?? brand['email'] ?? '').toString()
        : (host['email'] ?? '').toString();
    final phone = isBrand
        ? (brand['contactPhone'] ?? brand['phone'] ?? '').toString()
        : (host['phone'] ?? '').toString();

    // Brand specific fields
    final companyType = (brand['companyType'] ?? 'BRAND')
        .toString()
        .toUpperCase();
    final brandApprovalStatus = (brand['approvalStatus'] ?? '')
        .toString()
        .toUpperCase();
    final aboutCompany = (brand['aboutCompany'] ?? '').toString();
    final brandWebsite =
        (brand['socialLinks'] is Map
                ? (brand['socialLinks']['website'] ?? '')
                : (brand['website'] ?? ''))
            .toString();
    final brandIndustry = (brand['industry'] ?? '').toString();

    // Community specific fields
    final hostType = (host['hostType'] ?? 'INDIVIDUAL')
        .toString()
        .toUpperCase();
    final isIndividual = hostType == 'INDIVIDUAL';
    final genderKey = (host['gender'] ?? '').toString();
    final gender =
        _genderLabels[genderKey] ??
        (genderKey.isNotEmpty ? genderKey : 'Not specified');
    final communityName =
        (community['name'] ?? host['communityName'] ?? 'Not specified')
            .toString();
    final hasCommunity = community.isNotEmpty && community['id'] != null;
    final kycStatus = (host['kycStatus'] ?? 'NOT_SUBMITTED').toString();
    final isKycVerified = kycStatus == 'VERIFIED';

    return Scaffold(
      backgroundColor: MeetdayColors.background,
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
            child: Container(
              width: 38,
              height: 38,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.black,
                        size: 20,
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
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
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
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
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
      body: RefreshIndicator(
        color: MeetdayColors.primaryRed,
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Main Title & Subtitle (Welcome banner removed per user request)
            Text(
              'My Profile',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: MeetdayColors.textPrimary,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isBrand
                  ? 'Your brand identity and account details'
                  : 'Your host identity and account details',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MeetdayColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Loading state banner
            if (isLoading)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MeetdayColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Fetching latest profile data...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Brand Review Status Banner (matching website) ───
            if (isBrand &&
                (brandApprovalStatus == 'PENDING' ||
                    brandApprovalStatus == 'APPROVED' ||
                    brandApprovalStatus == 'REJECTED')) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: brandApprovalStatus == 'APPROVED'
                      ? const Color(0xFFF0FDF4)
                      : brandApprovalStatus == 'PENDING'
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: brandApprovalStatus == 'APPROVED'
                        ? const Color(0xFF16A34A)
                        : brandApprovalStatus == 'PENDING'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      brandApprovalStatus == 'APPROVED'
                          ? Icons.check_circle_rounded
                          : brandApprovalStatus == 'PENDING'
                          ? Icons.hourglass_top_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: brandApprovalStatus == 'APPROVED'
                          ? const Color(0xFF15803D)
                          : brandApprovalStatus == 'PENDING'
                          ? const Color(0xFFB45309)
                          : const Color(0xFFB91C1C),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        brandApprovalStatus == 'APPROVED'
                            ? 'Approved - Your brand profile is live and active.'
                            : brandApprovalStatus == 'PENDING'
                            ? 'Awaiting admin approval - your profile is currently under review.'
                            : 'Rejected - Please update your profile details and submit again.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: brandApprovalStatus == 'APPROVED'
                              ? const Color(0xFF166534)
                              : brandApprovalStatus == 'PENDING'
                              ? const Color(0xFF92400E)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (isBrand) ...[
              // ─── The Iconic Yellow Neo-Brutalist Card (Brand Profile) ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MeetdayColors.accentYellow,
                  border: Border.all(color: Colors.black, width: 3),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.black.withAlpha(90),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar & Brand Details Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.business_rounded,
                                        size: 32,
                                        color: Colors.black54,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.business_rounded,
                                      size: 32,
                                      color: Colors.black54,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E1B4B,
                                    ), // Dark Indigo matching website
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    companyType == 'AGENCY'
                                        ? 'AGENCY'
                                        : 'BRAND',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE5E7EB), thickness: 1.5),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        'Email ID :',
                        email.isNotEmpty ? email : 'Not specified',
                        labelWidth: 140,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        'Phone No :',
                        phone.isNotEmpty ? phone : 'Not specified',
                        labelWidth: 140,
                      ),
                      if (brandWebsite.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          'Website :',
                          brandWebsite,
                          labelWidth: 140,
                        ),
                      ],
                      if (brandIndustry.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          'Industry :',
                          brandIndustry,
                          labelWidth: 140,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        'About The Company :',
                        aboutCompany.isNotEmpty
                            ? aboutCompany
                            : 'Not specified',
                        labelWidth: 140,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Brand Options Menu List (matching website) ───
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 1. Edit Brand Profile
              _buildOptionLineItem(
                title: 'Edit Brand Profile',
                actionLabel: 'EDIT DETAILS',
                actionColor: MeetdayColors.primaryRed,
                onTap: () => _openEditBrandProfile(brand),
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 2. Notification Sound Toggle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notification Sounds',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _notificationSounds,
                      thumbColor: WidgetStateProperty.resolveWith<Color>(
                        (states) => Colors.white,
                      ),
                      trackColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return MeetdayColors.primaryRed;
                        }
                        return Colors.black26;
                      }),
                      onChanged: _setNotificationSoundPreference,
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 3. Team Members
              _buildOptionLineItem(
                title: 'Team Members',
                actionLabel: 'MANAGE',
                actionColor: MeetdayColors.primaryRed,
                onTap: () => _openBrandTeamMembers(displayName),
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 4. Profile Actions (LOG OUT / DELETE)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Actions',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _confirmSignOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.black,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'LOG OUT',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _confirmDeleteAccount,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MeetdayColors.primaryRed,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.black,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'DELETE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),
            ] else ...[
              // ─── The Iconic Yellow Neo-Brutalist Card (Community Rep Profile) ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MeetdayColors.accentYellow,
                  border: Border.all(color: Colors.black, width: 3),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.black.withAlpha(90),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar & Host Details Row (No edit button near badge per user request)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar container
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person,
                                        size: 32,
                                        color: Colors.black54,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 32,
                                      color: Colors.black54,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name and host type pill
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1E1B4B,
                                    ), // Dark Indigo matching website
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isIndividual
                                        ? 'INDIVIDUAL HOST'
                                        : 'BUSINESS HOST',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE5E7EB), thickness: 1.5),
                      const SizedBox(height: 12),

                      // Info Rows matching website
                      _buildInfoRow('Gender :', gender),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        'Email ID :',
                        email.isNotEmpty ? email : 'Not specified',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        'Phone No :',
                        phone.isNotEmpty ? phone : 'Not specified',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow('Community :', communityName),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Options Menu List (separated by clean divider lines, not in boxes) ───
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 1. Community Profile
              _buildOptionLineItem(
                title: 'Community Profile',
                actionLabel: isLoading
                    ? 'LOADING…'
                    : hasCommunity
                    ? 'VIEW DETAILS'
                    : 'ACTIVATE NOW',
                actionColor: MeetdayColors.primaryRed,
                onTap: _openCommunityDetails,
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 2. My Verifications
              _buildOptionLineItem(
                title: 'My Verifications',
                actionLabel: isKycVerified ? 'VIEW DETAILS' : 'VERIFY NOW',
                actionColor: MeetdayColors.primaryRed,
                onTap: _openVerifications,
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 3. Notification Sound Toggle (flat row separated by line)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notification Sounds',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _notificationSounds,
                      thumbColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return MeetdayColors.primaryRed;
                        }
                        return Colors.black26;
                      }),
                      onChanged: (val) =>
                          setState(() => _notificationSounds = val),
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 4. Team Members
              _buildOptionLineItem(
                title: 'Team Members',
                actionLabel: 'MANAGE',
                actionColor: MeetdayColors.primaryRed,
                onTap: _openTeamMembers,
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),

              // 5. Profile Actions (LOG OUT / DELETE - separated by line)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Actions',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        // LOG OUT Button
                        GestureDetector(
                          onTap: _confirmSignOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.black,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'LOG OUT',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // DELETE Button
                        GestureDetector(
                          onTap: _confirmDeleteAccount,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MeetdayColors.primaryRed,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.black,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Text(
                              'DELETE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Color(0x1A000000),
                thickness: 1.2,
                height: 1,
              ),
            ],
            const SizedBox(height: 36),
          ],
        ),
      ),
      bottomNavigationBar: MeetdayMobileBottomBar(
        currentIndex: widget.currentTabIndex,
        role: authRole ?? AccountRole.community,
        onTap: (index) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          widget.onSelectTab?.call(index);
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {double labelWidth = 95}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6C32D1), // Meetday Purple
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionLineItem({
    required String title,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor,
                    borderRadius: BorderRadius.circular(8),
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
                    actionLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '>',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Community Profile Details Bottom Sheet (replicates CommunityProfileDetailsPanel.tsx)
// ─────────────────────────────────────────────────────────────────────────────
class _CommunityProfileDetailsSheet extends StatelessWidget {
  const _CommunityProfileDetailsSheet({
    required this.community,
    required this.hostProfile,
    required this.onEdit,
    required this.onBrandPreview,
  });

  final Map<String, dynamic> community;
  final Map<String, dynamic> hostProfile;
  final VoidCallback onEdit;
  final VoidCallback onBrandPreview;

  @override
  Widget build(BuildContext context) {
    final name =
        (community['name'] ?? hostProfile['communityName'] ?? 'Community')
            .toString();
    final about = (community['about'] ?? '').toString();
    final logoUrl = community['logoUrl'] as String?;
    final posterUrl = community['secondaryImageUrl'] as String?;
    final size = (community['size'] ?? '1,000 - 5,000').toString();
    final avgGuestCount = (community['avgGuestCount'] ?? '0').toString();
    final experiencesPerYear = (community['experiencesPerYear'] ?? '0')
        .toString();
    final approvalStatus = (community['approvalStatus'] ?? 'PENDING')
        .toString()
        .toUpperCase();
    final adminRejectionRemark = community['adminRejectionRemark'] as String?;
    final pendingRevision = community['pendingRevision'];

    final rawCategories = community['categories'] as List? ?? [];
    final categories = rawCategories
        .map((c) {
          if (c is Map) return (c['name'] ?? '').toString();
          return c.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList();

    final operatingCities =
        (hostProfile['operatingCities'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final socialLinks =
        (hostProfile['socialLinks'] as Map?) ?? <String, dynamic>{};
    final instagram = socialLinks['instagram']?.toString();
    final linkedin = socialLinks['linkedin']?.toString();
    final youtube = socialLinks['youtube']?.toString();
    final website = socialLinks['website']?.toString();

    final pastEvents = (community['pastEvents'] as List?) ?? [];
    final brandsWorkedWith = (community['brandsWorkedWith'] as List?) ?? [];

    // Approval status badge styling
    Color statusBg = const Color(0xFFFEF9C3);
    Color statusBorder = const Color(0xFFF59E0B);
    Color statusText = const Color(0xFF92400E);
    String statusLabel = 'Pending admin approval';

    if (approvalStatus == 'APPROVED') {
      statusBg = const Color(0xFFE8F8F0);
      statusBorder = const Color(0xFF10B981);
      statusText = const Color(0xFF065F46);
      statusLabel = 'Live to Brands';
    } else if (approvalStatus == 'REJECTED') {
      statusBg = const Color(0xFFFEE2E2);
      statusBorder = const Color(0xFFEF4444);
      statusText = const Color(0xFFB91C1C);
      statusLabel =
          adminRejectionRemark != null && adminRejectionRemark.isNotEmpty
          ? 'Rejected — $adminRejectionRemark'
          : 'Rejected — needs changes';
    } else if (approvalStatus == 'SUSPENDED') {
      statusBg = const Color(0xFFF3F4F6);
      statusBorder = const Color(0xFF9CA3AF);
      statusText = const Color(0xFF4B5563);
      statusLabel = 'Suspended';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Colors.black, width: 3.5),
            left: BorderSide(color: Colors.black, width: 3.5),
            right: BorderSide(color: Colors.black, width: 3.5),
          ),
        ),
        child: Column(
          children: [
            // Modal Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Community Profile',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            onBrandPreview();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: MeetdayColors.accentYellow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: 2),
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
                                Text(
                                  'Brand preview',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE5E7EB), thickness: 1.5, height: 1),

            // Sheet Scrollable Body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Approval Status Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusBorder, width: 2),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusText,
                      ),
                    ),
                  ),
                  if (pendingRevision != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Your recent edit is pending admin review — brands still see the live version until it is approved.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Community Name & Logo Header
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black, width: 2.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: logoUrl != null && logoUrl.isNotEmpty
                              ? Image.network(
                                  logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.groups, size: 32),
                                )
                              : const Icon(Icons.groups, size: 32),
                        ),
                      ),
                      const SizedBox(width: 14),
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
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: MeetdayColors.accentYellow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                '$size MEMBERS',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // About The Community
                  _buildSectionHeader('About The Community'),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withAlpha(20)),
                    ),
                    child: Text(
                      about.isNotEmpty ? about : 'No description provided.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Community Poster (Secondary Image)
                  if (posterUrl != null && posterUrl.isNotEmpty) ...[
                    _buildSectionHeader('Community Poster'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => _PhotoLightboxDialog(
                            imageUrl: posterUrl,
                            title: 'Community Poster',
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                posterUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  'Tap to Zoom 🔍',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Past Experiences
                  if (pastEvents.isNotEmpty) ...[
                    _buildSectionHeader('Past Experiences'),
                    const SizedBox(height: 8),
                    ...pastEvents.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final event = entry.value as Map;
                      final eventName =
                          (event['name'] ?? 'Experience #${idx + 1}')
                              .toString();
                      final eventDesc = (event['description'] ?? '').toString();
                      final imageUrls =
                          (event['imageUrls'] as List?)
                              ?.map((e) => e.toString())
                              .toList() ??
                          [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withAlpha(20)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    eventName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'EXPERIENCE #${idx + 1}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (eventDesc.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                eventDesc,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                            if (imageUrls.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 80,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: imageUrls.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (ctx, imgIdx) => GestureDetector(
                                    onTap: () {
                                      showDialog<void>(
                                        context: ctx,
                                        builder: (_) => _PhotoLightboxDialog(
                                          imageUrl: imageUrls[imgIdx],
                                          title:
                                              '$eventName - Photo ${imgIdx + 1}',
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrls[imgIdx],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.image, size: 24),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Associated Brands
                  if (brandsWorkedWith.isNotEmpty) ...[
                    _buildSectionHeader('Associated Brands'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: brandsWorkedWith.map((brand) {
                        final b = brand as Map;
                        final brandName = (b['brandName'] ?? 'Brand')
                            .toString();
                        final brandLogo = b['logoUrl'] as String?;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
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
                              if (brandLogo != null &&
                                  brandLogo.isNotEmpty) ...[
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Image.network(
                                    brandLogo,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                brandName,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Stats Grid (Avg Guest Count & Experiences / Yr)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withAlpha(20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AVG GUEST COUNT',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$avgGuestCount guests',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withAlpha(20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXPERIENCES / YR',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black45,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$experiencesPerYear events',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Categories
                  if (categories.isNotEmpty) ...[
                    _buildSectionHeader('Experience Categories'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categories
                          .map(
                            (cat) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF7C3AED).withAlpha(60),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Operating Cities
                  if (operatingCities.isNotEmpty) ...[
                    _buildSectionHeader('Operating Cities'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: operatingCities
                          .map(
                            (city) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.black.withAlpha(30),
                                ),
                              ),
                              child: Text(
                                city,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Digital Presence (Social Links)
                  _buildSectionHeader('Digital Presence'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withAlpha(30)),
                    ),
                    child: Column(
                      children: [
                        _buildSocialRow('Instagram', instagram),
                        const Divider(color: Color(0xFFF3F4F6)),
                        _buildSocialRow('LinkedIn', linkedin),
                        const Divider(color: Color(0xFFF3F4F6)),
                        _buildSocialRow('YouTube', youtube),
                        const Divider(color: Color(0xFFF3F4F6)),
                        _buildSocialRow('Website', website),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Edit Community Details Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MeetdayColors.accentYellow,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.black, width: 2.5),
                      ),
                    ),
                    onPressed: onEdit,
                    child: Text(
                      'EDIT COMMUNITY DETAILS',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildSocialRow(String label, String? url) {
    final hasUrl = url != null && url.trim().isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        Text(
          hasUrl ? url : 'Not provided',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: hasUrl ? const Color(0xFF10B981) : Colors.black26,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Verifications Details Bottom Sheet (replicates VerificationsDetailsPanel.tsx)
// ─────────────────────────────────────────────────────────────────────────────
class _VerificationsDetailsSheet extends StatelessWidget {
  const _VerificationsDetailsSheet({required this.hostProfile});

  final Map<String, dynamic> hostProfile;

  @override
  Widget build(BuildContext context) {
    final kycStatus = (hostProfile['kycStatus'] ?? 'NOT_SUBMITTED')
        .toString()
        .toUpperCase();
    final panStatus = (hostProfile['panVerificationStatus'] ?? 'NOT_SUBMITTED')
        .toString()
        .toUpperCase();
    final bankStatus =
        (hostProfile['bankVerificationStatus'] ?? 'NOT_SUBMITTED')
            .toString()
            .toUpperCase();
    final kycFailureReason = hostProfile['kycFailureReason'] as String?;
    final isVerified = kycStatus == 'VERIFIED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.black, width: 3.5),
          left: BorderSide(color: Colors.black, width: 3.5),
          right: BorderSide(color: Colors.black, width: 3.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Verifications',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
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
          const SizedBox(height: 6),
          Text(
            'Verify your identity and bank credentials to host events and receive payouts.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),

          // Identity KYC Card
          _buildVerificationCard(
            title: 'Identity Verification',
            subtitle: 'Overall KYC Status',
            status: kycStatus,
          ),
          const SizedBox(height: 12),

          // PAN Card
          _buildVerificationCard(
            title: 'PAN Card',
            subtitle: 'Income tax identity check',
            status: panStatus,
          ),
          const SizedBox(height: 12),

          // Bank Account
          _buildVerificationCard(
            title: 'Bank Account',
            subtitle: 'Payout bank setup verification',
            status: bankStatus,
          ),

          if (kycFailureReason != null && kycFailureReason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: Text(
                'KYC Failed: $kycFailureReason',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB91C1C),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          if (!isVerified)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MeetdayColors.accentYellow,
                foregroundColor: Colors.black,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.black, width: 2.5),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please complete verification through the Meetday Portal.',
                    ),
                  ),
                );
              },
              child: Text(
                'VERIFY KYC NOW',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required String status,
  }) {
    Color bg = const Color(0xFFF3F4F6);
    Color fg = Colors.black54;
    IconData icon = Icons.access_time_rounded;

    if (status == 'VERIFIED' || status == 'APPROVED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      icon = Icons.check_circle_rounded;
    } else if (status == 'PENDING') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFFB45309);
      icon = Icons.access_time_rounded;
    } else if (status == 'FAILED' || status == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withAlpha(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Team Members Bottom Sheet (replicates TeamMembersModal.tsx)
// ─────────────────────────────────────────────────────────────────────────────
class _TeamMembersSheet extends ConsumerStatefulWidget {
  const _TeamMembersSheet({required this.communityName, this.isBrand = false});

  final String communityName;
  final bool isBrand;

  @override
  ConsumerState<_TeamMembersSheet> createState() => _TeamMembersSheetState();
}

class _TeamMembersSheetState extends ConsumerState<_TeamMembersSheet> {
  String _emailInput = '';
  bool _isInviting = false;
  Map<String, dynamic>? _memberToRemove;
  bool _isRemoving = false;

  Future<void> _invite() async {
    final email = _emailInput.trim();
    if (email.isEmpty) return;

    setState(() => _isInviting = true);
    try {
      final api = ref.read(apiClientProvider);
      if (widget.isBrand) {
        await api.inviteBrandTeamMember(email);
        ref.invalidate(brandTeamMembersProvider);
      } else {
        await api.inviteHostTeamMember(email);
        ref.invalidate(teamMembersProvider);
      }
      setState(() => _emailInput = '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Invitation sent successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to invite member: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _removeMember() async {
    final member = _memberToRemove;
    if (member == null) return;

    setState(() => _isRemoving = true);
    try {
      final api = ref.read(apiClientProvider);
      final memberId = (member['id'] ?? '').toString();
      if (widget.isBrand) {
        await api.removeBrandTeamMember(memberId);
        ref.invalidate(brandTeamMembersProvider);
      } else {
        await api.removeHostTeamMember(memberId);
        ref.invalidate(teamMembersProvider);
      }
      if (mounted) {
        setState(() => _memberToRemove = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Removed ${member['email']}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  Future<void> _togglePermission(String memberId, bool currentValue) async {
    try {
      final api = ref.read(apiClientProvider);
      if (widget.isBrand) {
        await api.setBrandMemberPermission(memberId, !currentValue);
        ref.invalidate(brandTeamMembersProvider);
      } else {
        await api.setHostMemberPermission(memberId, !currentValue);
        ref.invalidate(teamMembersProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentValue
                  ? '✅ Member can now manage team members'
                  : '✅ Member permissions updated',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update permission: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = widget.isBrand
        ? ref.watch(brandTeamMembersProvider)
        : ref.watch(teamMembersProvider);
    final data = membersAsync.asData?.value ?? <String, dynamic>{};
    final members = (data['members'] as List?) ?? [];
    final viewerCanManage = data['viewerCanManage'] == true;
    final viewerIsOwner = data['viewerIsOwner'] == true;

    // Show invite form if: user can manage OR is owner OR if members list loaded (assuming ownership)
    final canShowInvite =
        viewerCanManage || viewerIsOwner || members.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Colors.black, width: 3.5),
            left: BorderSide(color: Colors.black, width: 3.5),
            right: BorderSide(color: Colors.black, width: 3.5),
          ),
        ),
        child: Column(
          children: [
            // Modal Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Team Members',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Collaborators for ${widget.communityName}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE5E7EB), thickness: 1.5, height: 1),

            // INVITE FORM - FIXED (outside ListView)
            if (canShowInvite)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        setState(() => _emailInput = value);
                      },
                      onSubmitted: (_) => _invite(),
                      decoration: InputDecoration(
                        hintText: 'Enter teammate email',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MeetdayColors.primaryRed,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeetdayColors.primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      onPressed: _isInviting
                          ? null
                          : () {
                              _invite();
                            },
                      child: SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: _isInviting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '+ Invite',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    "You don't have permission to add members.",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // MEMBERS LIST - SCROLLABLE (inside ListView)
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (membersAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: MeetdayColors.primaryRed,
                        ),
                      ),
                    )
                  else if (members.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Center(
                        child: Text(
                          'No team members added yet.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    )
                  else
                    ...members.map((m) {
                      final member = m as Map;
                      final memberId = (member['id'] ?? '').toString();
                      final memberEmail = (member['email'] ?? '').toString();
                      final memberName = (member['name'] ?? 'Pending signup')
                          .toString();
                      final role = (member['role'] ?? 'MEMBER')
                          .toString()
                          .toUpperCase();
                      final isOwner = role == 'OWNER';
                      final canManage = member['canManageMembers'] == true;
                      final status = (member['status'] ?? 'ACTIVE')
                          .toString()
                          .toUpperCase();
                      final isPending = status == 'PENDING';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF1E1B4B),
                                  child: Text(
                                    memberEmail.isNotEmpty
                                        ? memberEmail[0].toUpperCase()
                                        : 'U',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        memberName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        memberEmail,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOwner
                                            ? MeetdayColors.accentYellow
                                            : Colors.black.withAlpha(15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isOwner ? 'OWNER' : 'MEMBER',
                                        style: GoogleFonts.poppins(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: isOwner
                                              ? Colors.black
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                    if (isPending) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: Text(
                                          'PENDING',
                                          style: GoogleFonts.poppins(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (canShowInvite && !isOwner)
                                  GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => _memberToRemove = member
                                            .cast<String, dynamic>(),
                                      );
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            _showRemovalConfirmation();
                                          });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: MeetdayColors.primaryRed,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            // Permission toggle (only for non-owner members, only if viewer is owner)
                            if (!isOwner && viewerIsOwner) ...[
                              const SizedBox(height: 8),
                              const Divider(
                                color: Color(0xFFF3F4F6),
                                height: 1,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Can add/remove members',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: canManage,
                                    thumbColor:
                                        WidgetStateProperty.resolveWith<Color>(
                                          (states) => Colors.white,
                                        ),
                                    trackColor:
                                        WidgetStateProperty.resolveWith<Color>((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.selected,
                                          )) {
                                            return MeetdayColors.primaryRed;
                                          }
                                          return Colors.black26;
                                        }),
                                    onChanged: (_) =>
                                        _togglePermission(memberId, canManage),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemovalConfirmation() {
    if (_memberToRemove == null) return;

    final memberEmail = (_memberToRemove!['email'] ?? '').toString();
    final communityName = widget.communityName;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 3),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Remove this member?',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$memberEmail will lose access to $communityName\'s dashboard immediately. If their invite is still pending, this email will no longer be able to join using the invite link.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogCtx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
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
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(dialogCtx).pop();
                      _removeMember();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        borderRadius: BorderRadius.circular(14),
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
                        child: _isRemoving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'REMOVE',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Edit Community Rep Profile Bottom Sheet (replicates EditProfilePanel.tsx)
// ─────────────────────────────────────────────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.hostProfile});

  final Map<String, dynamic> hostProfile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _communityNameController;
  late String _gender;
  late String _hostType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text:
          (widget.hostProfile['displayName'] ??
                  widget.hostProfile['legalName'] ??
                  '')
              .toString(),
    );
    _communityNameController = TextEditingController(
      text: (widget.hostProfile['communityName'] ?? '').toString(),
    );
    _gender = (widget.hostProfile['gender'] ?? 'PREFER_NOT_TO_SAY').toString();
    _hostType = (widget.hostProfile['hostType'] ?? 'INDIVIDUAL')
        .toString()
        .toUpperCase();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.updateHostProfile({
        'displayName': _displayNameController.text.trim(),
        'communityName': _communityNameController.text.trim(),
        'gender': _gender,
        'hostType': _hostType,
      });

      ref.invalidate(hostProfileProvider);
      ref.invalidate(communityProfileProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.black, width: 3.5),
          left: BorderSide(color: Colors.black, width: 3.5),
          right: BorderSide(color: Colors.black, width: 3.5),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Profile',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Display Name
            Text(
              'Display Name',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _displayNameController,
              decoration: _inputDecoration('e.g. Rahul Sharma'),
            ),
            const SizedBox(height: 14),

            // Community Name
            Text(
              'Community Name',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _communityNameController,
              decoration: _inputDecoration('e.g. Tech Creators Circle'),
            ),
            const SizedBox(height: 14),

            // Gender
            Text(
              'Gender',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _genderLabels.containsKey(_gender)
                  ? _gender
                  : 'PREFER_NOT_TO_SAY',
              decoration: _inputDecoration(''),
              items: _genderLabels.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _gender = val);
              },
            ),
            const SizedBox(height: 14),

            // Host Type
            Text(
              'Host Type',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _hostType == 'BUSINESS' ? 'BUSINESS' : 'INDIVIDUAL',
              decoration: _inputDecoration(''),
              items: const [
                DropdownMenuItem(
                  value: 'INDIVIDUAL',
                  child: Text('Individual Host'),
                ),
                DropdownMenuItem(
                  value: 'BUSINESS',
                  child: Text('Business Host'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _hostType = val);
              },
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MeetdayColors.primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.black, width: 2.5),
                ),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'SAVE CHANGES',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: MeetdayColors.primaryRed,
          width: 2.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4b. Edit Brand Profile Bottom Sheet (replicates EditBrandProfilePanel.tsx)
// ─────────────────────────────────────────────────────────────────────────────
class _EditBrandProfileSheet extends ConsumerStatefulWidget {
  const _EditBrandProfileSheet({required this.brandProfile});

  final Map<String, dynamic> brandProfile;

  @override
  ConsumerState<_EditBrandProfileSheet> createState() =>
      _EditBrandProfileSheetState();
}

class _EditBrandProfileSheetState
    extends ConsumerState<_EditBrandProfileSheet> {
  late final TextEditingController _brandNameController;
  late final TextEditingController _websiteController;
  late final TextEditingController _instagramController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _workEmailController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _aboutCompanyController;
  late String _companyType;
  late String _industry;
  List<Map<String, dynamic>> _categories = [];
  final Set<String> _selectedCategoryIds = {};
  XFile? _selectedLogo;
  Uint8List? _selectedLogoBytes;
  bool _isUploadingLogo = false;
  bool _isLoadingCategories = true;
  bool _isSaving = false;

  static const List<String> _industryOptions = [
    'Tech/SaaS',
    'Food & Beverage',
    'Fashion/Apparel',
    'Consumer Tech',
    'Health & Wellness',
    'FinTech',
    'Entertainment',
    'Alcobev',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.brandProfile;
    _brandNameController = TextEditingController(
      text: (p['brandName'] ?? p['displayName'] ?? '').toString(),
    );
    final social = p['socialLinks'] is Map ? p['socialLinks'] as Map : {};
    _websiteController = TextEditingController(
      text: (social['website'] ?? p['website'] ?? '').toString(),
    );
    _instagramController = TextEditingController(
      text: (social['instagram'] ?? '').toString(),
    );
    _linkedinController = TextEditingController(
      text: (social['linkedin'] ?? '').toString(),
    );
    _workEmailController = TextEditingController(
      text: (p['workEmail'] ?? p['email'] ?? '').toString(),
    );
    _contactPhoneController = TextEditingController(
      text: (p['contactPhone'] ?? p['phone'] ?? '').toString(),
    );
    _aboutCompanyController = TextEditingController(
      text: (p['aboutCompany'] ?? '').toString(),
    );
    _companyType = (p['companyType'] ?? 'BRAND').toString().toUpperCase();
    if (_companyType != 'BRAND' && _companyType != 'AGENCY') {
      _companyType = 'BRAND';
    }
    final rawInd = (p['industry'] ?? '').toString();
    _industry = _industryOptions.contains(rawInd) ? rawInd : 'Tech/SaaS';
    final existingCategories = p['categories'];
    if (existingCategories is List) {
      for (final category in existingCategories.whereType<Map>()) {
        final id = category['id']?.toString();
        if (id != null && id.isNotEmpty) _selectedCategoryIds.add(id);
      }
    }
    _loadBrandCategories();
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _workEmailController.dispose();
    _contactPhoneController.dispose();
    _aboutCompanyController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandCategories() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .getRequest('/categories');
      if (mounted && response is List) {
        setState(() {
          _categories = response
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (_) {
      // Category selection is optional; existing profile fields stay editable.
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _pickBrandLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _selectedLogo = file;
        _selectedLogoBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      String? uploadedLogoKey;
      if (_selectedLogo != null) {
        setState(() => _isUploadingLogo = true);
        uploadedLogoKey = await api.uploadMediaFile(
          bytes: await _selectedLogo!.readAsBytes(),
          fileName: _selectedLogo!.name,
          context: 'USER_AVATAR',
        );
        if (uploadedLogoKey == null) {
          throw const FormatException('Could not upload the brand logo.');
        }
      }
      final payload = <String, dynamic>{
        'brandName': _brandNameController.text.trim(),
        'companyType': _companyType,
        'industry': _industry,
        'aboutCompany': _aboutCompanyController.text.trim(),
        'categoryIds': _selectedCategoryIds.toList(),
        'socialLinks': {
          if (_websiteController.text.trim().isNotEmpty)
            'website': _websiteController.text.trim(),
          if (_instagramController.text.trim().isNotEmpty)
            'instagram': _instagramController.text.trim(),
          if (_linkedinController.text.trim().isNotEmpty)
            'linkedin': _linkedinController.text.trim(),
        },
        if (_workEmailController.text.trim().isNotEmpty)
          'workEmail': _workEmailController.text.trim(),
        if (_contactPhoneController.text.trim().isNotEmpty)
          'contactPhone': _contactPhoneController.text.trim(),
        if (uploadedLogoKey != null) 'logoKey': uploadedLogoKey,
      };

      await api.updateBrandProfile(payload);
      ref.invalidate(brandProfileProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Brand profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update brand profile: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingLogo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.black, width: 3.5),
          left: BorderSide(color: Colors.black, width: 3.5),
          right: BorderSide(color: Colors.black, width: 3.5),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Brand Profile',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Brand Name
            Text(
              'Brand Name',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _brandNameController,
              decoration: _inputDecoration('e.g. Acme Corp'),
            ),
            const SizedBox(height: 14),

            Text(
              'Company Logo',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedLogoBytes != null
                      ? Image.memory(_selectedLogoBytes!, fit: BoxFit.cover)
                      : (widget.brandProfile['logoUrl']
                                    ?.toString()
                                    .isNotEmpty ==
                                true
                            ? Image.network(
                                widget.brandProfile['logoUrl'].toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.business_rounded),
                              )
                            : const Icon(Icons.business_rounded)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickBrandLogo,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: Text(_isUploadingLogo ? 'Uploading…' : 'Upload logo'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Company Type (Brand vs Agency)
            Text(
              'Company Type',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _companyType,
              decoration: _inputDecoration(''),
              items: const [
                DropdownMenuItem(value: 'BRAND', child: Text('Brand')),
                DropdownMenuItem(value: 'AGENCY', child: Text('Agency')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _companyType = val);
              },
            ),
            const SizedBox(height: 14),

            Text(
              'Categories',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (_isLoadingCategories)
              const LinearProgressIndicator(minHeight: 2)
            else
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: _categories.map((category) {
                  final id = category['id']?.toString() ?? '';
                  final name = category['name']?.toString() ?? '';
                  if (id.isEmpty || name.isEmpty)
                    return const SizedBox.shrink();
                  return FilterChip(
                    label: Text(name),
                    selected: _selectedCategoryIds.contains(id),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedCategoryIds.add(id);
                      } else {
                        _selectedCategoryIds.remove(id);
                      }
                    }),
                  );
                }).toList(),
              ),
            const SizedBox(height: 14),

            // Industry
            Text(
              'Industry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _industry,
              decoration: _inputDecoration(''),
              items: _industryOptions
                  .map((ind) => DropdownMenuItem(value: ind, child: Text(ind)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _industry = val);
              },
            ),
            const SizedBox(height: 14),

            // Website
            Text(
              'Website',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _websiteController,
              decoration: _inputDecoration('e.g. https://brand.com'),
            ),
            const SizedBox(height: 14),

            Text(
              'Instagram',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _instagramController,
              keyboardType: TextInputType.url,
              decoration: _inputDecoration('https://instagram.com/brand'),
            ),
            const SizedBox(height: 14),

            Text(
              'LinkedIn',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _linkedinController,
              keyboardType: TextInputType.url,
              decoration: _inputDecoration(
                'https://linkedin.com/company/brand',
              ),
            ),
            const SizedBox(height: 14),

            // Work Email
            Text(
              'Work Email',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _workEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration('e.g. hello@brand.com'),
            ),
            const SizedBox(height: 14),

            // Contact Phone
            Text(
              'Contact Phone',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('e.g. +91 9876543210'),
            ),
            const SizedBox(height: 14),

            // About Company
            Text(
              'About The Company',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _aboutCompanyController,
              maxLines: 3,
              decoration: _inputDecoration(
                'Tell us about your brand and products...',
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MeetdayColors.primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.black, width: 2.5),
                ),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'SAVE CHANGES',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: MeetdayColors.primaryRed,
          width: 2.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Photo Lightbox Dialog (Tap-to-zoom for posters and event photos)
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoLightboxDialog extends StatelessWidget {
  const _PhotoLightboxDialog({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(230),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white30, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
