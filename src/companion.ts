// Адаптивный компаньон — экран для телефона без физической клавиатуры.
// Слепой печати на телефоне не научиться (нет физ-клавиш), поэтому показываем то, что
// клавиатуры НЕ требует: прогресс, метод/обучение, соревнование, ачивки. Полный тренажёр —
// за кнопкой «всё равно открыть» ИЛИ включается сам при подключении BT-клавиатуры (детект в main.ts).
// Питомец и тест тач-скорости — следующий заход (в приложении маскота пока нет).
import { progressSVG, streakDays, hasKeyData } from './stats-store';
import { BADGES, unlockedSet } from './achievements';
import { t } from './i18n';

const esc = (s: string) =>
  s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c] as string));

export interface CompanionCbs {
  openTrainer: () => void;
  openLearn: () => void;
  openCompete: () => void;
}

export function companionEnter(app: HTMLElement, cb: CompanionCbs): void {
  const streak = streakDays(Date.now());
  const un = unlockedSet();
  const chart = hasKeyData() ? progressSVG() : '';
  app.innerHTML = `
    <div class="comp">
      <section class="comp-hero">
        <div class="comp-kbd" aria-hidden="true">⌨️</div>
        <h1>${esc(t('cpn.h1'))}</h1>
        <p class="comp-sub">${esc(t('cpn.sub'))}</p>
        <button id="comp-train" class="comp-cta">${esc(t('cpn.train'))}</button>
        <p class="comp-hint">${esc(t('cpn.hint'))}</p>
      </section>

      <div class="comp-grid">
        <button class="comp-card" id="comp-learn">
          <span class="comp-ic" aria-hidden="true">📖</span>
          <b>${esc(t('cpn.learn'))}</b><small>${esc(t('cpn.learnP'))}</small>
        </button>
        <button class="comp-card" id="comp-compete">
          <span class="comp-ic" aria-hidden="true">🏆</span>
          <b>${esc(t('cpn.compete'))}</b><small>${esc(t('cpn.compP'))}</small>
        </button>
      </div>

      ${chart ? `<section class="comp-panel"><h3>${esc(t('cpn.progress'))}${streak > 0 ? ` · 🔥 ${streak}` : ''}</h3><div class="comp-chart">${chart}</div></section>` : ''}

      <section class="comp-panel">
        <h3>${esc(t('ach.sub'))} — ${un.size}/${BADGES.length}</h3>
        <div class="comp-badges">${BADGES.map(
          (b) => `<span class="comp-badge ${un.has(b.id) ? 'on' : ''}" title="${esc(t('ach.' + b.id))}">${b.icon}</span>`,
        ).join('')}</div>
      </section>
    </div>`;

  (app.querySelector('#comp-train') as HTMLButtonElement).onclick = cb.openTrainer;
  (app.querySelector('#comp-learn') as HTMLButtonElement).onclick = cb.openLearn;
  (app.querySelector('#comp-compete') as HTMLButtonElement).onclick = cb.openCompete;
}
