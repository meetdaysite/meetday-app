import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/dashboard_provider.dart';

// ─── Format Helpers ──────────────────────────────────────────────────────────

String _formatCurrency(dynamic amount, [String currency = '₹']) {
  if (amount == null) return '${currency}0';
  final clean = amount.toString().replaceAll(RegExp(r'[^0-9.]'), '');
  final numVal = num.tryParse(clean) ?? 0;
  final str = numVal.toStringAsFixed(0);
  if (str.length <= 3) return '$currency$str';
  final last3 = str.substring(str.length - 3);
  final remaining = str.substring(0, str.length - 3);
  final parts = <String>[];
  var pos = remaining.length;
  while (pos > 0) {
    final start = (pos - 2).clamp(0, pos);
    parts.insert(0, remaining.substring(start, pos));
    pos -= 2;
  }
  return '$currency${parts.join(',')},$last3';
}

String _formatDateShort(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '—';
  try {
    final dt = DateTime.parse(dateStr).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  } catch (_) {
    return dateStr.split('T').first;
  }
}

// ─── Campaigns Screen ────────────────────────────────────────────────────────

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  void _openCampaignDetails(Map<String, dynamic> campaign) {
    showCampaignDetailModal(context, campaign);
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(dashboardCampaignsProvider);

    return campaignsAsync.when(
      data: (campaigns) {
        final filtered = campaigns.where((c) {
          final offerType = (c['offerType'] ?? '').toString().toUpperCase();
          if (_selectedFilter != 'ALL') {
            if (_selectedFilter == 'CASH' && offerType != 'CASH' && offerType != 'BOTH') return false;
            if (_selectedFilter == 'BARTER' && offerType != 'BARTER' && offerType != 'BOTH') return false;
          }
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.toLowerCase().trim();
            final name = (c['name'] ?? '').toString().toLowerCase();
            final brand = (c['brandName'] ?? '').toString().toLowerCase();
            final desc = (c['description'] ?? '').toString().toLowerCase();
            final locs = (c['locations'] as List?)?.join(' ').toLowerCase() ?? '';
            if (!name.contains(q) && !brand.contains(q) && !desc.contains(q) && !locs.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

        final allCount = campaigns.length;
        final cashCount = campaigns.where((c) => c['offerType'] == 'CASH' || c['offerType'] == 'BOTH').length;
        final barterCount = campaigns.where((c) => c['offerType'] == 'BARTER' || c['offerType'] == 'BOTH').length;

        final filters = [
          {'key': 'ALL', 'label': 'ALL ($allCount)'},
          {'key': 'CASH', 'label': 'CASH ($cashCount)'},
          {'key': 'BARTER', 'label': 'BARTER ($barterCount)'},
        ];

        return RefreshIndicator(
          color: MeetdayColors.primaryRed,
          onRefresh: () async => ref.refresh(dashboardCampaignsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              // Back Breadcrumb if onBack is provided
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

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brand Campaigns',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Discover brand campaigns, apply with your community, and earn.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Filter Tabs Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: filters.map((f) {
                    final isSelected = _selectedFilter == f['key'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = f['key']!;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black, width: 1.8),
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          f['label']!,
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF525252),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Search Bar (Single border, no double border artifact)
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const Icon(Icons.search_rounded, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Search campaigns, brands, locations…',
                          hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.black45),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Campaign Cards List or Empty State
              if (filtered.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black38, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.rocket_launch_outlined, size: 44, color: Colors.black38),
                      const SizedBox(height: 10),
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
                        'Check back soon for new brand sponsorship briefs.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map(
                  (c) => CampaignListItemCard(
                    campaign: c,
                    onTap: () => _openCampaignDetails(c),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (err, _) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Text(
            'Brand Campaigns',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              children: [
                const Text('Could not load campaigns. Please try again.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.refresh(dashboardCampaignsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeetdayColors.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Campaign List Item Card (Replicating Proposal Card Design) ──────────────

class CampaignListItemCard extends StatelessWidget {
  const CampaignListItemCard({
    super.key,
    required this.campaign,
    required this.onTap,
  });

  final Map<String, dynamic> campaign;
  final VoidCallback onTap;

  Widget _fallbackMonogram(String brandName) {
    final initials = brandName.length > 2 ? brandName.substring(0, 2).toUpperCase() : brandName.toUpperCase();
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black38,
          ),
        ),
      ),
    );
  }

  Widget _buildOfferPill(String offerType) {
    Color bg = const Color(0xFFDCFCE7);
    Color fg = const Color(0xFF065F46);
    String label = 'CASH';

    if (offerType == 'BARTER') {
      bg = MeetdayColors.accentYellow;
      fg = Colors.black;
      label = 'BARTER';
    } else if (offerType == 'BOTH') {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF5B21B6);
      label = 'CASH + BARTER';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
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
        label,
        style: GoogleFonts.poppins(
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (campaign['name'] ?? 'Campaign Brief').toString();
    final brandName = (campaign['brandName'] ?? 'Brand').toString();
    final logoUrl = campaign['brandLogo'] as String?;
    final offerType = (campaign['offerType'] ?? 'CASH').toString().toUpperCase();
    final locations = (campaign['locations'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final description = (campaign['description'] ?? '').toString();
    final startDate = campaign['startDate'] as String?;
    final endDate = campaign['endDate'] as String?;
    final budgetAmount = campaign['budgetAmount'];
    final currency = (campaign['budgetCurrency'] ?? '₹').toString();

    final dateDisplay = startDate != null && endDate != null
        ? '${_formatDateShort(startDate)} – ${_formatDateShort(endDate)}'
        : _formatDateShort(startDate);

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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Image / Brand Logo Container (110 width)
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
                        child: (logoUrl != null && logoUrl.isNotEmpty)
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _fallbackMonogram(brandName),
                              )
                            : _fallbackMonogram(brandName),
                      ),
                      // Offer Type Badge on top-left
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _buildOfferPill(offerType),
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
                            const SizedBox(height: 3),
                            Text(
                              [
                                brandName,
                                if (locations.isNotEmpty) locations.take(2).join(', '),
                                if (locations.length > 2) '+${locations.length - 2}',
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF667085),
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Badges Row: Date + Budget
                        Row(
                          children: [
                            if (dateDisplay.isNotEmpty && dateDisplay != '—') ...[
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
                                  dateDisplay,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: MeetdayColors.primaryRed,
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
                                offerType == 'BARTER'
                                    ? 'BARTER'
                                    : _formatCurrency(budgetAmount, currency),
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
      ),
    );
  }
}

// ─── Campaign Detail Modal Bottom Sheet ──────────────────────────────────────

void showCampaignDetailModal(BuildContext context, Map<String, dynamic> campaign) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CampaignDetailModalSheet(campaign: campaign),
  );
}

class _CampaignDetailModalSheet extends ConsumerStatefulWidget {
  const _CampaignDetailModalSheet({required this.campaign});

  final Map<String, dynamic> campaign;

  @override
  ConsumerState<_CampaignDetailModalSheet> createState() => _CampaignDetailModalSheetState();
}

class _CampaignDetailModalSheetState extends ConsumerState<_CampaignDetailModalSheet> {
  bool _isSubmitting = false;

  Future<void> _handleExpressInterest() async {
    final campaignId = widget.campaign['id'];
    if (campaignId == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post<dynamic>(
        '/campaigns/published/$campaignId/interest',
        queryParameters: {'role': 'COMMUNITY'},
      );

      if (mounted) {
        Navigator.of(context).pop();
        ref.invalidate(chatHubProvider);

        final isAlready = res.data is Map && res.data['alreadyInterested'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAlready
                  ? 'You have already applied! Check your Campaigns chat hub.'
                  : 'Interest recorded! A chat has been created in your Campaigns chat hub.',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to express interest: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    }
  }

  Widget _redBadge(String text) {
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
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
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

  Widget _monogramFallback(String name) {
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

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final name = (c['name'] ?? 'Campaign Brief').toString();
    final brandName = (c['brandName'] ?? 'Brand').toString();
    final logoUrl = c['brandLogo'] as String?;
    final goal = (c['goal'] ?? '').toString();
    final offerType = (c['offerType'] ?? 'CASH').toString().toUpperCase();
    final locations = (c['locations'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final audience = (c['audience'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final description = (c['description'] ?? '').toString();
    final barterElements = c['barterElements'] as String?;
    final budgetAmount = c['budgetAmount'];
    final currency = (c['budgetCurrency'] ?? '₹').toString();
    final startDate = c['startDate'] as String?;
    final endDate = c['endDate'] as String?;
    final status = (c['status'] ?? 'PUBLISHED').toString().toUpperCase();
    final adminRejectionRemark = c['adminRejectionRemark'] as String?;

    final startDisplay = _formatDateShort(startDate);
    final endDisplay = _formatDateShort(endDate);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.black, width: 3),
          left: BorderSide(color: Colors.black, width: 3),
          right: BorderSide(color: Colors.black, width: 3),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          // Subheader: Welcome to Meetday
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Welcome to ',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      TextSpan(
                        text: 'Meetday',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MeetdayColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Navigation Bar: ← Back to Active Campaigns + Close button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 14, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF8F3),
              border: Border(
                top: BorderSide(color: Colors.black12, width: 1),
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
                        'Back to Active Campaigns',
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

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Section — side by side: logo left, name right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
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
                        clipBehavior: Clip.antiAlias,
                        child: (logoUrl != null && logoUrl.isNotEmpty)
                            ? Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _monogramFallback(brandName),
                              )
                            : _monogramFallback(brandName),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Initiated by $brandName',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildStatusPill(status),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Prominent Action Button: I AM INTERESTED / REQUEST SENT
                  GestureDetector(
                    onTap: _isSubmitting ? null : _handleExpressInterest,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: MeetdayColors.primaryRed,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'I AM INTERESTED',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Rejection Remark Banner (if REJECTED)
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

                  // Metadata Card (#FFF8F3 - exact match of CampaignDetailView.tsx)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                        // Start & End Dates Row
                        Row(
                          children: [
                            if (startDisplay.isNotEmpty && startDisplay != '—')
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
                                    _redBadge(startDisplay),
                                  ],
                                ),
                              ),
                            if (endDisplay.isNotEmpty && endDisplay != '—' && endDisplay != startDisplay)
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
                                    _redBadge(endDisplay),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        // Target Locations
                        const SizedBox(height: 10),
                        Text(
                          'TARGET LOCATIONS',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF525252),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (locations.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: locations.map((loc) => _redBadge(loc)).toList(),
                          )
                        else
                          Text(
                            'All India / Remote',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF525252),
                            ),
                          ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Colors.black12),
                        ),

                        // Campaign Goal & Offer Type Row
                        Row(
                          children: [
                            if (goal.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CAMPAIGN GOAL',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF525252),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    _redBadge(goal),
                                  ],
                                ),
                              ),
                            if (offerType.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OFFER TYPE',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF525252),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    _redBadge(offerType),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        // Target Audience Row
                        if (audience.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: Colors.black12),
                          ),
                          Text(
                            'TARGET AUDIENCE',
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
                            children: audience.map((aud) {
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
                                  aud.toUpperCase(),
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

                  const SizedBox(height: 16),

                  // About the Campaign Card
                  if (description.isNotEmpty) ...[
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
                            'About the Campaign',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
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
                  ],

                  // Collaboration Type / Campaign Budget Card
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
                            Text(
                              offerType == 'BARTER'
                                  ? 'Collaboration Type'
                                  : (offerType == 'BOTH' ? 'Budget & Barter' : 'Campaign Budget'),
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            Row(
                              children: [
                                if (offerType == 'CASH' || offerType == 'BOTH')
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
                                if (offerType == 'BARTER' || offerType == 'BOTH')
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
                        if (offerType == 'BARTER')
                          Text(
                            barterElements != null && barterElements.isNotEmpty
                                ? barterElements
                                : 'This brand is open to product, service, or venue barter collaborations.',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF525252),
                            ),
                          ),
                        if (offerType != 'BARTER') ...[
                          Container(
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
                                Text(
                                  'Budget: ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF525252),
                                  ),
                                ),
                                Text(
                                  _formatCurrency(budgetAmount, currency),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: MeetdayColors.primaryRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (barterElements != null && barterElements.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: Colors.black12),
                            const SizedBox(height: 8),
                            Text(
                              'BARTER ELEMENTS',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF525252),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              barterElements,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ],
                      ],
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
}
