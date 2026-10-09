import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MeetdayAiCookingLoadingCard extends StatefulWidget {
  const MeetdayAiCookingLoadingCard({
    super.key,
    this.isCampaign = false,
  });

  final bool isCampaign;

  @override
  State<MeetdayAiCookingLoadingCard> createState() => _MeetdayAiCookingLoadingCardState();
}

class _MeetdayAiCookingLoadingCardState extends State<MeetdayAiCookingLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  late final List<String> _loadingMessages;
  int _messageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _loadingMessages = widget.isCampaign
        ? const [
            'Meetday is cooking... 🍳',
            'Spicing up the campaign details... 🌶️',
            'Whipping up the target audience profile... 📊',
            'Simmering the budget and offer details... 💰',
            'Adding the secret sauce to the brief... 🍯',
            'Plating the perfect campaign... 🍽️',
            'Garnishing with final touches... ✨',
          ]
        : const [
            'Meetday is cooking... 🍳',
            'Spicing up the proposal details... 🌶️',
            'Whipping up the target audience profile... 📊',
            'Simmering the numbers and sponsor tiers... 💰',
            'Adding the secret sauce to the pitch... 🍯',
            'Plating the perfect proposal... 🍽️',
            'Garnishing with final touches... ✨',
          ];

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _messageTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.isCampaign
        ? 'Whipping up goals, audiences, and budget suggestions...'
        : 'Whipping up pricing tiers, target audiences, and descriptions...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE), // purple-100 on website
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rotating dashed circle around AI icon
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _spinController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _spinController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: const Size(64, 64),
                        painter: _DashedCirclePainter(
                          color: const Color(0xFFEE2C2C).withValues(alpha: 0.45),
                          strokeWidth: 3.5,
                          dashes: 12,
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEE2C2C),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Animated cycling message text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _loadingMessages[_messageIndex],
              key: ValueKey<int>(_messageIndex),
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7C3AED), // purple-700
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashes,
  });

  final Color color;
  final double strokeWidth;
  final int dashes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final sweepAngle = (2 * math.pi) / (dashes * 2);

    for (int i = 0; i < dashes; i++) {
      final startAngle = i * (sweepAngle * 2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashes != dashes;
}
