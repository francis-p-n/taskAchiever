import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/achievements/domain/achievement.dart';

/// Steam-style "Achievement Unlocked" popup.
void showAchievementToast(BuildContext context, Achievement achievement) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: NotionColors.surface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: NotionColors.yellow, width: 1),
      ),
      content: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: NotionColors.yellowBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: NotionColors.yellow, width: 0.5),
            ),
            child: Icon(achievement.iconData, size: 18, color: NotionColors.yellow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ACHIEVEMENT UNLOCKED',
                  style: NotionType.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: NotionColors.yellow,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.title,
                  style: NotionType.display(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
