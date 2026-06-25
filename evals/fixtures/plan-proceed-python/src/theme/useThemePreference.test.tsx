import { renderHook, act } from '@testing-library/react';
import { useThemePreference } from './useThemePreference';
import { ThemeContext } from './ThemeContext';
import { usePersistentPref } from '../prefs/usePersistentPref';

jest.mock('../prefs/usePersistentPref');
const mockSetTheme = jest.fn();

function wrapper({ children }: { children: React.ReactNode }) {
  return (
    <ThemeContext.Provider value={{ theme: 'light', setTheme: mockSetTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('useThemePreference', () => {
  it('first visit follows OS preference — GIVEN no stored pref AND OS prefers dark WHEN hook mounts THEN theme is dark', () => {
    Object.defineProperty(window, 'matchMedia', {
      writable: true,
      value: jest.fn().mockReturnValue({ matches: true }),
    });
    (usePersistentPref as jest.Mock).mockReturnValue(['dark', jest.fn()]);

    renderHook(() => useThemePreference(), { wrapper });

    expect(mockSetTheme).toHaveBeenCalledWith('dark');
  });

  it('stored pref wins over OS — GIVEN stored light pref AND OS prefers dark WHEN hook mounts THEN theme is light', () => {
    Object.defineProperty(window, 'matchMedia', {
      writable: true,
      value: jest.fn().mockReturnValue({ matches: true }),
    });
    (usePersistentPref as jest.Mock).mockReturnValue(['light', jest.fn()]);

    renderHook(() => useThemePreference(), { wrapper });

    expect(mockSetTheme).toHaveBeenCalledWith('light');
  });

  it('setting persists — WHEN consumer sets dark THEN pref is written via usePersistentPref', () => {
    Object.defineProperty(window, 'matchMedia', {
      writable: true,
      value: jest.fn().mockReturnValue({ matches: false }),
    });
    const mockSetPersisted = jest.fn();
    (usePersistentPref as jest.Mock).mockReturnValue(['light', mockSetPersisted]);

    const { result } = renderHook(() => useThemePreference(), { wrapper });

    act(() => {
      result.current[1]('dark');
    });

    expect(mockSetPersisted).toHaveBeenCalledWith('dark');
  });
});
