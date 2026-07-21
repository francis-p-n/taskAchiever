import Anthropic from '@anthropic-ai/sdk';

export const aiConfigured = () => Boolean(process.env.ANTHROPIC_API_KEY);

let client: Anthropic | null = null;
function getClient(): Anthropic {
  client ??= new Anthropic(); // reads ANTHROPIC_API_KEY from env
  return client;
}

/** Offline/unconfigured fallback so quest creation always works. */
export const heuristicSteps = (title: string) => [
  `Research ${title}`,
  `Plan ${title}`,
  `Execute ${title}`,
];

const STEPS_SCHEMA = {
  type: 'object' as const,
  properties: {
    steps: {
      type: 'array' as const,
      items: { type: 'string' as const },
      description: '3 to 5 short, actionable steps',
    },
  },
  required: ['steps'],
  additionalProperties: false,
};

const MEAL_SCHEMA = {
  type: 'object' as const,
  properties: {
    mealName: { type: 'string' as const, description: 'Short name of the dish(es)' },
    mealType: {
      type: 'string' as const,
      enum: ['Breakfast', 'Lunch', 'Dinner', 'Snack'],
      description: 'Best guess at which meal this is',
    },
    calories: { type: 'integer' as const, description: 'Estimated total kcal' },
    protein: { type: 'integer' as const, description: 'Estimated protein in grams' },
    carbs: { type: 'integer' as const, description: 'Estimated carbs in grams' },
    fats: { type: 'integer' as const, description: 'Estimated fats in grams' },
    confidence: {
      type: 'string' as const,
      enum: ['low', 'medium', 'high'],
    },
  },
  required: ['mealName', 'mealType', 'calories', 'protein', 'carbs', 'fats', 'confidence'],
  additionalProperties: false,
};

export interface MealEstimate {
  mealName: string;
  mealType: 'Breakfast' | 'Lunch' | 'Dinner' | 'Snack';
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  confidence: 'low' | 'medium' | 'high';
}

/** Estimates calories and macros from a photo of a meal. Returns null when
 *  the AI is unconfigured, refuses, or the image can't be parsed. */
export async function analyzeMealPhoto(
  imageBase64: string,
  mediaType: 'image/jpeg' | 'image/png' | 'image/webp' | 'image/gif'
): Promise<MealEstimate | null> {
  if (!aiConfigured()) return null;

  try {
    const response = await getClient().messages.create({
      model: 'claude-opus-4-8',
      max_tokens: 1024,
      output_config: { format: { type: 'json_schema', schema: MEAL_SCHEMA } },
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: { type: 'base64', media_type: mediaType, data: imageBase64 },
            },
            {
              type: 'text',
              text:
                'Estimate the nutrition of the food in this photo for a personal ' +
                'food-logging app: total calories and macros (protein, carbs, fats ' +
                'in grams) for the whole visible portion. Give your single best ' +
                'estimate and rate your confidence.',
            },
          ],
        },
      ],
    });

    if (response.stop_reason === 'refusal' || response.content.length === 0) return null;
    const text = response.content.find((b) => b.type === 'text');
    return text ? (JSON.parse(text.text) as MealEstimate) : null;
  } catch {
    return null;
  }
}

const SUGGESTIONS_SCHEMA = {
  type: 'object' as const,
  properties: {
    suggestions: {
      type: 'array' as const,
      items: {
        type: 'object' as const,
        properties: {
          title: {
            type: 'string' as const,
            description: 'Short, concrete side quest doable today, under 60 characters',
          },
          difficulty: { type: 'integer' as const, minimum: 1, maximum: 5 },
        },
        required: ['title', 'difficulty'],
        additionalProperties: false,
      },
      description: 'Exactly 5 side-quest ideas',
    },
  },
  required: ['suggestions'],
  additionalProperties: false,
};

export interface QuestSuggestion {
  title: string;
  difficulty: number;
}

/** Evergreen ideas so the button always produces something offline. */
const FALLBACK_SUGGESTIONS: QuestSuggestion[] = [
  { title: 'Take a 20-minute walk outside', difficulty: 1 },
  { title: 'Message a friend you miss', difficulty: 1 },
  { title: 'Clear your desk for 10 minutes', difficulty: 1 },
  { title: 'Cook one meal from scratch', difficulty: 2 },
  { title: 'Read 10 pages of any book', difficulty: 1 },
];

/** Suggests 5 fresh side quests informed by what the player has been doing
 *  and (optionally) their least-developed life area. Never throws. */
