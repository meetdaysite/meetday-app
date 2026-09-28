import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'meetday_colors.dart';

class MeetdayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final double radius;
  final double borderWidth;
  final Offset shadowOffset;
  final EdgeInsetsGeometry padding;
  final bool isFullWidth;

  const MeetdayButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor = MeetdayColors.primaryRed,
    this.textColor = Colors.white,
    this.radius = 14.0,
    this.borderWidth = 2.0,
    this.shadowOffset = const Offset(3, 3),
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.isFullWidth = true,
  });

  @override
  State<MeetdayButton> createState() => _MeetdayButtonState();
}

class _MeetdayButtonState extends State<MeetdayButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentShadow = _isPressed ? const Offset(1, 1) : widget.shadowOffset;
    final currentTranslation = _isPressed ? const Offset(2, 2) : Offset.zero;

    Widget button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: Transform.translate(
        offset: currentTranslation,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: MeetdayColors.inkBlack,
              width: widget.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: MeetdayColors.inkBlack,
                offset: currentShadow,
                blurRadius: 0,
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: GoogleFonts.poppins(
              color: widget.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            child: Center(
              widthFactor: widget.isFullWidth ? null : 1.0,
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    return widget.isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
