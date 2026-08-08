import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppNotifications {
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppTheme.primaryEmerald,
      accentColor: AppTheme.accentMint,
    );
  }

  static void showError(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: const Color(0xFF991B1B),
      accentColor: const Color(0xFFFCA5A5),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: const Color(0xFF0369A1),
      accentColor: const Color(0xFF7DD3FC),
    );
  }

  static void _showToast({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color accentColor,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 20),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
