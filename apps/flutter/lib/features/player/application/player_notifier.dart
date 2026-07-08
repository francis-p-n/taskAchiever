import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/features/player/domain/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'player_state_v2';

/// Result of an XP gain, so the UI can celebrate level-ups.
class XpGainResult {
  final int xpGained;
  final bool leveledUp;
  final int newLevel;

  const XpGainResult({
    required this.xpGained,
    required this.leveledUp,
    required this.newLevel,
  });
}

class PlayerNotifier extends StateNotifier<Player> {
  PlayerNotifier() : super(const Player()) {
    _load();
  }

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> _load() async {
    final prefs = await _instance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      state = Player.fromJson(raw);
    }
  }

  Future<void> _save() async {
    final prefs = await _instance();
    await prefs.setString(_prefsKey, state.toJson());
  }

  /// Awards XP (optionally growing an area), handling multi-level carryover.
  XpGainResult gainXp(int amount, {Area? area, bool countTask = true}) {
    var level = state.level;
    var xp = state.xp + amount;
    var leveledUp = false;

    while (xp >= Player.xpForLevel(level)) {
      xp -= Player.xpForLevel(level);
      level++;
      leveledUp = true;
    }

    final areas = Map<Area, int>.from(state.areas);
    if (area != null) {
      areas[area] = (areas[area] ?? 500) + amount;
    }

    state = state.copyWith(
      level: level,
      xp: xp,
      xpToday: state.xpToday + amount,
      tasksToday: state.tasksToday + (countTask ? 1 : 0),
      areas: areas,
    );
    _save();
    return XpGainResult(xpGained: amount, leveledUp: leveledUp, newLevel: level);
  }

  /// Energy menu actions: "Food +1 HP", "Doomscroll -1 Focus", etc.
  void adjustEnergy(Energy kind, int delta) {
    final energies = Map<Energy, int>.from(state.energies);
    energies[kind] =
        (state.energyOf(kind) + delta).clamp(0, maxEnergy);
    state = state.copyWith(energies: energies);
    _save();
  }

  void resetEnergies() {
    state = state.copyWith(
      energies: {for (final e in Energy.values) e: 8},
    );
    _save();
  }

  void rename(String name) {
    state = state.copyWith(name: name);
    _save();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, Player>(
  (ref) => PlayerNotifier(),
);
