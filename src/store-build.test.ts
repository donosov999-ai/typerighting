import { describe, it, expect, vi, afterEach } from 'vitest';
import { isStoreTag } from './store-build';
import { platformTag } from './session-log';

afterEach(() => { vi.unstubAllGlobals(); });

describe('isStoreTag', () => {
  it('телефон и планшет в оболочке приложения — магазинная сборка', () => {
    for (const tag of ['app-android', 'app-ios', 'dev-app-android', 'dev-app-ios']) expect(isStoreTag(tag)).toBe(true);
  });
  it('десктоп и веб — соцфункции остаются', () => {
    for (const tag of ['app-win', 'app-mac', 'app-linux', 'web-android', 'web-ios', 'web-mac', 'dev-web-win']) expect(isStoreTag(tag)).toBe(false);
  });
});

describe('platformTag в оболочке приложения', () => {
  const shell = (userAgent: string, maxTouchPoints: number) => {
    vi.stubGlobal('window', { __TAURI_INTERNALS__: {} });
    vi.stubGlobal('navigator', { userAgent, maxTouchPoints });
    return platformTag().replace(/^dev-/, '');
  };
  it('iPad по умолчанию шлёт настольный UA «Macintosh» — отличаем по касаниям', () => {
    expect(shell('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)', 5)).toBe('app-ios');
  });
  it('Mac без касаний остаётся десктопом', () => {
    expect(shell('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)', 0)).toBe('app-mac');
  });
  it('iPhone и Android', () => {
    expect(shell('Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148', 5)).toBe('app-ios');
    expect(shell('Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0 Mobile Safari/537.36', 5)).toBe('app-android');
  });
});
