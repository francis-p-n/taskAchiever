import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';

/// The four energy meters shown across the top of the template dashboard.
enum Energy { hp, mood, focus, motivation }

extension EnergyX on Energy {
  String get label {
    switch (this) {
      case Energy.hp:
        return 'HP';
      case Energy.mood:
        return 'Mood';
      case Energy.focus:
        return 'Focus';
      case Energy.motivation:
        return 'Motivation';
    }
  }

  IconData get icon {
    switch (this) {
      case Energy.hp:
        return Icons.favorite_outline;
      case Energy.mood:
        return Icons.sentiment_satisfied_outlined;
      case Energy.focus:
        return Icons.center_focus_strong_outlined;
      case Energy.motivation:
        return Icons.bolt_outlined;
    }
  }

  String get caption {
    switch (this) {
      case Energy.hp:
        return 'Body battery — refill with rest and self-care.';
      case Energy.mood:
        return 'How life feels right now. Protect the good days.';
      case Energy.focus:
        return 'Mental clarity available for deep work.';
      case Energy.motivation:
        return 'Your drive to grow and take on change.';
    }
  }

  Color get color {
    switch (this) {
      case Energy.hp:
        return NotionColors.green;
      case Energy.mood:
        return NotionColors.purple;
      case Energy.focus:
        return NotionColors.yellow;
      case Energy.motivation:
        return NotionColors.blue;
    }
  }

  Color get bgColor {
    switch (this) {
      case Energy.hp:
        return NotionColors.greenBg;
      case Energy.mood:
        return NotionColors.purpleBg;
      case Energy.focus:
        return NotionColors.yellowBg;
      case Energy.motivation:
        return NotionColors.blueBg;
    }
  }
}

/// Life areas plotted on the character radar chart.
enum Area { physical, intel, psyche, spiritual, care }

extension AreaX on Area {
  String get label {
    switch (this) {
      case Area.physical:
        return 'Physical';
      case Area.intel:
        return 'Intel';
      case Area.psyche:
        return 'Psyche';
      case Area.spiritual:
        return 'Spiritual';
      case Area.care:
        return 'Care';
    }
  }
}

const maxEnergy = 10;

/// Playable classes. A class is a specialization, not a costume: quests in
/// the class's favored area earn bonus XP, so picking one shapes which side
/// of life the game rewards hardest.
enum PlayerClass { warrior, sage, mage, monk, healer }

/// Favored-area quests earn base XP × this (rounded).
const classXpMultiplier = 1.5;

extension PlayerClassX on PlayerClass {
  String get label {
    switch (this) {
      case PlayerClass.warrior:
        return 'Warrior';
      case PlayerClass.sage:
        return 'Sage';
      case PlayerClass.mage:
        return 'Mage';
      case PlayerClass.monk:
        return 'Monk';
      case PlayerClass.healer:
        return 'Healer';
    }
  }

  Area get favoredArea {
    switch (this) {
      case PlayerClass.warrior:
        return Area.physical;
      case PlayerClass.sage:
        return Area.intel;
      case PlayerClass.mage:
        return Area.psyche;
      case PlayerClass.monk:
        return Area.spiritual;
      case PlayerClass.healer:
        return Area.care;
    }
  }

  IconData get icon {
    switch (this) {
      case PlayerClass.warrior:
        return Icons.fitness_center_outlined;
      case PlayerClass.sage:
        return Icons.menu_book_outlined;
      case PlayerClass.mage:
        return Icons.auto_fix_high_outlined;
      case PlayerClass.monk:
        return Icons.self_improvement_outlined;
      case PlayerClass.healer:
        return Icons.volunteer_activism_outlined;
    }
  }

  String get tagline {
    switch (this) {
      case PlayerClass.warrior:
        return 'Trains the body. Workouts and physical quests hit harder.';
      case PlayerClass.sage:
        return 'Sharpens the mind. Learning and deep work pay out more.';
      case PlayerClass.mage:
        return 'Feeds the psyche. Creative and joyful quests are amplified.';
      case PlayerClass.monk:
        return 'Stills the spirit. Meditation and reflection earn extra.';
      case PlayerClass.healer:
        return 'Tends to care. Self-care and looking after others rewards more.';
    }
  }

  /// The class bonus: favored-area quests pay base × [classXpMultiplier].
  int boostedXp(int baseXp, Area area) =>
      area == favoredArea ? (baseXp * classXpMultiplier).round() : baseXp;

  /// Parses the persisted job string; unknown/legacy values default to Mage
  /// (the app's original default job).
  static PlayerClass fromJob(String job) {
    final normalized = job.trim().toLowerCase();
    for (final playerClass in PlayerClass.values) {
      if (playerClass.label.toLowerCase() == normalized) return playerClass;
    }
    return PlayerClass.mage;
  }
}

class Player {
  final String name;
  final String job;
  final int age;
  final int level;
  final int xp; // progress within the current level
  final int xpToday;
  final int tasksToday;
  final Map<Energy, int> energies;
  final Map<Area, int> areas;

  const Player({
    this.name = 'Ash',
    this.job = 'Mage',
    this.age = 20,
    this.level = 1,
    this.xp = 0,
    this.xpToday = 0,
    this.tasksToday = 0,
    this.energies = const {},
    this.areas = const {},
  });

  /// The class parsed from the persisted job string.
  PlayerClass get playerClass => PlayerClassX.fromJob(job);

  /// XP required to advance from [level] to the next one.
  static int xpForLevel(int level) => 100 + (level - 1) * 50;

  int get xpToNext => xpForLevel(level);

  int get totalXp {
    var total = xp;
    for (var l = 1; l < level; l++) {
      total += xpForLevel(l);
    }
    return total;
  }

  int energyOf(Energy kind) => energies[kind] ?? 8;

  int areaOf(Area kind) => areas[kind] ?? 500;

  Player copyWith({
    String? name,
    String? job,
    int? age,
    int? level,
    int? xp,
    int? xpToday,
    int? tasksToday,
    Map<Energy, int>? energies,
    Map<Area, int>? areas,
  }) {
    return Player(
      name: name ?? this.name,
      job: job ?? this.job,
      age: age ?? this.age,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToday: xpToday ?? this.xpToday,
      tasksToday: tasksToday ?? this.tasksToday,
      energies: energies ?? this.energies,
      areas: areas ?? this.areas,
    );
  }

  String toJson() => jsonEncode({
        'name': name,
        'job': job,
        'age': age,
        'level': level,
        'xp': xp,
        'xpToday': xpToday,
        'tasksToday': tasksToday,
        'energies': energies.map((k, v) => MapEntry(k.name, v)),
        'areas': areas.map((k, v) => MapEntry(k.name, v)),
      });

  static Player fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final rawEnergies = (map['energies'] as Map<String, dynamic>? ?? {});
    final rawAreas = (map['areas'] as Map<String, dynamic>? ?? {});
    return Player(
      name: map['name'] as String? ?? 'Ash',
      job: map['job'] as String? ?? 'Mage',
      age: map['age'] as int? ?? 20,
      level: map['level'] as int? ?? 1,
      xp: map['xp'] as int? ?? 0,
      xpToday: map['xpToday'] as int? ?? 0,
      tasksToday: map['tasksToday'] as int? ?? 0,
      energies: {
        for (final e in rawEnergies.entries)
          Energy.values.byName(e.key): e.value as int,
      },
      areas: {
        for (final e in rawAreas.entries)
          Area.values.byName(e.key): e.value as int,
      },
    );
  }
}
