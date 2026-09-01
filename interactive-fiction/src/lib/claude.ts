import Groq from 'groq-sdk';
import type { EndingData, Genre, Language, SceneData, StoryEntry, WorldData } from '../types';

const groq = new Groq({
  apiKey: import.meta.env.VITE_GROQ_API_KEY || '',
  dangerouslyAllowBrowser: true,
});

const MODEL = 'llama-3.3-70b-versatile';

const GENRE_LABEL: Record<Genre, Record<Language, string>> = {
  horror:   { ko: '공포',   en: 'Horror'   },
  fantasy:  { ko: '판타지', en: 'Fantasy'  },
  romance:  { ko: '로맨스', en: 'Romance'  },
  thriller: { ko: '스릴러', en: 'Thriller' },
};

function parseJSON<T>(raw: string): T {
  const stripped = raw
    .replace(/^```(?:json)?\s*/m, '')
    .replace(/```\s*$/m, '')
    .trim();
  return JSON.parse(stripped) as T;
}

async function callGroq(systemPrompt: string, userPrompt: string): Promise<string> {
  const completion = await groq.chat.completions.create({
    model: MODEL,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ],
    temperature: 1.0,
  });
  return completion.choices[0]?.message?.content ?? '';
}

export async function generateWorld(genre: Genre, language: Language): Promise<WorldData> {
  const genreName = GENRE_LABEL[genre][language];
  const langLabel = language === 'ko' ? '한국어' : 'English';

  const text = await callGroq(
    `You are a creative story world generator. Always respond with valid JSON only, no markdown.`,
    `Generate a unique story world for a ${genreName} interactive fiction game in ${langLabel}.

OUTPUT FORMAT (strict JSON, no markdown):
{
  "title": "세계관 제목",
  "setting": "배경 설명 (2-3문장)",
  "protagonist": "주인공 설정 (1문장)",
  "hook": "첫 장면 도입부 (2문장, 긴장감 있게)"
}`,
  );

  return parseJSON<WorldData>(text);
}

export async function generateScene(
  round: number,
  genre: Genre,
  language: Language,
  worldSetting: string,
  storyHistory: StoryEntry[],
): Promise<SceneData> {
  const genreName = GENRE_LABEL[genre][language];
  const langLabel = language === 'ko' ? '한국어' : 'English';

  const system = `You are a master storyteller running an interactive fiction game.

SETTINGS:
- Genre: ${genreName}
- Language: ${langLabel} (한국어 or English)

STORYTELLING RULES:
- You have full narrative control — subvert player expectations freely
- Round 1-2: Plant subtle foreshadowing (invisible to most players)
- Round 3-4: You MAY use the player's choice pattern against them
- Round 5: Deliver a satisfying or shocking ending — your call
- Never repeat similar scene structures two rounds in a row
- Keep each scene vivid but concise (3-4 sentences)

Always respond with valid JSON only, no markdown.

OUTPUT FORMAT:
{
  "scene": "장면 묘사",
  "atmosphere": "one word: eerie | tense | hopeful | ominous | warm",
  "imagePrompt": "cinematic scene, ${genreName} style, [scene description in English, 10 words max]",
  "choices": [
    { "id": "A", "text": "선택지 A" },
    { "id": "B", "text": "선택지 B" }
  ],
  "foreshadowing": "[INTERNAL] hint planted this round"
}`;

  const historyText = storyHistory.length > 0
    ? storyHistory.map(e => `Round ${e.round}: ${e.scene}\nPlayer chose: ${e.choice}`).join('\n\n')
    : 'This is the beginning of the story.';

  const choiceHistory = storyHistory.length > 0
    ? storyHistory.map(e => `Round ${e.round}: ${e.choice}`).join('\n')
    : 'None yet';

  const text = await callGroq(system, `Round ${round} of 5.
Genre: ${genreName}
World: ${worldSetting}

Story so far:
${historyText}

Player's choices so far:
${choiceHistory}

Generate the next scene and two choices.`);

  return parseJSON<SceneData>(text);
}

export async function generateEnding(
  genre: Genre,
  language: Language,
  worldSetting: string,
  storyHistory: StoryEntry[],
): Promise<EndingData> {
  const genreName = GENRE_LABEL[genre][language];
  const langLabel = language === 'ko' ? '한국어' : 'English';

  const historyText = storyHistory.map(e => `Round ${e.round}: ${e.scene}\nPlayer chose: ${e.choice}`).join('\n\n');
  const choiceHistory = storyHistory.map(e => `Round ${e.round}: ${e.choice}`).join('\n');

  const text = await callGroq(
    `You are a master storyteller. Genre: ${genreName}, Language: ${langLabel}. Always respond with valid JSON only, no markdown.`,
    `Round 5 of 5 — FINAL ROUND.
Genre: ${genreName}
World: ${worldSetting}

Full story:
${historyText}

Player's choices:
${choiceHistory}

Deliver the ending. OUTPUT FORMAT (strict JSON):
{
  "scene": "엔딩 장면 묘사 (4-5문장, 임팩트 있게)",
  "endingType": "엔딩 이름 (예: 'The Survivor' / '고독한 영웅' / 'Twisted Fate')",
  "endingGrade": "S or A or B or C",
  "epilogue": "한 줄 총평 (플레이어에게 보여줄 문장)",
  "imagePrompt": "cinematic final scene, ${genreName} style, [description in English, 10 words max]",
  "atmosphere": "one word: eerie | tense | hopeful | ominous | warm"
}`,
  );

  return parseJSON<EndingData>(text);
}
