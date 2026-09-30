/* typerighting-updater · VER 4 · 30.09.2026 */
// Авто-апдейтер (только нативное приложение Tauri, не веб/PWA).
// При старте тихо проверяет релиз; если есть новее — предлагает скачать и перезапуститься.
// Подпись апдейтов проверяется по pubkey из tauri.conf.json (ключ в GH secret TAURI_SIGNING_PRIVATE_KEY).
import { t } from './i18n';

export async function checkForUpdate(): Promise<void> {
  // В браузере/PWA плагина нет — выходим молча
  if (!('__TAURI_INTERNALS__' in window)) return;
  try {
    const { check } = await import('@tauri-apps/plugin-updater');
    const update = await check();
    if (!update?.available) return;

    // До 30.09.2026 это окно было по-русски для всех семи языков: строк не было в словаре,
    // поэтому и тест на пары «кириллица : латиница» их не видел — английской ветки не существовало.
    const notes = update.body ? `\n\n${t('upd.notes')}\n${update.body}` : '';
    const ok = window.confirm(
      `${t('upd.available').replace('{ver}', update.version)}${notes}\n\n${t('upd.confirm')}`
    );
    if (!ok) return;

    await update.downloadAndInstall();
    const { relaunch } = await import('@tauri-apps/plugin-process');
    await relaunch();
  } catch {
    // офлайн, нет релиза или сеть недоступна — тихо игнорируем
  }
}
