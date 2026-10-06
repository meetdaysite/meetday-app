import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/account_role.dart';
import '../state/auth_provider.dart';
import 'auth_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.role});

  final AccountRole role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSignUp = false;
  bool _agreedToTerms = false;
  bool _isSubmitting = false;

  Future<void> _signInWithGoogle() async {
    if (_isSignUp && !_agreedToTerms) {
      _showError('Agree to the Terms of Service and Privacy Policy to continue.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (widget.role == AccountRole.brand && _isSignUp) {
        final started = await controller.beginBrandSignupWithGoogle();
        if (started && mounted) context.go('/brand-onboarding');
      } else {
        await controller.signInWithGoogle(role: widget.role);
      }
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
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
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _isSignUp ? 'Create Account' : 'Log In',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUp
                ? 'First time here? Sign up with Google to start onboarding!'
                : 'Welcome back! Sign in to your ${widget.role.label.toLowerCase()} workspace.',
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
                  children: const [
                    TextSpan(text: 'I agree to the Terms of Service and Privacy Policy.'),
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
