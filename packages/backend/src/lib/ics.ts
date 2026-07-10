// Dependency-free iCalendar (RFC 5545) parser — just enough for calendar
// sync: VEVENT extraction, common DTSTART/DTEND forms, and basic RRULE
// expansion (DAILY / WEEKLY+BYDAY / MONTHLY / YEARLY with INTERVAL,
// COUNT, UNTIL, EXDATE).

export interface IcsEvent {
  uid: string;
  summary: string;
  start: Date;
  end: Date | null;
  allDay: boolean;
  rrule: string | null;
  exdates: Date[];
}

/** Unfold per RFC 5545: a line break followed by space/tab continues the line. */
function unfold(text: string): string[] {
  return text
    .replace(/\r\n[ \t]/g, '')
    .replace(/\n[ \t]/g, '')
    .split(/\r?\n/);
}

function unescapeText(value: string): string {
  return value
    .replace(/\\n/gi, '\n')
    .replace(/\\,/g, ',')
    .replace(/\\;/g, ';')
    .replace(/\\\\/g, '\\');
}

/** Parse an iCal date/date-time value. 'Z' suffix = UTC; bare local-time and
 *  TZID forms are treated as server-local; VALUE=DATE is local midnight. */
function parseIcsDate(value: string): { date: Date; allDay: boolean } | null {
  let m = value.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/);
  if (m) {
    const [, y, mo, d, h, mi, s, z] = m;
    const date = z
      ? new Date(Date.UTC(+y, +mo - 1, +d, +h, +mi, +s))
      : new Date(+y, +mo - 1, +d, +h, +mi, +s);
    return { date, allDay: false };
  }
  m = value.match(/^(\d{4})(\d{2})(\d{2})$/);
  if (m) {
    const [, y, mo, d] = m;
    return { date: new Date(+y, +mo - 1, +d), allDay: true };
  }
  return null;
}

/** Minimal ISO-8601 duration → milliseconds (P#DT#H#M#S forms). */
function parseDurationMs(value: string): number | null {
  const m = value.match(/^-?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
  if (!m) return null;
  const [, w, d, h, mi, s] = m;
  const ms =
    (+(w || 0)) * 7 * 86400_000 +
    (+(d || 0)) * 86400_000 +
    (+(h || 0)) * 3600_000 +
    (+(mi || 0)) * 60_000 +
    (+(s || 0)) * 1000;
  return value.startsWith('-') ? -ms : ms;
}

export function parseIcs(text: string): IcsEvent[] {
  const lines = unfold(text);
  const events: IcsEvent[] = [];
  let current: Record<string, { params: string; value: string }[]> | null = null;

  for (const line of lines) {
    if (line === 'BEGIN:VEVENT') {
      current = {};
      continue;
    }
    if (line === 'END:VEVENT') {
      if (current) {
        const ev = buildEvent(current);
        if (ev) events.push(ev);
      }
      current = null;
      continue;
    }
    if (!current) continue;

    const idx = line.indexOf(':');
    if (idx < 0) continue;
    const head = line.slice(0, idx);
    const value = line.slice(idx + 1);
    const semi = head.indexOf(';');
    const name = (semi < 0 ? head : head.slice(0, semi)).toUpperCase();
    const params = semi < 0 ? '' : head.slice(semi + 1);
    (current[name] ??= []).push({ params, value });
  }

  return events;
}

function buildEvent(props: Record<string, { params: string; value: string }[]>): IcsEvent | null {
  const uid = props['UID']?.[0]?.value;
  const dtstartRaw = props['DTSTART']?.[0];
  if (!uid || !dtstartRaw) return null;

  const start = parseIcsDate(dtstartRaw.value);
  if (!start) return null;

  let end: Date | null = null;
  const dtendRaw = props['DTEND']?.[0];
  if (dtendRaw) {
    end = parseIcsDate(dtendRaw.value)?.date ?? null;
  } else {
    const durRaw = props['DURATION']?.[0];
    if (durRaw) {
      const ms = parseDurationMs(durRaw.value);
      if (ms !== null) end = new Date(start.date.getTime() + ms);
    }
  }

  const exdates: Date[] = [];
  for (const ex of props['EXDATE'] ?? []) {
    for (const v of ex.value.split(',')) {
      const parsed = parseIcsDate(v.trim());
      if (parsed) exdates.push(parsed.date);
    }
  }

  return {
    uid,
    summary: unescapeText(props['SUMMARY']?.[0]?.value ?? '(untitled)'),
    start: start.date,
    end,
    allDay: start.allDay,
    rrule: props['RRULE']?.[0]?.value ?? null,
    exdates,
  };
}

const WEEKDAYS: Record<string, number> = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
const MAX_ITERATIONS = 1000;

function sameOccurrence(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate() &&
    a.getHours() === b.getHours() &&
    a.getMinutes() === b.getMinutes()
  );
}

/** Expand an event's occurrences inside [windowStart, windowEnd]. */
export function expandOccurrences(
  ev: IcsEvent,
  windowStart: Date,
  windowEnd: Date
): { start: Date; end: Date | null }[] {
  const durationMs = ev.end ? ev.end.getTime() - ev.start.getTime() : null;
  const single = () =>
    ev.start <= windowEnd && (ev.end ?? ev.start) >= windowStart
      ? [{ start: ev.start, end: ev.end }]
      : [];

  if (!ev.rrule) return single();

  const rule: Record<string, string> = {};
  for (const part of ev.rrule.split(';')) {
    const [k, v] = part.split('=');
    if (k && v) rule[k.toUpperCase()] = v;
  }

  const freq = rule['FREQ'];
  if (!freq || !['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'].includes(freq)) return single();

  const interval = Math.max(1, parseInt(rule['INTERVAL'] || '1', 10) || 1);
  const count = rule['COUNT'] ? parseInt(rule['COUNT'], 10) : null;
  const until = rule['UNTIL'] ? parseIcsDate(rule['UNTIL'])?.date ?? null : null;
  const byday =
    freq === 'WEEKLY' && rule['BYDAY']
      ? rule['BYDAY']
          .split(',')
          .map((d) => WEEKDAYS[d.trim()])
          .filter((n) => n !== undefined)
      : null;

  const out: { start: Date; end: Date | null }[] = [];
  let occurrences = 0;
  let candidate = new Date(ev.start);

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    if (until && candidate > until) break;
    if (count !== null && occurrences >= count) break;
    if (candidate > windowEnd) break;

    const matchesByday = !byday || byday.includes(candidate.getDay());
    if (matchesByday) {
      occurrences++;
      const excluded = ev.exdates.some((ex) => sameOccurrence(ex, candidate));
      if (!excluded && candidate >= windowStart) {
        out.push({
          start: new Date(candidate),
          end: durationMs !== null ? new Date(candidate.getTime() + durationMs) : null,
        });
      }
    }

    // Advance. Weekly rules with BYDAY step a day at a time so each listed
    // weekday is visited; the interval applies week-by-week.
    if (freq === 'DAILY') {
      candidate.setDate(candidate.getDate() + interval);
    } else if (freq === 'WEEKLY') {
      if (byday) {
        const day = candidate.getDay();
        candidate.setDate(candidate.getDate() + (day === 6 ? 1 + (interval - 1) * 7 : 1));
      } else {
        candidate.setDate(candidate.getDate() + 7 * interval);
      }
    } else if (freq === 'MONTHLY') {
      candidate.setMonth(candidate.getMonth() + interval);
    } else {
      candidate.setFullYear(candidate.getFullYear() + interval);
    }
  }

  return out;
}
