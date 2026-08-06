// Авто-апдейтер (только нативное приложение Tauri, не веб/PWA).
// При старте тихо проверяет релиз; если есть новее — предлагает скачать и перезапуститься.
// Подпись апдейтов проверяется по pubkey из tauri.conf.json (ключ в GH secret TAURI_SIGNING_PRIVATE_KEY).

export async function checkForUpdate(): Promise<void> {
  // В браузере/PWA плагина нет — выходим молча
  if (!('__TAURI_INTERNALS__' in window)) return;
  try {
    const { check } = await import('@tauri-apps/plugin-updater');
    const update = await check();
    if (!update?.available) return;

    const notes = update.body ? `\n\nЧто нового:\n${update.body}` : '';
    const ok = window.confirm(
      `Доступна новая версия TypeRIGHT ${update.version}.${notes}\n\nОбновить сейчас?`
    );
    if (!ok) return;

    await update.downloadAndInstall();
    const { relaunch } = await import('@tauri-apps/plugin-process');
    await relaunch();
  } catch {
    // офлайн, нет релиза или сеть недоступна — тихо игнорируем
  }
}
