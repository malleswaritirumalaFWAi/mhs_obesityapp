/**
 * Run from backend folder:  node test-claude.js
 * This tests if the Anthropic API key works for both text AND vision.
 */
import dotenv from 'dotenv';
dotenv.config();

const key   = process.env.ANTHROPIC_API_KEY;
const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-6';

console.log('=== FitQuest Claude Diagnostic ===');
console.log('API Key  :', key ? key.slice(0, 24) + '...' : '❌ NOT SET');
console.log('Model    :', model);
console.log('');

if (!key) {
  console.error('❌ ANTHROPIC_API_KEY is missing in .env — add it and retry.');
  process.exit(1);
}


async function callClaude(body) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      'Authorization': `Bearer ${key}`,
    },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw Object.assign(new Error(data?.error?.message ?? res.statusText), { status: res.status });
  return data;
}

// --- Test 1: basic text message ---
console.log('Test 1 — text message...');
try {
  const msg = await callClaude({
    model,
    max_tokens: 20,
    messages: [{ role: 'user', content: 'Reply with just the word: OK' }],
  });
  console.log('✅ Text OK:', msg.content[0]?.text?.trim());
} catch (e) {
  console.error('❌ Text FAILED:', e.message, '| status:', e.status);
  process.exit(1);
}

// --- Test 2: vision using a URL image ---
console.log('\nTest 2 — vision (URL image of food)...');
try {
  const msg = await callClaude({
    model,
    max_tokens: 80,
    messages: [{
      role: 'user',
      content: [
        {
          type: 'image',
          source: {
            type: 'url',
            url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Biryani_at_Bawarchi.jpg/320px-Biryani_at_Bawarchi.jpg',
          },
        },
        { type: 'text', text: 'What food is in this image? One sentence.' },
      ],
    }],
  });
  console.log('✅ Vision OK:', msg.content[0]?.text?.trim());
} catch (e) {
  console.error('❌ Vision FAILED:', e.message, '| status:', e.status);
  process.exit(1);
}

console.log('\n✅ All tests passed — Claude is working correctly.');
console.log('   If meal analysis still shows mock data, restart the backend and try again.');
