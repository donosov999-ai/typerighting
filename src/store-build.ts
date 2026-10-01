// typefree-store-build · VER 1 · 01.10.2026 — магазинные сборки (App Store, Google Play) без соцфункций.
// Скрыты для всех: публикация результата и рейтинг с ником, недельная лига, вызовы, «Поделиться»,
// публичный сертификат с именем. Причина: правила для семей Google Play (детская аудитория, решение 25.09)
// и анкета возраста Apple (userGeneratedContent=false, socialMedia=false). Десктоп и веб не трогаем.
// Задача 37d215b4. Платформу определяет platformTag() — тот же признак, что пишется в tr_sessions.
import { platformTag } from './session-log';

/** Оболочка приложения на телефоне или планшете — то, что ставится из магазинов. */
export const isStoreTag = (tag: string): boolean => /^(dev-)?app-(android|ios)$/.test(tag);

export const STORE_APP = isStoreTag(platformTag());
