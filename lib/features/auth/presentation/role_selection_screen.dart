import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/account_role.dart';
import 'auth_shell.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 12),
          Text(
            'Welcome to Meetday',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick your side of the experience to get started.',
            style: GoogleFonts.poppins(
              color: const Color(0xFF667085),
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          ...AccountRole.values.map(
            (role) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoleCard(role: role),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'One account. Every side of the experience.',
              style: GoogleFonts.poppins(
                color: const Color(0xFF98A2B3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final AccountRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      AccountRole.brand => const Color(0xFFE5484D),
      AccountRole.community => const Color(0xFFF0A12B),
      AccountRole.space => const Color(0xFF2673E8),
    };
    final icon = switch (role) {
      AccountRole.brand => Icons.auto_awesome,
      AccountRole.community => Icons.groups_rounded,
      AccountRole.space => Icons.location_city_rounded,
    };

    return InkWell(
      onTap: () => context.push('/login/${role.name}'),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF667085),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
