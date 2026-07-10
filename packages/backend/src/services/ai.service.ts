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
