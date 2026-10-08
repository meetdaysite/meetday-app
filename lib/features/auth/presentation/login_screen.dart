import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/account_role.dart';
import '../state/auth_provider.dart';
import 'auth_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role, this.redirectTo});

  final AccountRole role;
  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSignUp = false;
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegalPage('https://www.meetday.ai/terms');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegalPage('https://www.meetday.ai/privacy');
    if (widget.role == AccountRole.brand && widget.redirectTo != null) {
      ref.read(pendingBrandRedirectProvider.notifier).set(widget.redirectTo);
    }
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _openLegalPage(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) _showError('Could not open the legal page.');
  }

  Future<void> _signInWithGoogle() async {
    if (_isSignUp && !_agreedToTerms) {
      _showError(
        'Agree to the Terms of Service and Privacy Policy to continue.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (widget.role == AccountRole.brand && _isSignUp) {
        final started = await controller.beginBrandSignupWithGoogle();
        if (started && mounted) context.go('/brand-onboarding');
      } else if (widget.role == AccountRole.space && _isSignUp) {
        final started = await controller.beginSpaceSignupWithGoogle();
        if (started && mounted) context.go('/space-onboarding');
      } else {
        await controller.signInWithGoogle(role: widget.role);
      }
    } on AuthException catch (error) {
      if (mounted &&
          widget.role == AccountRole.brand &&
          error.message.toLowerCase().contains('no brand account found')) {
        setState(() => _isSignUp = true);
        _showError('Create your brand account to continue.');
      } else if (mounted &&
          widget.role == AccountRole.space &&
          error.message.toLowerCase().contains('no hub partner account found')) {
        setState(() => _isSignUp = true);
        _showError('Create your Hub Partner account to continue.');
      } else if (mounted) {
        _showError(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showError(
          AuthController.formatLoginError(
            error,
            fallback: 'Unable to sign in right now. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      role: widget.role,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('Back to home'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                padding: EdgeInsets.zero,
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _isSignUp
              ? (widget.role == AccountRole.space
                ? 'Create Hub Partner Account'
                : 'Create Account')
              : (widget.role == AccountRole.space
                ? 'Hub Partner Login'
                : 'Log In'),
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUp
              ? (widget.role == AccountRole.space
                ? 'Join Meetday Hubs and set up your venue business.'
                : 'First time here? Sign up with Google to start onboarding!')
              : 'Welcome back! Sign in to your ${widget.role == AccountRole.space ? 'Hub Partner' : widget.role.label} workspace.',
            style: GoogleFonts.poppins(
              color: const Color(0xFF667085),
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _isSubmitting || (_isSignUp && !_agreedToTerms)
                ? null
                : _signInWithGoogle,
            icon: const _GoogleMark(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC940),
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black, width: 3),
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            label: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    !_agreedToTerms && _isSignUp
                        ? 'Agree to terms to continue'
                        : 'Continue with Google',
                    style: GoogleFonts.poppins(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _agreedToTerms = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text.rich(
                TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _termsTap,
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _privacyTap,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() {
                      _isSignUp = !_isSignUp;
                      _agreedToTerms = false;
                    }),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Log in'
                    : 'New to Meetday? Create an account',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onLongPress: _showDevLoginOption,
            child: Center(
              child: Text(
                'Development Mode',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.black26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDevLoginOption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Development Mode'),
        content: const Text('Login without Google for testing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _devLogin();
            },
            child: const Text('Yes, Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _devLogin() async {
    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(authControllerProvider.notifier);
      await controller.signIn(
        uid: 'dev-user-${widget.role.name}',
        role: widget.role,
      );
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) _showError('Dev login failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
