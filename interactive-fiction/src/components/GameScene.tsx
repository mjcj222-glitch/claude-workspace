import type { Atmosphere, Choice, SceneData } from '../types';
import { ATMOSPHERE_THEME } from '../types';
import SceneImage from './SceneImage';

interface Props {
  round: number;
  scene: SceneData;
  onChoice: (choice: Choice) => void;
  loading: boolean;
  worldTitle: string;
}

export default function GameScene({ round, scene, onChoice, loading, worldTitle }: Props) {
  const theme = ATMOSPHERE_THEME[scene.atmosphere as Atmosphere] ?? ATMOSPHERE_THEME.ominous;

  return (
    <div className={`min-h-screen bg-gradient-to-b ${theme.bg} flex flex-col relative`}>
      {/* Subtle vignette */}
      <div className="absolute inset-0 bg-radial-[ellipse_at_top] from-transparent via-transparent to-black/60 pointer-events-none" />

      {/* Top bar */}
      <div className="relative z-10 flex items-center justify-between px-6 py-4 border-b border-white/10">
        <div className="flex items-center gap-2">
          <span className="text-white/40 text-xs font-mono tracking-widest uppercase">
            {worldTitle}
          </span>
        </div>
        <RoundIndicator current={round} total={5} />
        <div className="w-24 text-right">
          <span className={`text-xs font-mono uppercase tracking-wider px-2 py-1 rounded border ${theme.accent}`}>
            {scene.atmosphere}
          </span>
        </div>
      </div>

      {/* Scene image */}
      <div className="relative">
        <SceneImage
          prompt={scene.imagePrompt}
          alt={`Round ${round} scene`}
          className="w-full h-56 md:h-72 lg:h-80"
        />
      </div>

      {/* Scene content */}
      <div className="relative z-10 flex-1 flex flex-col max-w-2xl mx-auto w-full px-6 py-8 scene-enter">
        {/* Round label */}
        <p className="text-white/30 text-xs font-mono tracking-[0.25em] uppercase mb-4">
          Round {round} / 5
        </p>

        {/* Scene text */}
        <div className={`relative mb-8 p-6 rounded-2xl border ${theme.border} bg-black/40 backdrop-blur-sm`}>
          <div className={`absolute left-0 top-0 bottom-0 w-0.5 rounded-full ${theme.border} opacity-80`} />
          <p className={`text-lg leading-relaxed ${theme.text} pl-2`}>
            {scene.scene}
          </p>
        </div>

        {/* Choices */}
        <div className="space-y-3">
          <p className="text-white/30 text-xs font-mono tracking-widest uppercase mb-4">
            선택하세요
          </p>
          {scene.choices.map((choice) => (
            <button
              key={choice.id}
              onClick={() => !loading && onChoice(choice)}
              disabled={loading}
              className={`choice-hover w-full flex items-start gap-4 p-4 rounded-xl border text-left
                transition-all duration-200 group
                ${theme.accent}
                ${loading ? 'opacity-40 cursor-not-allowed' : 'hover:bg-white/10 hover:border-white/30 cursor-pointer'}
              `}
            >
              <span className={`flex-shrink-0 w-8 h-8 rounded-lg flex items-center justify-center
                font-bold text-sm border border-current bg-black/30 group-hover:bg-white/10
                transition-colors duration-200`}>
                {choice.id}
              </span>
              <span className="pt-1 text-sm md:text-base leading-relaxed">{choice.text}</span>
            </button>
          ))}
        </div>
      </div>

      {loading && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="text-center">
            <div className="w-10 h-10 border-2 border-white/20 border-t-white rounded-full animate-spin mx-auto mb-4" />
            <p className="text-white/60 font-mono text-sm">이야기를 엮는 중...</p>
          </div>
        </div>
      )}
    </div>
  );
}

function RoundIndicator({ current, total }: { current: number; total: number }) {
  return (
    <div className="flex items-center gap-1.5">
      {Array.from({ length: total }, (_, i) => (
        <div
          key={i}
          className={`h-1.5 rounded-full transition-all duration-500 ${
            i < current
              ? 'bg-white w-4'
              : i === current - 1
              ? 'bg-white/80 w-4'
              : 'bg-white/20 w-2'
          }`}
        />
      ))}
    </div>
  );
}
