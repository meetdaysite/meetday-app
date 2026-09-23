import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  Future<void> _signInWithGoogle() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithGoogle(role: widget.role);
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Unable to sign in right now. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isSubmitting = false;

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
              onPressed: () => context.go('/roles'),
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('Back to welcome'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Log In',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome back! Sign in to your ${widget.role.label.toLowerCase()} workspace.',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 15),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _signInWithGoogle,
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
                : const Text('Continue with Google'),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: () => _showError('Sign up flow is coming next.'),
              child: const Text('Create a new account'),
            ),
          ),
        ],
      ),
    );
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
