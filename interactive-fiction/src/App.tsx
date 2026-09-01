import { useState } from 'react';
import EndingScreen from './components/EndingScreen';
import GameScene from './components/GameScene';
import GenreSelect from './components/GenreSelect';
import { generateEnding, generateScene, generateWorld } from './lib/claude';
import type { Choice, EndingData, GamePhase, Genre, Language, SceneData, StoryEntry, WorldData } from './types';

export default function App() {
  const [phase, setPhase] = useState<GamePhase>('genre-select');
  const [genre, setGenre] = useState<Genre>('horror');
  const [language, setLanguage] = useState<Language>('ko');
  const [world, setWorld] = useState<WorldData | null>(null);
  const [currentRound, setCurrentRound] = useState(1);
  const [storyHistory, setStoryHistory] = useState<StoryEntry[]>([]);
  const [currentScene, setCurrentScene] = useState<SceneData | null>(null);
  const [ending, setEnding] = useState<EndingData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleStart = async (g: Genre, lang: Language) => {
    setGenre(g);
    setLanguage(lang);
    setPhase('loading');
    setLoading(true);
    setError(null);

    try {
      const worldData = await generateWorld(g, lang);
      setWorld(worldData);

      const worldDesc = `${worldData.title}: ${worldData.setting} ${worldData.protagonist}`;
      const firstScene = await generateScene(1, g, lang, worldDesc, []);
      setCurrentScene(firstScene);
      setCurrentRound(1);
      setStoryHistory([]);
      setPhase('playing');
    } catch (e) {
      setError(e instanceof Error ? e.message : '오류가 발생했습니다. API 키를 확인해주세요.');
      setPhase('genre-select');
    } finally {
      setLoading(false);
    }
  };

  const handleChoice = async (choice: Choice) => {
    if (!currentScene || !world || loading) return;

    setLoading(true);
    setError(null);

    const entry: StoryEntry = {
      round: currentRound,
      scene: currentScene.scene,
      choice: `${choice.id}: ${choice.text}`,
      atmosphere: currentScene.atmosphere,
    };

    const newHistory = [...storyHistory, entry];
    setStoryHistory(newHistory);

    const worldDesc = `${world.title}: ${world.setting} ${world.protagonist}`;

    try {
      if (currentRound >= 4) {
        // Generate ending (round 5)
        const endingData = await generateEnding(genre, language, worldDesc, newHistory);
        setEnding(endingData);
        setPhase('ending');
      } else {
        const nextRound = currentRound + 1;
        const nextScene = await generateScene(nextRound, genre, language, worldDesc, newHistory);
        setCurrentScene(nextScene);
        setCurrentRound(nextRound);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : '오류가 발생했습니다.');
    } finally {
      setLoading(false);
    }
  };

  const handleRestart = () => {
    setPhase('genre-select');
    setWorld(null);
    setCurrentRound(1);
    setStoryHistory([]);
    setCurrentScene(null);
    setEnding(null);
    setError(null);
  };

  if (phase === 'genre-select' || phase === 'loading') {
    return (
      <>
        <GenreSelect onStart={handleStart} />
        {phase === 'loading' && (
          <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50">
            <div className="text-center px-6">
              <div className="w-12 h-12 border-2 border-white/20 border-t-white rounded-full animate-spin mx-auto mb-5" />
              <p className="text-white text-lg font-light mb-2">
                {language === 'ko' ? '세계를 창조하는 중...' : 'Creating your world...'}
              </p>
              <p className="text-white/40 text-sm font-mono">Claude AI가 이야기를 구성하고 있습니다</p>
            </div>
          </div>
        )}
        {error && (
          <div className="fixed bottom-6 left-1/2 -translate-x-1/2 bg-red-900/90 border border-red-500/50 text-red-200 px-6 py-3 rounded-xl text-sm max-w-sm text-center z-50">
            {error}
          </div>
        )}
      </>
    );
  }

  if (phase === 'playing' && currentScene && world) {
    return (
      <>
        <GameScene
          round={currentRound}
          scene={currentScene}
          onChoice={handleChoice}
          loading={loading}
          worldTitle={world.title}
        />
        {error && (
          <div className="fixed bottom-6 left-1/2 -translate-x-1/2 bg-red-900/90 border border-red-500/50 text-red-200 px-6 py-3 rounded-xl text-sm max-w-sm text-center z-50">
            {error}
          </div>
        )}
      </>
    );
  }

  if (phase === 'ending' && ending) {
    return (
      <EndingScreen
        ending={ending}
        genre={genre}
        language={language}
        onRestart={handleRestart}
      />
    );
  }

  return null;
}
