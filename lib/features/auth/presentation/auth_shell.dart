import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/account_role.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child, this.role});

  final Widget child;
  final AccountRole? role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEE2C2C),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 780;
            return Row(
              children: [
                if (wide) Expanded(child: _BrandPanel(role: role)),
                Expanded(
                  child: Column(
                    children: [
                      if (!wide) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 14, bottom: 8),
                          child: Center(child: _Logo(large: false)),
                        ),
                      ],
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 28 : 20,
                              vertical: wide ? 28 : 16,
                            ),
                            child: _AuthCard(child: child),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 550),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 30),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        border: Border.all(color: Colors.black, width: 4),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(8, 8))],
      ),
      child: child,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.role});

  final AccountRole? role;

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (role) {
      AccountRole.brand => const Color(0xFFFFC940),
      AccountRole.community => const Color(0xFFFFFDF9),
      AccountRole.space => const Color(0xFFB9D6FF),
      null => const Color(0xFFFFC940),
    };

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _Logo(large: true),
          const SizedBox(height: 48),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC70B0B), width: 18),
                ),
              ),
              Container(
                width: 218,
                height: 218,
                decoration: BoxDecoration(
                  color: roleColor,
                  border: Border.all(color: Colors.black, width: 5),
                  borderRadius: BorderRadius.circular(54),
                ),
                child: Icon(
                  switch (role) {
                    AccountRole.brand => Icons.auto_awesome,
                    AccountRole.community => Icons.groups_rounded,
                    AccountRole.space => Icons.location_city_rounded,
                    null => Icons.favorite_rounded,
                  },
                  size: 92,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            role == null ? 'Find your people.' : 'Your ${role!.label} space.',
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo/meetday-white.svg',
      height: large ? 46 : 34,
      fit: BoxFit.contain,
      semanticsLabel: 'Meetday Logo',
    );
  }
}
