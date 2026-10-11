import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';

class SpaceCommunityListingForm extends ConsumerStatefulWidget {
  const SpaceCommunityListingForm({super.key, this.onEditAccount, this.isCommunity = false});

  final VoidCallback? onEditAccount;
  final bool isCommunity;

  @override
  ConsumerState<SpaceCommunityListingForm> createState() =>
      _SpaceCommunityListingFormState();
}

class _SpaceCommunityListingFormState
    extends ConsumerState<SpaceCommunityListingForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _venuesController = TextEditingController();
  final _capacityController = TextEditingController();
  final _communitySizeController = TextEditingController();
  final _experiencesController = TextEditingController();
  final _locationsController = TextEditingController();
  final _popupDaysController = TextEditingController();
  final _popupPriceController = TextEditingController();
  final _brandingDaysController = TextEditingController();
  final _brandingPriceController = TextEditingController();
  final _videoController = TextEditingController();
  final _averageGuestsController = TextEditingController();
  final List<Map<String, dynamic>> _pastEvents = [];
  final List<Map<String, dynamic>> _brands = [];
  List<String> _showcaseKeys = [];
  String? _posterKey;
  String? _pdfKey;
  String? _loadError;
  bool _uploading = false;
  final Map<String, Uint8List> _assetPreviews = {};

  late final Future<List<Map<String, dynamic>>> _categoriesFuture;
  Map<String, dynamic>? _existingProfile;
  PlatformFile? _logoFile;
  List<String> _selectedCategoryIds = [];
  bool _loadingProfile = true;
  bool _saving = false;
  String get _profilePath => widget.isCommunity ? '/hosts/community' : '/spaces/community';

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
    _loadExistingProfile();
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get<dynamic>('/categories', queryParameters: widget.isCommunity ? null : const {'type': 'SPACE'});
    final body = response.data;
    final payload = body is Map ? (body['data'] ?? body) : body;
    return payload is List
        ? payload.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];
  }

  Future<void> _loadExistingProfile() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<dynamic>(_profilePath);
      final body = response.data;
      final data = body is Map ? (body['data'] ?? body) : null;
      if (data is Map) {
        final profile = <String, dynamic>{...Map<String, dynamic>.from(data),
          if (data['pendingRevision'] is Map) ...Map<String, dynamic>.from(data['pendingRevision'] as Map),
        };
        _existingProfile = profile;
        _nameController.text = (profile['name'] ?? '').toString();
        _aboutController.text = (profile['about'] ?? '').toString();
        _venuesController.text = (profile['numberOfVenues'] ?? '').toString();
        _capacityController.text = (profile['venueCapacity'] ?? '').toString();
        _communitySizeController.text = (profile[widget.isCommunity ? 'size' : 'communitySize'] ?? '')
            .toString();
        _averageGuestsController.text = (profile['avgGuestCount'] ?? '').toString();
        _experiencesController.text = (profile['experiencesPerYear'] ?? '')
            .toString();
        _locationsController.text =
            ((profile['activeLocations'] as List?) ?? const []).join(', ');
        _popupDaysController.text = (profile['popupDays'] ?? '').toString();
        _popupPriceController.text = (profile['popupPrice'] ?? '').toString();
        _brandingDaysController.text = (profile['brandingDays'] ?? '')
            .toString();
        _brandingPriceController.text = (profile['brandingPrice'] ?? '')
            .toString();
        _selectedCategoryIds = profile['categoryIds'] is List
          ? (profile['categoryIds'] as List).map((id) => id.toString()).toList()
          : ((profile['categories'] as List?) ?? const [])
            .whereType<Map>()
            .map((category) => (category['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
        _videoController.text = (profile['videoLink'] ?? '').toString();
        _posterKey = profile[widget.isCommunity ? 'secondaryImageKey' : 'posterKey']?.toString();
        _pdfKey = profile['proposalPdfKey']?.toString();
        _showcaseKeys = (profile['centreShowcaseImageKeys'] as List? ?? const []).map((key) => key.toString()).toList();
        _pastEvents.addAll((profile['pastEvents'] as List? ?? const []).whereType<Map>().map((event) => {
          'name': event['name'] ?? '', 'description': event['description'] ?? '',
          'imageKeys': List<String>.from(event['imageKeys'] as List? ?? const []),
        }));
        _brands.addAll((profile['brandsWorkedWith'] as List? ?? const []).whereType<Map>().map((brand) => {
          'brandName': brand['brandName'] ?? '', 'url': brand['url'] ?? '', 'logoKey': brand['logoKey'],
        }));
      }
    } catch (error) {
      if (error is! DioException || error.response?.statusCode != 404) {
        _loadError = 'Could not load your listing. Retry before editing.';
      }
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isEmpty) return;
    final file = result.single;
    final size = await file.length();
    if (size == null || size > 5 * 1024 * 1024) {
      _showMessage('Logo must be 5 MB or smaller.', isError: true);
      return;
    }
    setState(() => _logoFile = file);
  }

  Future<String> _uploadLogo(PlatformFile file, {String context = 'SPONSORSHIP_MEDIA'}) async {
    final extension = file.extension?.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };
    final api = ref.read(apiClientProvider);
    final response = await api.dio.post<dynamic>(
      '/storage/upload-url',
      data: {'context': context, 'contentType': contentType},
    );
    final body = response.data;
    final data = body is Map ? (body['data'] ?? body) : null;
    if (data is! Map || (data['uploadUrl'] ?? data['url']) == null || data['key'] == null) {
      throw const FormatException('Storage did not return an upload URL.');
    }
    await Dio().put<dynamic>(
      (data['uploadUrl'] ?? data['url']).toString(),
      data: await file.readAsBytes(),
      options: Options(
        headers: {'Content-Type': contentType},
        responseType: ResponseType.plain,
      ),
    );
    return data['key'].toString();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? MeetdayColors.primaryRed : null,
      ),
    );
  }

  Future<void> _pickAsset({required String context, required ValueChanged<String> onUploaded,
    bool pdf = false}) async {
    if (_uploading || _saving) return;
    final files = await FilePicker.pickFiles(type: FileType.custom,
      allowedExtensions: pdf ? const ['pdf'] : const ['jpg', 'jpeg', 'png', 'webp']);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final size = await file.length();
    if (size == null || size > (pdf ? 10 : 5) * 1024 * 1024) {
      _showMessage(pdf ? 'Choose a PDF under 10 MB.' : 'Choose an image under 5 MB.', isError: true);
      return;
    }
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final key = await _uploadLogo(file, context: context);
      if (!mounted) return;
      setState(() {
        if (!pdf) _assetPreviews[key] = bytes;
        onUploaded(key);
      });
    } catch (_) {
      if (mounted) _showMessage('Upload failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _assetTile(String key, VoidCallback onRemove, {String? url}) => SizedBox(
    width: 100, height: 100,
    child: Stack(fit: StackFit.expand, children: [
      if (_assetPreviews[key] != null)
        Image.memory(_assetPreviews[key]!, fit: BoxFit.cover)
      else if (url != null && url.isNotEmpty)
        Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined))
      else const Center(child: Icon(Icons.image_outlined)),
      Positioned(right: 0, top: 0, child: IconButton(
        tooltip: 'Remove image', onPressed: _saving || _uploading ? null : onRemove,
        style: IconButton.styleFrom(backgroundColor: Colors.white),
        icon: const Icon(Icons.close_rounded, size: 18),
      )),
    ]),
  );

  Widget _draftField(Map<String, dynamic> draft, String field, String label, {int maxLines = 1,
    int maxLength = 200}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(initialValue: draft[field]?.toString() ?? '', maxLines: maxLines,
      maxLength: maxLength, decoration: InputDecoration(labelText: label),
      onChanged: (value) => draft[field] = value.trim()),
  );

  List<Widget> _mediaFields() => [
    const SizedBox(height: 16),
    Text('Media', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
    if (_uploading) const LinearProgressIndicator(),
    OutlinedButton.icon(icon: const Icon(Icons.image_outlined),
      label: Text(_posterKey == null ? 'Add highlight poster' : 'Replace highlight poster'),
      onPressed: _uploading || _saving ? null : () => _pickAsset(context: 'SPONSORSHIP_MEDIA',
        onUploaded: (key) => _posterKey = key)),
    if (_posterKey != null) _assetTile(_posterKey!, () => setState(() => _posterKey = null),
      url: _existingProfile?['posterUrl']?.toString()),
    const SizedBox(height: 10),
    if (!widget.isCommunity) ...[
    OutlinedButton.icon(icon: const Icon(Icons.add_photo_alternate_outlined),
      label: const Text('Add centre photo'),
      onPressed: _uploading || _saving ? null : () => _pickAsset(context: 'COMMUNITY_PAST_EVENT_MEDIA',
        onUploaded: (key) => _showcaseKeys.add(key))),
    Wrap(spacing: 8, runSpacing: 8, children: _showcaseKeys.map((key) {
      final oldKeys = _existingProfile?['centreShowcaseImageKeys'] as List? ?? const [];
      final oldUrls = _existingProfile?['centreShowcaseUrls'] as List? ?? const [];
      final index = oldKeys.indexOf(key);
      return _assetTile(key, () => setState(() => _showcaseKeys.remove(key)),
        url: index >= 0 && index < oldUrls.length ? oldUrls[index].toString() : null);
    }).toList()),
    const SizedBox(height: 10),
    _textField(_videoController, 'Video link', required: false),
    const SizedBox(height: 10),
    OutlinedButton.icon(icon: const Icon(Icons.upload_file_outlined),
      label: Text(_pdfKey == null ? 'Add listing proposal PDF' : 'Replace listing proposal PDF'),
      onPressed: _uploading || _saving ? null : () => _pickAsset(context: 'SPACE_PROPOSAL_DOCUMENT', pdf: true,
        onUploaded: (key) => _pdfKey = key)),
    if (_pdfKey != null) ListTile(contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(_pdfKey!.split('/').last),
      trailing: IconButton(tooltip: 'Remove PDF', icon: const Icon(Icons.close_rounded),
        onPressed: _saving || _uploading ? null : () => setState(() => _pdfKey = null))),
    ],
    const SizedBox(height: 16),
    Text('Past experiences', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
    for (final event in _pastEvents) Padding(key: ObjectKey(event),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _draftField(event, 'name', 'Experience name'),
        _draftField(event, 'description', 'Description', maxLines: 3, maxLength: 2000),
        Wrap(spacing: 8, children: (event['imageKeys'] as List<String>).map((key) =>
          _assetTile(key, () => setState(() => (event['imageKeys'] as List).remove(key)))).toList()),
        Row(children: [Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add photo'), onPressed: _saving || _uploading || (event['imageKeys'] as List).length >= 2
              ? null : () => _pickAsset(context: 'COMMUNITY_PAST_EVENT_MEDIA',
                onUploaded: (key) => (event['imageKeys'] as List).add(key)))),
          IconButton(tooltip: 'Remove experience', icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _saving || _uploading ? null : () => setState(() => _pastEvents.remove(event)))]),
        const Divider(),
      ])),
    OutlinedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Add experience'),
      onPressed: _saving || _uploading ? null : () => setState(() => _pastEvents.add({
        'name': '', 'description': '', 'imageKeys': <String>[],
      }))),
    const SizedBox(height: 16),
    Text('Brands worked with', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
    for (final brand in _brands) Padding(key: ObjectKey(brand),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _draftField(brand, 'brandName', 'Brand name'),
        _draftField(brand, 'url', 'Brand website', maxLength: 500),
        if (brand['logoKey'] != null) _assetTile(brand['logoKey'].toString(),
          () => setState(() => brand['logoKey'] = null)),
        Row(children: [Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.image_outlined),
          label: const Text('Choose brand logo'), onPressed: _saving || _uploading ? null : () => _pickAsset(
            context: 'COMMUNITY_BRAND_LOGO_MEDIA', onUploaded: (key) => brand['logoKey'] = key))),
          IconButton(tooltip: 'Remove brand', icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _saving || _uploading ? null : () => setState(() => _brands.remove(brand)))]),
        const Divider(),
      ])),
    OutlinedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('Add brand'),
      onPressed: _saving || _uploading ? null : () => setState(() => _brands.add({'brandName': '', 'url': ''}))),
  ];

  Future<void> _save() async {
    if (_saving || _uploading || _loadError != null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryIds.isEmpty) {
      _showMessage('Select at least one category.', isError: true);
      return;
    }
    if (_logoFile == null &&
        (_existingProfile?['logoKey'] ?? '').toString().isEmpty) {
      _showMessage('Choose a logo to activate your listing.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final logoKey = _logoFile != null
          ? await _uploadLogo(_logoFile!)
          : _existingProfile!['logoKey'].toString();
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post<dynamic>(
            _profilePath,
            data: {
              'name': _nameController.text.trim(),
              'about': _aboutController.text.trim(),
              'logoKey': logoKey,
              if (widget.isCommunity) ...{
                'secondaryImageKey': _posterKey,
                'size': _communitySizeController.text.trim(),
                'avgGuestCount': _averageGuestsController.text.trim(),
              } else ...{
                'posterKey': _posterKey,
                'numberOfVenues': _venuesController.text.trim(),
                'venueCapacity': _capacityController.text.trim(),
                'communitySize': _communitySizeController.text.trim(),
              },
              'experiencesPerYear': _experiencesController.text.trim(),
              if (!widget.isCommunity) ...{
              'activeLocations': _locationsController.text
                  .split(',')
                  .map((location) => location.trim())
                  .where((location) => location.isNotEmpty)
                  .toList(),
              'centreShowcaseImageKeys':
                    _showcaseKeys,
                  'videoLink': _videoController.text.trim(),
                  'proposalPdfKey': _pdfKey,
                  },
              'categoryIds': _selectedCategoryIds,
              'pastEvents': _pastEvents,
              'brandsWorkedWith': _brands.map((brand) => {
                'brandName': brand['brandName'], 'url': brand['url'],
                if (brand['logoKey'] != null) 'logoKey': brand['logoKey'],
              }).toList(),
              if (!widget.isCommunity) ...{
                'popupDays': _popupDaysController.text.trim(),
                'popupPrice': _popupPriceController.text.trim(),
                'brandingDays': _brandingDaysController.text.trim(),
                'brandingPrice': _brandingPriceController.text.trim(),
              },
            },
          );
      if (!mounted) return;
      final body = response.data;
      final data = body is Map ? (body['data'] ?? body) : null;
      _existingProfile = data is Map
          ? <String, dynamic>{...Map<String, dynamic>.from(data),
              if (data['pendingRevision'] is Map) ...Map<String, dynamic>.from(data['pendingRevision'] as Map),
            }
          : _existingProfile;
      _logoFile = null;
      _showMessage(
        'Listing submitted. Updates require admin approval before going live.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Could not save listing: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) =>
          required && (value == null || value.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _venuesController.dispose();
    _capacityController.dispose();
    _communitySizeController.dispose();
    _experiencesController.dispose();
    _locationsController.dispose();
    _popupDaysController.dispose();
    _popupPriceController.dispose();
    _brandingDaysController.dispose();
    _brandingPriceController.dispose();
    _videoController.dispose();
    _averageGuestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isCommunity ? 'Community Profile' : 'Community Hubs Profile'), actions: [
        if (widget.onEditAccount != null) IconButton(
          tooltip: 'Edit account details',
          onPressed: widget.onEditAccount,
          icon: const Icon(Icons.manage_accounts_outlined),
        ),
      ]),
      body: _loadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
            )
          : _loadError != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_loadError!),
              TextButton(onPressed: () {
                setState(() { _loadingProfile = true; _loadError = null; });
                _loadExistingProfile();
              }, child: const Text('Retry')),
            ])) : FutureBuilder<List<Map<String, dynamic>>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load categories: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: MeetdayColors.primaryRed,
                    ),
                  );
                }
                final categories = snapshot.data!;
                return Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_existingProfile?['approvalStatus'] != null) ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Status: ${_existingProfile!['approvalStatus']}'),
                        subtitle: Text(_existingProfile?['pendingRevision'] != null
                            ? 'Changes are awaiting review; your approved listing stays live.'
                            : (_existingProfile?['adminRejectionRemark'] ?? '').toString()),
                      ),
                      _textField(_nameController, 'Listing name'),
                      const SizedBox(height: 10),
                      _textField(_aboutController, 'About', maxLines: 4),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          _logoFile?.name ??
                              ((_existingProfile?['logoKey'] ?? '')
                                      .toString()
                                      .isNotEmpty
                                  ? 'Change listing logo'
                                  : 'Choose listing logo'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Categories',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                      ),
                      ...categories.map((category) {
                        final id = (category['id'] ?? '').toString();
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selectedCategoryIds.contains(id),
                          title: Text((category['name'] ?? '').toString()),
                          onChanged: id.isEmpty
                              ? null
                              : (selected) => setState(() {
                                  if (selected == true) {
                                    _selectedCategoryIds.add(id);
                                  } else {
                                    _selectedCategoryIds.remove(id);
                                  }
                                }),
                        );
                      }),
                      const SizedBox(height: 10),
                      if (!widget.isCommunity) ...[
                      _textField(
                        _venuesController,
                        'Number of venues',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        _capacityController,
                        'Venue capacity',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      ],
                      _textField(
                        _communitySizeController,
                        'Community size',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      if (widget.isCommunity) ...[
                        _textField(_averageGuestsController, 'Average guest count', keyboardType: TextInputType.number),
                        const SizedBox(height: 10),
                      ],
                      _textField(
                        _experiencesController,
                        'Experiences per year',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      if (!widget.isCommunity) ...[
                      _textField(
                        _locationsController,
                        'Active locations',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sponsorship offerings',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _textField(
                        _popupDaysController,
                        'Pop-up days',
                        keyboardType: TextInputType.number,
                        required: false,
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        _popupPriceController,
                        'Pop-up price',
                        keyboardType: TextInputType.number,
                        required: false,
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        _brandingDaysController,
                        'Branding days',
                        keyboardType: TextInputType.number,
                        required: false,
                      ),
                      const SizedBox(height: 10),
                      _textField(
                        _brandingPriceController,
                        'Branding price',
                        keyboardType: TextInputType.number,
                        required: false,
                      ),
                      ],
                      ..._mediaFields(),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _saving || _uploading ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Submitting…' : 'Submit for approval',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MeetdayColors.primaryRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
