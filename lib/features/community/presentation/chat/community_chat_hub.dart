import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../providers/chat_provider.dart';

// ─── Format Helpers ──────────────────────────────────────────────────────────

String _timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

String _shortTimeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  } catch (_) {
    return '';
  }
}

String _messageTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final min = local.minute.toString().padLeft(2, '0');
  return '$hour:$min $period';
}

// ─── Main Chat Hub Screen ────────────────────────────────────────────────────

class CommunityChatHubScreen extends ConsumerStatefulWidget {
  const CommunityChatHubScreen({
    super.key,
    this.initialCategory,
  });

  final String? initialCategory;

  @override
  ConsumerState<CommunityChatHubScreen> createState() => _CommunityChatHubScreenState();
}

class _CommunityChatHubScreenState extends ConsumerState<CommunityChatHubScreen> {
  // 'landing' or 'active'
  String _viewMode = 'landing';
  String _activeCategory = 'sponsorships';
  String _activeQueue = 'INCOMING'; // 'INCOMING' or 'OUTGOING'
  String _categoryFilter = 'ALL';
  String _landingSearchQuery = '';
  String _activeSearchQuery = '';
  String? _respondingId;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _activeCategory = widget.initialCategory!;
      _viewMode = 'active';
    }
  }

  void _openCategory(String catKey) {
    setState(() {
      _activeCategory = catKey;
      _viewMode = 'active';
      _activeSearchQuery = '';
    });
  }

  void _backToLanding() {
    setState(() {
      _viewMode = 'landing';
      _landingSearchQuery = '';
    });
  }

  void _openThread(UnifiedActiveThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(thread: thread),
      ),
    );
  }

  Future<void> _handleAcceptRequest(UnifiedRequestItem request) async {
    setState(() {
      _respondingId = request.id;
    });

    try {
      final api = ref.read(apiClientProvider);
      final id = request.id;

      switch (request.kind) {
        case 'SPONSORSHIP':
        case 'CAMPAIGN':
          await api.dio.post<dynamic>('/sponsorships/chats/$id/accept');
          break;
        case 'SPACE_INTEREST':
          await api.dio.post<dynamic>('/spaces/chats/$id/accept', queryParameters: {'role': 'COMMUNITY'});
          break;
        case 'SPACE_HOST':
          await api.dio.post<dynamic>('/space-host/chats/$id/accept', queryParameters: {'role': 'HOST'});
          break;
        case 'COMMUNITY_COLLAB':
          if (request.category == 'brands') {
            await api.dio.post<dynamic>('/brand-community-collaboration/chats/$id/accept', queryParameters: {'asRole': 'COMMUNITY'});
          } else {
            await api.dio.post<dynamic>('/community-collaboration/chats/$id/accept');
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted collaboration request from ${request.counterpartName}!'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }

      ref.invalidate(chatHubProvider);

      setState(() {
        _activeCategory = request.category;
        _viewMode = 'active';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _respondingId = null;
        });
      }
    }
  }

  Future<void> _handleDeclineRequest(UnifiedRequestItem request) async {
    setState(() {
      _respondingId = request.id;
    });

    try {
      final api = ref.read(apiClientProvider);
      final id = request.id;

      switch (request.kind) {
        case 'SPACE_INTEREST':
          await api.dio.post<dynamic>('/spaces/chats/$id/decline', queryParameters: {'role': 'COMMUNITY'});
          break;
        case 'COMMUNITY_COLLAB':
          if (request.category == 'brands') {
            await api.dio.post<dynamic>('/brand-community-collaboration/chats/$id/decline', queryParameters: {'asRole': 'COMMUNITY'});
          } else {
            await api.dio.post<dynamic>('/community-collaboration/chats/$id/decline');
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request declined'),
            backgroundColor: Colors.black87,
          ),
        );
      }

      ref.invalidate(chatHubProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _respondingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatHubAsync = ref.watch(chatHubProvider);

    return chatHubAsync.when(
      data: (data) {
        if (_viewMode == 'active') {
          return _buildActiveView(data);
        }
        return _buildLandingView(data);
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: MeetdayColors.primaryRed,
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42, color: MeetdayColors.primaryRed),
              const SizedBox(height: 12),
              Text(
                'Could not load chats',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF667085)),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.refresh(chatHubProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: MeetdayColors.primaryRed,
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
                  child: Text(
                    'Retry',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 1. LANDING VIEW (Exact Website Mobile Replicate: Header, Categories, Box)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildLandingView(ChatHubData data) {
    // Filter requests by queue direction (INCOMING vs OUTGOING), category filter, and search
    final filteredRequests = data.allRequests.where((req) {
      if (req.direction != _activeQueue) return false;
      if (_categoryFilter != 'ALL' && req.category != _categoryFilter) return false;
      if (_landingSearchQuery.trim().isNotEmpty) {
        final q = _landingSearchQuery.toLowerCase().trim();
        final matchName = req.counterpartName.toLowerCase().contains(q);
        final matchTitle = req.title.toLowerCase().contains(q);
        final matchSub = (req.subtitle ?? '').toLowerCase().contains(q);
        if (!matchName && !matchTitle && !matchSub) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      color: MeetdayColors.primaryRed,
      onRefresh: () async => ref.refresh(chatHubProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ─── Header ──────────────────────────────────────────────────────────
          Text(
            'Chats & Requests Hub',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Select a category to view active conversations, or manage your requests below.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          // ─── Chat Categories Section ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CHAT CATEGORIES',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Colors.black54,
                ),
              ),
              Text(
                'Choose a category to open conversations',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Category Entry Cards matching ChatHubLandingView.tsx
          ...data.categories.map((cat) => _buildCategoryCard(cat)),

          const SizedBox(height: 26),

          // ─── Requests Hub Header ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REQUESTS HUB',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Incoming requests & outgoing inquiries',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),

              // Queue Switcher Navtab: Incoming vs Sent
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0x0F000000), // bg-black/5
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1F000000), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Incoming Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeQueue = 'INCOMING';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _activeQueue == 'INCOMING' ? MeetdayColors.primaryRed : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeQueue == 'INCOMING'
                              ? const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Incoming',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _activeQueue == 'INCOMING' ? Colors.white : Colors.black54,
                              ),
                            ),
                            if (data.incomingCount > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _activeQueue == 'INCOMING' ? Colors.white : MeetdayColors.accentYellow,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _activeQueue == 'INCOMING' ? Colors.transparent : Colors.black12,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${data.incomingCount}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: _activeQueue == 'INCOMING' ? MeetdayColors.primaryRed : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Sent Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeQueue = 'OUTGOING';
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _activeQueue == 'OUTGOING' ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeQueue == 'OUTGOING'
                              ? const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sent',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _activeQueue == 'OUTGOING' ? Colors.white : Colors.black54,
                              ),
                            ),
                            if (data.sentCount > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _activeQueue == 'OUTGOING' ? MeetdayColors.accentYellow : const Color(0x1F000000),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${data.sentCount}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
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
            ],
          ),
          const SizedBox(height: 12),

          // ─── The Requests Box Container (Exact Website Styling) ──────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Toolbar: Category Pills & Search Input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFA),
                    border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
                  ),
                  child: Column(
                    children: [
                      // Horizontal Category Filter Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterPill('ALL', 'All', _categoryFilter == 'ALL', data.allRequests),
                            _filterPill('sponsorships', 'Sponsorships', _categoryFilter == 'sponsorships', data.allRequests),
                            _filterPill('spaces', 'Hubs', _categoryFilter == 'spaces', data.allRequests),
                            _filterPill('communities', 'Communities', _categoryFilter == 'communities', data.allRequests),
                            _filterPill('brands', 'Brands', _categoryFilter == 'brands', data.allRequests),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Search requests… input
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33000000), width: 2),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            const Icon(Icons.search_rounded, size: 16, color: Colors.black38),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                onChanged: (val) {
                                  setState(() {
                                    _landingSearchQuery = val;
                                  });
                                },
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: 'Search requests…',
                                  hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.black38),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            if (_landingSearchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _landingSearchQuery = '';
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.close_rounded, size: 14, color: Colors.black45),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Request Cards Feed
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: filteredRequests.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _activeQueue == 'INCOMING'
                                      ? 'No incoming requests pending'
                                      : 'No sent requests in this category',
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _activeQueue == 'INCOMING'
                                      ? 'When counterparts reach out, their requests will appear here.'
                                      : 'Any requests you have sent will be tracked here.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black45,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: filteredRequests.map((req) => _buildRequestCard(req)).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Entry Card (Matching ChatHubLandingView.tsx) ───────────────────

  Widget _buildCategoryCard(CategoryDefinition cat) {
    Color iconBg = MeetdayColors.accentYellow;
    Color iconCol = Colors.black;
    IconData iconData = Icons.description_outlined;

    switch (cat.key) {
      case 'sponsorships':
        iconBg = MeetdayColors.accentYellow;
        iconCol = Colors.black;
        iconData = Icons.description_outlined;
        break;
      case 'spaces':
        iconBg = Colors.black;
        iconCol = Colors.white;
        iconData = Icons.calendar_today_outlined;
        break;
      case 'communities':
        iconBg = MeetdayColors.accentYellow;
        iconCol = Colors.black;
        iconData = Icons.groups_outlined;
        break;
      case 'brands':
        iconBg = MeetdayColors.primaryRed;
        iconCol = Colors.white;
        iconData = Icons.local_offer_outlined;
        break;
    }

    final hasUnread = cat.badgeCount > 0;
    final hasPending = cat.pendingRequestsCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openCategory(cat.key),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black, width: 3),
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
                // Top Row: Icon Box + Title & Subtitle + Red Unread Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2.5),
                      ),
                      child: Center(
                        child: Icon(iconData, size: 22, color: iconCol),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.label,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            cat.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0x99000000), // text-black/60
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (hasUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: MeetdayColors.primaryRed,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(
                          cat.badgeCount > 9 ? '9+' : '${cat.badgeCount}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bottom Meta Row: Green Live Dot + Active Count | Pending Pill or "Open →"
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x1F000000), width: 1.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x4D000000), width: 1),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${cat.activeCount} active conversation${cat.activeCount == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xCC000000), // text-black/80
                            ),
                          ),
                        ],
                      ),

                      if (hasPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: MeetdayColors.accentYellow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Text(
                            '${cat.pendingRequestsCount} pending',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Open →',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0x99000000),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Filter Pills inside Requests Box ────────────────────────────────────────

  Widget _filterPill(String key, String label, bool isSelected, List<UnifiedRequestItem> allReqs) {
    final count = key == 'ALL'
        ? allReqs.where((r) => r.direction == _activeQueue).length
        : allReqs.where((r) => r.direction == _activeQueue && r.category == key).length;

    Color pillBg = Colors.white;
    Color textColor = const Color(0x99000000);
    Color borderColor = const Color(0x1F000000);
    Color badgeBg = const Color(0x1A000000);
    Color badgeText = const Color(0xB3000000);

    if (isSelected) {
      switch (key) {
        case 'sponsorships':
        case 'communities':
          pillBg = MeetdayColors.accentYellow;
          textColor = Colors.black;
          borderColor = Colors.black;
          badgeBg = Colors.black;
          badgeText = Colors.white;
          break;
        case 'brands':
          pillBg = MeetdayColors.primaryRed;
          textColor = Colors.white;
          borderColor = Colors.black;
          badgeBg = Colors.white;
          badgeText = MeetdayColors.primaryRed;
          break;
        case 'ALL':
        case 'spaces':
        default:
          pillBg = Colors.black;
          textColor = Colors.white;
          borderColor = Colors.black;
          badgeBg = MeetdayColors.accentYellow;
          badgeText = Colors.black;
          break;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _categoryFilter = key;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: badgeText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Request Card inside Feed (Matching ChatHubLandingView.tsx) ──────────────

  Widget _buildRequestCard(UnifiedRequestItem req) {
    final isIncoming = req.direction == 'INCOMING';
    final isResponding = _respondingId == req.id;
    final timeStr = _timeAgo(req.createdAt);

    Color badgeBg = const Color(0x1F000000);
    Color badgeText = Colors.black;
    Color badgeBorder = const Color(0x33000000);

    switch (req.category) {
      case 'sponsorships':
        badgeBg = MeetdayColors.accentYellow;
        badgeText = Colors.black;
        badgeBorder = const Color(0x33000000);
        break;
      case 'spaces':
        badgeBg = const Color(0x1F000000);
        badgeText = Colors.black;
        badgeBorder = const Color(0x33000000);
        break;
      case 'communities':
        badgeBg = const Color(0x40FFC940);
        badgeText = Colors.black;
        badgeBorder = const Color(0x33000000);
        break;
      case 'brands':
        badgeBg = const Color(0x26EE2C2C);
        badgeText = MeetdayColors.primaryRed;
        badgeBorder = const Color(0x4DEE2C2C);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Category Pill, Timestamp
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(req.counterpartAvatarUrl, req.counterpartName, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            req.counterpartName,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeBorder, width: 1),
                          ),
                          child: Text(
                            req.category.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: badgeText,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            '• $timeStr',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.title,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xB3000000), // text-black/70
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Description or message preview
          const SizedBox(height: 6),
          Text(
            req.description ?? req.lastMessagePreview ?? (isIncoming ? 'Requested connection with your profile.' : 'You sent a connection request.'),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0x80000000), // text-black/50
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // Actions Row
          if (isIncoming)
            Row(
              children: [
                // Accept Button (Green #22C55E)
                GestureDetector(
                  onTap: isResponding ? null : () => _handleAcceptRequest(req),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
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
                    child: isResponding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Accept',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 8),

                // Decline Button (White)
                GestureDetector(
                  onTap: isResponding ? null : () => _handleDeclineRequest(req),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0x0F000000), // bg-black/5
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x26000000), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: MeetdayColors.accentYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Awaiting Response',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0x99000000),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 2. ACTIVE VIEW (Matching ChatHubActiveView.tsx for Phones)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildActiveView(ChatHubData data) {
    final activeThreads = data.activeThreadsByCategory[_activeCategory] ?? [];

    final filteredThreads = activeThreads.where((t) {
      if (_activeSearchQuery.trim().isEmpty) return true;
      final q = _activeSearchQuery.toLowerCase().trim();
      return t.counterpartName.toLowerCase().contains(q) ||
          t.title.toLowerCase().contains(q) ||
          (t.lastMessagePreview ?? '').toLowerCase().contains(q);
    }).toList();

    String headingTitle = 'Sponsorship Chats';
    String headingSubtitle = 'Talk to brands interested in your proposals.';

    switch (_activeCategory) {
      case 'sponsorships':
        headingTitle = 'Sponsorship Chats';
        headingSubtitle = 'Talk to brands interested in your proposals.';
        break;
      case 'spaces':
        headingTitle = 'Hubs Chats';
        headingSubtitle = 'Collaborate with Community Hubs and manage your requests.';
        break;
      case 'communities':
        headingTitle = 'Community Chats';
        headingSubtitle = 'Collaborate with other communities and manage partnership chats.';
        break;
      case 'brands':
        headingTitle = 'Brand Chats';
        headingSubtitle = 'Manage hub bookings and inquiries from brands.';
        break;
    }

    return Column(
      children: [
        // Top Area: Back link, Title, and Horizontal Navtab Switcher
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0x1F000000), width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back to Chats & Requests Hub Link
              GestureDetector(
                onTap: _backToLanding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      'Back to Chats & Requests Hub',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Dynamic Category Heading & Subtitle
              Text(
                headingTitle,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                headingSubtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),

              // Category Navtab Switcher (All 4 categories with pills matching website)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0x0F000000), // bg-black/5
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x1F000000), width: 2),
                  ),
                  child: Row(
                    children: data.categories.map((cat) {
                      final isSelected = cat.key == _activeCategory;
                      final hasUnread = cat.badgeCount > 0;

                      Color tabBg = Colors.transparent;
                      Color tabText = const Color(0x99000000);
                      Color badgeBg = MeetdayColors.primaryRed;
                      Color badgeTextColor = Colors.white;

                      if (isSelected) {
                        switch (cat.key) {
                          case 'sponsorships':
                          case 'communities':
                            tabBg = MeetdayColors.accentYellow;
                            tabText = Colors.black;
                            badgeBg = Colors.black;
                            badgeTextColor = Colors.white;
                            break;
                          case 'brands':
                            tabBg = MeetdayColors.primaryRed;
                            tabText = Colors.white;
                            badgeBg = Colors.white;
                            badgeTextColor = MeetdayColors.primaryRed;
                            break;
                          case 'spaces':
                          default:
                            tabBg = Colors.black;
                            tabText = Colors.white;
                            badgeBg = MeetdayColors.primaryRed;
                            badgeTextColor = Colors.white;
                            break;
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeCategory = cat.key;
                            _activeSearchQuery = '';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tabBg,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cat.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  color: tabText,
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    cat.badgeCount > 9 ? '9+' : '${cat.badgeCount}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: badgeTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ─── Main Box: Search + Conversation List ─────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Container(
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
                children: [
                  // Search Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFA),
                      border: Border(bottom: BorderSide(color: Color(0x1F000000), width: 2)),
                    ),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x33000000), width: 2),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          const Icon(Icons.search_rounded, size: 16, color: Colors.black38),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                setState(() {
                                  _activeSearchQuery = val;
                                });
                              },
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Search conversations…',
                                hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          if (_activeSearchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeSearchQuery = '';
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.close_rounded, size: 14, color: Colors.black45),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Conversations List
                  Expanded(
                    child: filteredThreads.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _activeSearchQuery.isNotEmpty
                                        ? 'No matching conversations found.'
                                        : 'No active conversations in this category yet.',
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Accepted inquiries will automatically show up here.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black45,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredThreads.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0x1F000000),
                            ),
                            itemBuilder: (context, index) {
                              final thread = filteredThreads[index];
                              return _buildActiveThreadRow(thread);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Active Conversation Row (Matching ChatHubActiveView.tsx) ───────────────

  Widget _buildActiveThreadRow(UnifiedActiveThread thread) {
    final unread = thread.unreadCount;
    final timeStr = _shortTimeAgo(thread.lastMessageAt ?? thread.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openThread(thread),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with unread indicator badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _avatar(thread.counterpartAvatarUrl, thread.counterpartName, size: 40),
                  if (unread > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: MeetdayColors.primaryRed,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: GoogleFonts.poppins(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Counterpart Name, Deal status icon, Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  thread.counterpartName,
                                  style: GoogleFonts.bricolageGrotesque(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (thread.isDealClosed) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                                ),
                              ] else if (thread.isDealLocked) ...[
                                const SizedBox(width: 5),
                                const Icon(Icons.lock, size: 12, color: Colors.black54),
                              ],
                            ],
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                              color: unread > 0 ? MeetdayColors.primaryRed : Colors.black38,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 1),

                    // Proposal / Item title
                    Text(
                      thread.title,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0x80000000), // text-black/50
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Last message snippet
                    if (thread.lastMessagePreview?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        thread.lastMessagePreview!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          color: unread > 0 ? Colors.black87 : const Color(0x66000000), // text-black/40
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  }

  // ─── Reusable Avatar ────────────────────────────────────────────────────────

  Widget _avatar(String? url, String name, {double size = 40}) {
    final initials = name.trim().isNotEmpty
        ? (name.trim().length > 2 ? name.trim().substring(0, 2).toUpperCase() : name.trim().toUpperCase())
        : 'MD';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initials,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w900,
                    color: Colors.black54,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initials,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  color: Colors.black54,
                ),
              ),
            ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. INDIVIDUAL CHAT CONVERSATION SCREEN (Matching ActiveConversationPane)
// ═════════════════════════════════════════════════════════════════════════════

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.thread,
  });

  final UnifiedActiveThread thread;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _hasInitiallyScrolled = false;
  bool _showEmojiPicker = false;
  UnifiedChatMessage? _replyingTo;
  UnifiedChatMessage? _editingMessage;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _sendMessage({String? mediaUrl, String? mediaKey}) async {
    final text = _textController.text.trim();
    if (text.isEmpty && mediaUrl == null && mediaKey == null) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    final api = ref.read(apiClientProvider);
    final id = widget.thread.id;

    try {
      if (_editingMessage != null) {
        await editChatMessageApi(api, widget.thread, _editingMessage!.id, text);
        setState(() {
          _editingMessage = null;
          _textController.clear();
        });
      } else {
        final payload = <String, dynamic>{
          if (text.isNotEmpty) 'content': text,
        };
        if (mediaUrl != null) payload['mediaUrl'] = mediaUrl;
        if (mediaKey != null) payload['mediaKey'] = mediaKey;
        if (_replyingTo != null) payload['replyToId'] = _replyingTo!.id;

        switch (widget.thread.kind) {
          case 'SPONSORSHIP':
          case 'CAMPAIGN':
            payload['asRole'] = 'HOST';
            await api.dio.post<dynamic>('/sponsorships/chats/$id/messages', data: payload);
            break;
          case 'SPACE_INTEREST':
            payload['asRole'] = 'COMMUNITY';
            await api.dio.post<dynamic>('/spaces/chats/$id/messages', data: payload);
            break;
          case 'SPACE_HOST':
            payload['asRole'] = 'HOST';
            await api.dio.post<dynamic>('/space-host/chats/$id/messages', data: payload);
            break;
          case 'COMMUNITY_COLLAB':
            if (widget.thread.category == 'brands') {
              await api.dio.post<dynamic>(
                '/brand-community-collaboration/chats/$id/messages',
                queryParameters: {'asRole': 'COMMUNITY'},
                data: payload,
              );
            } else {
              await api.dio.post<dynamic>(
                '/community-collaboration/chats/$id/messages',
                data: payload,
              );
            }
            break;
        }

        setState(() {
          _textController.clear();
          _replyingTo = null;
          _showEmojiPicker = false;
        });
      }

      ref.invalidate(chatMessagesProvider(widget.thread));
      ref.invalidate(chatHubProvider);

      Future.delayed(const Duration(milliseconds: 150), () {
        _scrollToBottom(animated: true);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handleDelete(UnifiedChatMessage msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        title: Text(
          'Delete Message',
          style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete this message? This cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MeetdayColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = ref.read(apiClientProvider);
        await deleteChatMessageApi(api, widget.thread, msg.id);
        ref.invalidate(chatMessagesProvider(widget.thread));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete message: $e'), backgroundColor: MeetdayColors.primaryRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<UnifiedChatMessage>>>(
      chatMessagesProvider(widget.thread),
      (previous, next) {
        if (next.hasValue && (next.value?.isNotEmpty ?? false)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(animated: _hasInitiallyScrolled);
            _hasInitiallyScrolled = true;
          });
        }
      },
    );

    final messagesAsync = ref.watch(chatMessagesProvider(widget.thread));

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 2.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.thread.counterpartAvatarUrl != null && widget.thread.counterpartAvatarUrl!.isNotEmpty
                  ? Image.network(
                      widget.thread.counterpartAvatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          widget.thread.counterpartName.isNotEmpty ? widget.thread.counterpartName[0] : 'U',
                          style: GoogleFonts.bricolageGrotesque(fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        widget.thread.counterpartName.isNotEmpty ? widget.thread.counterpartName[0] : 'U',
                        style: GoogleFonts.bricolageGrotesque(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.thread.counterpartName,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.thread.counterpartType != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0x1A000000),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            widget.thread.counterpartType!.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    widget.thread.title,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            onPressed: () {
              ref.invalidate(chatMessagesProvider(widget.thread));
              ref.invalidate(threadDealProvider(widget.thread));
              ref.invalidate(threadReportProvider(widget.thread));
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Pinned Deal Banner matching website
            _buildDealBanner(),

            // Messages Scroll Area
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.waving_hand_rounded, size: 40, color: MeetdayColors.accentYellow),
                            const SizedBox(height: 8),
                            Text(
                              'Active Conversation Started',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Say hello to ${widget.thread.counterpartName} and start collaborating!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_hasInitiallyScrolled && _scrollController.hasClients) {
                      _scrollToBottom(animated: false);
                      _hasInitiallyScrolled = true;
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(msg);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
                ),
                error: (err, stack) => Center(
                  child: Text('Failed to load messages: $err'),
                ),
              ),
            ),

            // Replying banner above composer
            if (_replyingTo != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                color: const Color(0xFFF9FAFB),
                child: Row(
                  children: [
                    Container(width: 3.5, height: 28, color: MeetdayColors.primaryRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REPLYING TO ${_replyingTo!.senderType == 'ADMIN' ? 'ADMIN' : (_replyingTo!.isMe ? 'YOU' : widget.thread.counterpartName.toUpperCase())}',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: MeetdayColors.primaryRed,
                            ),
                          ),
                          Text(
                            _replyingTo!.content.isNotEmpty ? _replyingTo!.content : 'Attachment',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),
            ],

            // Editing status banner above composer
            if (_editingMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                color: const Color(0xFFFFFBEB),
                child: Row(
                  children: [
                    Container(width: 3.5, height: 28, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EDITING MESSAGE',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                          Text(
                            _editingMessage!.content,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.black54),
                      onPressed: () => setState(() {
                        _editingMessage = null;
                        _textController.clear();
                      }),
                    ),
                  ],
                ),
              ),
            ],

            // Composer bar
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black, width: 2.5)),
              ),
              child: Row(
                children: [
                  // Attachment button
                  GestureDetector(
                    onTap: _showAttachmentDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.attach_file_rounded, size: 20, color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Emoji button
                  GestureDetector(
                    onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _showEmojiPicker ? MeetdayColors.accentYellow : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.emoji_emotions_outlined, size: 20, color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _textController.text.isNotEmpty
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: TextField(
                        controller: _textController,
                        cursorColor: Colors.black,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: _editingMessage != null
                              ? 'Edit message…'
                              : 'Type a message to ${widget.thread.counterpartName}…',
                          hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Emoji Picker Panel
            if (_showEmojiPicker) _buildEmojiPicker(),
          ],
        ),
      ),
    );
  }

  // ─── Pinned Deal Banner ──────────────────────────────────────────────────

  Widget _buildDealBanner() {
    final dealAsync = ref.watch(threadDealProvider(widget.thread));
    final reportAsync = ref.watch(threadReportProvider(widget.thread));

    return dealAsync.when(
      data: (deal) {
        final report = reportAsync.asData?.value;
        final isReportApproved = report != null &&
            (report['status'] == 'APPROVED' ||
                (report['summary'] is String && report['summary'].toString().contains('"status":"APPROVED"')));
        final isClosed = isReportApproved || (deal != null && deal['status'] == 'CLOSED');

        if (deal == null) {
          // Show "Lock the Deal" banner
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              border: Border(bottom: BorderSide(color: Colors.black, width: 2.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Once terms are agreed, submit the final details here.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0x99000000),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showDealFormDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: MeetdayColors.accentYellow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 13, color: Colors.black),
                        const SizedBox(width: 5),
                        Text(
                          'Lock the Deal',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Deal exists: Status banner
        final dealStatus = (deal['status'] ?? 'PENDING_APPROVAL').toString().toUpperCase();
        final paymentStatus = (deal['paymentStatus'] ?? 'UNPAID').toString().toUpperCase();
        final projectName = (deal['projectName'] ?? widget.thread.title).toString();
        final amount = deal['sponsorshipAmount'] ?? deal['amount'] ?? '0';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: Colors.black, width: 2.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Deal Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isClosed
                                ? Colors.black
                                : dealStatus == 'APPROVED'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isClosed) ...[
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 8, color: Colors.white),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'CLOSED',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  dealStatus == 'APPROVED'
                                      ? 'LOCKED'
                                      : (dealStatus == 'CHANGES_REQUESTED' ? 'REVISION' : 'PENDING'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: dealStatus == 'APPROVED'
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (dealStatus == 'APPROVED') ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: paymentStatus == 'PAID' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            child: Text(
                              paymentStatus,
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: paymentStatus == 'PAID'
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$projectName · ₹$amount',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // View Deal Button
                  GestureDetector(
                    onTap: () => _showDealDetailsDialog(context, deal, report),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Deal',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Edit Deal or Report button
                  if (dealStatus != 'APPROVED') ...[
                    GestureDetector(
                      onTap: () => _showDealFormDialog(context, existingDeal: deal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: MeetdayColors.accentYellow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_rounded, size: 12, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () => _showDealReportDialog(context, existingReport: report, deal: deal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: MeetdayColors.accentYellow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              report != null ? Icons.description_rounded : Icons.post_add_rounded,
                              size: 12,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              report != null ? 'Report' : 'Report',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  // ─── System Message Bubble (Matching SystemMessageBubble.tsx) ───────────────

  Widget _buildSystemMessageBubble(UnifiedChatMessage msg) {
    final lower = msg.content.toLowerCase();
    final isCampaign = widget.thread.kind == 'CAMPAIGN' ||
        (lower.contains('campaign') && !lower.contains('sponsorship proposal'));

    Color bg;
    Color textColor;
    Color iconCircleBg;
    Color iconColor;
    IconData iconData;
    Widget messageText;

    // 1. Report Approved / Deal Closed / Completed
    if (lower.contains('report approved') ||
        lower.contains('deliverables approved') ||
        lower.contains('deal is closed') ||
        lower.contains('closed') ||
        lower.contains('completed') ||
        (lower.contains('approved') && (lower.contains('deliverables') || lower.contains('report')))) {
      bg = const Color(0xFFECFDF5);
      textColor = const Color(0xFF065F46);
      iconCircleBg = const Color(0xFF10B981);
      iconColor = Colors.white;
      iconData = Icons.check_rounded;
      messageText = RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600),
          children: const [
            TextSpan(text: 'Congratulations! The '),
            TextSpan(text: 'deal is officially completed and closed', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: '!'),
          ],
        ),
      );
    }
    // 2. Deliverables Report Revision Requested
    else if ((lower.contains('deliverables') || lower.contains('report')) &&
        (lower.contains('revision') || lower.contains('requested change') || lower.contains('requested changes'))) {
      bg = const Color(0xFFFFFBEB);
      textColor = const Color(0xFF92400E);
      iconCircleBg = const Color(0xFFFFC940);
      iconColor = Colors.black;
      iconData = Icons.edit_rounded;
      messageText = RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600),
          children: const [
            TextSpan(text: 'Revision requested', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' on the deliverables report.'),
          ],
        ),
      );
    }
    // 3. Deliverables Report Submitted
    else if (lower.contains('submitted the deliverables') ||
        lower.contains('submitted the report') ||
        (lower.contains('submitted') && (lower.contains('deliverables') || lower.contains('report')))) {
      bg = const Color(0xFFFEF2F2);
      textColor = const Color(0xFF991B1B);
      iconCircleBg = const Color(0xFFEE2C2C);
      iconColor = Colors.white;
      iconData = Icons.assignment_turned_in_rounded;
      messageText = RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600),
          children: const [
            TextSpan(text: 'The '),
            TextSpan(text: 'deliverables report', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' was submitted for review.'),
          ],
        ),
      );
    }
    // 4. Deal Locked / Approved
    else if (lower.contains('locked') ||
        lower.contains('deal confirmed') ||
        lower.contains('deal approved') ||
        lower.contains('approved')) {
      bg = const Color(0xFFECFDF5);
      textColor = const Color(0xFF065F46);
      iconCircleBg = const Color(0xFF10B981);
      iconColor = Colors.white;
      iconData = Icons.lock_rounded;
      messageText = RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600),
          children: const [
            TextSpan(text: 'The '),
            TextSpan(text: 'deal is officially locked', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' and confirmed!'),
          ],
        ),
      );
    }
    // 5. Deal Proposal Created / Shared
    else if (lower.contains('created') ||
        lower.contains('proposal') ||
        lower.contains('campaign') ||
        lower.contains('shared') ||
        lower.contains('deal terms')) {
      bg = const Color(0xFFFEF2F2);
      textColor = const Color(0xFF991B1B);
      iconCircleBg = const Color(0xFFEE2C2C);
      iconColor = Colors.white;
      iconData = Icons.description_rounded;
      final dealWord = isCampaign ? 'campaign deal' : 'deal proposal';
      messageText = RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600),
          children: [
            const TextSpan(text: 'A new '),
            TextSpan(text: dealWord, style: const TextStyle(fontWeight: FontWeight.w800)),
            const TextSpan(text: ' was shared for approval.'),
          ],
        ),
      );
    }
    // 6. Proposal Changes Requested
    else if (lower.contains('changes') || lower.contains('requested change') || lower.contains('revision')) {
      bg = const Color(0xFFFFFBEB);
      textColor = const Color(0xFF92400E);
      iconCircleBg = const Color(0xFFFFC940);
      iconColor = Colors.black;
      iconData = Icons.edit_rounded;
      final dealWord = isCampaign ? 'campaign deal' : 'proposal';
      messageText = RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600),
          children: [
            const TextSpan(text: 'Changes requested', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' on the $dealWord.'),
          ],
        ),
      );
    }
    // 7. Payment Completed
    else if (lower.contains('paid') || lower.contains('payment')) {
      bg = const Color(0xFFF0FDF4);
      textColor = const Color(0xFF15803D);
      iconCircleBg = const Color(0xFF10B981);
      iconColor = Colors.white;
      iconData = Icons.credit_card_rounded;
      messageText = RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600),
          children: const [
            TextSpan(text: 'Payment completed', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' successfully!'),
          ],
        ),
      );
    }
    // 8. Generic Fallback
    else {
      final clean = msg.content
          .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '')
          .trim();
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1),
          ),
          child: Text(
            clean.isNotEmpty ? clean : msg.content,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
        ),
      );
    }

    // Subtle, compact pill matching user request
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.12), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: iconCircleBg,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 10, color: iconColor),
            ),
            const SizedBox(width: 8),
            Flexible(child: messageText),
          ],
        ),
      ),
    );
  }

  // ─── Chat Message Bubble ──────────────────────────────────────────────────

  Widget _buildMessageBubble(UnifiedChatMessage msg) {
    if (msg.isSystem) {
      return _buildSystemMessageBubble(msg);
    }

    final isAdmin = msg.isAdmin;
    final isMe = msg.isMe && !isAdmin;
    final isDeleted = msg.isDeleted;

    // Website bubble coloring:
    // admin = grey (#F3F4F6) only, text black
    // isMe (community) = Meetday Yellow (#FFC940), text black
    // brand = Meetday Red (#EE2C2C), text white
    // space = black, text white
    // other community collab = white (#FFFFFF), text black
    Color bubbleBg;
    Color textColor;

    if (isAdmin) {
      bubbleBg = const Color(0xFFF3F4F6);
      textColor = Colors.black;
    } else if (isMe) {
      bubbleBg = MeetdayColors.accentYellow;
      textColor = Colors.black;
    } else if (widget.thread.category == 'brands' ||
        widget.thread.kind == 'SPONSORSHIP' ||
        widget.thread.kind == 'CAMPAIGN') {
      bubbleBg = MeetdayColors.primaryRed;
      textColor = Colors.white;
    } else if (widget.thread.category == 'spaces' ||
        widget.thread.kind == 'SPACE_HOST' ||
        widget.thread.kind == 'SPACE_INTEREST') {
      bubbleBg = Colors.black;
      textColor = Colors.white;
    } else {
      bubbleBg = Colors.white;
      textColor = Colors.black;
    }

    final isDarkBubble = (bubbleBg == MeetdayColors.primaryRed || bubbleBg == Colors.black);
    final alignment = (isAdmin || !isMe) ? Alignment.centerLeft : Alignment.centerRight;
    final crossAlign = (isAdmin || !isMe) ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    return Dismissible(
      key: ValueKey('msg_${msg.id}_${msg.createdAt}'),
      direction: isMe ? DismissDirection.startToEnd : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        setState(() {
          _editingMessage = null;
          _replyingTo = msg;
        });
        return false;
      },
      background: isMe
          ? Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: const Icon(Icons.reply_rounded, color: MeetdayColors.primaryRed, size: 24),
            )
          : Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.reply_rounded, color: MeetdayColors.primaryRed, size: 24),
            ),
      secondaryBackground: !isMe
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.reply_rounded, color: MeetdayColors.primaryRed, size: 24),
            )
          : const SizedBox.shrink(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: crossAlign,
            children: [
              // Sender Name Header (only for counterpart / admin, not self)
              if (!isMe || isAdmin)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    isAdmin ? 'Admin' : widget.thread.counterpartName,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

              // Message Bubble: Long press opens context menu with Reply, Copy, Edit, Delete
              GestureDetector(
                onLongPress: () => _showMessageContextMenu(msg),
                child: isDeleted
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'This message was deleted',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: Colors.black45,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: bubbleBg,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(3) : const Radius.circular(16),
                            bottomLeft: (!isMe || isAdmin) ? const Radius.circular(3) : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Replying quote snippet preview
                            if (msg.replyTo != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDarkBubble
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: isDarkBubble ? Colors.white70 : Colors.black45,
                                      width: 3.5,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '↩ Replying to ${msg.replyTo!.senderType == 'ADMIN' ? 'Admin' : (msg.replyTo!.isMe ? 'You' : widget.thread.counterpartName)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: isDarkBubble ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    if (msg.replyTo!.content.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        msg.replyTo!.content,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkBubble ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            // Media Attachment
                            if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  msg.mediaUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    padding: const EdgeInsets.all(8),
                                    color: Colors.black12,
                                    child: const Icon(Icons.broken_image_rounded, size: 36),
                                  ),
                                ),
                              ),
                              if (msg.content.isNotEmpty) const SizedBox(height: 6),
                            ],

                            // Content text
                            if (msg.content.isNotEmpty)
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    height: 1.35,
                                  ),
                                  children: [
                                    TextSpan(text: msg.content),
                                    if (msg.isEdited)
                                      TextSpan(
                                        text: ' (edited)',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontStyle: FontStyle.italic,
                                          color: isDarkBubble ? Colors.white60 : Colors.black45,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),

              // Timestamp UNDER the message
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _messageTime(msg.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black38,
                      ),
                    ),
                    if (msg.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(edited)',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: Colors.black38,
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
  }

  // ─── Emoji Picker Panel ───────────────────────────────────────────────────

  Widget _buildEmojiPicker() {
    const emojis = [
      '👍', '❤️', '🔥', '🎉', '🚀', '👏', '🤝', '✨', '💯', '🙌',
      '😊', '😂', '🤣', '😍', '🤔', '😎', '🥳', '🤩', '💡', '💬',
      '📅', '📍', '🏢', '💼', '📈', '💰', '🏷️', '🎯', '🎤', '☕',
      '⭐', '📌', '🏆', '✅', '🔔', '📣', '🍻', '🍔', '🍕', '🎈',
    ];

    return Container(
      height: 190,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(top: BorderSide(color: Colors.black, width: 2)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          return InkWell(
            onTap: () {
              final text = _textController.text;
              final selection = _textController.selection;
              final newText = selection.start >= 0
                  ? text.replaceRange(selection.start, selection.end, emoji)
                  : text + emoji;
              _textController.text = newText;
              _textController.selection = TextSelection.collapsed(
                offset: (selection.start >= 0 ? selection.start : text.length) + emoji.length,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }

  // ─── Context Menu Bottom Sheet ─────────────────────────────────────────────

  void _showMessageContextMenu(UnifiedChatMessage msg) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: Colors.black),
                  title: Text('Reply', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _editingMessage = null;
                      _replyingTo = msg;
                    });
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.black),
                title: Text('Copy Text', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard')),
                  );
                },
              ),
              if (msg.isMe && !msg.isDeleted) ...[
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.black),
                  title: Text('Edit Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _replyingTo = null;
                      _editingMessage = msg;
                      _textController.text = msg.content;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: MeetdayColors.primaryRed),
                  title: Text('Delete Message',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: MeetdayColors.primaryRed)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleDelete(msg);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Attachment Dialog & Phone File Picking ────────────────────────────────

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading media...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.black87,
          ),
        );
      }

      final bytes = await picked.readAsBytes();
      final api = ref.read(apiClientProvider);

      String uploadContext = 'SPONSORSHIP_CHAT_MEDIA';
      if (widget.thread.kind == 'SPACE_INTEREST') {
        uploadContext = 'SPACE_CHAT_MEDIA';
      } else if (widget.thread.kind == 'SPACE_HOST') {
        uploadContext = 'SPACE_HOST_CHAT_MEDIA';
      } else if (widget.thread.kind == 'COMMUNITY_COLLAB') {
        uploadContext = 'COMMUNITY_COLLABORATION_CHAT_MEDIA';
      }

      final key = await api.uploadMediaFile(
        bytes: bytes,
        fileName: picked.name,
        context: uploadContext,
        resourceId: widget.thread.id,
      );

      if (key != null) {
        await _sendMessage(mediaKey: key);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed. Please try again.'),
              backgroundColor: MeetdayColors.primaryRed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking/uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx'],
      );
      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.xFile.readAsBytes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading file...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.black87,
          ),
        );
      }

      final api = ref.read(apiClientProvider);
      String uploadContext = 'SPONSORSHIP_CHAT_MEDIA';
      if (widget.thread.kind == 'SPACE_INTEREST') {
        uploadContext = 'SPACE_CHAT_MEDIA';
      } else if (widget.thread.kind == 'SPACE_HOST') {
        uploadContext = 'SPACE_HOST_CHAT_MEDIA';
      } else if (widget.thread.kind == 'COMMUNITY_COLLAB') {
        uploadContext = 'COMMUNITY_COLLABORATION_CHAT_MEDIA';
      }

      final key = await api.uploadMediaFile(
        bytes: bytes,
        fileName: file.name,
        context: uploadContext,
        resourceId: widget.thread.id,
      );

      if (key != null) {
        await _sendMessage(mediaKey: key);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed. Please try again.'),
              backgroundColor: MeetdayColors.primaryRed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking/uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    }
  }

  void _showAttachmentDialog() {
    final urlController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Attach Media',
              style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Select files from your phone or share a media link',
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Selection Grid: Gallery, Camera, Document
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndSendImage(ImageSource.gallery);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: MeetdayColors.accentYellow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 24, color: Colors.black),
                          const SizedBox(height: 6),
                          Text(
                            'Gallery',
                            style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndSendImage(ImageSource.camera);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_rounded, size: 24, color: Colors.black),
                          const SizedBox(height: 6),
                          Text(
                            'Camera',
                            style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndSendFile();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.file_present_rounded, size: 24, color: Color(0xFF2563EB)),
                          const SizedBox(height: 6),
                          Text(
                            'Document',
                            style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Divider or text URL
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.black12, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR PASTE URL',
                    style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black38),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.black12, thickness: 1)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
              ),
              child: TextField(
                controller: urlController,
                style: GoogleFonts.poppins(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'https://example.com/image.png',
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeetdayColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  final url = urlController.text.trim();
                  if (url.isNotEmpty) {
                    Navigator.of(ctx).pop();
                    _sendMessage(mediaUrl: url);
                  }
                },
                child: Text('Send Media URL', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Deal Form Dialog (Lock Deal / Edit Deal) ──────────────────────────────

  void _showDealFormDialog(BuildContext context, {Map<String, dynamic>? existingDeal}) {
    final nameCtrl = TextEditingController(text: existingDeal?['projectName']?.toString() ?? widget.thread.title);
    final amountCtrl =
        TextEditingController(text: (existingDeal?['sponsorshipAmount'] ?? existingDeal?['amount'] ?? '').toString());
    final deliverablesCtrl = TextEditingController(text: existingDeal?['deliverables']?.toString() ?? '');
    final venueCtrl = TextEditingController(text: existingDeal?['venue']?.toString() ?? 'Main Stage / Venue');
    final dateCtrl = TextEditingController(
        text: existingDeal?['startDate']?.toString().split('T').first ??
            DateTime.now().toIso8601String().split('T').first);
    final notesCtrl = TextEditingController(
        text: (existingDeal?['additionalNotes'] ?? existingDeal?['otherTerms'] ?? '').toString());
    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingDeal != null ? 'Edit Deal Terms' : 'Lock the Deal',
                        style: GoogleFonts.bricolageGrotesque(fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  Text(
                    'Finalize terms and submit them to ${widget.thread.counterpartName} for lock confirmation.',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('PROJECT / EVENT NAME'),
                  _formInput(nameCtrl, 'e.g. Developer Meetup 2026'),
                  const SizedBox(height: 10),
                  _fieldLabel('DEAL AMOUNT (₹)'),
                  _formInput(amountCtrl, 'e.g. 50000', keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  _fieldLabel('DELIVERABLES AGREED'),
                  _formInput(deliverablesCtrl, 'List agreed deliverables, logo display, speaking slot…', maxLines: 3),
                  const SizedBox(height: 10),
                  _fieldLabel('VENUE / LOCATION'),
                  _formInput(venueCtrl, 'e.g. Innovation Hub / Bangalore'),
                  const SizedBox(height: 10),
                  _fieldLabel('START DATE'),
                  _formInput(dateCtrl, 'YYYY-MM-DD'),
                  const SizedBox(height: 10),
                  _fieldLabel('ADDITIONAL NOTES'),
                  _formInput(notesCtrl, 'Special conditions, payment schedules…', maxLines: 2),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeetdayColors.accentYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                              if (name.isEmpty) return;

                              setModalState(() => isSaving = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                final payload = {
                                  'projectName': name,
                                  'sponsorshipAmount': amount,
                                  'deliverables': deliverablesCtrl.text.trim(),
                                  'venue': venueCtrl.text.trim(),
                                  'startDate': dateCtrl.text.trim(),
                                  'additionalNotes': notesCtrl.text.trim(),
                                };
                                await saveDealApi(api, widget.thread, payload, isUpdate: existingDeal != null);
                                ref.invalidate(threadDealProvider(widget.thread));
                                ref.invalidate(chatMessagesProvider(widget.thread));
                                ref.invalidate(chatHubProvider);

                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(existingDeal != null
                                          ? 'Deal terms updated!'
                                          : 'Deal locked successfully!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Failed to save deal: $e'),
                                        backgroundColor: MeetdayColors.primaryRed),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) setModalState(() => isSaving = false);
                              }
                            },
                      child: Text(
                        isSaving
                            ? 'Saving…'
                            : (existingDeal != null ? 'Update Deal Terms' : 'Confirm & Lock Deal'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Deal Details Dialog ───────────────────────────────────────────────────

  void _showDealDetailsDialog(BuildContext context, Map<String, dynamic> deal, Map<String, dynamic>? report) {
    final dealStatus = (deal['status'] ?? 'PENDING').toString().toUpperCase();
    final isLocked = dealStatus == 'APPROVED';
    final isReviewer = widget.thread.category == 'brands' && widget.thread.kind == 'SPONSORSHIP';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deal Details',
                  style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow('Project', deal['projectName']?.toString() ?? '-'),
            _infoRow('Amount', '₹${deal['sponsorshipAmount'] ?? deal['amount'] ?? '0'}'),
            _infoRow('Status', dealStatus),
            _infoRow('Payment', (deal['paymentStatus'] ?? 'UNPAID').toString().toUpperCase()),
            _infoRow('Venue', deal['venue']?.toString() ?? '-'),
            _infoRow('Date', deal['startDate']?.toString().split('T').first ?? '-'),
            if (deal['deliverables'] != null && deal['deliverables'].toString().isNotEmpty)
              _infoRow('Deliverables', deal['deliverables'].toString()),
            if (deal['additionalNotes'] != null && deal['additionalNotes'].toString().isNotEmpty)
              _infoRow('Notes', deal['additionalNotes'].toString()),
            const SizedBox(height: 16),

            // Deal Actions: Approve / Request Changes / Edit Deal
            if (!isLocked) ...[
              if (isReviewer) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          try {
                            final api = ref.read(apiClientProvider);
                            await approveDealApi(api, widget.thread);
                            ref.invalidate(threadDealProvider(widget.thread));
                            ref.invalidate(chatMessagesProvider(widget.thread));
                            ref.invalidate(chatHubProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Deal approved and locked!'), backgroundColor: Color(0xFF10B981)),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to approve deal: $e'), backgroundColor: MeetdayColors.primaryRed),
                              );
                            }
                          }
                        },
                        child: Text('Approve & Lock', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MeetdayColors.accentYellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showRequestDealChangesDialog(context);
                        },
                        child: Text('Request Changes', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MeetdayColors.accentYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showDealFormDialog(context, existingDeal: deal);
                    },
                    child: Text('Edit Deal Terms', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ],
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showDealReportDialog(context, existingReport: report, deal: deal);
                  },
                  child: Text('View Deliverables Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRequestDealChangesDialog(BuildContext context) {
    final noteCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.black, width: 2.5)),
        title: Text('Request Changes', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          style: GoogleFonts.poppins(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'Describe changes needed on the deal terms…',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MeetdayColors.primaryRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(dCtx).pop();
              try {
                final api = ref.read(apiClientProvider);
                await requestDealChangesApi(api, widget.thread, note: noteCtrl.text.trim());
                ref.invalidate(threadDealProvider(widget.thread));
                ref.invalidate(chatMessagesProvider(widget.thread));
                ref.invalidate(chatHubProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Changes requested successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to request changes: $e')));
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ─── Deal Report Dialog ────────────────────────────────────────────────────

  void _showDealReportDialog(
      BuildContext context, {Map<String, dynamic>? existingReport, Map<String, dynamic>? deal}) {
    // Parse summary if stored as JSON (matching meetday-frontend DealPanel.tsx)
    Map<String, dynamic> parsedSummary = {};
    if (existingReport != null && existingReport['summary'] != null) {
      try {
        final decoded = jsonDecode(existingReport['summary'].toString());
        if (decoded is Map) parsedSummary = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    final projectName = parsedSummary['projectName'] ?? existingReport?['projectName'] ?? deal?['projectName'] ?? widget.thread.title;
    final eventDate = parsedSummary['date'] ?? existingReport?['eventDate'] ?? deal?['startDate']?.toString().split('T').first ?? '';
    final venue = parsedSummary['venue'] ?? existingReport?['venue'] ?? deal?['venue'] ?? '';
    final time = parsedSummary['time'] ?? existingReport?['time'] ?? '';
    final guestCount = parsedSummary['guestCount'] ?? existingReport?['guestCount'] ?? '';
    final ageRange = parsedSummary['ageRange'] ?? existingReport?['ageRange'] ?? '';
    final summaryText = parsedSummary['summary'] ?? existingReport?['summary'] ?? '';
    final status = (existingReport?['status'] ?? parsedSummary['status'] ?? 'PENDING').toString().toUpperCase();
    final revisionNote = (existingReport?['revisionNote'] ?? parsedSummary['revisionNote'] ?? '').toString();

    final nameCtrl = TextEditingController(text: projectName.toString());
    final dateCtrl = TextEditingController(text: eventDate.toString());
    final venueCtrl = TextEditingController(text: venue.toString());
    final timeCtrl = TextEditingController(text: time.toString());
    final guestCountCtrl = TextEditingController(text: guestCount.toString());
    final ageRangeCtrl = TextEditingController(text: ageRange.toString());
    final summaryCtrl = TextEditingController(text: summaryText.isNotEmpty && !summaryText.startsWith('{') ? summaryText : '');
    final notesCtrl = TextEditingController(text: existingReport?['notes']?.toString() ?? '');

    final initialProofKeys = <String>[];
    if (existingReport?['proofKeys'] is List) {
      initialProofKeys.addAll((existingReport!['proofKeys'] as List).map((e) => e.toString()));
    }

    final proofKeys = List<String>.from(initialProofKeys);
    bool isSaving = false;
    bool isUploadingProof = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existingReport != null ? 'Deliverables Report' : 'Submit Deliverables Report',
                      style: GoogleFonts.bricolageGrotesque(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                  ],
                ),
                if (status == 'REVISION_REQUESTED' && revisionNote.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Revision Requested:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF92400E))),
                        const SizedBox(height: 2),
                        Text(revisionNote, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF92400E))),
                      ],
                    ),
                  ),
                ],
                Text(
                  'Share execution proof, photos, video links, or attendee counts.',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                _fieldLabel('PROJECT / EVENT NAME'),
                _formInput(nameCtrl, 'Project Name'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('EVENT DATE'),
                          _formInput(dateCtrl, 'YYYY-MM-DD'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('TIME'),
                          _formInput(timeCtrl, 'e.g. 5:00 PM'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _fieldLabel('VENUE'),
                _formInput(venueCtrl, 'Event Venue'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('GUEST COUNT'),
                          _formInput(guestCountCtrl, 'e.g. 150'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('AGE RANGE'),
                          _formInput(ageRangeCtrl, 'e.g. 18-35'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _fieldLabel('EVENT HIGHLIGHTS & SUMMARY'),
                _formInput(summaryCtrl, 'Overview of how deliverables were fulfilled…', maxLines: 3),
                const SizedBox(height: 10),
                _fieldLabel('PROOF PHOTOS & FILES (${proofKeys.length} attached)'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.black, width: 1.5),
                        ),
                      ),
                      onPressed: isUploadingProof
                          ? null
                          : () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                              if (picked == null) return;

                              setModalState(() => isUploadingProof = true);
                              try {
                                final bytes = await picked.readAsBytes();
                                final api = ref.read(apiClientProvider);
                                final key = await api.uploadMediaFile(
                                  bytes: bytes,
                                  fileName: picked.name,
                                  context: widget.thread.kind == 'SPACE_INTEREST' || widget.thread.kind == 'SPACE_HOST'
                                      ? 'SPACE_DEAL_REPORT_MEDIA'
                                      : 'SPONSORSHIP_DEAL_REPORT_MEDIA',
                                  resourceId: widget.thread.id,
                                );
                                if (key != null) {
                                  setModalState(() => proofKeys.add(key));
                                }
                              } catch (e) {
                                debugPrint('Error uploading proof: $e');
                              } finally {
                                setModalState(() => isUploadingProof = false);
                              }
                            },
                      icon: isUploadingProof
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_photo_alternate_rounded, size: 16),
                      label: Text('Attach Proof from Phone', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _fieldLabel('ADDITIONAL NOTES'),
                _formInput(notesCtrl, 'Any further notes or details for review', maxLines: 2),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MeetdayColors.accentYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              final summaryData = jsonEncode({
                                'projectName': nameCtrl.text.trim(),
                                'date': dateCtrl.text.trim(),
                                'venue': venueCtrl.text.trim(),
                                'time': timeCtrl.text.trim(),
                                'guestCount': guestCountCtrl.text.trim(),
                                'ageRange': ageRangeCtrl.text.trim(),
                                'summary': summaryCtrl.text.trim(),
                                'status': 'PENDING',
                                'revisionNote': '',
                              });

                              final payload = {
                                'projectName': nameCtrl.text.trim(),
                                'eventDate': dateCtrl.text.trim(),
                                'venue': venueCtrl.text.trim(),
                                'time': timeCtrl.text.trim(),
                                'guestCount': guestCountCtrl.text.trim(),
                                'ageRange': ageRangeCtrl.text.trim(),
                                'status': 'PENDING',
                                'revisionNote': '',
                                'summary': summaryData,
                                'notes': notesCtrl.text.trim(),
                                'proofKeys': proofKeys,
                              };

                              await saveReportApi(api, widget.thread, payload);
                              ref.invalidate(threadReportProvider(widget.thread));
                              ref.invalidate(chatMessagesProvider(widget.thread));
                              ref.invalidate(chatHubProvider);

                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Deliverables report submitted successfully!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Failed to submit report: $e'),
                                      backgroundColor: MeetdayColors.primaryRed),
                                );
                              }
                            } finally {
                              if (ctx.mounted) setModalState(() => isSaving = false);
                            }
                          },
                    child: Text(
                      isSaving
                          ? 'Submitting…'
                          : (existingReport != null ? 'Update Report' : 'Submit Deliverables Report'),
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Modal Helpers ─────────────────────────────────────────────────────────

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Colors.black54,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _formInput(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)],
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
