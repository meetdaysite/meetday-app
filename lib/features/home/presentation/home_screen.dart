import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/meetday_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Infinite carousel virtual start index (multiple of 3)
  static const int _initialPageIndex = 300;
  late final PageController _pageController;
  late final AnimationController _floatingController;
  late final Animation<double> _floatingAnimation;
  int _activeCardIndex = 0;
  Timer? _autoSlideTimer;
  bool _isUserInteracting = false;

  static const List<_CardItem> _cards = [
    _CardItem(
      title: 'Community',
      description:
          'Publish proposals, get discovered by top brands, and lock sponsorship deals instantly.',
      imagePath: 'assets/images/home-page/community.png',
      buttonText: 'Community',
      targetRoute: '/login/community',
    ),
    _CardItem(
      title: 'Brand',
      description:
          'Publish campaigns, discover verified offline communities, and close partnerships in one workspace.',
      imagePath: 'assets/images/home-page/brand.png',
      buttonText: 'Brand',
      targetRoute: '/login/brand',
    ),
    _CardItem(
      title: 'Community Hub',
      description:
          'List your space, host curated IRL experiences, and monetize your hub effortlessly.',
      imagePath: 'assets/images/home-page/spaces.png',
      buttonText: 'Community Hub',
      targetRoute: '/login/space',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _initialPageIndex,
      viewportFraction: 0.77,
    );

    // Unified floating animation for all bubbles (matches meetday-frontend ease-in-out float together)
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _floatingAnimation = CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    );

    _startAutoSlide();
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
    _autoSlideTimer?.cancel();
    _floatingController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeetdayColors.primaryRed,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Header Bar (Clean White Meetday Logo - ALWAYS ON TOP)
            _buildTopHeader(),

            // 2. Upper Floating Speech Bubbles (in open space between logo and cards)
            Expanded(
              child: IgnorePointer(
                child: _buildUpperBubbles(),
              ),
            ),

            // 3. Central Swipable Cards Carousel & Indicators
            _buildSwipableCardsCarousel(),
            const SizedBox(height: 14),
            _buildPageIndicators(),

            // 4. Lower Floating Speech Bubbles (in open space below cards & indicators)
            Expanded(
              child: IgnorePointer(
                child: _buildLowerBubbles(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpperBubbles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        if (h < 50) return const SizedBox.shrink();

        final topRowY = (h * 0.08).clamp(8.0, 18.0);
        final centerRowY = ((h - 31) / 2).clamp(32.0, 70.0);
        final bottomRowY = (h - 40).clamp(centerRowY + 30, h - 8.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Top Row
            _FloatingBubble(
              text: 'RAISE SPONSORSHIP',
              bg: Colors.white,
              textColor: MeetdayColors.primaryRed,
              rotation: -7 * math.pi / 180,
              tailPositionFraction: 0.25,
              animation: _floatingAnimation,
              floatDelta: -6.0,
              left: 10,
              top: topRowY,
            ),
            _FloatingBubble(
              text: 'ENGAGE GEN Z',
              bg: MeetdayColors.accentYellow,
              textColor: Colors.black,
              rotation: 6 * math.pi / 180,
              tailPositionFraction: 0.75,
              animation: _floatingAnimation,
              floatDelta: -8.5,
              right: 10,
              top: topRowY,
            ),

            // Center Accent
            _FloatingBubble(
              text: 'BACKED BY DATA',
              bg: Colors.white,
              textColor: Colors.black,
              rotation: -3 * math.pi / 180,
              tailPositionFraction: 0.50,
              animation: _floatingAnimation,
              floatDelta: -7.0,
              left: (w - 110) / 2,
              top: centerRowY,
            ),

            // Bottom Row (above card top)
            _FloatingBubble(
              text: 'CREATE EXPERIENCES',
              bg: MeetdayColors.accentYellow,
              textColor: Colors.black,
              rotation: 5 * math.pi / 180,
              tailPositionFraction: 0.35,
              animation: _floatingAnimation,
              floatDelta: -5.0,
              left: 14,
              top: bottomRowY,
            ),
            _FloatingBubble(
              text: 'GROW COMMUNITY',
              bg: Colors.white,
              textColor: MeetdayColors.primaryRed,
              rotation: -6 * math.pi / 180,
              tailPositionFraction: 0.65,
              animation: _floatingAnimation,
              floatDelta: -7.5,
              right: 14,
              top: bottomRowY,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLowerBubbles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        if (h < 50) return const SizedBox.shrink();

        final topRowY = (h * 0.08).clamp(8.0, 18.0);
        final centerRowY = ((h - 31) / 2).clamp(32.0, 70.0);
        final bottomRowY = (h - 40).clamp(centerRowY + 30, h - 8.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Top Row (below indicators)
            _FloatingBubble(
              text: 'MONETIZE COMMUNITY',
              bg: MeetdayColors.accentYellow,
              textColor: Colors.black,
              rotation: -6 * math.pi / 180,
              tailPositionFraction: 0.25,
              animation: _floatingAnimation,
              floatDelta: -7.0,
              left: 10,
              top: topRowY,
            ),
            _FloatingBubble(
              text: 'LIST COMMUNITY HUBS',
              bg: Colors.white,
              textColor: Colors.black,
              rotation: 6 * math.pi / 180,
              tailPositionFraction: 0.75,
              animation: _floatingAnimation,
              floatDelta: -5.0,
              right: 10,
              top: topRowY,
            ),

            // Center Accent
            _FloatingBubble(
              text: 'VERIFIED USERS',
              bg: MeetdayColors.accentYellow,
              textColor: Colors.black,
              rotation: 4 * math.pi / 180,
              tailPositionFraction: 0.50,
              animation: _floatingAnimation,
              floatDelta: -8.0,
              left: (w - 105) / 2,
              top: centerRowY,
            ),

            // Bottom Row
            _FloatingBubble(
              text: 'OPTIMIZE BUDGETS',
              bg: Colors.white,
              textColor: MeetdayColors.primaryRed,
              rotation: -5 * math.pi / 180,
              tailPositionFraction: 0.35,
              animation: _floatingAnimation,
              floatDelta: -6.5,
              left: 14,
              top: bottomRowY,
            ),
            _FloatingBubble(
              text: 'TRUSTED PAYMENTS',
              bg: MeetdayColors.accentYellow,
              textColor: Colors.black,
              rotation: 5 * math.pi / 180,
              tailPositionFraction: 0.65,
              animation: _floatingAnimation,
              floatDelta: -7.5,
              right: 14,
              top: bottomRowY,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Center(
        child: SvgPicture.asset(
          'assets/logo/meetday-white.svg',
          height: 38,
          fit: BoxFit.contain,
          semanticsLabel: 'Meetday Logo',
        ),
      ),
    );
  }

  Widget _buildSwipableCardsCarousel() {
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
          height: 335,
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

                  // Center card is visibly larger (scale 1.0 vs 0.88 for adjacent)
                  final scale = 1.0 - (distance * 0.12);

                  // Side cards are less transparent (high opacity: 0.90 to 1.0)
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
                    onCardTap: () => context.push(card.targetRoute),
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

  const _CardItem({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.buttonText,
    required this.targetRoute,
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
            // Image with matching inner border radius to cleanly fit in its box
            Container(
              height: 180,
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

            const SizedBox(height: 10),

            // Card Content: Description text from meetday-frontend in Poppins (no top title)
            Expanded(
              child: Center(
                child: Text(
                  card.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: MeetdayColors.textPrimary,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Neo-Brutalist Action Button in Bricolage Grotesque (without arrows)
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
          padding: const EdgeInsets.symmetric(vertical: 11),
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
                fontSize: 16.5,
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
          // Exactly as in frontend: vertical keyframe float together (0 to -delta to 0)
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

    // 2. Background fill (100% solid opacity)
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
