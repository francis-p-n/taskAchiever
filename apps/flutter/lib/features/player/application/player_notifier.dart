import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/features/player/data/profile_repository.dart';
import 'package:life_os/features/player/domain/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'player_state_v2';
const _savedAtKey = 'player_state_saved_at_v1';

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
  PlayerNotifier(this._ref) : super(const Player()) {
    _loading = _load();
  }

  final Ref _ref;
  SharedPreferences? _prefs;
  Future<void>? _loading;
  DateTime _savedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> _load() async {
    final prefs = await _instance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      state = Player.fromJson(raw);
      _savedAt = DateTime.tryParse(prefs.getString(_savedAtKey) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<void> _save() async {
    _savedAt = DateTime.now().toUtc();
    final prefs = await _instance();
    final json = state.toJson();
    await prefs.setString(_prefsKey, json);
    await prefs.setString(_savedAtKey, _savedAt.toIso8601String());
    // Mirror to the server so the phone and desktop share one player.
    // Fire-and-forget: offline just means the next device wins on recency.
    _ref
        .read(profileRepositoryProvider)
        .push(json, _savedAt)
        .then((winner) {
      if (winner?.profile != null && mounted) {
        _adopt(winner!);
      }
    }).catchError((_) {});
  }

  /// Takes over a newer profile from another device (no re-push).
  void _adopt(RemoteProfile remote) {
    state = Player.fromJson(jsonEncode(remote.profile));
    _savedAt = remote.updatedAt ?? DateTime.now().toUtc();
    _instance().then((prefs) async {
      await prefs.setString(_prefsKey, state.toJson());
      await prefs.setString(_savedAtKey, _savedAt.toIso8601String());
    });
  }

  /// Startup reconciliation: adopt the server profile when another device
  /// wrote more recently; push ours when we're ahead.
  Future<void> syncProfile() async {
    await _loading;
    final remote = await _ref.read(profileRepositoryProvider).fetch();
    if (remote == null || !mounted) return; // offline

    if (remote.profile != null &&
        remote.updatedAt != null &&
        remote.updatedAt!.isAfter(_savedAt)) {
      _adopt(remote);
    } else if (_savedAt.millisecondsSinceEpoch > 0) {
      await _ref.read(profileRepositoryProvider).push(state.toJson(), _savedAt);
    }
  }

  /// Rebases level/progress on the backend's lifetime XP (user_stats).
  /// Waits for the prefs load so it can't be overwritten by stale local state.
  Future<void> hydrateFromServerXp(int experiencePoints) async {
    await _loading;
    if (experiencePoints <= state.totalXp) return; // local is ahead or equal

    var level = 1;
    var xp = experiencePoints;
    while (xp >= Player.xpForLevel(level)) {
      xp -= Player.xpForLevel(level);
      level++;
    }
    state = state.copyWith(level: level, xp: xp);
    _save();
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

  /// Takes back previously-awarded XP (quest undo), handling level-downs.
  void revertXp(int amount, {Area? area, bool countTask = true}) {
    var level = state.level;
    var xp = state.xp - amount;

    while (xp < 0 && level > 1) {
      level--;
      xp += Player.xpForLevel(level);
    }
    if (xp < 0) xp = 0;

    final areas = Map<Area, int>.from(state.areas);
    if (area != null) {
      areas[area] = (areas[area] ?? 500) - amount;
    }

    state = state.copyWith(
      level: level,
      xp: xp,
      xpToday: (state.xpToday - amount).clamp(0, 1 << 31),
      tasksToday:
          (state.tasksToday - (countTask ? 1 : 0)).clamp(0, 1 << 31),
      areas: areas,
    );
    _save();
  }

  /// Energy menu actions: "Food +1 HP", "Doomscroll -1 Focus", etc.
  void adjustEnergy(Energy kind, int delta) {
    final energies = Map<Energy, int>.from(state.energies);
    energies[kind] =
        (state.energyOf(kind) + delta).clamp(0, maxEnergy);
    state = state.copyWith(energies: energies);
    _save();
  }

  /// Refills every energy bar to full.
  void resetEnergies() {
    state = state.copyWith(
      energies: {for (final e in Energy.values) e: maxEnergy},
    );
    _save();
  }

  void rename(String name) {
    state = state.copyWith(name: name);
    _save();
  }

  /// Updates the Player ID card fields (name / job / age).
  void updateProfile({String? name, String? job, int? age}) {
    state = state.copyWith(name: name, job: job, age: age);
    _save();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, Player>(
  (ref) => PlayerNotifier(ref),
);
