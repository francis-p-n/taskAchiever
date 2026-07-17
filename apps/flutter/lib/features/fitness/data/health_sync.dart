import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:life_os/features/fitness/data/fitness_repository.dart';

/// Pulls today's data out of Google Health Connect and pushes it to the
/// backend. This is the route for wearables without a public API (Nothing X
/// / CMF Watch): let their app sync into Health Connect, then read it here.
///
/// Android-only — Health Connect doesn't exist on desktop, so [syncToday]
/// just explains that on other platforms.
class HealthSyncService {
  HealthSyncService(this._repository);

  final FitnessRepository _repository;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,
  ];

  /// Returns a user-displayable result message.
  Future<String> syncToday() async {
    if (!Platform.isAndroid) {
      return 'Health Connect sync only works on the Android app. On the '
          'Nothing X / CMF Watch app, enable Google Health Connect sync, '
          'then sync from lifeOS on your phone.';
    }

    try {
      final health = Health();
      await health.configure();

      final granted = await health.requestAuthorization(_types);
      if (!granted) {
        return 'Health Connect permissions denied — allow lifeOS to read '
            'steps, heart rate, energy and workouts.';
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final steps = await health.getTotalStepsInInterval(midnight, now) ?? 0;

      final points = await health.getHealthDataFromTypes(
        types: _types,
        startTime: midnight,
        endTime: now,
      );

      var calories = 0.0;
      int? hrMin;
      int? hrMax;
      var workouts = 0;

      for (final point in points) {
        final value = point.value;
        switch (point.type) {
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            if (value is NumericHealthValue) {
              calories += value.numericValue.toDouble();
            }
          case HealthDataType.HEART_RATE:
            if (value is NumericHealthValue) {
              final bpm = value.numericValue.round();
              hrMin = hrMin == null || bpm < hrMin ? bpm : hrMin;
              hrMax = hrMax == null || bpm > hrMax ? bpm : hrMax;
            }
          case HealthDataType.WORKOUT:
            if (value is WorkoutHealthValue) {
              final logged = await _repository.logActivityEntry(
                name: value.workoutActivityType.name,
                sportType: value.workoutActivityType.name,
                source: 'health',
                externalId: point.uuid,
                startTime: point.dateFrom,
                durationSeconds:
                    point.dateTo.difference(point.dateFrom).inSeconds,
                caloriesBurned: value.totalEnergyBurned,
              );
              if (logged) workouts++;
            }
          default:
            break;
        }
      }

      final ok = await _repository.pushDailyTotals(
        steps: steps,
        caloriesBurned: calories.round(),
        heartRateMin: hrMin,
        heartRateMax: hrMax,
      );
      if (!ok) return 'Backend offline — health data not saved.';

      return 'Health sync complete: $steps steps, ${calories.round()} kcal'
          '${workouts > 0 ? ', $workouts workout(s)' : ''}.';
    } catch (err) {
      return 'Health sync failed: $err';
    }
  }
}

final healthSyncProvider = Provider<HealthSyncService>((ref) {
  return HealthSyncService(ref.watch(fitnessRepositoryProvider));
});
