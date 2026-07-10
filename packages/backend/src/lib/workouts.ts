/** True when two logged workouts are plausibly the same session: their time
 *  intervals overlap (with a little slack), or — when durations are unknown —
 *  they start within 15 minutes of each other. A strength session logged half
 *  an hour before a run is NOT a duplicate. */
export function isSameWorkout(
  aStart: Date,
  aDurationSeconds: number,
  bStart: Date,
  bDurationSeconds: number
): boolean {
  const SLACK_MS = 5 * 60 * 1000;
  const START_PROXIMITY_MS = 15 * 60 * 1000;

  if (aDurationSeconds > 0 && bDurationSeconds > 0) {
    const aEnd = aStart.getTime() + aDurationSeconds * 1000;
    const bEnd = bStart.getTime() + bDurationSeconds * 1000;
    return (
      Math.min(aEnd, bEnd) + SLACK_MS > Math.max(aStart.getTime(), bStart.getTime())
    );
  }
  return Math.abs(aStart.getTime() - bStart.getTime()) <= START_PROXIMITY_MS;
}