export async function suggestQuests(
  recentTitles: string[],
  focusArea?: string
): Promise<{ suggestions: QuestSuggestion[]; source: 'ai' | 'fallback' }> {
  if (!aiConfigured()) {
    return { suggestions: FALLBACK_SUGGESTIONS, source: 'fallback' };
  }

  try {
    const response = await getClient().messages.create({
      model: 'claude-opus-4-8',
      max_tokens: 1024,
      output_config: { format: { type: 'json_schema', schema: SUGGESTIONS_SCHEMA } },
      messages: [
        {
          role: 'user',
          content:
            `You suggest side quests for a gamified personal life planner. ` +
            `Side quests are small, concrete, feel-good tasks a person can ` +
            `finish today (under 60 characters each).\n` +
            (recentTitles.length > 0
              ? `They have recently been working on: ${recentTitles.slice(0, 20).join('; ')}.\n`
              : '') +
            (focusArea
              ? `Their least-developed life area is "${focusArea}" — bias 2-3 ideas toward it.\n`
              : '') +
            `Suggest 5 fresh ideas that are NOT rephrasings of the recent ones. ` +
            `Rate each 1 (trivial) to 5 (ambitious); most should be 1-2.`,
        },
      ],
    });

    if (response.stop_reason === 'refusal' || response.content.length === 0) {
      return { suggestions: FALLBACK_SUGGESTIONS, source: 'fallback' };
    }
    const text = response.content.find((b) => b.type === 'text');
    const parsed = text
      ? (JSON.parse(text.text) as { suggestions: QuestSuggestion[] })
      : null;
    if (!parsed?.suggestions?.length) {
      return { suggestions: FALLBACK_SUGGESTIONS, source: 'fallback' };
    }
    return {
      suggestions: parsed.suggestions.slice(0, 5).map((s) => ({
        title: String(s.title).slice(0, 120),
        difficulty: Math.min(5, Math.max(1, Math.round(s.difficulty || 1))),
      })),
      source: 'ai',
    };
  } catch {
    return { suggestions: FALLBACK_SUGGESTIONS, source: 'fallback' };
  }
}

const DIFFICULTY_SCHEMA = {
  type: 'object' as const,
  properties: {
    difficulty: {
      type: 'integer' as const,
      minimum: 1,
      maximum: 5,
      description: '1 = trivial errand, 3 = solid effort, 5 = major undertaking',
    },
  },
  required: ['difficulty'],
  additionalProperties: false,
};

/** Rates a quest's difficulty 1-5. Never throws: unconfigured or failing AI
 *  falls back to a neutral 2 so quest creation always works. */
export async function estimateDifficulty(
  title: string,
  description?: string | null
): Promise<{ difficulty: number; source: 'ai' | 'fallback' }> {
  if (!aiConfigured()) return { difficulty: 2, source: 'fallback' };

  try {
    const response = await getClient().messages.create({
      model: 'claude-opus-4-8',
      max_tokens: 256,
      output_config: { format: { type: 'json_schema', schema: DIFFICULTY_SCHEMA } },
      messages: [
        {
          role: 'user',
          content:
            `Rate the difficulty of this personal quest from 1 (trivial errand) to ` +
            `5 (major multi-day undertaking) for a day-planner app.\n` +
            `Title: ${title}` +
            (description ? `\nDescription: ${description}` : ''),
        },
      ],
    });

    if (response.stop_reason === 'refusal' || response.content.length === 0) {
      return { difficulty: 2, source: 'fallback' };
    }
    const text = response.content.find((b) => b.type === 'text');
    const parsed = text ? (JSON.parse(text.text) as { difficulty: number }) : null;
    if (!parsed || !Number.isInteger(parsed.difficulty)) {
      return { difficulty: 2, source: 'fallback' };
    }
    return { difficulty: Math.min(5, Math.max(1, parsed.difficulty)), source: 'ai' };
  } catch {
    return { difficulty: 2, source: 'fallback' };
  }
}

/** Breaks a quest title into 3-5 actionable steps. Never throws: falls back
 *  to the heuristic steps when the AI is unconfigured or errors. */
