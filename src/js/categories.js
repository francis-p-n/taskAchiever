/* ═══════════════════════════════════════════════════════════════════════════
   Categories — Auto-categorization engine
   ═══════════════════════════════════════════════════════════════════════════ */

const Categories = (() => {
  const CATEGORIES = {
    adventure: {
      name: 'Adventure',
      icon: '🗺️',
      color: '#F59E0B',
      keywords: [
        'travel', 'hike', 'hiking', 'explore', 'surf', 'surfing', 'camp', 'camping',
        'dive', 'diving', 'climb', 'climbing', 'trek', 'trekking', 'backpack',
        'road trip', 'roadtrip', 'kayak', 'kayaking', 'sail', 'sailing', 'ski',
        'skiing', 'snowboard', 'paraglide', 'bungee', 'skydive', 'snorkel',
        'mountain', 'beach', 'forest', 'jungle', 'desert', 'island', 'volcano',
        'waterfall', 'canyon', 'cave', 'river', 'lake', 'ocean', 'outdoor',
        'adventure', 'expedition', 'discover', 'wander', 'nature', 'wildlife',
        'safari', 'scuba', 'paddle', 'bike', 'cycling', 'ride', 'visit',
        'trip', 'journey', 'destination', 'country', 'abroad', 'explore'
      ]
    },
    creative: {
      name: 'Creative',
      icon: '🎨',
      color: '#8B5CF6',
      keywords: [
        'paint', 'painting', 'draw', 'drawing', 'sketch', 'write', 'writing',
        'novel', 'poem', 'poetry', 'music', 'song', 'compose', 'guitar',
        'piano', 'drum', 'sing', 'singing', 'dance', 'dancing', 'choreography',
        'design', 'graphic', 'illustration', 'film', 'filmmaking', 'video',
        'photography', 'photo', 'craft', 'pottery', 'sculpt', 'sculpture',
        'knit', 'knitting', 'sew', 'sewing', 'crochet', 'woodwork', 'diy',
        'create', 'art', 'artistic', 'creative', 'cook', 'cooking', 'bake',
        'baking', 'recipe', 'blog', 'vlog', 'podcast', 'animation', 'animate',
        'calligraphy', 'origami', 'jewelry', 'tattoo', 'instrument', 'band',
        'theater', 'theatre', 'act', 'acting', 'improv', 'stand-up', 'comedy'
      ]
    },
    scholarly: {
      name: 'Scholarly',
      icon: '📚',
      color: '#3B82F6',
      keywords: [
        'learn', 'learning', 'study', 'studying', 'read', 'reading', 'book',
        'course', 'class', 'certify', 'certification', 'certificate', 'degree',
        'research', 'science', 'math', 'mathematics', 'history', 'philosophy',
        'language', 'spanish', 'french', 'japanese', 'mandarin', 'german',
        'coding', 'programming', 'code', 'python', 'javascript', 'develop',
        'algorithm', 'data', 'machine learning', 'ai', 'tutorial', 'lecture',
        'workshop', 'seminar', 'conference', 'thesis', 'paper', 'essay',
        'exam', 'test', 'quiz', 'practice', 'mentor', 'teach', 'education',
        'university', 'school', 'academy', 'skill', 'knowledge', 'master',
        'expertise', 'understand', 'analyze', 'theory', 'concept', 'bootcamp'
      ]
    },
    achievement: {
      name: 'Achievement',
      icon: '🏆',
      color: '#10B981',
      keywords: [
        'run', 'running', 'marathon', 'half-marathon', '5k', '10k', 'launch',
        'build', 'ship', 'compete', 'competition', 'goal', 'fitness', 'gym',
        'workout', 'exercise', 'weight', 'muscle', 'strength', 'train',
        'training', 'challenge', 'race', 'swim', 'swimming', 'triathlon',
        'pushup', 'pullup', 'plank', 'yoga', 'meditation', 'mindfulness',
        'habit', 'discipline', 'routine', 'startup', 'business', 'income',
        'save', 'saving', 'invest', 'investment', 'portfolio', 'fund',
        'publish', 'release', 'milestone', 'record', 'personal best', 'pb',
        'accomplish', 'achieve', 'win', 'victory', 'success', 'target',
        'streak', 'consecutive', 'daily', 'monthly', 'annual', 'yearly',
        'promote', 'promotion', 'career', 'job', 'salary', 'raise',
        'volunteer', 'donate', 'charity', 'community', 'impact'
      ]
    }
  };

  /**
   * Auto-detect category from quest title and description.
   * Returns the category key with the highest keyword match score.
   */
  function autoDetect(title, description = '') {
    const text = `${title} ${description}`.toLowerCase();
    const scores = {};

    for (const [key, cat] of Object.entries(CATEGORIES)) {
      scores[key] = 0;
      for (const keyword of cat.keywords) {
        // Match whole words or the keyword as part of a compound
        const regex = new RegExp(`\\b${escapeRegex(keyword)}\\b`, 'i');
        if (regex.test(text)) {
          scores[key] += keyword.includes(' ') ? 3 : 1; // Multi-word matches score higher
        }
      }
    }

    // Find highest score
    let best = 'adventure'; // default fallback
    let bestScore = 0;
    for (const [key, score] of Object.entries(scores)) {
      if (score > bestScore) {
        bestScore = score;
        best = key;
      }
    }

    return best;
  }

  function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function getCategory(key) {
    return CATEGORIES[key] || CATEGORIES.adventure;
  }

  function getAllCategories() {
    return CATEGORIES;
  }

  function getCategoryIcon(key) {
    return CATEGORIES[key]?.icon || '🗺️';
  }

  function getCategoryColor(key) {
    return CATEGORIES[key]?.color || '#F59E0B';
  }

  return {
    autoDetect,
    getCategory,
    getAllCategories,
    getCategoryIcon,
    getCategoryColor,
    CATEGORIES
  };
})();
