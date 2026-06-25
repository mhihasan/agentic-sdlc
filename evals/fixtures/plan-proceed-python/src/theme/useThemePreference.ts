import { useEffect } from 'react';
import { useContext } from 'react';
import { ThemeContext } from './ThemeContext';
import { usePersistentPref } from '../prefs/usePersistentPref';

export function useThemePreference() {
  const { setTheme } = useContext(ThemeContext);
  const osDefault = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  const [theme, setPersistedTheme] = usePersistentPref<'light' | 'dark'>('theme', osDefault);

  useEffect(() => {
    setTheme(theme);
  }, [theme, setTheme]);

  return [theme, setPersistedTheme] as const;
}
