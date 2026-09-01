import { useState } from 'react';
import type { EndingData, Genre, Language } from '../types';
import { ATMOSPHERE_THEME, GENRE_META } from '../types';
import SceneImage from './SceneImage';

interface Props {
  ending: EndingData;
  genre: Genre;
  language: Language;
  onRestart: () => void;
}

export default function EndingScreen({ ending, genre, language, onRestart }: Props) {
  const [copied, setCopied] = useState(false);
  const theme = ATMOSPHERE_THEME[ending.atmosphere] ?? ATMOSPHERE_THEME.ominous;
  const genreMeta = GENRE_META[genre];

  const gradeConfig = {
    S: { label: 'S', class: 'grade-s', desc: language === 'ko' ? '전설적인 결말' : 'Legendary Ending' },
    A: { label: 'A', class: 'grade-a', desc: language === 'ko' ? '인상적인 결말' : 'Impressive Ending' },
    B: { label: 'B', class: 'grade-b', desc: language === 'ko' ? '흥미로운 결말' : 'Interesting Ending' },
    C: { label: 'C', class: 'grade-c', desc: language === 'ko' ? '평범한 결말' : 'Common Ending' },
  };

  const grade = gradeConfig[ending.endingGrade] ?? gradeConfig.B;
  const genreLabel = language === 'ko' ? genreMeta.labelKo : genreMeta.labelEn;

  const shareText = `[이야기의 선택] ${genreLabel} - "${ending.endingType}" 엔딩 달성!\n등급: ${ending.endingGrade} | ${ending.epilogue}`;

  const handleShare = async () => {
    try {
      await navigator.clipboard.writeText(shareText);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    } catch {
      // fallback
      const el = document.createElement('textarea');
      el.value = shareText;
      document.body.appendChild(el);
      el.select();
      document.execCommand('copy');
      document.body.removeChild(el);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    }
  };

  return (
    <div className={`min-h-screen bg-gradient-to-b ${theme.bg} flex flex-col relative overflow-hidden`}>
      {/* Background glow */}
      <div className="absolute inset-0 pointer-events-none">
        <div className={`absolute inset-0 opacity-10 bg-gradient-radial from-white/5 via-transparent to-transparent`} />
      </div>

      {/* Scene image - full width */}
      <div className="relative">
        <SceneImage
          prompt={ending.imagePrompt}
          alt="Ending scene"
          className="w-full h-64 md:h-96"
        />
        {/* Ending overlay text */}
        <div className="absolute inset-0 flex flex-col items-center justify-end pb-6 px-4">
          <div className="text-center">
            <p className="text-white/50 text-xs font-mono tracking-[0.4em] uppercase mb-2 animate-pulse">
              {language === 'ko' ? '— 이야기의 끝 —' : '— The End —'}
            </p>
          </div>
        </div>
      </div>

      {/* Main content */}
      <div className="relative z-10 flex-1 max-w-2xl mx-auto w-full px-6 py-8 scene-enter">

        {/* Grade + Ending type */}
        <div className="flex items-start gap-6 mb-8">
          <div className="flex-shrink-0 text-center">
            <div className={`text-7xl font-black leading-none ${grade.class}`}>
              {grade.label}
            </div>
            <p className="text-white/30 text-xs mt-1">{grade.desc}</p>
          </div>
          <div className="flex-1 pt-2">
            <p className="text-white/40 text-xs font-mono tracking-widest uppercase mb-1">
              {language === 'ko' ? '엔딩 타입' : 'Ending Type'}
            </p>
            <h2 className={`text-2xl md:text-3xl font-bold ${theme.text} leading-tight`}>
              "{ending.endingType}"
            </h2>
          </div>
        </div>

        {/* Scene text */}
        <div className={`mb-6 p-6 rounded-2xl border ${theme.border} bg-black/40 backdrop-blur-sm`}>
          <p className={`text-base md:text-lg leading-relaxed ${theme.text}`}>
            {ending.scene}
          </p>
        </div>

        {/* Epilogue */}
        <div className="mb-8 text-center">
          <div className="inline-block relative">
            <div className="absolute left-0 top-1/2 -translate-y-1/2 w-8 h-px bg-white/20" />
            <div className="absolute right-0 top-1/2 -translate-y-1/2 w-8 h-px bg-white/20" />
            <p className={`text-sm md:text-base italic px-10 ${theme.text} opacity-80`}>
              "{ending.epilogue}"
            </p>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex flex-col sm:flex-row gap-3">
          <button
            onClick={handleShare}
            className={`flex-1 flex items-center justify-center gap-2 py-3.5 px-6 rounded-xl border text-sm font-medium transition-all duration-200
              ${theme.accent} hover:bg-white/15`}
          >
            {copied ? (
              <>
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
                {language === 'ko' ? '복사됨!' : 'Copied!'}
              </>
            ) : (
              <>
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" />
                </svg>
                {language === 'ko' ? '결과 공유하기' : 'Share Result'}
              </>
            )}
          </button>

          <button
            onClick={onRestart}
            className="flex-1 flex items-center justify-center gap-2 py-3.5 px-6 rounded-xl bg-white text-black text-sm font-semibold hover:bg-white/90 transition-all duration-200 hover:scale-[1.02]"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            {language === 'ko' ? '다시 플레이' : 'Play Again'}
          </button>
        </div>

        {/* Share preview */}
        {copied && (
          <div className="mt-4 p-3 rounded-lg bg-white/5 border border-white/10">
            <p className="text-white/40 text-xs font-mono leading-relaxed">{shareText}</p>
          </div>
        )}
      </div>
    </div>
  );
}
