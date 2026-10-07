import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../state/auth_provider.dart';
import 'auth_shell.dart';

const _brandIndustries = [
  'Tech/SaaS',
  'Food & Beverage',
  'Fashion/Apparel',
  'Consumer Tech',
  'Health & Wellness',
  'FinTech',
  'Entertainment',
  'Alcobev',
  'Custom',
];

class BrandOnboardingScreen extends ConsumerStatefulWidget {
  const BrandOnboardingScreen({super.key});

  @override
  ConsumerState<BrandOnboardingScreen> createState() =>
      _BrandOnboardingScreenState();
}

class _BrandOnboardingScreenState extends ConsumerState<BrandOnboardingScreen> {
  final _brandNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _aboutController = TextEditingController();
  final _customIndustryController = TextEditingController();
  final _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _categories = [];
  XFile? _logoFile;
  Uint8List? _logoBytes;
  final Set<String> _selectedCategoryIds = {};
  String? _companyType;
  String? _industry;
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _workEmailController.dispose();
    _contactPhoneController.dispose();
    _aboutController.dispose();
    _customIndustryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .getRequest('/categories');
      if (!mounted || response is! List) return;
      setState(() {
        _categories = response
            .whereType<Map>()
            .map((category) => Map<String, dynamic>.from(category))
            .toList();
      });
    } catch (_) {
      // Category selection is optional; onboarding can continue if this request fails.
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  String? _validateUrl(String label, String value) {
    if (value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !['http', 'https'].contains(uri.scheme) ||
        !uri.hasAuthority) {
      return '$label must be a full URL starting with https://';
    }
    return null;
  }

  Future<void> _submit() async {
    final brandName = _brandNameController.text.trim();
    if (brandName.isEmpty) {
      _showMessage('Brand name is required.');
      return;
    }

    final urlError =
        _validateUrl('Website', _websiteController.text) ??
        _validateUrl('Instagram', _instagramController.text) ??
        _validateUrl('LinkedIn', _linkedinController.text);
    if (urlError != null) {
      _showMessage(urlError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? logoKey;
      if (_logoFile != null && _logoBytes != null) {
        logoKey = await ref.read(apiClientProvider).uploadMediaFile(
          bytes: _logoBytes!,
          fileName: _logoFile!.name,
          context: 'USER_AVATAR',
        );
        if (logoKey == null) {
          throw const FormatException('Could not upload the brand logo.');
        }
      }
      await ref
          .read(authControllerProvider.notifier)
          .completeBrandSignup(
            brandName: brandName,
            categoryIds: _selectedCategoryIds.toList(),
            website: _websiteController.text,
            instagram: _instagramController.text,
            linkedin: _linkedinController.text,
            companyType: _companyType,
            industry: _industry == 'Custom'
                ? _customIndustryController.text
                : _industry,
            aboutCompany: _aboutController.text,
            workEmail: _workEmailController.text,
            contactPhone: _contactPhoneController.text,
            logoKey: logoKey,
          );
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted) {
        _showMessage(
          AuthController.formatLoginError(
            error,
            fallback: 'Could not finish brand setup. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFFFFDF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black54, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return AuthShell(
      role: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login/brand');
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('Back to login'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black54,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Set up your Brand profile',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Brand name is required. The rest can be added later from your profile.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.45,
              color: const Color(0xFF667085),
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              email,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 18),
          _section('Brand Details', [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: _logoBytes == null ? null : MemoryImage(_logoBytes!),
                  child: _logoBytes == null
                      ? const Icon(Icons.business_rounded, size: 28, color: Colors.black54)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _logoFile?.name ?? 'Brand logo (optional)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final file = await _imagePicker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (file == null) return;
                                final bytes = await file.readAsBytes();
                                if (bytes.length > 5 * 1024 * 1024) {
                                  _showMessage('Choose a logo smaller than 5 MB.');
                                  return;
                                }
                                if (mounted) {
                                  setState(() {
                                    _logoFile = file;
                                    _logoBytes = bytes;
                                  });
                                }
                              },
                        icon: const Icon(Icons.upload_rounded, size: 16),
                        label: Text(_logoFile == null ? 'Choose logo' : 'Replace logo'),
                      ),
                    ],
                  ),
                ),
                if (_logoFile != null)
                  IconButton(
                    tooltip: 'Remove logo',
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                              _logoFile = null;
                              _logoBytes = null;
                            }),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _field(_brandNameController, 'Brand name *'),
            const SizedBox(height: 12),
            Text(
              'Company type',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final option in const [
                  ('BRAND', 'Brand'),
                  ('AGENCY', 'Agency'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _companyType == option.$1,
                    onSelected: (_) => setState(() => _companyType = option.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Industry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final industry in _brandIndustries)
                  ChoiceChip(
                    label: Text(industry),
                    selected: _industry == industry,
                    onSelected: (_) => setState(() => _industry = industry),
                  ),
              ],
            ),
            if (_industry == 'Custom') ...[
              const SizedBox(height: 10),
              _field(_customIndustryController, 'Your industry'),
            ],
            const SizedBox(height: 12),
            _field(_aboutController, 'About your company', maxLines: 3),
            const SizedBox(height: 12),
            Text(
              'Categories (optional)',
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
                runSpacing: 4,
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
          ]),
          const SizedBox(height: 12),
          _section('Contact', [
            _field(
              _workEmailController,
              'Work email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _field(
              _contactPhoneController,
              'Phone number (optional)',
              keyboardType: TextInputType.phone,
            ),
          ]),
          const SizedBox(height: 12),
          _section('Website / Social Links', [
            _field(_websiteController, 'Website'),
            const SizedBox(height: 12),
            _field(_instagramController, 'Instagram URL'),
            const SizedBox(height: 12),
            _field(_linkedinController, 'LinkedIn URL'),
          ]),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEE2C2C),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: Colors.black, width: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
