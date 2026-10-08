import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/meetday_colors.dart';
import '../domain/account_role.dart';
import '../state/auth_provider.dart';
import 'auth_shell.dart';

class SpaceOnboardingScreen extends ConsumerStatefulWidget {
  const SpaceOnboardingScreen({super.key});

  @override
  ConsumerState<SpaceOnboardingScreen> createState() =>
      _SpaceOnboardingScreenState();
}

class _SpaceOnboardingScreenState extends ConsumerState<SpaceOnboardingScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final Set<String> _cities = {};
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isNotEmpty) _firstNameController.text = parts.first;
    if (parts.length > 1) _lastNameController.text = parts.skip(1).join(' ');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _addCity() {
    final city = _cityController.text.trim();
    if (city.isEmpty || _cities.any((item) => item.toLowerCase() == city.toLowerCase())) {
      return;
    }
    setState(() {
      _cities.add(city);
      _cityController.clear();
      _error = null;
    });
  }

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final businessName = _businessNameController.text.trim();
    final phone = _phoneController.text.trim();
    final phonePattern = RegExp(r'^\+[1-9]\d{7,14}$');

    if (firstName.isEmpty || lastName.isEmpty || businessName.isEmpty) {
      setState(() => _error = 'Name and business name are required.');
      return;
    }
    if (_cities.isEmpty) {
      setState(() => _error = 'Add at least one operating city.');
      return;
    }
    if (!phonePattern.hasMatch(phone)) {
      setState(() => _error = 'Enter your phone with country code, e.g. +919876543210.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).completeSpaceSignup(
            firstName: firstName,
            lastName: lastName,
            businessName: businessName,
            operatingCities: _cities.toList(),
            phone: phone,
          );
    } catch (error) {
      if (mounted) {
        setState(() => _error = AuthController.formatLoginError(error));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
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
      role: AccountRole.space,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go('/login/space');
                  },
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('Back to Hub login'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black54,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Set up your Hub Partner profile',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add your business and operating cities to list and manage your venues.',
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF667085)),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Google account email'),
              child: Text(email, style: GoogleFonts.poppins(fontSize: 14)),
            ),
          ],
          const SizedBox(height: 18),
          _field(_firstNameController, 'First name *'),
          const SizedBox(height: 12),
          _field(_lastNameController, 'Last name *'),
          const SizedBox(height: 12),
          _field(_businessNameController, 'Business name *'),
          const SizedBox(height: 12),
          _field(
            _phoneController,
            'Phone number with country code *',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _addCity(),
                  decoration: const InputDecoration(
                    labelText: 'Operating city *',
                    hintText: 'Type a city and press Add',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Add city',
                onPressed: _addCity,
                style: IconButton.styleFrom(
                  backgroundColor: MeetdayColors.accentYellow,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black, width: 2),
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (_cities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _cities
                  .map((city) => InputChip(
                        label: Text(city),
                        onDeleted: _isSubmitting
                            ? null
                            : () => setState(() => _cities.remove(city)),
                      ))
                  .toList(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.poppins(fontSize: 12, color: MeetdayColors.primaryRed),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: MeetdayColors.primaryRed,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: Colors.black, width: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Complete Hub Registration'),
          ),
        ],
      ),
    );
  }
}