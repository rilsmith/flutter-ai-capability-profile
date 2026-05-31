import 'package:flutter/material.dart';

class DashboardTheme {
  static const background = Color(0xFFF3F4F6);
  static const cardBorder = Color(0xFFE5E7EB);
  static const cardShadow = Color(0x0F000000);
  static const heading = Color(0xFF111827);
  static const body = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const subtle = Color(0xFF9CA3AF);
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFEFF6FF);
  static const divider = Color(0xFFF3F4F6);

  static Color parseHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  static BoxDecoration cardDecoration({Color? backgroundColor}) {
    return BoxDecoration(
      color: backgroundColor ?? Colors.white,
      border: Border.all(color: cardBorder),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: cardShadow,
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  static BoxDecoration dashboardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: cardBorder),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 24,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  static TextStyle cardHeading = const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
    color: muted,
  );

  static ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: body,
    side: const BorderSide(color: cardBorder),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  static ButtonStyle primaryButton = FilledButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
