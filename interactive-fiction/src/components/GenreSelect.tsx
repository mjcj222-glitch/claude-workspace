import { useState } from 'react';
import type { Genre, Language } from '../types';
import { GENRE_META } from '../types';

interface Props {
  onStart: (genre: Genre, language: Language) => void;
}

export default function GenreSelect({ onStart }: Props) {
  const [selected, setSelected] = useState<Genre | null>(null);
  const [lang, setLang] = useState<Language>('ko');

  const genres: Genre[] = ['horror', 'fantasy', 'romance', 'thriller'];

  const genreColors: Record<Genre, string> = {
    horror:   'border-purple-700/60 hover:border-purple-400 hover:bg-purple-900/30 hover:shadow-purple-900/50',
    fantasy:  'border-blue-700/60 hover:border-blue-400 hover:bg-blue-900/30 hover:shadow-blue-900/50',
    romance:  'border-rose-700/60 hover:border-rose-400 hover:bg-rose-900/30 hover:shadow-rose-900/50',
    thriller: 'border-red-700/60 hover:border-red-400 hover:bg-red-900/30 hover:shadow-red-900/50',
  };

  const selectedColors: Record<Genre, string> = {
    horror:   'border-purple-400 bg-purple-900/40 shadow-purple-900/60',
    fantasy:  'border-blue-400 bg-blue-900/40 shadow-blue-900/60',
    romance:  'border-rose-400 bg-rose-900/40 shadow-rose-900/60',
    thriller: 'border-red-400 bg-red-900/40 shadow-red-900/60',
  };

  const emojiAnim: Record<Genre, string> = {
    horror:   'group-hover:scale-110 group-hover:animate-pulse',
    fantasy:  'group-hover:scale-110 group-hover:rotate-12',
    romance:  'group-hover:scale-110',
    thriller: 'group-hover:scale-110 group-hover:-rotate-6',
  };

  return (
    <div className="min-h-screen bg-[#0a0a0f] flex flex-col items-center justify-center px-4 py-12 relative overflow-hidden">
      {/* Atmospheric background */}
      <div className="absolute inset-0 bg-gradient-radial from-gray-900/20 via-transparent to-transparent pointer-events-none" />
      <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />

      {/* Title */}
      <div className="text-center mb-12 scene-enter">
        <p className="text-white/30 text-sm tracking-[0.3em] uppercase mb-3 font-mono">
          Interactive Fiction
        </p>
        <h1 className="text-4xl md:text-6xl font-bold text-white mb-2 tracking-tight">
          이야기의 선택
        </h1>
        <p className="text-white/40 text-lg mt-3">
          당신의 선택이 이야기를 만든다
        </p>
      </div>

      {/* Language Toggle */}
      <div className="flex items-center gap-1 mb-10 bg-white/5 rounded-full p-1 border border-white/10 scene-enter">
        {(['ko', 'en'] as Language[]).map((l) => (
          <button
            key={l}
            onClick={() => setLang(l)}
            className={`px-5 py-1.5 rounded-full text-sm font-medium transition-all duration-200 ${
              lang === l
                ? 'bg-white text-black'
                : 'text-white/50 hover:text-white/80'
            }`}
          >
            {l === 'ko' ? '한국어' : 'English'}
          </button>
        ))}
      </div>

      {/* Genre Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 max-w-3xl w-full mb-10 scene-enter">
        {genres.map((genre) => {
          const meta = GENRE_META[genre];
          const isSelected = selected === genre;
          return (
            <button
              key={genre}
              onClick={() => setSelected(genre)}
              className={`group relative flex flex-col items-center gap-3 p-6 rounded-2xl border-2 transition-all duration-300 shadow-lg
                ${isSelected ? selectedColors[genre] : `border-white/10 bg-white/3 ${genreColors[genre]}`}
              `}
            >
              {isSelected && (
                <div className="absolute top-2 right-2 w-5 h-5 rounded-full bg-white/90 flex items-center justify-center">
                  <svg className="w-3 h-3 text-black" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </div>
              )}
              <span className={`text-4xl transition-transform duration-300 ${emojiAnim[genre]}`}>
                {meta.emoji}
              </span>
              <div className="text-center">
                <p className="text-white font-semibold text-lg">
                  {lang === 'ko' ? meta.labelKo : meta.labelEn}
                </p>
                <p className="text-white/40 text-xs mt-1 leading-relaxed">
                  {meta.desc}
                </p>
              </div>
            </button>
          );
        })}
      </div>

      {/* Start Button */}
      <button
        onClick={() => selected && onStart(selected, lang)}
        disabled={!selected}
        className={`relative px-10 py-4 rounded-full text-lg font-semibold transition-all duration-300 overflow-hidden
          ${selected
            ? 'bg-white text-black hover:bg-white/90 hover:scale-105 hover:shadow-2xl shadow-white/20 cursor-pointer'
            : 'bg-white/10 text-white/30 cursor-not-allowed'
          }
        `}
      >
        {selected ? (
          <>
            <span className="relative z-10">
              {lang === 'ko' ? '이야기 시작하기' : 'Begin the Story'} →
            </span>
          </>
        ) : (
          <span>{lang === 'ko' ? '장르를 선택하세요' : 'Choose a genre'}</span>
        )}
      </button>

      <p className="text-white/20 text-xs mt-6 font-mono">
        Powered by Claude AI + Pollinations
      </p>
    </div>
  );
}
