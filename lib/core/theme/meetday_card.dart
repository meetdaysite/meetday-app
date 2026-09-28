import 'package:flutter/material.dart';
import 'meetday_colors.dart';

class MeetdayCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double radius;
  final double borderWidth;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const MeetdayCard({
    super.key,
    required this.child,
    this.backgroundColor = MeetdayColors.cardWhite,
    this.radius = 22.0,
    this.borderWidth = 2.5,
    this.shadowOffset = const Offset(4, 4),
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: MeetdayColors.inkBlack, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: MeetdayColors.inkBlack,
            offset: shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
