import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/meetday_colors.dart';

/// Displays a neo-brutalist popup notification banner sliding in from the top of the screen.
void showTopNotification(
  BuildContext context, {
  required String message,
  String? title,
  bool isError = false,
  bool isSuccess = false,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlayState = Overlay.maybeOf(context, rootOverlay: true);
  if (overlayState == null) return;

  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _TopNotificationWidget(
      title: title,
      message: message,
      isError: isError,
      isSuccess: isSuccess,
      onTap: () {
        entry.remove();
        onTap?.call();
      },
      onDismiss: () {
        entry.remove();
      },
      duration: duration,
    ),
  );

  overlayState.insert(entry);
}

class _TopNotificationWidget extends StatefulWidget {
  const _TopNotificationWidget({
    this.title,
    required this.message,
    required this.isError,
    required this.isSuccess,
    required this.onTap,
    required this.onDismiss,
    required this.duration,
  });

  final String? title;
  final String message;
  final bool isError;
  final bool isSuccess;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top > 0 ? media.padding.top + 8 : 16.0;

    final badgeColor = widget.isError
        ? MeetdayColors.primaryRed
        : (widget.isSuccess
            ? const Color(0xFF10B981)
            : MeetdayColors.accentYellow);

    final iconData = widget.isError
        ? Icons.error_outline_rounded
        : (widget.isSuccess
            ? Icons.check_circle_rounded
            : Icons.notifications_active_rounded);

    final iconColor = widget.isError || widget.isSuccess
        ? Colors.white
        : Colors.black;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              _dismiss();
              widget.onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(1.5, 1.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(iconData, size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title != null && widget.title!.isNotEmpty) ...[
                          Text(
                            widget.title!,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 1),
                        ],
                        Text(
                          widget.message,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF222222),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
