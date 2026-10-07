import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/meetday_colors.dart';
import '../../auth/domain/account_role.dart';
import '../../auth/state/auth_provider.dart';
import 'proposal_components.dart';

class BrandDataRoomScreen extends ConsumerStatefulWidget {
  const BrandDataRoomScreen({super.key, this.proposalId});

  final String? proposalId;

  @override
  ConsumerState<BrandDataRoomScreen> createState() =>
      _BrandDataRoomScreenState();
}

class _BrandDataRoomScreenState extends ConsumerState<BrandDataRoomScreen> {
  List<Map<String, dynamic>> _proposals = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedCategoryId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    final proposalId = widget.proposalId;
    if (proposalId != null && proposalId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openSharedProposal(proposalId),
      );
    }
  }

  dynamic _unwrap(dynamic response) =>
      response is Map && response['data'] != null ? response['data'] : response;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.dio.get<dynamic>('/sponsorships/published'),
        api.dio.get<dynamic>('/categories'),
      ]);
      final proposalsPayload = _unwrap(results[0].data);
      final categoriesPayload = _unwrap(results[1].data);
      final rawProposals = proposalsPayload is Map
          ? proposalsPayload['proposals']
          : proposalsPayload;
      final rawCategories = categoriesPayload is List
          ? categoriesPayload
          : const [];
      if (!mounted) return;
      setState(() {
        _proposals = rawProposals is List
            ? rawProposals
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _categories = rawCategories
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openSharedProposal(String proposalId) async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<dynamic>('/sponsorships/published/$proposalId');
      final proposal = _unwrap(response.data);
      if (!mounted || proposal is! Map) return;
      _openProposal(Map<String, dynamic>.from(proposal));
    } catch (error) {
      if (mounted)
        _showMessage('Could not load this proposal: $error', isError: true);
    }
  }

  List<Map<String, dynamic>> get _filteredProposals {
    final query = _search.trim().toLowerCase();
    return _proposals.where((proposal) {
      if (_selectedCategoryId != null) {
        final host = proposal['hostProfile'] is Map
            ? proposal['hostProfile'] as Map
            : const {};
        final space = proposal['spaceProfile'] is Map
            ? proposal['spaceProfile'] as Map
            : const {};
        final categories = host['categories'] is List
            ? host['categories'] as List
            : (space['categories'] is List
                  ? space['categories'] as List
                  : const []);
        final matches = categories.whereType<Map>().any(
          (category) => category['id']?.toString() == _selectedCategoryId,
        );
        if (!matches) return false;
      }
      if (query.isEmpty) return true;
      final host = proposal['hostProfile'] is Map
          ? proposal['hostProfile'] as Map
          : const {};
      final hostName = (host['displayName'] ?? '').toString().toLowerCase();
      return (proposal['name'] ?? '').toString().toLowerCase().contains(
            query,
          ) ||
          (proposal['about'] ?? '').toString().toLowerCase().contains(query) ||
          hostName.contains(query) ||
          (proposal['city'] ?? '').toString().toLowerCase().contains(query);
    }).toList();
  }

  void _openProposal(Map<String, dynamic> proposal) {
    final role = ref.read(authControllerProvider).role;
    if (role != AccountRole.brand) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Brand account required'),
          content: const Text(
            'Sign in or create a brand account to view full details and express interest.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final returnPath = widget.proposalId == null
                    ? '/brand/data-room'
                    : '/brand/proposal/${Uri.encodeComponent(widget.proposalId!)}';
                context.push(
                  '/login/brand?redirectTo=${Uri.encodeQueryComponent(returnPath)}',
                );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => ProposalDetailDialog(
        proposal: proposal,
        isBrand: true,
        onChatStarted: () => context.go('/dashboard'),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? MeetdayColors.primaryRed
              : const Color(0xFF10B981),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final proposals = _filteredProposals;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      body: RefreshIndicator(
        color: MeetdayColors.primaryRed,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            Text(
              'Active Sponsorships',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Browse proposals published by communities and hubs.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search proposals, communities, or cities',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = null),
                    ),
                  ),
                  ..._categories.map((category) {
                    final id = category['id']?.toString() ?? '';
                    if (id.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          (category['name'] ?? 'Category').toString(),
                        ),
                        selected: _selectedCategoryId == id,
                        onSelected: (_) =>
                            setState(() => _selectedCategoryId = id),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: MeetdayColors.primaryRed,
                      ),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else if (proposals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Text(
                  'No proposals found for this filter.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              )
            else
              ...proposals.map((proposal) {
                final host = proposal['hostProfile'] is Map
                    ? proposal['hostProfile'] as Map
                    : const {};
                final space = proposal['spaceProfile'] is Map
                    ? proposal['spaceProfile'] as Map
                    : const {};
                final hostName =
                    (host['displayName'] ??
                            space['businessName'] ??
                            'Community')
                        .toString();
                final title = (proposal['name'] ?? 'Sponsorship proposal')
                    .toString();
                final about = (proposal['about'] ?? '').toString();
                final date = (proposal['eventDate'] ?? '')
                    .toString()
                    .split('T')
                    .first;
                final city = (proposal['city'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openProposal(proposal),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Hosted by $hostName',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                          if (about.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              about,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 11),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (date.isNotEmpty) Chip(label: Text(date)),
                              if (city.isNotEmpty) Chip(label: Text(city)),
                              Chip(
                                label: Text(
                                  (proposal['sponsorshipType'] ?? 'CASH')
                                      .toString(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
