import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';

/// Full-featured Experience / Sponsorship Proposal Creation & Editing screen.
/// Replicates meetday-frontend's `proposal/page.tsx` with live backend connectivity.
class ProposalFormScreen extends ConsumerStatefulWidget {
  const ProposalFormScreen({
    super.key,
    this.initialProposal,
    required this.onSuccess,
  });

  /// Null when creating a new proposal; populated when editing an existing one.
  final Map<String, dynamic>? initialProposal;
  final VoidCallback onSuccess;

  @override
  ConsumerState<ProposalFormScreen> createState() => _ProposalFormScreenState();
}

class _ProposalFormScreenState extends ConsumerState<ProposalFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _aboutController;
  late final TextEditingController _ageGroupController;
  late final TextEditingController _guestCountController;
  late final TextEditingController _videoUrlController;
  final TextEditingController _audienceTagInputController = TextEditingController();

  // State
  String? _imageUrl;
  String? _docUrl;
  String _docName = '';

  DateTime? _startDate;
  DateTime? _endDate;

  // Venues: list of maps { 'venue': string, 'city': string }
  List<Map<String, String>> _venues = [
    {'venue': '', 'city': ''}
  ];

  // Audience Profile tags
  List<String> _audienceTags = [];

  // Sponsorship type: CASH, BARTER, BOTH
  String _sponsorshipType = 'BOTH';

  // Sponsorship slots: list of { 'name': string, 'price': string }
  List<Map<String, String>> _sponsorTiers = [
    {'name': 'Title Sponsor', 'price': '50000'}
  ];

  bool _isLoading = false;
  bool _isCommunityApproved = true;
  String? _communityName;
  String? _communityApprovalStatus;

  bool get _isEditing => widget.initialProposal != null;

  @override
  void initState() {
    super.initState();

    final p = widget.initialProposal;
    _nameController = TextEditingController(text: p?['name']?.toString() ?? '');
    _aboutController = TextEditingController(text: p?['about']?.toString() ?? '');
    _ageGroupController = TextEditingController(text: p?['ageGroup']?.toString() ?? '21-40');
    _guestCountController = TextEditingController(text: p?['guestCount']?.toString() ?? '150');
    _videoUrlController = TextEditingController(text: p?['videoUrl']?.toString() ?? '');

    _imageUrl = p?['imageUrl'] as String?;
    _docUrl = p?['docUrl'] as String?;
    _docName = (p?['docName'] ?? '').toString();

    // Dates
    if (p?['eventDate'] != null) {
      try {
        _startDate = DateTime.parse(p!['eventDate'].toString()).toLocal();
      } catch (_) {}
    }
    _startDate ??= DateTime.now().add(const Duration(days: 14));

    if (p?['eventEndDate'] != null) {
      try {
        _endDate = DateTime.parse(p!['eventEndDate'].toString()).toLocal();
      } catch (_) {}
    }
    _endDate ??= _startDate!.add(const Duration(days: 2));

    // Venues
    final pVenues = (p?['venues'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final pCities = (p?['venueCities'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (pVenues.isNotEmpty) {
      _venues = List.generate(pVenues.length, (i) {
        return {
          'venue': pVenues[i],
          'city': i < pCities.length ? pCities[i] : '',
        };
      });
    }

    // Audience Profile
    final pAudience = (p?['audienceProfile'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (pAudience.isNotEmpty) {
      _audienceTags = List.from(pAudience);
    } else {
      _audienceTags = ['Tech Enthusiasts', 'Creators', 'Founders'];
    }

    // Sponsorship type
    final pType = p?['sponsorshipType']?.toString().toUpperCase();
    if (pType == 'CASH' || pType == 'BARTER' || pType == 'BOTH') {
      _sponsorshipType = pType!;
    }

    // Sponsor Tiers
    final pTiers = (p?['sponsorTiers'] as List?)?.whereType<Map>().toList();
    if (pTiers != null && pTiers.isNotEmpty) {
      _sponsorTiers = pTiers.map((t) {
        return {
          'name': (t['name'] ?? '').toString(),
          'price': (t['price'] ?? '').toString().replaceAll('₹', '').trim(),
        };
      }).toList();
    }

    _fetchCommunityProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _ageGroupController.dispose();
    _guestCountController.dispose();
    _videoUrlController.dispose();
    _audienceTagInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchCommunityProfile() async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.dio.get<dynamic>('/hosts/community');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data['data'] is Map ? res.data['data'] as Map : res.data as Map;
        setState(() {
          _communityName = data['name']?.toString();
          _communityApprovalStatus = data['approvalStatus']?.toString().toUpperCase();
          _isCommunityApproved = _communityApprovalStatus == 'APPROVED';
          // Pre-populate city if not set
          final city = data['city']?.toString();
          if (city != null && city.isNotEmpty && _venues.isNotEmpty && (_venues[0]['city'] ?? '').isEmpty) {
            _venues[0]['city'] = city;
          }
        });
      }
    } catch (_) {
      // Non-blocking fallback
    }
  }

  void _addAudienceTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    if (!_audienceTags.contains(trimmed)) {
      setState(() {
        _audienceTags.add(trimmed);
      });
    }
    _audienceTagInputController.clear();
  }

  void _removeAudienceTag(String tag) {
    setState(() {
      _audienceTags.remove(tag);
    });
  }

  void _addVenue() {
    setState(() {
      _venues.add({'venue': '', 'city': _venues.isNotEmpty ? (_venues[0]['city'] ?? '') : ''});
    });
  }

  void _removeVenue(int index) {
    if (_venues.length > 1) {
      setState(() {
        _venues.removeAt(index);
      });
    }
  }

  void _addSponsorSlot() {
    setState(() {
      _sponsorTiers.add({'name': '', 'price': ''});
    });
  }

  void _removeSponsorSlot(int index) {
    if (_sponsorTiers.length > 1) {
      setState(() {
        _sponsorTiers.removeAt(index);
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: MeetdayColors.primaryRed,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate!.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final initial = _endDate ?? (_startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_startDate ?? DateTime.now()) ? (_startDate ?? DateTime.now()) : initial,
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: MeetdayColors.primaryRed,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  // ── AI Copilot Prompt & Generation ─────────────────────────────────────────

  Future<void> _showAiCopilotDialog() async {
    final promptController = TextEditingController(
      text: 'Annual tech summit with 300 developers, keynotes, and sponsor booths in Bengaluru',
    );
    bool isGenerating = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.black, width: 2.5),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Text('✨', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meetday AI Copilot',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Describe your event idea or format. AI Copilot will generate a complete, structured sponsorship proposal draft.',
                style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1.8),
                ),
                child: TextField(
                  controller: promptController,
                  maxLines: 4,
                  style: GoogleFonts.poppins(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. Creator meetup and panel discussion for 200 video creators in Mumbai...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isGenerating ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
              onPressed: isGenerating
                  ? null
                  : () async {
                      final prompt = promptController.text.trim();
                      if (prompt.isEmpty) return;

                      final messenger = ScaffoldMessenger.of(context);

                      setDialogState(() => isGenerating = true);
                      try {
                        final api = ref.read(apiClientProvider);
                        final res = await api.dio.post<dynamic>(
                          '/sponsorships/copilot/generate-draft',
                          data: {'prompt': prompt},
                        );

                        if (res.statusCode == 200 || res.statusCode == 201) {
                          final data = res.data is Map && res.data['data'] is Map
                              ? res.data['data'] as Map
                              : (res.data as Map? ?? {});

                          setState(() {
                            if (data['name'] != null) _nameController.text = data['name'].toString();
                            if (data['about'] != null) _aboutController.text = data['about'].toString();
                            if (data['age_group'] != null) _ageGroupController.text = data['age_group'].toString();
                            if (data['guest_count'] != null) _guestCountController.text = data['guest_count'].toString();

                            if (data['audience_profile'] is List) {
                              _audienceTags = (data['audience_profile'] as List).map((e) => e.toString()).toList();
                            }
                            if (data['sponsor_tiers'] is List) {
                              final tiers = (data['sponsor_tiers'] as List).whereType<Map>().toList();
                              if (tiers.isNotEmpty) {
                                _sponsorTiers = tiers.map((t) {
                                  return {
                                    'name': (t['name'] ?? '').toString(),
                                    'price': (t['price'] ?? '').toString(),
                                  };
                                }).toList();
                              }
                            }
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Meetday AI filled in the proposal. Review and adjust as needed.',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              backgroundColor: const Color(0xFF7C3AED),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isGenerating = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('AI draft generation failed: $e', style: GoogleFonts.poppins(fontSize: 12)),
                            backgroundColor: MeetdayColors.primaryRed,
                          ),
                        );
                      }
                    },
              child: isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Generate Draft', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image Picker / URL Sheet ───────────────────────────────────────────────

  void _showImagePickerSheet() {
    final urlController = TextEditingController(text: _imageUrl ?? '');
    final presets = [
      'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
      'https://images.unsplash.com/photo-1511578314322-379afb476865?w=800',
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800',
      'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800',
      'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?w=800',
    ];

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
              'Project Logo / Cover Image',
              style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter an image URL or choose from curated event covers (1:1 aspect ratio recommended).',
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1.8),
              ),
              child: TextField(
                controller: urlController,
                style: GoogleFonts.poppins(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'https://...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Or pick a cover template:',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final pUrl = presets[idx];
                  return GestureDetector(
                    onTap: () {
                      urlController.text = pUrl;
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.5),
                        child: Image.network(pUrl, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeetdayColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                onPressed: () {
                  final url = urlController.text.trim();
                  if (url.isNotEmpty) {
                    setState(() => _imageUrl = url);
                  }
                  Navigator.pop(ctx);
                },
                child: Text('Set Image', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Document Picker Sheet ──────────────────────────────────────────────────

  void _showDocumentPickerSheet() {
    final urlController = TextEditingController(text: _docUrl ?? '');
    final nameController = TextEditingController(text: _docName.isNotEmpty ? _docName : 'Sponsorship_Pitch_Deck.pdf');

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
              'Attach Proposal Document (PDF)',
              style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter a direct PDF document or pitch deck link to attach to your sponsorship proposal.',
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Text('Document Name', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1.8),
              ),
              child: TextField(
                controller: nameController,
                style: GoogleFonts.poppins(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Sponsorship_Deck.pdf',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Document PDF URL', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1.8),
              ),
              child: TextField(
                controller: urlController,
                style: GoogleFonts.poppins(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'https://.../deck.pdf',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeetdayColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                onPressed: () {
                  final url = urlController.text.trim();
                  if (url.isNotEmpty) {
                    setState(() {
                      _docUrl = url;
                      _docName = nameController.text.trim().isNotEmpty
                          ? nameController.text.trim()
                          : 'Proposal_Document.pdf';
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: Text('Attach PDF', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Save & Submit Handlers ─────────────────────────────────────────────────

  Future<void> _handleSave({required bool submitForReview}) async {
    final name = _nameController.text.trim();
    final about = _aboutController.text.trim();

    // Basic Draft Validation
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project Name is required'),
          backgroundColor: MeetdayColors.primaryRed,
        ),
      );
      return;
    }

    // Full Submit Validation matching meetday-frontend proposal/page.tsx
    if (submitForReview) {
      if (about.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('About the project description is required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_imageUrl == null || _imageUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project Logo / Cover Image is required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start and End dates are required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_endDate!.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date cannot be before the start date'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_venues.every((v) => (v['venue'] ?? '').trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one venue is required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_venues.any((v) => (v['venue'] ?? '').trim().isNotEmpty && (v['city'] ?? '').trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add a city for every venue'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_audienceTags.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('At least one Audience Profile tag is required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_ageGroupController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Age Group is required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_guestCountController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Number of Guests is required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
      if (_sponsorshipType != 'BARTER') {
        if (_sponsorTiers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one Sponsor Price entry is required'),
              backgroundColor: MeetdayColors.primaryRed,
            ),
          );
          return;
        }
        for (final sp in _sponsorTiers) {
          if ((sp['name'] ?? '').trim().isEmpty || (sp['price'] ?? '').trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All Sponsor slot names and prices must be filled out'),
                backgroundColor: MeetdayColors.primaryRed,
              ),
            );
            return;
          }
        }
      }
      if (_docUrl == null || _docUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal Document file / PDF is required'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);

      final validVenues = _venues.where((v) => (v['venue'] ?? '').trim().isNotEmpty).toList();
      final venuesList = validVenues.isNotEmpty
          ? validVenues.map((v) => v['venue']!.trim()).toList()
          : ['Community Hub'];
      final citiesList = validVenues.isNotEmpty
          ? validVenues.map((v) => v['city']!.trim().isNotEmpty ? v['city']!.trim() : 'Bengaluru').toList()
          : ['Bengaluru'];

      final filteredTiers = _sponsorTiers
          .where((t) => (t['name'] ?? '').trim().isNotEmpty && (t['price'] ?? '').trim().isNotEmpty)
          .map((t) => {
                'name': t['name']!.trim(),
                'price': t['price']!.trim(),
              })
          .toList();

      final payload = <String, dynamic>{
        'name': name,
        'about': about.isNotEmpty ? about : 'Community sponsorship proposal for $name',
        if (_startDate != null) 'eventDate': DateFormat('yyyy-MM-dd').format(_startDate!),
        if (_endDate != null) 'eventEndDate': DateFormat('yyyy-MM-dd').format(_endDate!),
        'venues': venuesList,
        'venueCities': citiesList,
        'audienceProfile': _audienceTags.isNotEmpty ? _audienceTags : ['Community Members'],
        'ageGroup': _ageGroupController.text.trim().isNotEmpty ? _ageGroupController.text.trim() : '18-40',
        'guestCount': _guestCountController.text.trim().isNotEmpty ? _guestCountController.text.trim() : '100',
        'sponsorshipType': _sponsorshipType,
        'sponsorTiers': _sponsorshipType == 'BARTER' ? [] : filteredTiers,
      };

      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        payload['imageKey'] = _imageUrl;
        payload['imageUrl'] = _imageUrl;
      }
      if (_docUrl != null && _docUrl!.isNotEmpty) {
        payload['docKey'] = _docUrl;
        payload['docUrl'] = _docUrl;
        payload['docName'] = _docName.isNotEmpty ? _docName : 'Proposal_Document.pdf';
        payload['docType'] = 'application/pdf';
        payload['docSize'] = 1024 * 1024;
      }
      if (_videoUrlController.text.trim().isNotEmpty) {
        payload['videoUrl'] = _videoUrlController.text.trim();
      }

      String? targetProposalId;

      if (_isEditing) {
        // Update existing proposal: PATCH /sponsorships/:id
        targetProposalId = widget.initialProposal!['id'].toString();
        await api.dio.patch<dynamic>(
          '/sponsorships/$targetProposalId',
          data: payload,
        );
      } else {
        // Create new proposal draft: POST /sponsorships
        final res = await api.dio.post<dynamic>(
          '/sponsorships',
          data: payload,
        );
        if (res.data is Map) {
          final data = res.data['data'] is Map ? res.data['data'] as Map : res.data as Map;
          targetProposalId = data['id']?.toString();
        }
      }

      // If user clicked Submit, call PATCH /sponsorships/:id/submit
      if (submitForReview && targetProposalId != null) {
        await api.dio.patch<dynamic>('/sponsorships/$targetProposalId/submit');
      }

      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submitForReview
                  ? 'Proposal submitted for admin review!'
                  : 'Proposal saved as draft!',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save proposal: $e', style: GoogleFonts.poppins(fontSize: 12)),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Proposal' : 'Create Proposal',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        actions: [
          // Save Draft Action in AppBar
          TextButton(
            onPressed: _isLoading ? null : () => _handleSave(submitForReview: false),
            child: Text(
              'Draft',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          // Submit Action
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MeetdayColors.primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
              onPressed: _isLoading ? null : () => _handleSave(submitForReview: true),
              child: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'SUBMIT',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: Colors.black, height: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title card
              Text(
                _isEditing ? 'Edit Proposal Details' : 'Create New Proposal',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Provide details and upload your proposal document to pitch to brands.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF667085),
                ),
              ),
              if (_communityName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isCommunityApproved ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCommunityApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
                        size: 16,
                        color: _isCommunityApproved ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Community: $_communityName • ${_isCommunityApproved ? 'Approved Host' : 'Pending Approval'}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // AI Copilot Card (matching website's AI Copilot)
              if (!_isEditing) ...[
                GestureDetector(
                  onTap: _showAiCopilotDialog,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 2.2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black, width: 1.8),
                          ),
                          child: const Center(
                            child: Text('🪄', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meetday AI Copilot',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                'Generate a full proposal draft from your idea in seconds',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Text(
                            'TRY AI',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Main Form Container: Neo-Brutalist White Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Project Name
                    _buildLabel('Project Name', isRequired: true),
                    const SizedBox(height: 4),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Annual Charity Gala or Tech Summit',
                    ),
                    const SizedBox(height: 14),

                    // 2. About the project
                    _buildLabel('About the project', isRequired: true),
                    const SizedBox(height: 4),
                    _buildTextField(
                      controller: _aboutController,
                      hint: "Describe your project's details, format, goals, and brand exposure opportunities...",
                      maxLines: 4,
                    ),
                    const SizedBox(height: 14),

                    // 3. Project Logo / Cover Image
                    _buildLabel('Project Logo / Cover Image', isRequired: true),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _imageUrl != null && _imageUrl!.isNotEmpty
                                ? Image.network(
                                    _imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.black38),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_outlined, size: 26, color: Colors.black38),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _showImagePickerSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black, width: 1.8),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_photo_alternate_outlined, size: 16, color: Colors.black),
                                      const SizedBox(width: 6),
                                      Text(
                                        _imageUrl != null ? 'Change Image' : 'Choose Image',
                                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'JPG, PNG accepted (1:1 ratio, max 5MB).',
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Dates
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Start Date', isRequired: true),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: _selectStartDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black, width: 1.8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.black54),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _startDate != null ? dateFormat.format(_startDate!) : 'Select Date',
                                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('End Date', isRequired: true),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: _selectEndDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black, width: 1.8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_outlined, size: 16, color: Colors.black54),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _endDate != null ? dateFormat.format(_endDate!) : 'Select Date',
                                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600),
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
                    const SizedBox(height: 16),

                    // 5. Venues & Cities
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Venues & Cities', isRequired: true),
                        GestureDetector(
                          onTap: _addVenue,
                          child: Text(
                            '+ Add Venue',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: MeetdayColors.primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(_venues.length, (idx) {
                      final v = _venues[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black, width: 1.8),
                                ),
                                child: TextFormField(
                                  initialValue: v['venue'],
                                  style: GoogleFonts.poppins(fontSize: 12),
                                  onChanged: (val) => _venues[idx]['venue'] = val,
                                  decoration: InputDecoration(
                                    hintText: 'Venue (e.g. Palace Grounds)',
                                    hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black, width: 1.8),
                                ),
                                child: TextFormField(
                                  initialValue: v['city'],
                                  style: GoogleFonts.poppins(fontSize: 12),
                                  onChanged: (val) => _venues[idx]['city'] = val,
                                  decoration: InputDecoration(
                                    hintText: 'City (e.g. Bengaluru)',
                                    hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                            if (_venues.length > 1) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removeVenue(idx),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(Icons.close_rounded, size: 18, color: Colors.black45),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    // 6. Audience Profile Tags
                    _buildLabel('Audience Profile', isRequired: true),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black, width: 1.8),
                            ),
                            child: TextField(
                              controller: _audienceTagInputController,
                              style: GoogleFonts.poppins(fontSize: 12),
                              onSubmitted: _addAudienceTag,
                              decoration: InputDecoration(
                                hintText: 'e.g. Founders, College Students',
                                hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _addAudienceTag(_audienceTagInputController.text),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: 1.8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                              ],
                            ),
                            child: Text(
                              'Add',
                              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_audienceTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _audienceTags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tag,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeAudienceTag(tag),
                                  child: const Icon(Icons.close_rounded, size: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 7. Demographics (Age Group & Guest Count)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Age Group', isRequired: true),
                              const SizedBox(height: 4),
                              _buildTextField(
                                controller: _ageGroupController,
                                hint: 'e.g. 21-40 or 18-28',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Guests Count', isRequired: true),
                              const SizedBox(height: 4),
                              _buildTextField(
                                controller: _guestCountController,
                                hint: 'e.g. 150',
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 8. Proposal Video Link (Optional)
                    _buildLabel('Proposal Video Link (Optional)', isRequired: false),
                    const SizedBox(height: 4),
                    _buildTextField(
                      controller: _videoUrlController,
                      hint: 'https://youtube.com/watch?v=...',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste a YouTube or public video link for your proposal.',
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45),
                    ),
                    const SizedBox(height: 16),

                    // 9. Proposal Document (PDF)
                    _buildLabel('Proposal Document (PDF)', isRequired: true),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 1.8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            child: const Center(
                              child: Text('📄', style: TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _docName.isNotEmpty ? _docName : 'No PDF attached yet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _docName.isNotEmpty ? Colors.black : Colors.black45,
                                  ),
                                ),
                                Text(
                                  'PDF accepted. Max 10MB.',
                                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.black45),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _showDocumentPickerSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                                ],
                              ),
                              child: Text(
                                _docUrl != null ? 'Change' : 'Attach',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 10. Sponsorship Type
                    _buildLabel('Sponsorship Type', isRequired: true),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTypeSegment('CASH', 'Cash'),
                        const SizedBox(width: 8),
                        _buildTypeSegment('BARTER', 'Barter'),
                        const SizedBox(width: 8),
                        _buildTypeSegment('BOTH', 'Both'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sponsorshipType == 'BARTER'
                          ? 'Barter selected — brands collaborate through products/services without fixed cash pricing.'
                          : _sponsorshipType == 'BOTH'
                              ? 'Both selected — define cash sponsorship pricing slots while also remaining open to barter.'
                              : 'Cash selected — define your cash pricing slots for brands.',
                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),

                    // 11. Sponsorship Slots / Pricing (if CASH or BOTH)
                    if (_sponsorshipType != 'BARTER') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Sponsorship Slots', isRequired: true),
                          GestureDetector(
                            onTap: _addSponsorSlot,
                            child: Text(
                              '+ Add Slot',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: MeetdayColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(_sponsorTiers.length, (idx) {
                        final tier = _sponsorTiers[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black, width: 1.8),
                                  ),
                                  child: TextFormField(
                                    initialValue: tier['name'],
                                    style: GoogleFonts.poppins(fontSize: 12),
                                    onChanged: (val) => _sponsorTiers[idx]['name'] = val,
                                    decoration: InputDecoration(
                                      hintText: 'Slot Name (e.g. Title Partner)',
                                      hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black, width: 1.8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(left: 10),
                                        child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: tier['price'],
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.poppins(fontSize: 12),
                                          onChanged: (val) => _sponsorTiers[idx]['price'] = val,
                                          decoration: InputDecoration(
                                            hintText: '50,000',
                                            hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_sponsorTiers.length > 1) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeSponsorSlot(idx),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.black45),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons at bottom of form
                    const Divider(height: 24, thickness: 1.5, color: Colors.black12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLoading ? null : () => _handleSave(submitForReview: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'SAVE AS DRAFT',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
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
                            onTap: _isLoading ? null : () => _handleSave(submitForReview: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: MeetdayColors.primaryRed,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        'SUBMIT FOR REVIEW',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
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
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildLabel(String text, {required bool isRequired}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: MeetdayColors.primaryRed, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.8),
      ),
      child: TextField(
        controller: controller,
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

  Widget _buildTypeSegment(String value, String label) {
    final isSelected = _sponsorshipType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sponsorshipType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? MeetdayColors.primaryRed : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: isSelected
                ? const [BoxShadow(color: Colors.black, offset: Offset(2.5, 2.5), blurRadius: 0)]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
