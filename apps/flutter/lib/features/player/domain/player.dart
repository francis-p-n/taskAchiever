import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:life_achiever/core/theme.dart';

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

  String get emoji {
    switch (this) {
      case Energy.hp:
        return '❤️';
      case Energy.mood:
        return '😊';
      case Energy.focus:
        return '🎯';
      case Energy.motivation:
        return '⚡';
    }
  }

  String get caption {
    switch (this) {
      case Energy.hp:
        return 'Begin Game! Light Tasks, Self-care.';
      case Energy.mood:
        return 'Joy, Love, Wonder. Enjoy Life in Fullest.';
      case Energy.focus:
        return 'Light Cognitive Tasks.';
      case Energy.motivation:
        return 'Embrace Growth and Change.';
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
