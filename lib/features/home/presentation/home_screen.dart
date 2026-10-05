import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/meetday_colors.dart';
import '../../auth/domain/account_role.dart';
import '../../auth/state/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  // Infinite carousel virtual start index (multiple of 3)
  static const int _initialPageIndex = 300;
  late final PageController _pageController;
  late final AnimationController _floatingController;
  late final Animation<double> _floatingAnimation;
  late final AnimationController _crossfadeController;
  late final Animation<double> _crossfadeAnimation;
  int _activeCardIndex = 0;
  Timer? _autoSlideTimer;
  Timer? _bubbleCrossfadeTimer;
  Timer? _headingTimer;
  bool _isUserInteracting = false;
  bool _isShowingSetB = false;

  static const List<Map<String, String>> _heroHeadings = [
    {'prefix': 'Offline', 'suffix': 'Communities'},
    {'prefix': 'Curated', 'suffix': 'Experiences'},
    {'prefix': 'Modern', 'suffix': 'Brands'},
    {'prefix': 'Community', 'suffix': 'Hubs'},
  ];
  int _currentHeadingIndex = 0;

  static const List<_CardItem> _cards = [
    _CardItem(
      title: 'Community',
      description:
          'Publish proposals, get discovered by top brands, and lock sponsorship deals instantly.',
      imagePath: 'assets/images/home-page/community.png',
      buttonText: 'Community',
      targetRoute: '/login/community',
      targetRole: AccountRole.community,
    ),
    _CardItem(
      title: 'Brand',
      description:
          'Publish campaigns, discover verified offline communities, and close partnerships in one workspace.',
      imagePath: 'assets/images/home-page/brand.png',
      buttonText: 'Brand',
      targetRoute: '/login/brand',
      targetRole: AccountRole.brand,
    ),
    _CardItem(
      title: 'Community Hub',
      description:
          'List your space, host curated IRL experiences, and monetize your hub effortlessly.',
      imagePath: 'assets/images/home-page/spaces.png',
      buttonText: 'Community Hub',
      targetRoute: '/login/space',
      targetRole: AccountRole.space,
    ),
  ];

  void _onCardTap(_CardItem card) {
    final authState = ref.read(authControllerProvider);
    final fbUser = FirebaseAuth.instance.currentUser;
    final isLoggedIn = authState.status == AuthStatus.authenticated || fbUser != null;

    if (isLoggedIn) {
      // User is already logged in -> directly take them to dashboard, not login page
      final role = authState.role ?? card.targetRole;
      final destination = (role == AccountRole.brand)
          ? '/dashboard'
          : '/community-dashboard';
      context.go(destination);
    } else {
      context.push(card.targetRoute);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _initialPageIndex,
      viewportFraction: 0.77,
    );

    // Floating animation for speech bubbles
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _floatingAnimation = CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    );

    // Crossfade animation between Set A and Set B of 5 bubbles below cards
    _crossfadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _crossfadeAnimation = CurvedAnimation(
      parent: _crossfadeController,
      curve: Curves.easeInOut,
    );

    // Heading rotation timer matching website frontend (every 2.5s)
    _headingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      setState(() {
        _currentHeadingIndex =
            (_currentHeadingIndex + 1) % _heroHeadings.length;
      });
    });

    _startBubbleCrossfade();
    _startAutoSlide();
  }

  void _startBubbleCrossfade() {
    _bubbleCrossfadeTimer?.cancel();
    _bubbleCrossfadeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_isShowingSetB) {
        _crossfadeController.reverse();
        _isShowingSetB = false;
      } else {
        _crossfadeController.forward();
        _isShowingSetB = true;
      }
    });
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isUserInteracting && _pageController.hasClients) {
        final currentRealPage =
            _pageController.page?.round() ?? _initialPageIndex;
        _pageController.animateToPage(
          currentRealPage + 1,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
  }

  void _goToCardIndex(int targetIndex) {
    if (!_pageController.hasClients) return;
    final currentRealPage = _pageController.page?.round() ?? _initialPageIndex;
    final currentMod = currentRealPage % _cards.length;
    final diff = targetIndex - currentMod;
    _pageController.animateToPage(
      currentRealPage + diff,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
    _startAutoSlide();
  }

  @override
  void dispose() {
    _headingTimer?.cancel();
    _autoSlideTimer?.cancel();
    _bubbleCrossfadeTimer?.cancel();
    _crossfadeController.dispose();
    _floatingController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeetdayColors.primaryRed,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            // Adaptive card height so cards fit comfortably and scale gracefully on all screen sizes
            final cardHeight = (availableHeight * 0.38).clamp(290.0, 320.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Section - Shifted upwards in the space above cards
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: _buildTopSection(),
                    ),
                  ),
                ),

                // 2. Central Cards (Strictly centrally placed wrt screen height)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSwipableCardsCarousel(cardHeight),
                    const SizedBox(height: 10),
                    _buildPageIndicators(),
                  ],
                ),

                // 3. Lower Floating Speech Bubbles (Strictly in the bottom half space below the cards)
                Expanded(
                  flex: 1,
                  child: IgnorePointer(
                    child: _buildLowerBubbles(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    final heading = _heroHeadings[_currentHeadingIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Meetday Brand Logo (Shifted upwards near top)
          SvgPicture.asset(
            'assets/logo/meetday-white.svg',
            height: 34,
            fit: BoxFit.contain,
            semanticsLabel: 'Meetday Logo',
          ),
          const SizedBox(height: 10),

          // Alternating Animated Heading (Pure fade in / fade out without motion)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: Row(
              key: ValueKey<int>(_currentHeadingIndex),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${heading['prefix']} ',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      heading['suffix']!,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: MeetdayColors.accentYellow,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -5,
                      child: SizedBox(
                        height: 7,
                        child: CustomPaint(
                          painter: const HandDrawnUnderlinePainter(
                            color: Colors.white,
                            strokeWidth: 3.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle text (exact replicate of meetday-frontend, tuned for Red background)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.95),
                  height: 1.35,
                ),
                children: [
                  const TextSpan(text: 'Whether you’re looking 👀 to '),
                  TextSpan(
                    text: 'market',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: MeetdayColors.accentYellow,
                    ),
                  ),
                  const TextSpan(text: ' your products, '),
                  TextSpan(
                    text: 'monetize',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: MeetdayColors.accentYellow,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' your IRL community, or explore how we’re building 💪 the infrastructure layer for real-world, you’re in the right place.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowerBubbles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        if (h < 50) return const SizedBox.shrink();

        // Dynamically space rows across the entire lower area to fill the space
        final row1Top = (h * 0.08).clamp(6.0, 26.0);
        final row2Top = (h * 0.38).clamp(row1Top + 36.0, h * 0.54);
        final row3Top = (h * 0.68).clamp(row2Top + 36.0, h - 36.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ─── Set A (5 Bubbles) ───────────────────────────────────────────
            FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0)
                  .animate(_crossfadeAnimation),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _FloatingBubble(
                    text: 'RAISE SPONSORSHIP',
                    bg: Colors.white,
                    textColor: Colors.black,
                    rotation: -6 * math.pi / 180,
                    tailPositionFraction: 0.25,
                    animation: _floatingAnimation,
                    floatDelta: -6.0,
                    left: 12,
                    top: row1Top,
                  ),
                  _FloatingBubble(
                    text: 'ENGAGE GEN Z',
                    bg: MeetdayColors.accentYellow,
                    textColor: Colors.black,
                    rotation: 5 * math.pi / 180,
                    tailPositionFraction: 0.75,
                    animation: _floatingAnimation,
                    floatDelta: -8.0,
                    right: 12,
                    top: row1Top + 6,
                  ),
                  _FloatingBubble(
                    text: 'BACKED BY DATA',
                    bg: Colors.white,
                    textColor: Colors.black,
                    rotation: -3 * math.pi / 180,
                    tailPositionFraction: 0.50,
                    animation: _floatingAnimation,
                    floatDelta: -7.0,
                    left: (w - 118) / 2,
                    top: row2Top,
                  ),
                  _FloatingBubble(
                    text: 'CREATE EXPERIENCES',
                    bg: const Color(0xFFFFF8F3),
                    textColor: Colors.black,
                    rotation: 4 * math.pi / 180,
                    tailPositionFraction: 0.35,
                    animation: _floatingAnimation,
                    floatDelta: -5.0,
                    left: 14,
                    top: row3Top,
                  ),
                  _FloatingBubble(
                    text: 'GROW COMMUNITY',
                    bg: MeetdayColors.accentYellow,
                    textColor: Colors.black,
                    rotation: -5 * math.pi / 180,
                    tailPositionFraction: 0.65,
                    animation: _floatingAnimation,
                    floatDelta: -7.5,
                    right: 14,
                    top: row3Top - 2,
                  ),
                ],
              ),
            ),

            // ─── Set B (Next 5 Bubbles, spaced nicely across the canvas) ───────
            FadeTransition(
              opacity: _crossfadeAnimation,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _FloatingBubble(
                    text: 'MONETIZE COMMUNITY',
                    bg: MeetdayColors.accentYellow,
                    textColor: Colors.black,
                    rotation: -5 * math.pi / 180,
                    tailPositionFraction: 0.30,
                    animation: _floatingAnimation,
                    floatDelta: -7.0,
                    left: 14,
                    top: row1Top + 8,
                  ),
                  _FloatingBubble(
                    text: 'LIST COMMUNITY HUBS',
                    bg: Colors.white,
                    textColor: Colors.black,
                    rotation: 6 * math.pi / 180,
                    tailPositionFraction: 0.70,
                    animation: _floatingAnimation,
                    floatDelta: -5.0,
                    right: 14,
                    top: row1Top - 2,
                  ),
                  _FloatingBubble(
                    text: 'VERIFIED USERS',
                    bg: MeetdayColors.accentYellow,
                    textColor: Colors.black,
                    rotation: -4 * math.pi / 180,
                    tailPositionFraction: 0.40,
                    animation: _floatingAnimation,
                    floatDelta: -8.0,
                    left: 16,
                    top: row2Top + 4,
                  ),
                  _FloatingBubble(
                    text: 'OPTIMIZE BUDGETS',
                    bg: const Color(0xFFFFF8F3),
                    textColor: Colors.black,
                    rotation: 5 * math.pi / 180,
                    tailPositionFraction: 0.60,
                    animation: _floatingAnimation,
                    floatDelta: -6.5,
                    right: 16,
                    top: row2Top - 4,
                  ),
                  _FloatingBubble(
                    text: 'TRUSTED PAYMENTS',
                    bg: Colors.white,
                    textColor: Colors.black,
                    rotation: -3 * math.pi / 180,
                    tailPositionFraction: 0.50,
                    animation: _floatingAnimation,
                    floatDelta: -7.5,
                    left: (w - 120) / 2,
                    top: row3Top,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSwipableCardsCarousel([double height = 320]) {
    return Listener(
      onPointerDown: (_) {
        _isUserInteracting = true;
        _stopAutoSlide();
      },
      onPointerUp: (_) {
        _isUserInteracting = false;
        _startAutoSlide();
      },
      onPointerCancel: (_) {
        _isUserInteracting = false;
        _startAutoSlide();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            if (notification.dragDetails != null) {
              _isUserInteracting = true;
              _stopAutoSlide();
            }
          } else if (notification is UserScrollNotification) {
            if (notification.direction != ScrollDirection.idle) {
              _isUserInteracting = true;
              _stopAutoSlide();
            } else {
              _isUserInteracting = false;
              _startAutoSlide();
            }
          } else if (notification is ScrollEndNotification) {
            _isUserInteracting = false;
            _startAutoSlide();
          }
          return false;
        },
        child: SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _activeCardIndex = index % _cards.length;
              });
            },
            itemBuilder: (context, index) {
              final card = _cards[index % _cards.length];

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double pageOffset = 0.0;
                  if (_pageController.position.haveDimensions) {
                    pageOffset =
                        (_pageController.page ?? _initialPageIndex.toDouble()) -
                            index;
                  } else {
                    pageOffset = (_initialPageIndex - index).toDouble();
                  }

                  final distance = pageOffset.abs().clamp(0.0, 1.0);

                  // Center card scale 1.0 vs 0.88 for adjacent
                  final scale = 1.0 - (distance * 0.12);

                  // Side cards have slight fade
                  final opacity = 1.0 - (distance * 0.10);

                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: _SwipableNeoCard(
                    card: card,
                    onCardTap: () => _onCardTap(card),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_cards.length, (index) {
        final isActive = _activeCardIndex == index;
        return GestureDetector(
          onTap: () => _goToCardIndex(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 10,
            width: isActive ? 28 : 10,
            decoration: BoxDecoration(
              color: isActive ? MeetdayColors.accentYellow : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: MeetdayColors.inkBlack, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: MeetdayColors.inkBlack,
                  offset: Offset(1.5, 1.5),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _CardItem {
  final String title;
  final String description;
  final String imagePath;
  final String buttonText;
  final String targetRoute;
  final AccountRole targetRole;

  const _CardItem({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.buttonText,
    required this.targetRoute,
    required this.targetRole,
  });
}

class _SwipableNeoCard extends StatelessWidget {
  final _CardItem card;
  final VoidCallback onCardTap;

  const _SwipableNeoCard({
    required this.card,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MeetdayColors.inkBlack, width: 2.8),
          boxShadow: const [
            BoxShadow(
              color: MeetdayColors.inkBlack,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with matching inner border radius
            Container(
              height: 165,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MeetdayColors.inkBlack, width: 2.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13.5),
                child: Image.asset(
                  card.imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 44,
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Card Description
            Expanded(
              child: Center(
                child: Text(
                  card.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: MeetdayColors.textPrimary,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Neo-Brutalist Action Button
            _TactileActionButton(
              label: card.buttonText,
              onPressed: onCardTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _TactileActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _TactileActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_TactileActionButton> createState() => _TactileActionButtonState();
}

class _TactileActionButtonState extends State<_TactileActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final shadowOffset =
        _isPressed ? const Offset(1, 1) : const Offset(2.5, 2.5);
    final translation =
        _isPressed ? const Offset(1.5, 1.5) : Offset.zero;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Transform.translate(
        offset: translation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: MeetdayColors.primaryRed,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MeetdayColors.inkBlack, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: MeetdayColors.inkBlack,
                offset: shadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  final String text;
  final Color bg;
  final Color textColor;
  final double rotation;
  final double tailPositionFraction;
  final Animation<double> animation;
  final double floatDelta;
  final double? left;
  final double? right;
  final double? top;

  const _FloatingBubble({
    required this.text,
    required this.bg,
    required this.textColor,
    required this.rotation,
    required this.animation,
    this.floatDelta = -7.0,
    this.tailPositionFraction = 0.25,
    this.left,
    this.right,
    this.top,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, animation.value * floatDelta),
            child: child,
          );
        },
        child: Transform.rotate(
          angle: rotation,
          child: CustomPaint(
            painter: SpeechBubblePainter(
              backgroundColor: bg,
              borderColor: MeetdayColors.inkBlack,
              borderWidth: 2.0,
              shadowOffset: 2.5,
              tailPositionFraction: tailPositionFraction,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 6,
                bottom: 13, // 6 + 7 tailHeight
              ),
              child: Text(
                text,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SpeechBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double shadowOffset;
  final double tailPositionFraction;
  final double tailWidth;
  final double tailHeight;

  SpeechBubblePainter({
    required this.backgroundColor,
    this.borderColor = MeetdayColors.inkBlack,
    this.borderWidth = 2.0,
    this.shadowOffset = 2.5,
    this.tailPositionFraction = 0.25,
    this.tailWidth = 12.0,
    this.tailHeight = 7.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height - tailHeight;
    final r = bodyHeight / 2.0;

    final path = Path();
    // Top-left arc
    path.moveTo(r, 0);
    // Top line
    path.lineTo(size.width - r, 0);
    // Right semicircle
    path.arcToPoint(
      Offset(size.width - r, bodyHeight),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // Bottom edge with tail (going right to left)
    final tailCenterX = (size.width * tailPositionFraction)
        .clamp(r + tailWidth / 2, size.width - r - tailWidth / 2);
    final tailStartX = tailCenterX + tailWidth / 2;
    final tailEndX = tailCenterX - tailWidth / 2;

    path.lineTo(tailStartX, bodyHeight);
    path.lineTo(tailCenterX, size.height);
    path.lineTo(tailEndX, bodyHeight);
    path.lineTo(r, bodyHeight);

    // Left semicircle
    path.arcToPoint(
      Offset(r, 0),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.close();

    // 1. Hard drop shadow
    if (shadowOffset > 0) {
      final shadowPath = path.shift(Offset(shadowOffset, shadowOffset));
      canvas.drawPath(
        shadowPath,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.fill,
      );
    }

    // 2. Background fill
    canvas.drawPath(
      path,
      Paint()
        ..color = backgroundColor.withValues(alpha: 1.0)
        ..style = PaintingStyle.fill,
    );

    // 3. Neo-brutalist border stroke
    if (borderWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..strokeWidth = borderWidth
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpeechBubblePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.tailPositionFraction != tailPositionFraction;
  }
}

class HandDrawnUnderlinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const HandDrawnUnderlinePainter({
    this.color = MeetdayColors.accentYellow,
    this.strokeWidth = 3.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Curved hand-drawn underline matching SVG d="M3 7C30 3 70 3 97 7"
    path.moveTo(w * 0.03, h * 0.7);
    path.cubicTo(
      w * 0.30,
      h * 0.20,
      w * 0.70,
      h * 0.20,
      w * 0.97,
      h * 0.7,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HandDrawnUnderlinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
