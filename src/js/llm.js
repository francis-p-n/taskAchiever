/* ═══════════════════════════════════════════════════════════════════════════
   LLM Service — Lightweight AI integration for intelligent recommendations
   ═══════════════════════════════════════════════════════════════════════════ */

const LLM = (() => {
  // Check if Chrome's window.ai (Gemini Nano) is available
  async function isAiAvailable() {
    if ('ai' in window && window.ai && window.ai.createTextSession) {
      try {
        const capability = await window.ai.canCreateTextSession();
        return capability !== 'no';
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  // Uses the LLM to analyze quests and recommend logical stepping stones.
  // Blends heuristic scores with LLM insights.
  async function enhanceAchievableScoring(questsWithScores) {
    const available = await isAiAvailable();
    
    if (!available) {
      console.log('LLM not available, falling back to heuristic scoring solely.');
      return questsWithScores;
    }

    try {
      // Create a simplified list to send to the LLM
      const questListStr = questsWithScores.map((q, index) => 
        `[ID: ${index}] Title: "${q.title}" - Category: ${q.category}`
      ).join('\n');

      const prompt = `
You are an intelligent task analyzer. Your goal is to identify "stepping stone" tasks from a list. 
If there are large, difficult tasks (e.g., "Run a marathon") and smaller related tasks (e.g., "Run a half-marathon"), you should highly recommend the smaller task as a stepping stone.
Review the following list of active quests:

${questListStr}

Please respond with a JSON array of objects, where each object has:
- "id": the ID number from the list above
- "boost": A number between 0 and 50 representing how much of a "stepping stone" this is. 50 means it's an excellent, logical stepping stone. 0 means it is not.

Output only valid JSON, nothing else.`;

      const session = await window.ai.createTextSession();
      const response = await session.prompt(prompt);
      session.destroy();

      // Attempt to parse JSON from the LLM response
      // Find the first '[' and last ']' to extract JSON safely
      const jsonStart = response.indexOf('[');
      const jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart !== -1 && jsonEnd !== -1) {
        const jsonStr = response.slice(jsonStart, jsonEnd);
        const aiBoosts = JSON.parse(jsonStr);
        
        // Blend scores: Heuristic Score + AI Boost
        return questsWithScores.map((q, index) => {
          const aiData = aiBoosts.find(item => item.id === index);
          const boost = aiData && typeof aiData.boost === 'number' ? aiData.boost : 0;
          return {
            ...q,
            score: q.score + boost
          };
        });
      } else {
        throw new Error('LLM did not return a valid JSON array.');
      }
    } catch (error) {
      console.error('LLM enhancement failed:', error);
      // Fallback to original scores
      return questsWithScores;
    }
  }

  async function generateRoadmapSteps(questTitle, questDescription) {
    const available = await isAiAvailable();
    if (!available) {
      console.log('LLM not available for roadmap generation.');
      return null;
    }

    try {
      const prompt = `
You are an expert task planner. Your goal is to break down a main task into 3 to 6 logical, actionable subtasks or milestones.
Main Task: "${questTitle}"
Description: "${questDescription || 'No description provided.'}"

Please respond with a JSON array of strings, where each string is a clear, concise subtask.
For example, for a marathon, it might be: ["Run 5 mins", "Run 15 mins", "Finish a 5k", "Finish a 10k", "Finish a half marathon"]

Output only valid JSON, nothing else.`;

      const session = await window.ai.createTextSession();
      const response = await session.prompt(prompt);
      session.destroy();

      const jsonStart = response.indexOf('[');
      const jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart !== -1 && jsonEnd !== -1) {
        const jsonStr = response.slice(jsonStart, jsonEnd);
        const steps = JSON.parse(jsonStr);
        return Array.isArray(steps) ? steps : null;
      }
      return null;
    } catch (error) {
      console.error('LLM roadmap generation failed:', error);
      return null;
    }
  }

  return {
    enhanceAchievableScoring,
    generateRoadmapSteps
  };
})();
