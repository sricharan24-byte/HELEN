import 'package:flutter/material.dart';

/// Standard, unified BusBuddy branding logo widget.
///
/// Strictly renders "Bus" in white and "Buddy" in brand electric blue (#007AFF)
/// across all screens for a coherent, recognizable visual identity.
class BusBuddyLogo extends StatelessWidget {
  const BusBuddyLogo({
    super.key,
    this.fontSize = 20,
    this.subtitle,
    this.subtitleColor,
    this.mainAxisSize = MainAxisSize.min,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  /// Base font size for 'Bus' and 'Buddy' text.
  final double fontSize;

  /// Optional subtitle below the logo (e.g. 'My Tickets', 'Ticket Details').
  final String? subtitle;

  /// Optional color override for subtitle text.
  final Color? subtitleColor;

  /// Layout axis sizing for the logo row.
  final MainAxisSize mainAxisSize;

  /// Cross-axis alignment when subtitle is present.
  final CrossAxisAlignment crossAxisAlignment;

  /// Brand colors: Bus is strictly white, Buddy is strictly Blue (#007AFF).
  static const Color busColor = Colors.white;
  static const Color buddyColor = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final logoRow = Row(
      mainAxisSize: mainAxisSize,
      children: [
        Text(
          'Bus',
          style: TextStyle(
            color: busColor,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          'Buddy',
          style: TextStyle(
            color: buddyColor,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );

    if (subtitle == null) {
      return Semantics(
        label: 'BusBuddy',
        child: logoRow,
      );
    }

    final effectiveSubColor = subtitleColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF334155));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Semantics(
          label: 'BusBuddy',
          child: logoRow,
        ),
        const SizedBox(height: 1),
        Text(
          subtitle!,
          style: TextStyle(
            color: effectiveSubColor,
            fontSize: (fontSize * 0.58).clamp(11.0, 14.0),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