export async function generateSteps(
  title: string
): Promise<{ steps: string[]; source: 'ai' | 'fallback' }> {
  if (!aiConfigured()) {
    return { steps: heuristicSteps(title), source: 'fallback' };
  }

  try {
    const response = await getClient().messages.create({
      model: 'claude-opus-4-8',
      max_tokens: 1024,
      output_config: { format: { type: 'json_schema', schema: STEPS_SCHEMA } },
      messages: [
        {
          role: 'user',
          content:
            `Break down the quest "${title}" into 3 to 5 concrete, actionable steps ` +
            `a person can check off in a day-planner app. Keep each step under 60 characters.`,
        },
      ],
    });

    if (response.stop_reason === 'refusal' || response.content.length === 0) {
      return { steps: heuristicSteps(title), source: 'fallback' };
    }
    const text = response.content.find((b) => b.type === 'text');
    const parsed = text ? (JSON.parse(text.text) as { steps: string[] }) : null;
    if (!parsed?.steps?.length) {
      return { steps: heuristicSteps(title), source: 'fallback' };
    }
    return { steps: parsed.steps.slice(0, 5), source: 'ai' };
  } catch {
    return { steps: heuristicSteps(title), source: 'fallback' };
  }
}

const INSIGHTS_SCHEMA = {
  type: 'object' as const,
  properties: {
    insights: {
      type: 'array' as const,
      items: { type: 'string' as const },
      description: '3 concise, actionable observations about the week',
    },
  },
  required: ['insights'],
  additionalProperties: false,
};

/** Rule-based insights when the AI is unconfigured or fails. */
export function heuristicWeeklyInsights(summary: {
  timeByCategory: { category: string; minutes: number; avgRoi: number }[];
  spentWeekCents: number;
  moodAvg: number | null;
  activeStreaks: number;
  atRiskContacts: number;
}): string[] {
  const insights: string[] = [];

  const waste = summary.timeByCategory.find((c) => c.category === 'waste');
  const top = [...summary.timeByCategory].sort((a, b) => b.avgRoi - a.avgRoi)[0];
  if (waste && waste.minutes >= 120) {
    insights.push(
      `You logged ${Math.round(waste.minutes / 60)}h of waste time this week — reclaiming half of it would fund a new habit.`
    );
  }
  if (top) {
    insights.push(
      `Your highest-ROI time went to ${top.category} (score ${top.avgRoi}) — protect that block in next week's schedule.`
    );
  }
  if (summary.moodAvg != null) {
    insights.push(
      summary.moodAvg >= 7
        ? `Mood averaged ${summary.moodAvg}/10 — whatever this week looked like, it's working.`
        : `Mood averaged ${summary.moodAvg}/10 — check sleep and social time, they move it most.`
    );
  }
  if (summary.atRiskContacts > 0) {
    insights.push(
      `${summary.atRiskContacts} relationship${summary.atRiskContacts > 1 ? 's are' : ' is'} past the contact window — a short message today keeps them warm.`
    );
  }
  if (summary.activeStreaks > 0) {
    insights.push(`${summary.activeStreaks} habit streak${summary.activeStreaks > 1 ? 's' : ''} alive — consistency compounds.`);
  }
  if (insights.length === 0) {
    insights.push('Not enough tracked data yet this week — log a few time entries and check-ins to unlock insights.');
  }
  return insights.slice(0, 3);
}

/** Claude-written weekly insights over the aggregated tracking data. */
export async function generateWeeklyInsights(
  summary: Parameters<typeof heuristicWeeklyInsights>[0]
): Promise<{ insights: string[]; source: 'ai' | 'fallback' }> {
  if (!aiConfigured()) {
    return { insights: heuristicWeeklyInsights(summary), source: 'fallback' };
  }

  try {
    const response = await getClient().messages.create({
      model: 'claude-opus-4-8',
      max_tokens: 1024,
      output_config: { format: { type: 'json_schema', schema: INSIGHTS_SCHEMA } },
      messages: [
        {
          role: 'user',
          content:
            'You are the insights engine of a life-tracking app. From this weekly ' +
            'summary of the user\'s time allocation (minutes + 0-100 ROI score per ' +
            'category), spending, mood, habit streaks and neglected relationships, ' +
            'write exactly 3 concise, specific, actionable insights (max 140 chars ' +
            'each). Cite the numbers. Data: ' +
            JSON.stringify(summary),
        },
      ],
    });

    if (response.stop_reason === 'refusal' || response.content.length === 0) {
      return { insights: heuristicWeeklyInsights(summary), source: 'fallback' };
    }
    const text = response.content.find((b) => b.type === 'text');
    const parsed = text ? (JSON.parse(text.text) as { insights: string[] }) : null;
    if (!parsed?.insights?.length) {
      return { insights: heuristicWeeklyInsights(summary), source: 'fallback' };
    }
    return { insights: parsed.insights.slice(0, 3), source: 'ai' };
  } catch {
    return { insights: heuristicWeeklyInsights(summary), source: 'fallback' };
  }
}
