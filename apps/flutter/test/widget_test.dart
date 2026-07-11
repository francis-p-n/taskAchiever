import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/features/player/domain/player.dart';

void main() {
  group('Player classes', () {
    test('favored-area quests earn 1.5x, others unchanged', () {
      expect(PlayerClass.warrior.boostedXp(10, Area.physical), 15);
      expect(PlayerClass.warrior.boostedXp(10, Area.intel), 10);
      expect(PlayerClass.healer.boostedXp(5, Area.care), 8); // rounds .5 up
    });

    test('job string parses to a class, legacy values default to Mage', () {
      expect(PlayerClassX.fromJob('warrior'), PlayerClass.warrior);
      expect(PlayerClassX.fromJob(' Sage '), PlayerClass.sage);
      expect(PlayerClassX.fromJob('Adventurer'), PlayerClass.mage);
      expect(const Player(job: 'Monk').playerClass, PlayerClass.monk);
    });
  });

  group('Player leveling', () {
    test('xp curve grows with level', () {
      expect(Player.xpForLevel(1), 100);
      expect(Player.xpForLevel(2), 150);
      expect(Player.xpForLevel(10), 550);
    });

    test('total xp accumulates prior levels', () {
      const player = Player(level: 3, xp: 20);
      // levels 1 (100) + 2 (150) + current 20
      expect(player.totalXp, 270);
    });

    test('serialization round-trips', () {
      const player = Player(
        name: 'Ash',
        job: 'Mage',
        level: 12,
        xp: 40,
        xpToday: 15,
        tasksToday: 3,
        energies: {Energy.hp: 6, Energy.mood: 9},
        areas: {Area.physical: 803, Area.intel: 393},
      );
      final restored = Player.fromJson(player.toJson());
      expect(restored.name, 'Ash');
      expect(restored.job, 'Mage');
      expect(restored.level, 12);
      expect(restored.xp, 40);
      expect(restored.xpToday, 15);
      expect(restored.tasksToday, 3);
      expect(restored.energyOf(Energy.hp), 6);
      expect(restored.energyOf(Energy.mood), 9);
      expect(restored.energyOf(Energy.focus), 8); // default
      expect(restored.areaOf(Area.physical), 803);
      expect(restored.areaOf(Area.care), 500); // default
    });
  });
}
