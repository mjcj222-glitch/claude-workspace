import { useState } from 'react';

interface Props {
  prompt: string;
  alt?: string;
  className?: string;
}

export default function SceneImage({ prompt, alt = 'scene', className = '' }: Props) {
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(false);

  const encoded = encodeURIComponent(prompt);
  const src = `https://image.pollinations.ai/prompt/${encoded}?width=768&height=432&nologo=true&seed=${Math.abs(prompt.split('').reduce((a, c) => a + c.charCodeAt(0), 0))}`;

  return (
    <div className={`relative overflow-hidden ${className}`}>
      {!loaded && !error && (
        <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
          <div className="flex flex-col items-center gap-3">
            <div className="w-8 h-8 border-2 border-white/20 border-t-white/80 rounded-full animate-spin" />
            <p className="text-white/40 text-sm">이미지 생성 중...</p>
          </div>
          <div className="absolute inset-0 loading-shimmer" />
        </div>
      )}
      {error && (
        <div className="absolute inset-0 bg-black/80 flex items-center justify-center">
          <p className="text-white/30 text-sm">이미지를 불러올 수 없습니다</p>
        </div>
      )}
      <img
        src={src}
        alt={alt}
        onLoad={() => setLoaded(true)}
        onError={() => setError(true)}
        className={`w-full h-full object-cover transition-opacity duration-700 ${loaded ? 'opacity-100' : 'opacity-0'}`}
      />
      <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-black/20 pointer-events-none" />
    </div>
  );
}
