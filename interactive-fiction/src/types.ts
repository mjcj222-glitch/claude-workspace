export type Genre = 'horror' | 'fantasy' | 'romance' | 'thriller';
export type Language = 'ko' | 'en';
export type Atmosphere = 'eerie' | 'tense' | 'hopeful' | 'ominous' | 'warm';
export type EndingGrade = 'S' | 'A' | 'B' | 'C';
export type GamePhase = 'genre-select' | 'loading' | 'playing' | 'ending';

export interface Choice {
  id: 'A' | 'B';
  text: string;
}

export interface SceneData {
  scene: string;
  atmosphere: Atmosphere;
  imagePrompt: string;
  choices: Choice[];
  foreshadowing?: string;
}

export interface EndingData {
  scene: string;
  endingType: string;
  endingGrade: EndingGrade;
  epilogue: string;
  imagePrompt: string;
  atmosphere: Atmosphere;
}

export interface WorldData {
  title: string;
  setting: string;
  protagonist: string;
  hook: string;
}

export interface StoryEntry {
  round: number;
  scene: string;
  choice: string;
  atmosphere: Atmosphere;
}

export const GENRE_META: Record<Genre, { labelKo: string; labelEn: string; emoji: string; desc: string }> = {
  horror: { labelKo: '공포', labelEn: 'Horror', emoji: '👁️', desc: '어둠 속에 숨은 공포' },
  fantasy: { labelKo: '판타지', labelEn: 'Fantasy', emoji: '⚔️', desc: '마법과 신화의 세계' },
  romance: { labelKo: '로맨스', labelEn: 'Romance', emoji: '🌹', desc: '운명적인 사랑 이야기' },
  thriller: { labelKo: '스릴러', labelEn: 'Thriller', emoji: '🔪', desc: '숨막히는 긴장과 반전' },
};

export const ATMOSPHERE_THEME: Record<Atmosphere, {
  bg: string;
  border: string;
  accent: string;
  glow: string;
  text: string;
}> = {
  eerie: {
    bg: 'from-purple-950 via-purple-900/50 to-black',
    border: 'border-purple-600/50',
    accent: 'bg-purple-600/20 text-purple-300 border-purple-500/40',
    glow: 'shadow-purple-900',
    text: 'text-purple-200',
  },
  tense: {
    bg: 'from-red-950 via-red-900/50 to-black',
    border: 'border-red-600/50',
    accent: 'bg-red-600/20 text-red-300 border-red-500/40',
    glow: 'shadow-red-900',
    text: 'text-red-100',
  },
  hopeful: {
    bg: 'from-teal-950 via-teal-900/50 to-black',
    border: 'border-teal-500/50',
    accent: 'bg-teal-600/20 text-teal-300 border-teal-500/40',
    glow: 'shadow-teal-900',
    text: 'text-teal-100',
  },
  ominous: {
    bg: 'from-gray-900 via-gray-800/50 to-black',
    border: 'border-gray-600/50',
    accent: 'bg-gray-700/30 text-gray-300 border-gray-500/40',
    glow: 'shadow-gray-900',
    text: 'text-gray-200',
  },
  warm: {
    bg: 'from-amber-950 via-amber-900/50 to-black',
    border: 'border-amber-500/50',
    accent: 'bg-amber-600/20 text-amber-300 border-amber-500/40',
    glow: 'shadow-amber-900',
    text: 'text-amber-100',
  },
};
