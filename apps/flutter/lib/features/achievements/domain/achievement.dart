import 'package:flutter/material.dart';

enum AchievementCategory { quests, fitness, food, spending }

extension AchievementCategoryX on AchievementCategory {
  String get label {
    switch (this) {
      case AchievementCategory.quests:
        return 'Quests';
      case AchievementCategory.fitness:
        return 'Fitness';
      case AchievementCategory.food:
        return 'Food';
      case AchievementCategory.spending:
        return 'Spending';
    }
  }

  static AchievementCategory fromKey(String key) => switch (key) {
        'fitness' => AchievementCategory.fitness,
        'food' => AchievementCategory.food,
        'spending' => AchievementCategory.spending,
        _ => AchievementCategory.quests,
      };
}

/// Backend icon names → Material icons. Covers the achievement catalog in
/// achievements.service.ts; unrecognized names fall back to a trophy.
const _iconByName = <String, IconData>{
  'flag_outlined': Icons.flag_outlined,
  'checklist_outlined': Icons.checklist_outlined,
  'military_tech_outlined': Icons.military_tech_outlined,
  'workspace_premium_outlined': Icons.workspace_premium_outlined,
  'local_fire_department_outlined': Icons.local_fire_department_outlined,
  'whatshot_outlined': Icons.whatshot_outlined,
  'star_outline': Icons.star_outline,
  'auto_awesome_outlined': Icons.auto_awesome_outlined,
  'directions_run_outlined': Icons.directions_run_outlined,
  'fitness_center_outlined': Icons.fitness_center_outlined,
  'sports_gymnastics_outlined': Icons.sports_gymnastics_outlined,
  'bolt_outlined': Icons.bolt_outlined,
  'restaurant_outlined': Icons.restaurant_outlined,
  'menu_book_outlined': Icons.menu_book_outlined,
  'set_meal_outlined': Icons.set_meal_outlined,
  'payments_outlined': Icons.payments_outlined,
  'file_upload_outlined': Icons.file_upload_outlined,
  'account_balance_wallet_outlined': Icons.account_balance_wallet_outlined,
};

class Achievement {
  final String key;
  final String title;
  final String description;
  final String icon;
  final AchievementCategory category;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    this.unlocked = false,
    this.unlockedAt,
  });

  IconData get iconData => _iconByName[icon] ?? Icons.emoji_events_outlined;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        key: json['key']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Achievement',
        description: json['description']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'emoji_events_outlined',
        category:
            AchievementCategoryX.fromKey(json['category']?.toString() ?? ''),
        unlocked: json['unlocked'] == true,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.tryParse(json['unlockedAt'].toString())
            : null,
      );
}
