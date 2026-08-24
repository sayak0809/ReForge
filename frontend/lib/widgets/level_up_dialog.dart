import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'trophy_badge.dart';

Future<void> showLevelUpDialog(
  BuildContext context, {
  required int newLevel,
  required String newTitle,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrophyReveal(title: newTitle, size: 96),
          const SizedBox(height: 20),
          const Text(
            'LEVEL UP',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'You are now\nLevel $newLevel: $newTitle',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text(
            'FORGE ON',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
      ],
    ),
  );
}
