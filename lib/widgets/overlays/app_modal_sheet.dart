import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AppModalSheet {
  /// Show a standardized, rounded bottom sheet with safe-area insets & keyboard scroll
  static Future<T?> showCustomBottomSheet<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    IconData? titleIcon,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardInset = mediaQuery.viewInsets.bottom;
        final systemBottomInset = mediaQuery.padding.bottom;
        final totalBottomPadding = keyboardInset + systemBottomInset + 24.0;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.85,
            ),
            padding: EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: totalBottomPadding,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Modal Header Title & Close Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (titleIcon != null) ...[
                              Icon(titleIcon, color: AppTheme.primaryEmerald, size: 22),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AppTheme.primaryEmerald,
                                      fontSize: 18,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Modal Content
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show a standardized warning/error dialog
  static Future<void> showAlertDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.warning_amber_rounded,
    Color iconColor = AppTheme.statusCancelled,
    String confirmText = "Compris",
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
