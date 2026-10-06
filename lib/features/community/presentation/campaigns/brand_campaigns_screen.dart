import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../providers/dashboard_provider.dart';

const List<String> _kAudienceOptions = [
  'Tech Developers',
  'Creative Designers',
  'Founders & Executives',
  'Remote Workers',
  'Investors',
  'Corporate Professionals',
  'Students',
  'Fitness Enthusiasts',
  'Artists & Musicians',
  'Food & Coffee',
  'Avid Readers',
  'Eco Advocates',
  'Gamers',
  'Kids & Families',
];

const List<String> _kGoalOptions = [
  'Product Sampling',
  'Pop-up / Booth',
  'Host an Event',
  'Community Growth',
];

/// Experiences / Brand Campaigns Screen for Brands.
/// Replicates `meetday-frontend` (/brand/dashboard/campaigns) with full creation,
/// editing, status filtering, and live backend connectivity.
class BrandCampaignsScreen extends ConsumerStatefulWidget {
  const BrandCampaignsScreen({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  ConsumerState<BrandCampaignsScreen> createState() => _BrandCampaignsScreenState();
}

class _BrandCampaignsScreenState extends ConsumerState<BrandCampaignsScreen> {
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  void _openCreateCampaignModal([Map<String, dynamic>? initialCampaign]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BrandCampaignFormSheet(
        initialCampaign: initialCampaign,
        onSuccess: () {
          ref.invalidate(brandCampaignsProvider);
          ref.invalidate(dashboardCampaignsProvider);
        },
      ),
    );
  }

  void _openCampaignDetail(Map<String, dynamic> campaign) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BrandCampaignDetailSheet(
        campaign: campaign,
        onEdit: () {
          Navigator.pop(context);
          _openCreateCampaignModal(campaign);
        },
        onSuccess: () {
          ref.invalidate(brandCampaignsProvider);
          ref.invalidate(dashboardCampaignsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(brandCampaignsProvider);

    return campaignsAsync.when(
      data: (campaigns) {
        final allCount = campaigns.length;
        final publishedCount = campaigns.where((c) => c['status'] == 'PUBLISHED').length;
        final underReviewCount = campaigns.where((c) => c['status'] == 'UNDER_REVIEW').length;
        final draftCount = campaigns.where((c) => c['status'] == 'DRAFT').length;
        final rejectedCount = campaigns.where((c) => c['status'] == 'REJECTED').length;

        final filtered = campaigns.where((c) {
          if (_selectedFilter != 'ALL' && c['status'] != _selectedFilter) {
            return false;
          }
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.toLowerCase().trim();
            final name = (c['name'] ?? '').toString().toLowerCase();
            final desc = (c['description'] ?? '').toString().toLowerCase();
            final locs = (c['locations'] as List?)?.join(' ').toLowerCase() ?? '';
            final goals = (c['goal'] ?? '').toString().toLowerCase();
            if (!name.contains(q) && !desc.contains(q) && !locs.contains(q) && !goals.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

        final filterSegments = [
          {'key': 'ALL', 'label': 'ALL ($allCount)'},
          {'key': 'PUBLISHED', 'label': 'PUBLISHED ($publishedCount)'},
          {'key': 'UNDER_REVIEW', 'label': 'UNDER REVIEW ($underReviewCount)'},
          {'key': 'DRAFT', 'label': 'DRAFT ($draftCount)'},
          {'key': 'REJECTED', 'label': 'REJECTED ($rejectedCount)'},
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFFFFDFC),
          body: RefreshIndicator(
            color: MeetdayColors.primaryRed,
            onRefresh: () async {
              ref.invalidate(brandCampaignsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                if (widget.onBack != null) ...[
                  GestureDetector(
                    onTap: widget.onBack,
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
                          'Back to Explore',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0x99000000),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Top Header Row: Title & "+ CREATE CAMPAIGN" button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Campaigns',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Launch marketing campaigns & match with communities',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _openCreateCampaignModal(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'CREATE CAMPAIGN',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search campaigns by name, location, or goal...',
                    hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.black, width: 1.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MeetdayColors.primaryRed, width: 2.5),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Horizontal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filterSegments.map((seg) {
                      final isSelected = _selectedFilter == seg['key'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = seg['key']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black, width: 1.6),
                              boxShadow: isSelected
                                  ? const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        offset: Offset(1.5, 1.5),
                                        blurRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              seg['label']!,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 18),

                // Campaign List
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.rocket_launch_rounded, size: 40, color: Colors.black38),
                        const SizedBox(height: 12),
                        Text(
                          'No campaigns found',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedFilter == 'ALL'
                              ? 'Launch your first campaign brief to collaborate with verified host communities.'
                              : 'No campaigns found for the "$_selectedFilter" status filter.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _openCreateCampaignModal(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: MeetdayColors.accentYellow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                              ],
                            ),
                            child: Text(
                              '+ LAUNCH CAMPAIGN',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((c) => _buildCampaignCard(c)),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load campaigns: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(brandCampaignsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> c) {
    final name = (c['name'] ?? 'Campaign').toString();
    final status = (c['status'] ?? 'DRAFT').toString().toUpperCase();
    final offerType = (c['offerType'] ?? 'CASH').toString().toUpperCase();
    final budgetAmount = c['budgetAmount'];
    final budgetCurrency = (c['budgetCurrency'] ?? '₹').toString();
    final locations = (c['locations'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final goals = (c['goal'] ?? '').toString();
    final startDate = c['startDate']?.toString();
    final endDate = c['endDate']?.toString();

    String budgetText = '';
    if (offerType == 'BARTER') {
      budgetText = 'Barter';
    } else if (budgetAmount != null && budgetAmount != 0) {
      budgetText = '$budgetCurrency$budgetAmount';
      if (offerType == 'BOTH') budgetText += ' + Barter';
    } else {
      budgetText = offerType;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _openCampaignDetail(c),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(status),
                  ],
                ),
                const SizedBox(height: 8),

                // Offer / Budget pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: Text(
                        budgetText,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ),
                    if (startDate != null && startDate.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(startDate, endDate),
                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                    ],
                  ],
                ),

                if (goals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Goals: $goals',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (locations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: locations.take(3).map((loc) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black54, width: 1),
                        ),
                        child: Text(
                          loc,
                          style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = Colors.black;
    String label = status;

    if (status == 'PUBLISHED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      label = 'LIVE';
    } else if (status == 'UNDER_REVIEW') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = 'UNDER REVIEW';
    } else if (status == 'DRAFT') {
      bg = const Color(0xFFF1F5F9);
      fg = Colors.black54;
      label = 'DRAFT';
    } else if (status == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      label = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  String _formatDate(String start, String? end) {
    try {
      final s = DateTime.parse(start);
      final sStr = '${s.day} ${_monthName(s.month)}';
      if (end == null || end.isEmpty || end == start) return sStr;
      final e = DateTime.parse(end);
      return '$sStr – ${e.day} ${_monthName(e.month)}';
    } catch (_) {
      return start;
    }
  }

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(m - 1).clamp(0, 11)];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campaign Detail Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _BrandCampaignDetailSheet extends ConsumerStatefulWidget {
  const _BrandCampaignDetailSheet({
    required this.campaign,
    required this.onEdit,
    required this.onSuccess,
  });

  final Map<String, dynamic> campaign;
  final VoidCallback onEdit;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_BrandCampaignDetailSheet> createState() => _BrandCampaignDetailSheetState();
}

class _BrandCampaignDetailSheetState extends ConsumerState<_BrandCampaignDetailSheet> {
  bool _isSubmitting = false;
  bool _isDeleting = false;

  Future<void> _submitForApproval() async {
    setState(() => _isSubmitting = true);
    try {
      final id = widget.campaign['id'].toString();
      final api = ref.read(apiClientProvider);
      await api.updateCampaign(id, {'status': 'UNDER_REVIEW'});
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign brief submitted for approval!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteCampaign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black, width: 2)),
        title: Text('Delete Campaign', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete this campaign brief?', style: GoogleFonts.poppins(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MeetdayColors.primaryRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final id = widget.campaign['id'].toString();
      final api = ref.read(apiClientProvider);
      await api.deleteCampaign(id);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign deleted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: MeetdayColors.primaryRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final name = (c['name'] ?? 'Campaign').toString();
    final status = (c['status'] ?? 'DRAFT').toString().toUpperCase();
    final goals = (c['goal'] ?? '').toString();
    final locations = (c['locations'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final audience = (c['audience'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final description = (c['description'] ?? '').toString();
    final offerType = (c['offerType'] ?? 'CASH').toString().toUpperCase();
    final budgetAmount = c['budgetAmount'];
    final budgetCurrency = (c['budgetCurrency'] ?? '₹').toString();
    final barterElements = (c['barterElements'] ?? '').toString();
    final startDate = c['startDate']?.toString();
    final endDate = c['endDate']?.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.black, width: 3),
          left: BorderSide(color: Colors.black, width: 3),
          right: BorderSide(color: Colors.black, width: 3),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.bricolageGrotesque(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1.5)),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons (Edit, Submit, Delete)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GestureDetector(
                  onTap: widget.onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0)],
                    ),
                    child: Text('EDIT BRIEF', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
                if (status == 'DRAFT' || status == 'REJECTED')
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitForApproval,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0)],
                      ),
                      child: Text(
                        _isSubmitting ? 'SUBMITTING…' : 'SUBMIT FOR APPROVAL',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _isDeleting ? null : _deleteCampaign,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0)],
                    ),
                    child: Text('DELETE', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: MeetdayColors.primaryRed)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.black12, thickness: 1),
            const SizedBox(height: 12),

            // Metadata fields
            _detailRow('Offer Type', offerType),
            if (offerType != 'BARTER' && budgetAmount != null)
              _detailRow('Budget', '$budgetCurrency$budgetAmount'),
            if (barterElements.isNotEmpty)
              _detailRow('Barter Elements', barterElements),
            if (startDate != null && startDate.isNotEmpty)
              _detailRow('Dates', '$startDate ${endDate != null ? 'to $endDate' : ''}'),
            if (goals.isNotEmpty)
              _detailRow('Goals', goals),
            if (locations.isNotEmpty)
              _detailRow('Locations', locations.join(', ')),
            if (audience.isNotEmpty)
              _detailRow('Target Audience', audience.join(', ')),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Description', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(description, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campaign Create / Edit Form Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _BrandCampaignFormSheet extends ConsumerStatefulWidget {
  const _BrandCampaignFormSheet({
    this.initialCampaign,
    required this.onSuccess,
  });

  final Map<String, dynamic>? initialCampaign;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_BrandCampaignFormSheet> createState() => _BrandCampaignFormSheetState();
}

class _BrandCampaignFormSheetState extends ConsumerState<_BrandCampaignFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetAmountController;
  late final TextEditingController _barterElementsController;
  late final TextEditingController _descriptionController;
  final TextEditingController _locationInputController = TextEditingController();
  final TextEditingController _customAudienceInputController = TextEditingController();
  final TextEditingController _aiPromptController = TextEditingController();

  List<String> _goals = [];
  List<String> _locations = [];
  List<String> _audience = [];
  bool _showCustomAudience = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String _offerType = 'CASH';
  String _budgetCurrency = 'INR';

  bool _isAiOpen = false;
  bool _isAiGenerating = false;
  bool _isSaving = false;

  bool get _isEditing => widget.initialCampaign != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCampaign;
    _nameController = TextEditingController(text: (c?['name'] ?? '').toString());
    _budgetAmountController = TextEditingController(text: c?['budgetAmount']?.toString() ?? '');
    _barterElementsController = TextEditingController(text: (c?['barterElements'] ?? '').toString());
    _descriptionController = TextEditingController(text: (c?['description'] ?? '').toString());

    _offerType = (c?['offerType'] ?? 'CASH').toString().toUpperCase();
    _budgetCurrency = (c?['budgetCurrency'] ?? 'INR').toString();

    if (c?['goal'] != null) {
      _goals = (c!['goal'] as String)
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList();
    }
    if (c?['locations'] is List) {
      _locations = (c!['locations'] as List).map((e) => e.toString()).toList();
    }
    if (c?['audience'] is List) {
      final rawAudience = (c!['audience'] as List).map((e) => e.toString()).toList();
      _audience = rawAudience.where((a) => _kAudienceOptions.contains(a)).toList();
      final custom = rawAudience.firstWhere((a) => !_kAudienceOptions.contains(a), orElse: () => '');
      if (custom.isNotEmpty) {
        _showCustomAudience = true;
        _customAudienceInputController.text = custom;
      }
    }
    if (c?['startDate'] != null) {
      try {
        _startDate = DateTime.parse(c!['startDate'].toString().substring(0, 10));
      } catch (_) {}
    }
    if (c?['endDate'] != null) {
      try {
        _endDate = DateTime.parse(c!['endDate'].toString().substring(0, 10));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetAmountController.dispose();
    _barterElementsController.dispose();
    _descriptionController.dispose();
    _locationInputController.dispose();
    _customAudienceInputController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        backgroundColor: MeetdayColors.primaryRed,
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: MeetdayColors.primaryRed,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final first = _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? first,
      firstDate: first,
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: MeetdayColors.primaryRed,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _addLocation() {
    final val = _locationInputController.text.trim();
    if (val.isNotEmpty && !_locations.contains(val)) {
      setState(() => _locations.add(val));
      _locationInputController.clear();
    }
  }

  Future<void> _handleSave({required bool submitForReview}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showToast('Campaign Name is required.');
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showToast('Description is required.');
      return;
    }
    final wordCount = description.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount > 250) {
      _showToast('Description cannot exceed 250 words.');
      return;
    }

    if (_goals.isEmpty) {
      _showToast('Please select at least one goal.');
      return;
    }
    if (_locations.isEmpty) {
      _showToast('Please add at least one location.');
      return;
    }

    final finalAudience = [..._audience];
    if (_showCustomAudience && _customAudienceInputController.text.trim().isNotEmpty) {
      finalAudience.add(_customAudienceInputController.text.trim());
    }
    if (finalAudience.isEmpty) {
      _showToast('Please select at least one audience target.');
      return;
    }

    if (_startDate == null || _endDate == null) {
      _showToast('Please pick run dates.');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showToast('End date cannot be before start date.');
      return;
    }

    if (_offerType != 'BARTER') {
      final amt = num.tryParse(_budgetAmountController.text.trim());
      if (amt == null || amt <= 0) {
        _showToast('Please enter a valid budget amount.');
        return;
      }
    }

    if ((_offerType == 'BARTER' || _offerType == 'BOTH') &&
        _barterElementsController.text.trim().isEmpty) {
      _showToast('Please describe the elements for barter.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'name': name,
        'description': description,
        'goal': _goals.join(', '),
        'locations': _locations,
        'audience': finalAudience,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate!),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
        'offerType': _offerType,
        'budgetAmount': _offerType == 'BARTER'
            ? 0
            : (num.tryParse(_budgetAmountController.text.trim()) ?? 0),
        'budgetCurrency': _offerType == 'BARTER' ? 'INR' : _budgetCurrency,
        if (_offerType == 'BARTER' || _offerType == 'BOTH')
          'barterElements': _barterElementsController.text.trim(),
        'status': submitForReview ? 'UNDER_REVIEW' : 'DRAFT',
      };

      final api = ref.read(apiClientProvider);
      if (_isEditing) {
        final id = widget.initialCampaign!['id'].toString();
        await api.updateCampaign(id, payload);
      } else {
        await api.createCampaign(payload);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submitForReview
                  ? 'Campaign brief submitted for approval!'
                  : 'Campaign brief saved as draft!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to save campaign: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generateAiDraft() async {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) return;

    final wordCount = prompt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount < 20) {
      _showToast('Describe your campaign in a minimum of 20 words to continue.');
      return;
    }

    setState(() => _isAiGenerating = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.generateCampaignDraft(prompt);
      if (mounted) {
        setState(() {
          if (res['name'] != null) _nameController.text = res['name'].toString();
          if (res['description'] != null) _descriptionController.text = res['description'].toString();
          if (res['goal'] != null) {
            _goals = [res['goal'].toString()];
          }
          if (res['locations'] is List) {
            _locations = (res['locations'] as List).map((e) => e.toString()).toList();
          }
          if (res['audience'] is List) {
            final raw = (res['audience'] as List).map((e) => e.toString()).toList();
            _audience = raw.where((a) => _kAudienceOptions.contains(a)).toList();
            final custom = raw.firstWhere((a) => !_kAudienceOptions.contains(a), orElse: () => '');
            if (custom.isNotEmpty) {
              _showCustomAudience = true;
              _customAudienceInputController.text = custom;
            }
          }
          if (res['offer_type'] != null) _offerType = res['offer_type'].toString().toUpperCase();
          if (res['budget_amount'] != null) _budgetAmountController.text = res['budget_amount'].toString();
          if (res['budget_currency'] != null) _budgetCurrency = res['budget_currency'].toString();
          if (res['barter_elements'] != null) _barterElementsController.text = res['barter_elements'].toString();
          _isAiOpen = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Meetday AI filled in the campaign brief!'),
            backgroundColor: Color(0xFF7C3AED),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast('AI draft failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
      child: Column(
        children: [
          // Drag Handle
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

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit Campaign brief' : 'Create a Campaign',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Provide campaign details to match with host communities',
                      style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Icon(Icons.close, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              children: [
                // 1. AI Draft Companion Card (Matching Website)
                if (!_isEditing) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: MeetdayColors.primaryRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.bricolageGrotesque(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                      children: const [
                                        TextSpan(text: 'Start with our '),
                                        TextSpan(
                                          text: 'AI Companion',
                                          style: TextStyle(color: MeetdayColors.primaryRed),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Describe your campaign in a few words, we fill the rest.',
                                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isAiOpen = !_isAiOpen),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black, width: 1.5),
                                ),
                                child: Text(
                                  _isAiOpen ? 'Close' : 'Draft with AI',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isAiOpen) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Describe your campaign in a minimum of 20 words to continue',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _aiPromptController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'e.g. We want to sample our new energy drink at rooftop networking meetups for young professionals in Bangalore and Mumbai over the next quarter.',
                              hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.black38),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.black, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.black, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isAiGenerating ? null : _generateAiDraft,
                              child: _isAiGenerating
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Start Cooking ✨',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Campaign Name *
                _fieldLabel('Campaign Name *'),
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('e.g., "Figma Q3 Sampling Campaign"'),
                ),
                const SizedBox(height: 14),

                // 3. Description * (Max 250 words)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _fieldLabel('Description *'),
                    Text(
                      'Max 250 words',
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45),
                    ),
                  ],
                ),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    'Provide context for our AI matching engine (e.g., "Looking for hubs with high afternoon foot traffic and an eco-friendly vibe.")',
                  ),
                ),
                const SizedBox(height: 14),

                // 4. What is the goal? *
                _fieldLabel('What is the goal? *'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kGoalOptions.map((g) {
                    final selected = _goals.contains(g);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _goals.remove(g);
                          } else {
                            _goals.add(g);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? MeetdayColors.accentYellow : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.black,
                            width: selected ? 2 : 1.2,
                          ),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(2, 2),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          g,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 5. Where? (City / Region) *
                _fieldLabel('Where? (City / Region) *'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationInputController,
                        decoration: _inputDecoration('e.g., "Delhi", "Mumbai" (press Add or Enter)'),
                        onSubmitted: (_) => _addLocation(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black, width: 1.8),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _addLocation,
                      child: Text('Add', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                if (_locations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _locations.map((loc) {
                      return Chip(
                        label: Text(loc, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700)),
                        deleteIcon: const Icon(Icons.close, size: 12),
                        onDeleted: () => setState(() => _locations.remove(loc)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: const BorderSide(color: Colors.black, width: 1),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Add at least one targeted region.',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45),
                  ),
                ],
                const SizedBox(height: 14),

                // 6. Who is the audience? *
                _fieldLabel('Who is the audience? *'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._kAudienceOptions.map((aud) {
                      final selected = _audience.contains(aud);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _audience.remove(aud);
                            } else {
                              _audience.add(aud);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF6C32D1) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.black,
                              width: selected ? 2 : 1.2,
                            ),
                            boxShadow: selected
                                ? const [
                                    BoxShadow(
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                      blurRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            aud,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: () => setState(() => _showCustomAudience = !_showCustomAudience),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_showCustomAudience || _customAudienceInputController.text.isNotEmpty)
                              ? const Color(0xFF6C32D1)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Text(
                          'Custom..',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: (_showCustomAudience || _customAudienceInputController.text.isNotEmpty)
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showCustomAudience) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customAudienceInputController,
                    decoration: _inputDecoration('Type custom audience description...'),
                  ),
                ],
                const SizedBox(height: 14),

                // 7. Run Dates *
                _fieldLabel('Run Dates *'),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickStartDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 1.8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.black54),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _startDate != null
                                      ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                      : 'Start Date *',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _startDate != null ? Colors.black : Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickEndDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 1.8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_available_rounded, size: 14, color: Colors.black54),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _endDate != null
                                      ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                      : 'End Date *',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _endDate != null ? Colors.black : Colors.black38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 8. Offer *
                _fieldLabel('Offer *'),
                Row(
                  children: ['CASH', 'BARTER', 'BOTH'].map((type) {
                    final selected = _offerType == type;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _offerType = type),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? MeetdayColors.primaryRed : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: selected ? 2 : 1.2),
                              boxShadow: selected
                                  ? const [
                                      BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(2, 2),
                                        blurRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: selected ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 9. Total Budget * (if Cash or Both)
                if (_offerType != 'BARTER') ...[
                  _fieldLabel('Total Budget *'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _budgetAmountController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('e.g. 50,000'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 1.8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _budgetCurrency,
                            items: const [
                              DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                              DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                              DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _budgetCurrency = val);
                            },
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // 10. Elements for Barter * (if Barter or Both)
                if (_offerType == 'BARTER' || _offerType == 'BOTH') ...[
                  _fieldLabel('Elements for Barter *'),
                  TextField(
                    controller: _barterElementsController,
                    decoration: _inputDecoration(
                      'Describe goods, services or products offered in exchange...',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 12),

                // 11. Bottom Action Buttons (Save As Draft / Submit For Review)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : () => _handleSave(submitForReview: false),
                        child: Text(
                          'Save As Draft',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MeetdayColors.primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        onPressed: _isSaving ? null : () => _handleSave(submitForReview: true),
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'SUBMIT FOR REVIEW',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MeetdayColors.primaryRed, width: 2.2),
      ),
    );
  }
}
