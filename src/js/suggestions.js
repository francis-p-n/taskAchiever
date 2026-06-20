/* ═══════════════════════════════════════════════════════════════════════════
   Suggestions — Rule-based quest recommendation engine
   ═══════════════════════════════════════════════════════════════════════════ */

const Suggestions = (() => {
  // ─── Curated Quest Database ─────────────────────────────────────────────
  const QUEST_DATABASE = {
    adventure: [
      { title: 'Hike a national park trail', desc: 'Pick a local national park and complete a full day hike. Bonus: summit a peak!', icon: '🏔️', difficulty: 2 },
      { title: 'Learn to surf', desc: 'Take a beginner surfing lesson and catch your first wave.', icon: '🏄', difficulty: 3 },
      { title: 'Go on a solo road trip', desc: 'Plan a 3-day road trip to somewhere you\'ve never been.', icon: '🚗', difficulty: 2 },
      { title: 'Try rock climbing', desc: 'Visit an indoor climbing gym and complete a beginner route.', icon: '🧗', difficulty: 3 },
      { title: 'Camp under the stars', desc: 'Spend a night camping in nature with no phone.', icon: '⛺', difficulty: 1 },
      { title: 'Explore a new city on foot', desc: 'Pick a city within driving distance and walk 10+ miles exploring.', icon: '🚶', difficulty: 1 },
      { title: 'Go kayaking or canoeing', desc: 'Paddle a river or lake for half a day.', icon: '🛶', difficulty: 2 },
      { title: 'Visit a UNESCO World Heritage site', desc: 'Research and visit a heritage site within your region.', icon: '🏛️', difficulty: 2 },
      { title: 'Try snorkeling or scuba diving', desc: 'Explore an underwater world for the first time.', icon: '🤿', difficulty: 3 },
      { title: 'Bike a scenic trail', desc: 'Find a cycling trail and ride at least 20 miles.', icon: '🚴', difficulty: 2 },
      { title: 'Attend an outdoor festival', desc: 'Find a local outdoor/music/food festival and go!', icon: '🎪', difficulty: 1 },
      { title: 'Explore a cave system', desc: 'Visit a show cave or go on a guided spelunking tour.', icon: '🕳️', difficulty: 3 },
    ],
    creative: [
      { title: 'Write a short story', desc: 'Craft a complete short story (2000+ words) in any genre.', icon: '✍️', difficulty: 2 },
      { title: 'Learn a musical instrument', desc: 'Pick up guitar, piano, or ukulele and learn 3 songs.', icon: '🎸', difficulty: 4 },
      { title: 'Start a photography project', desc: 'Choose a theme and shoot 30 photos over 30 days.', icon: '📸', difficulty: 2 },
      { title: 'Paint or draw a self-portrait', desc: 'Create a self-portrait in any medium.', icon: '🎨', difficulty: 3 },
      { title: 'Cook 10 dishes from a new cuisine', desc: 'Pick a cuisine you\'ve never cooked and master 10 recipes.', icon: '👨‍🍳', difficulty: 3 },
      { title: 'Make a short film', desc: 'Script, shoot, and edit a 3-5 minute short film.', icon: '🎬', difficulty: 4 },
      { title: 'Learn hand lettering', desc: 'Practice calligraphy or hand lettering for a month.', icon: '✒️', difficulty: 2 },
      { title: 'Build something with your hands', desc: 'Woodworking, pottery, or any craft — build a tangible thing.', icon: '🔨', difficulty: 3 },
      { title: 'Start a creative journal', desc: 'Keep a daily sketch/writing/idea journal for 30 days.', icon: '📓', difficulty: 1 },
      { title: 'Learn digital illustration', desc: 'Complete a digital art course and create 5 illustrations.', icon: '💻', difficulty: 3 },
      { title: 'Compose a song', desc: 'Write lyrics and compose music for an original song.', icon: '🎵', difficulty: 4 },
      { title: 'Create a recipe book', desc: 'Document 20 of your favorite recipes with photos.', icon: '📖', difficulty: 2 },
    ],
    scholarly: [
      { title: 'Read 12 books this year', desc: 'One book per month — mix fiction and non-fiction.', icon: '📚', difficulty: 3 },
      { title: 'Learn a new programming language', desc: 'Pick a language you\'ve never used and build a project.', icon: '💻', difficulty: 4 },
      { title: 'Take an online certification', desc: 'Complete a professional certification on Coursera/Udemy.', icon: '🎓', difficulty: 3 },
      { title: 'Learn conversational basics of a new language', desc: 'Use Duolingo or a tutor to learn basic conversation in a new language.', icon: '🗣️', difficulty: 4 },
      { title: 'Complete a MOOC', desc: 'Finish an entire massive open online course with assignments.', icon: '🖥️', difficulty: 3 },
      { title: 'Write an essay or blog post', desc: 'Research and write a well-structured 1500+ word piece.', icon: '📝', difficulty: 2 },
      { title: 'Study a historical period in depth', desc: 'Pick an era and read 3 books about it.', icon: '🏺', difficulty: 3 },
      { title: 'Learn basic data analysis', desc: 'Learn Excel/Python data analysis and analyze a real dataset.', icon: '📊', difficulty: 3 },
      { title: 'Attend a workshop or seminar', desc: 'Sign up for a professional development workshop.', icon: '🎯', difficulty: 1 },
      { title: 'Start a study group', desc: 'Form a group to study a topic together for 8 weeks.', icon: '👥', difficulty: 2 },
      { title: 'Build a personal knowledge base', desc: 'Organize your notes into a structured wiki or Notion setup.', icon: '🧠', difficulty: 2 },
      { title: 'Learn financial literacy', desc: 'Study investing, budgeting, and financial planning fundamentals.', icon: '💰', difficulty: 2 },
    ],
    achievement: [
      { title: 'Run a 5K race', desc: 'Train for and complete an official 5K run.', icon: '🏃', difficulty: 2 },
      { title: 'Build a 30-day habit', desc: 'Pick one habit and do it every single day for 30 days.', icon: '📅', difficulty: 3 },
      { title: 'Launch a side project', desc: 'Ship a website, app, or product and share it publicly.', icon: '🚀', difficulty: 4 },
      { title: 'Complete a fitness challenge', desc: '100 pushups, 30-day yoga, or any structured fitness program.', icon: '💪', difficulty: 3 },
      { title: 'Save a specific amount of money', desc: 'Set a savings target and hit it within a timeframe.', icon: '🏦', difficulty: 3 },
      { title: 'Volunteer for a cause', desc: 'Donate 20+ hours to a charity or community project.', icon: '❤️', difficulty: 2 },
      { title: 'Complete a digital detox weekend', desc: 'Go 48 hours without social media or entertainment screens.', icon: '📵', difficulty: 2 },
      { title: 'Run a half-marathon', desc: 'Train for and complete a 21K race.', icon: '🏅', difficulty: 5 },
      { title: 'Meditate daily for 30 days', desc: 'Build a consistent meditation practice — even just 10 minutes.', icon: '🧘', difficulty: 2 },
      { title: 'Declutter your entire living space', desc: 'Marie Kondo style — go through every room and simplify.', icon: '🏠', difficulty: 3 },
      { title: 'Publish something publicly', desc: 'Write an article, make a video, or release open source code.', icon: '📢', difficulty: 3 },
      { title: 'Network with 10 new people', desc: 'Attend events, reach out online, and build genuine connections.', icon: '🤝', difficulty: 2 },
    ]
  };

  // ─── Generate Suggestions ─────────────────────────────────────────────
  async function generate() {
    const quests = await QuestStore.getQuests();
    const completed = await QuestStore.getCompletedQuests();
    const allQuests = [...quests, ...completed];
    const suggestions = [];

    // Count completed categories for the text
    const doneCounts = { adventure: 0, creative: 0, scholarly: 0, achievement: 0 };
    completed.forEach(q => { if (doneCounts[q.category] !== undefined) doneCounts[q.category]++; });

    // Count all for general representation finding
    const catCounts = { adventure: 0, creative: 0, scholarly: 0, achievement: 0 };
    allQuests.forEach(q => { if (catCounts[q.category] !== undefined) catCounts[q.category]++; });

    // Find under-represented categories
    const totalQuests = allQuests.length;
    const categories = Object.keys(catCounts);

    // Sort categories by count (ascending = most under-represented first)
    const sortedCats = categories.sort((a, b) => catCounts[a] - catCounts[b]);

    // Get existing quest titles for deduplication
    const existingTitles = new Set(allQuests.map(q => q.title.toLowerCase()));

    // Strategy 1: Suggest from under-represented categories
    sortedCats.forEach(cat => {
      const available = QUEST_DATABASE[cat].filter(q => !existingTitles.has(q.title.toLowerCase()));
      const picks = shuffleArray(available).slice(0, 2);

      picks.forEach(pick => {
        let reason = '';
        if (doneCounts[cat] === 0) {
          reason = `You haven't completed any ${cat} quests yet — this is a great place to start!`;
        } else if (doneCounts[cat] < completed.length / 4) {
          reason = `You've completed ${doneCounts[cat]} ${cat} quest${doneCounts[cat] > 1 ? 's' : ''} — explore more in this category!`;
        } else {
          reason = `Based on your ${cat} interests — keep the momentum going!`;
        }

        suggestions.push({
          ...pick,
          category: cat,
          reason
        });
      });
    });

    // Strategy 2: Seasonal suggestions
    const month = new Date().getMonth();
    const seasonal = getSeasonalSuggestion(month);
    if (seasonal && !existingTitles.has(seasonal.title.toLowerCase())) {
      suggestions.push(seasonal);
    }

    // Strategy 3: Pattern-based suggestions
    const patternSuggestion = getPatternSuggestion(completed);
    if (patternSuggestion && !existingTitles.has(patternSuggestion.title.toLowerCase())) {
      suggestions.push(patternSuggestion);
    }

    // Shuffle and limit
    return shuffleArray(suggestions).slice(0, 8);
  }

  function getSeasonalSuggestion(month) {
    const seasonal = {
      // Winter (Dec-Feb)
      11: { title: 'Try ice skating or skiing', desc: 'Embrace the winter season with a cold-weather sport.', icon: '⛷️', category: 'adventure', difficulty: 2, reason: '❄️ Perfect for the winter season!' },
      0: { title: 'Set and review yearly goals', desc: 'Start the new year with clear, written goals for all life areas.', icon: '🎯', category: 'achievement', difficulty: 1, reason: '🎆 Great way to kick off the new year!' },
      1: { title: 'Write love letters or gratitude notes', desc: 'Express appreciation to 5 people who matter to you.', icon: '💌', category: 'creative', difficulty: 1, reason: '💝 February is the month of appreciation!' },
      // Spring (Mar-May)
      2: { title: 'Start a garden', desc: 'Plant herbs, vegetables, or flowers and nurture them to bloom.', icon: '🌱', category: 'achievement', difficulty: 2, reason: '🌸 Spring is the perfect time to start growing!' },
      3: { title: 'Go on a nature photography walk', desc: 'Capture spring blooms and wildlife on a long nature walk.', icon: '📸', category: 'creative', difficulty: 1, reason: '🌷 Spring is blooming — capture it!' },
      4: { title: 'Train for a summer race', desc: 'Start a couch-to-5K or similar program for a summer event.', icon: '🏃', category: 'achievement', difficulty: 3, reason: '☀️ Get ready for summer fitness!' },
      // Summer (Jun-Aug)
      5: { title: 'Learn to swim or improve your technique', desc: 'Take swimming lessons or train for open water swimming.', icon: '🏊', category: 'adventure', difficulty: 3, reason: '☀️ Summer is the best time for water activities!' },
      6: { title: 'Go on a camping adventure', desc: 'Plan and execute a multi-day camping trip.', icon: '⛺', category: 'adventure', difficulty: 2, reason: '🌞 Peak camping season — get out there!' },
      7: { title: 'Visit a farmers market every weekend', desc: 'Explore local food culture and cook with seasonal ingredients.', icon: '🥬', category: 'creative', difficulty: 1, reason: '🌽 Late summer harvest is amazing!' },
      // Fall (Sep-Nov)
      8: { title: 'Start a new learning course', desc: 'Enroll in a fall semester course or online program.', icon: '📖', category: 'scholarly', difficulty: 3, reason: '🍂 Back-to-school energy — channel it!' },
      9: { title: 'Do a fall foliage hike', desc: 'Find the most colorful trail and hike through autumn leaves.', icon: '🍁', category: 'adventure', difficulty: 1, reason: '🍂 Peak foliage season — don\'t miss it!' },
      10: { title: 'Write a novel (NaNoWriMo)', desc: 'Join National Novel Writing Month and write 50,000 words.', icon: '✍️', category: 'creative', difficulty: 5, reason: '📝 November is NaNoWriMo — the ultimate creative challenge!' },
    };

    return seasonal[month] || null;
  }

  function getPatternSuggestion(completed) {
    if (completed.length < 3) return null;

    // Find the most common category in recent completions
    const recent = completed.slice(-10);
    const counts = {};
    recent.forEach(q => { counts[q.category] = (counts[q.category] || 0) + 1; });

    const topCat = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
    if (!topCat) return null;

    const catKey = topCat[0];
    const progressions = {
      adventure: { title: 'Plan an international trip', desc: 'You\'re on an adventure roll! Level up with a trip abroad.', icon: '✈️', difficulty: 4, reason: `🔥 You've completed ${topCat[1]} recent adventure quests — time to level up!` },
      creative: { title: 'Organize a creative showcase', desc: 'Share your creative work with friends or online.', icon: '🎭', difficulty: 3, reason: `🔥 You've been on a creative streak — show the world!` },
      scholarly: { title: 'Teach someone what you\'ve learned', desc: 'The best way to master a subject is to teach it.', icon: '👨‍🏫', difficulty: 3, reason: `🔥 You've been learning a lot — share your knowledge!` },
      achievement: { title: 'Set a personal record', desc: 'Push beyond your current best in any activity you track.', icon: '🏆', difficulty: 4, reason: `🔥 You're crushing achievements — break your own record!` }
    };

    return { ...progressions[catKey], category: catKey };
  }

  function shuffleArray(arr) {
    const shuffled = [...arr];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  }

  // ─── Render Suggestions ───────────────────────────────────────────────
  async function render() {
    const container = document.getElementById('suggestions-list');
    const suggestions = await generate();

    if (suggestions.length === 0) {
      container.innerHTML = `
        <div class="empty-state" style="grid-column: 1 / -1;">
          <div class="empty-icon">💡</div>
          <h2>No suggestions right now</h2>
          <p>Complete some quests and we'll suggest new ones based on your journey!</p>
        </div>
      `;
      return;
    }

    container.innerHTML = suggestions.map((s, i) => `
      <div class="suggestion-card" data-category="${s.category}" data-index="${i}">
        <div class="suggestion-header">
          <div class="suggestion-icon">${s.icon}</div>
          <div>
            <div class="suggestion-title">${s.title}</div>
            <span class="quest-badge quest-badge-${s.category}">${Categories.getCategoryIcon(s.category)} ${s.category}</span>
          </div>
        </div>
        <div class="suggestion-desc">${s.desc}</div>
        <div class="suggestion-reason">${s.reason}</div>
        <div style="font-size: var(--font-xs); color: var(--text-muted);">
          Difficulty: ${'⚔️'.repeat(s.difficulty || 1)}${'  '.repeat(5 - (s.difficulty || 1))}
        </div>
        <div class="suggestion-actions">
          <button class="btn btn-primary btn-accept-suggestion" data-index="${i}">
            Accept Quest
          </button>
          <button class="btn btn-ghost btn-dismiss-suggestion" data-index="${i}">
            Dismiss
          </button>
        </div>
      </div>
    `).join('');

    // Store suggestions for reference
    container._suggestions = suggestions;
  }

  return { generate, render, init: () => {} };
})();
