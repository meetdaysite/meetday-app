import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/meetday_colors.dart';
import '../../auth/domain/account_role.dart';
import '../../auth/state/auth_provider.dart';
import '../../community/presentation/profile/profile_screen.dart';

class MeetdaySidebarDrawer extends ConsumerStatefulWidget {
  const MeetdaySidebarDrawer({
    super.key,
    required this.currentTabIndex,
    required this.onSelectTab,
    this.communityName,
    this.avatarUrl,
    this.role,
  });

  final int currentTabIndex;
  final ValueChanged<int> onSelectTab;
  final String? communityName;
  final String? avatarUrl;
  final AccountRole? role;

  @override
  ConsumerState<MeetdaySidebarDrawer> createState() => _MeetdaySidebarDrawerState();
}

class _MeetdaySidebarDrawerState extends ConsumerState<MeetdaySidebarDrawer> {
  bool _showIncompleteCard = true;

  void _showSignOutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(6, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign Out',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to sign out of your Meetday workspace?',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF525252),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(dialogCtx).pop();
                        Navigator.of(context).pop(); // close drawer
                        await ref.read(authControllerProvider.notifier).signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeetdayColors.primaryRed,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.black, width: 2),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.communityName?.isNotEmpty == true
        ? widget.communityName!
        : (widget.role == AccountRole.brand ? 'My Brand' : 'My Community');

    return Drawer(
      backgroundColor: MeetdayColors.primaryRed,
      elevation: 0,
      width: 290,
      child: SafeArea(
        child: Column(
          children: [
            // Top Meetday Logo Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SvgPicture.asset(
                    'assets/logo/meetday-white.svg',
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Top Primary Navigation items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  _DrawerNavItem(
                    label: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    isActive: widget.currentTabIndex == 0,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(0);
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerNavItem(
                    label: widget.role == AccountRole.brand
                        ? 'Curated Experiences'
                        : 'Experience Proposals',
                    icon: Icons.description_outlined,
                    activeIcon: Icons.description,
                    isActive: widget.currentTabIndex == 1,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(1);
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerNavItem(
                    label: 'Brand Campaigns',
                    icon: Icons.rocket_launch_outlined,
                    activeIcon: Icons.rocket_launch,
                    badgeText: 'SOON',
                    isActive: false,
                    disabled: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 4),
                  _DrawerNavItem(
                    label: 'Community Hubs',
                    icon: Icons.calendar_today_outlined,
                    activeIcon: Icons.calendar_today,
                    isActive: widget.currentTabIndex == 2,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(2);
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerNavItem(
                    label: 'Communities',
                    icon: Icons.groups_outlined,
                    activeIcon: Icons.groups,
                    isActive: widget.currentTabIndex == 3,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(3);
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerNavItem(
                    label: 'Locked Deals',
                    icon: Icons.lock_outline,
                    activeIcon: Icons.lock,
                    isActive: widget.currentTabIndex == 4,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(4);
                    },
                  ),
                ],
              ),
            ),

            // Middle section (Incomplete Profile Alert Card)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    if (_showIncompleteCard) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEAA7),
                          border: Border.all(color: Colors.black, width: 3),
                          borderRadius: BorderRadius.circular(20),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Incomplete Profile',
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111111),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _showIncompleteCard = false),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Complete your profile to be eligible for sponsorships and collaboration.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProfileScreen(
                                      initialOpenPanel: 'community',
                                      onSelectTab: widget.onSelectTab,
                                      currentTabIndex: widget.currentTabIndex,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: MeetdayColors.accentYellow,
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
                                    'COMPLETE NOW',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Navigation Items (Chats, Support, Notifications)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                children: [
                  _DrawerNavItem(
                    label: 'Chats',
                    svgAsset: 'assets/icons/chat.svg',
                    activeSvgAsset: 'assets/icons/chat-filled.svg',
                    badgeCount: 2,
                    isActive: widget.currentTabIndex == 4,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(4); // Chats tab
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerNavItem(
                    label: 'Support Chat',
                    icon: Icons.headset_mic_outlined,
                    activeIcon: Icons.headset_mic,
                    isActive: widget.currentTabIndex == 5,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(5);
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerNavItem(
                    label: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                    activeIcon: Icons.notifications_rounded,
                    hasUnreadDot: true,
                    isActive: widget.currentTabIndex == 6,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelectTab(6);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Bottom Profile Button / Pill (matches website: navigates to /community/dashboard/profile)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: MeetdayColors.accentYellow,
                        border: Border.all(color: Colors.black, width: 3),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Center(
                              child: widget.avatarUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        widget.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.person,
                                          size: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: Colors.black,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  widget.role?.label ?? 'Workspace',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showSignOutDialog(context),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: Colors.black,
                              ),
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
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.label,
    this.icon,
    this.activeIcon,
    this.svgAsset,
    this.activeSvgAsset,
    required this.isActive,
    required this.onTap,
    this.badgeText,
    this.badgeCount,
    this.hasUnreadDot = false,
    this.disabled = false,
  });

  final String label;
  final IconData? icon;
  final IconData? activeIcon;
  final String? svgAsset;
  final String? activeSvgAsset;
  final bool isActive;
  final VoidCallback onTap;
  final String? badgeText;
  final int? badgeCount;
  final bool hasUnreadDot;
  final bool disabled;

  Widget _buildIcon(Color color) {
    if (svgAsset != null) {
      final path = (isActive && activeSvgAsset != null) ? activeSvgAsset! : svgAsset!;
      return SvgPicture.asset(
        path,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(
      isActive ? (activeIcon ?? icon) : (icon ?? activeIcon),
      size: 20,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (disabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildIcon(Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
            if (badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText!,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? MeetdayColors.redPressed : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildIcon(Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: MeetdayColors.accentYellow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            if (hasUnreadDot)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: MeetdayColors.accentYellow,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
