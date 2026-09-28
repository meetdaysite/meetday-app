import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'meetday_colors.dart';

enum MeetdayBadgeType {
  unread,
  pending,
  success,
  hub,
  campaign,
  custom,
}

class MeetdayBadge extends StatelessWidget {
  final String label;
  final MeetdayBadgeType type;
  final Color? backgroundColor;
  final Color? textColor;
  final Color borderColor;
  final double borderWidth;
  final double radius;

  const MeetdayBadge({
    super.key,
    required this.label,
    this.type = MeetdayBadgeType.custom,
    this.backgroundColor,
    this.textColor,
    this.borderColor = MeetdayColors.inkBlack,
    this.borderWidth = 1.5,
    this.radius = 10.0,
  });

  const MeetdayBadge.unread({
    super.key,
    required this.label,
    this.borderColor = MeetdayColors.inkBlack,
    this.borderWidth = 1.5,
    this.radius = 10.0,
  })  : type = MeetdayBadgeType.unread,
        backgroundColor = MeetdayColors.primaryRed,
        textColor = Colors.white;

  const MeetdayBadge.pending({
    super.key,
    required this.label,
    this.borderColor = MeetdayColors.inkBlack,
    this.borderWidth = 1.5,
    this.radius = 10.0,
  })  : type = MeetdayBadgeType.pending,
        backgroundColor = MeetdayColors.accentYellow,
        textColor = MeetdayColors.inkBlack;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case MeetdayBadgeType.unread:
        bg = MeetdayColors.primaryRed;
        fg = Colors.white;
        break;
      case MeetdayBadgeType.pending:
        bg = MeetdayColors.accentYellow;
        fg = MeetdayColors.inkBlack;
        break;
      case MeetdayBadgeType.success:
        bg = MeetdayColors.successGreen;
        fg = Colors.white;
        break;
      case MeetdayBadgeType.hub:
        bg = MeetdayColors.hubBlue;
        fg = Colors.white;
        break;
      case MeetdayBadgeType.campaign:
        bg = MeetdayColors.campaignPurple;
        fg = Colors.white;
        break;
      case MeetdayBadgeType.custom:
        bg = backgroundColor ?? MeetdayColors.mutedSurface;
        fg = textColor ?? MeetdayColors.textPrimary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
