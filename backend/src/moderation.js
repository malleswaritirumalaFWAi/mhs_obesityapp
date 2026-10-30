/**
 * Content moderation for community posts and chat messages.
 *
 * Three-layer approach:
 * 1. Local profanity / PII filter (instant, no API call)
 * 2. Relevance keyword check (fast heuristic)
 * 3. Optional AI moderation via Anthropic (for borderline cases)
 */

// ── Profanity word list (common English profanity + slurs) ──
const PROFANITY = new Set([
  'fuck','shit','bitch','asshole','bastard','dick','pussy','cunt',
  'nigger','nigga','faggot','retard','whore','slut','damn','crap',
  'motherfucker','bullshit','jackass','dumbass','wtf','stfu','lmao',
  'stupid','idiot','idiots','moron','morons','dumb','loser','losers',
  'shut up','shutup','suck','sucks','screw','screwed','piss','pissed',
  'arse','twat','wanker','bloody','bollock','bugger',
]);

// ── PII patterns ──
const PHONE_REGEX = /(?:\+?\d{1,3}[\s.-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,5}[\s.-]?\d{3,5}/g;
const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;

// ── Relevance keywords (weight-loss / wellness context) ──
const RELEVANT_KEYWORDS = new Set([
  'weight','diet','food','meal','calories','protein','carbs','fat','fiber',
  'breakfast','lunch','dinner','snack','fasting','intermittent','keto','paleo',
  'exercise','workout','walk','run','steps','gym','yoga','cardio','strength',
  'water','hydration','sleep','rest','stress','mood','energy','motivation',
  'progress','goal','target','loss','gain','bmi','scale','weigh',
  'coach','check-in','checkin','challenge','streak','xp','badge',
  'healthy','health','wellness','fitness','habit','routine','discipline',
  'sugar','salt','oil','vegetable','fruit','salad','rice','roti','dal',
  'congrats','congratulations','well done','keep going','proud','amazing',
  'great','good job','support','help','advice','tip','recipe','ingredient',
  'doctor','medicine','diabetes','bp','blood pressure','thyroid','pcos',
  'hi','hello','hey','good morning','good evening','good night','thanks','thank you',
]);

/**
 * Moderate a piece of text content.
 * @param {string} text - The content to check
 * @param {object} [options] - { useAI: false }
 * @returns {{ allowed: boolean, reason?: string }}
 */
export function moderateContent(text, options = {}) {
  if (!text || !text.trim()) return { allowed: false, reason: 'Content cannot be empty.' };

  const lower = text.toLowerCase().trim();
  const words = lower.replace(/[^a-z0-9\s]/g, ' ').split(/\s+/);

  // 1. Profanity check
  for (const word of words) {
    if (PROFANITY.has(word)) {
      return { allowed: false, reason: 'Your message contains inappropriate language. Please rephrase and try again.' };
    }
  }

  // Check for leet-speak / obfuscated profanity (common patterns)
  const deobfuscated = lower
    .replace(/0/g, 'o').replace(/1/g, 'i').replace(/3/g, 'e')
    .replace(/4/g, 'a').replace(/5/g, 's').replace(/@/g, 'a')
    .replace(/\$/g, 's').replace(/!/g, 'i');
  const deobWords = deobfuscated.replace(/[^a-z\s]/g, ' ').split(/\s+/);
  for (const word of deobWords) {
    if (PROFANITY.has(word) && word.length > 3) {
      return { allowed: false, reason: 'Your message contains inappropriate language. Please rephrase and try again.' };
    }
  }

  // 2. PII check — phone numbers and emails
  if (PHONE_REGEX.test(text)) {
    PHONE_REGEX.lastIndex = 0; // reset regex state
    return { allowed: false, reason: 'Please don\'t share phone numbers publicly. You can message your coach privately.' };
  }
  if (EMAIL_REGEX.test(text)) {
    return { allowed: false, reason: 'Please don\'t share email addresses publicly for your privacy.' };
  }

  // 3. Relevance check (only for posts longer than a greeting)
  if (words.length > 5) {
    let relevantCount = 0;
    for (const word of words) {
      if (RELEVANT_KEYWORDS.has(word)) relevantCount++;
    }
    // Also check 2-word phrases
    for (let i = 0; i < words.length - 1; i++) {
      const phrase = words[i] + ' ' + words[i + 1];
      if (RELEVANT_KEYWORDS.has(phrase)) relevantCount++;
    }
    // If less than ~15% of words are relevant and it's a substantial message
    const relevanceRatio = relevantCount / words.length;
    if (words.length > 8 && relevanceRatio < 0.15) {
      return { allowed: false, reason: 'This community is focused on health, diet, and fitness. Please share content related to your wellness journey.' };
    }
  }

  return { allowed: true };
}

/**
 * AI-powered moderation for chat messages (fast, ~1-2s).
 * Uses Anthropic with a short system prompt. Falls back to local filter on failure.
 */
export async function moderateWithAI(text) {
  // First run local filter
  const local = moderateContent(text);
  if (!local.allowed) return local;

  // If no API key, local filter is sufficient
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) return local;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2000); // 2s max

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: process.env.MODERATION_MODEL || 'claude-haiku-4-5-20251001',
        max_tokens: 100,
        system: `You are a content moderator for a weight-loss community chat. Respond ONLY with JSON: {"allowed":true} or {"allowed":false,"reason":"brief explanation"}.
Block: profanity, hate speech, harassment, sexually explicit content, spam, clearly off-topic content unrelated to health/diet/fitness/wellness.
Allow: greetings, encouragement, progress updates, diet/exercise discussion, questions, casual friendly chat related to the program.`,
        messages: [{ role: 'user', content: `Check this message: "${text}"` }],
      }),
      signal: controller.signal,
    });

    clearTimeout(timeout);

    if (!resp.ok) return { allowed: true }; // fail-open on API error

    const data = await resp.json();
    const reply = data.content?.[0]?.text || '';
    const parsed = JSON.parse(reply);
    return { allowed: !!parsed.allowed, reason: parsed.reason };
  } catch {
    // Timeout or parse error — fail open (allow message, rely on local filter)
    return { allowed: true };
  }
}
