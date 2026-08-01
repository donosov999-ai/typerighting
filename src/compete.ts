// Режим «Тест-соревнование» (запрос Дениса 13.06.2026, по мотивам typinggames.zone):
// несколько дисциплин на скорость (алфавит А→Я / Я→А, слова, цифры, спринт),
// личные рекорды + онлайн-лидерборд (Supabase, см. src/leaderboard.ts).
import { createState, pressChar, stats, MARK, type TypingState } from './typing';
import { keyboardSVG, bridgeChar, keyIdFor } from './keyboard';
import { recordKey, pushHistory } from './stats-store';
import { t, lang } from './i18n';
import type { Profile } from './profiles';
import { submitScore, fetchTop, type LbRow } from './leaderboard';
import { saveReplay, getReplay, createChallenge, leagueSubmit, leagueBoard, CHALLENGE_BASE, type Tick, type ChallengeData, type LeagueRow } from './compete-net';

type DiscKey = 'alpha_fwd' | 'alpha_rev' | 'words' | 'digits' | 'sprint';
const DISCIPLINES: DiscKey[] = ['alpha_fwd', 'alpha_rev', 'words', 'digits', 'sprint'];

const ALPHA = { en: 'abcdefghijklmnopqrstuvwxyz', ru: 'абвгдежзийклмнопрстуфхцчшщъыьэюя' };
const WORDS = {
  en: 'time year people way day man thing woman life child world school state family student group country problem hand part place case week company system program work',
  ru: 'время год человек дело жизнь день рука работа слово место вопрос сторона страна мир случай ребёнок голова система вода друг земля город конец час глаз',
};
const SPRINTS = {
  en: ['the quick brown fox jumps', 'practice makes perfect every day', 'never stop learning new things', 'small steps lead to big wins'],
  ru: ['тише едешь дальше будешь', 'практика путь к мастерству', 'учись каждый день понемногу', 'терпение и труд всё перетрут'],
};
const rnd = (n: number) => Math.floor(Math.random() * n);

function content(d: DiscKey, L: 'en' | 'ru'): string {
  if (d === 'alpha_fwd') return ALPHA[L];
  if (d === 'alpha_rev') return ALPHA[L].split('').reverse().join('');
  if (d === 'digits') { let s = ''; for (let i = 0; i < 30; i++) s += String(rnd(10)) + (i % 5 === 4 ? ' ' : ''); return s.trim(); }
  if (d === 'words') { const w = WORDS[L].split(/\s+/); const o = []; for (let i = 0; i < 12; i++) o.push(w[rnd(w.length)]); return o.join(' '); }
  return SPRINTS[L][rnd(SPRINTS[L].length)]; // sprint
}

// ── Личные рекорды: tr_compete = { "<disc>_<lang>": bestWpm } ──
let best: Record<string, number> = {};
function loadBest() { try { best = JSON.parse(localStorage.getItem('tr_compete') ?? '{}') || {}; } catch { best = {}; } }
function saveBest() { try { localStorage.setItem('tr_compete', JSON.stringify(best)); } catch { /* quota */ } }
const bestKey = (d: DiscKey, L: string) => `${d}_${L}`;

type Screen = 'menu' | 'run' | 'result' | 'board' | 'league';
let screen: Screen = 'menu';
let disc: DiscKey = 'alpha_fwd';
let st: TypingState = createState(['']);
let startedAt = 0;
let errs = 0;
let lastResult: { wpm: number; acc: number; ms: number; medal: string; isRecord: boolean } | null = null;
let prof: Profile = 'm';
let root: HTMLElement | null = null;
let onExit: (() => void) | null = null;
let boardRows: LbRow[] = [];
let boardLoading = false;
let published = false;
// P2 соревнование
let timeline: Tick[] = [];                    // тайминг нажатий текущего заезда (для ghost/челленджа)
let activeChallenge: ChallengeData | null = null; // если вошли по ссылке-вызову «обгони X»
let leagueRows: LeagueRow[] = [];
let leagueLoading = false;
let challengeShareUrl: string | null = null;  // ссылка на созданный вызов
// P2.1 ghost-replay: призрак-соперник едет по СВОЕМУ timeline синхронно с гонкой
let ghostTimeline: Tick[] | null = null;
let ghostNick = '';
let ghostRaf: number | null = null;
let ghostPos = 0;

function curLang(): 'en' | 'ru' { return lang() === 'ru' ? 'ru' : 'en'; }

export function competeEnter(container: HTMLElement, profile: Profile, exit: () => void, challenge?: ChallengeData | null) {
  root = container; onExit = exit; prof = profile;
  loadBest();
  activeChallenge = challenge ?? null;
  ghostTimeline = null; ghostNick = ''; ghostPos = 0;
  if (activeChallenge?.replay_id) {
    // подгружаем реплей соперника → его призрак поедет по своему timeline
    ghostNick = activeChallenge.from_nick;
    void getReplay(activeChallenge.replay_id).then((rep) => { if (rep?.timeline?.length) { ghostTimeline = rep.timeline; if (screen === 'run') render(); } });
  }
  if (activeChallenge) {
    // вошли по ссылке-вызову «обгони X» — сразу запускаем его дисциплину
    const cd = activeChallenge.discipline as DiscKey;
    startDisc(DISCIPLINES.includes(cd) ? cd : 'sprint');
  } else {
    screen = 'menu';
    render();
  }
}

function startDisc(d: DiscKey) {
  disc = d; errs = 0; startedAt = 0; published = false;
  timeline = []; challengeShareUrl = null;
  ghostPos = 0; if (ghostRaf !== null) { cancelAnimationFrame(ghostRaf); ghostRaf = null; }
  st = createState([content(d, curLang())]);
  screen = 'run';
  render();
}

export function competeHandleKey(e: KeyboardEvent) {
  if (screen !== 'run' || st.finishedAt !== null) return;
  if (e.key === 'Backspace') { e.preventDefault(); return; }
  let ch: string | null = null;
  if (e.key === 'Enter') ch = '\n';
  else if (e.key.length === 1) ch = e.key;
  if (ch === null) return;
  e.preventDefault();
  if (startedAt === 0) startedAt = Date.now();
  const expected = st.pattern[st.pos] ?? '';
  ch = bridgeChar(ch, expected);
  if (timeline.length < 5000) timeline.push({ c: ch, t: Date.now() - startedAt }); // запись для ghost/челленджа
  const rc = /[а-яё]/i.test(st.pattern);
  const r = pressChar(st, ch, true); // блок — соревнование требует точности
  if (expected && expected !== ' ' && expected !== '\n') { const id = keyIdFor(expected, rc); if (id) recordKey(id, !r.wrong); }
  if (r.wrong) errs++;
  if (r.finished) finish();
  render();
}

function finish() {
  const s = stats(st);
  const ms = Date.now() - startedAt;
  const min = ms / 60000;
  const chars = st.pattern.replace(/\s/g, '').length;
  const wpm = min > 0 ? Math.round((chars / 5) / min) : 0;
  const total = chars + errs;
  const acc = total > 0 ? Math.round((chars / total) * 100) : 100;
  const medal = acc === 100 ? (wpm >= 60 ? 'gold' : wpm >= 40 ? 'silver' : 'bronze') : (wpm >= 50 && acc >= 95 ? 'silver' : 'ribbon');
  const k = bestKey(disc, curLang());
  const isRecord = wpm > (best[k] ?? 0) && acc >= 90;
  if (isRecord) { best[k] = wpm; saveBest(); }
  pushHistory(wpm, acc, Date.now());
  void s;
  lastResult = { wpm, acc, ms, medal, isRecord };
  if (ghostRaf !== null) { cancelAnimationFrame(ghostRaf); ghostRaf = null; } // стоп призрак
  // недельная лига — записываем результат (async, не блокирует UI)
  if (prof !== 'kids') void leagueSubmit(localStorage.getItem('tr_name') || 'Anon', disc, curLang(), wpm, acc);
  screen = 'result';
}

async function openBoard() {
  screen = 'board'; boardLoading = true; boardRows = []; render();
  boardRows = await fetchTop(disc, curLang());
  boardLoading = false; render();
}

async function publish(name: string) {
  if (!lastResult || published) return;
  published = true;
  try { localStorage.setItem('tr_name', name); } catch { /* */ }
  await submitScore({ name, discipline: disc, lang: curLang(), wpm: lastResult.wpm, accuracy: lastResult.acc, ms: lastResult.ms });
  await openBoard();
}

// ── Рендер ──
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));

function renderPattern(): string {
  let html = '';
  for (let i = 0; i < st.pattern.length; i++) {
    const m = st.marks[i];
    const cls = i === st.pos ? 'cur' : m === MARK.CORRECT ? 'ok' : m === MARK.WRONG ? 'bad' : 'pend';
    html += `<span class="${cls}">${esc(st.pattern[i])}</span>`;
  }
  return html;
}

function render() {
  if (!root) return;
  if (screen === 'menu') renderMenu();
  else if (screen === 'run') renderRun();
  else if (screen === 'result') renderResult();
  else if (screen === 'league') renderLeague();
  else renderBoard();
}

function renderMenu() {
  const L = curLang();
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="cp-exit" class="mode-back">${t('nav.back')}</button>
        <h1>🏆 ${t('compete.title')}</h1>
      </header>
      <p class="c-intro">${t('compete.intro')}</p>
      <div class="cp-grid">
        ${DISCIPLINES.map((d) => {
          const b = best[bestKey(d, L)] ?? 0;
          return `<button class="cp-disc" data-d="${d}">
            <img class="disc-ic" src="images/icons/disc-${d}.webp" alt=""/>
            <span class="cp-name">${t('comp.' + d)}</span>
            <span class="cp-best">${b > 0 ? `${t('comp.best')}: ${b} ${t('st.wpm')}` : '—'}</span>
          </button>`;
        }).join('')}
      </div>
    </div>`;
  root!.querySelectorAll<HTMLButtonElement>('[data-d]').forEach((b) => { b.onclick = () => startDisc(b.dataset.d as DiscKey); });
  (root!.querySelector('#cp-exit') as HTMLButtonElement).onclick = () => onExit?.();
}

function renderRun() {
  const rc = /[а-яё]/i.test(st.pattern);
  const showRu = lang() === 'ru' || rc;
  const L = curLang() === 'ru';
  // P2.1: дорожка призрака — «ты» и соперник 👻 едут по прогрессу текста
  const ghostBar = ghostTimeline ? `
      <div class="cp-ghost">
        <div class="cp-track"><span class="cp-you" id="cp-you"></span><span class="cp-rival" id="cp-rival">👻</span></div>
        <div class="cp-glbl"><span>${L ? 'Ты' : 'You'}</span><b id="cp-gap"></b><span>${esc(ghostNick)} 👻</span></div>
      </div>` : '';
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="cp-back" class="mode-back">${t('nav.tomap')}</button>
        <span class="c-progress">🏆 ${t('comp.' + disc)}</span>
        <span class="c-acc">${activeChallenge ? `🎯 ${L ? 'Цель' : 'Target'}: ${activeChallenge.target_wpm} ${t('st.wpm')}` : t('comp.hint')}</span>
      </header>
      ${ghostBar}
      <div class="card"><div class="pattern pattern-big" id="pattern">${renderPattern()}</div></div>
      <div class="keyb">${keyboardSVG(st.finishedAt === null ? st.pattern[st.pos] ?? null : null, rc, showRu)}</div>
    </div>`;
  (root!.querySelector('#cp-back') as HTMLButtonElement).onclick = () => { screen = 'menu'; render(); };
  if (ghostTimeline && ghostRaf === null && st.finishedAt === null) ghostRaf = requestAnimationFrame(ghostTick);
}

// Анимация призрака: по реальному времени продвигаем его позицию по своему timeline,
// параллельно двигаем маркер юзера (st.pos) — гонка «ты vs соперник» в реальном темпе.
function ghostTick() {
  if (screen !== 'run' || !ghostTimeline || st.finishedAt !== null) { ghostRaf = null; return; }
  const total = st.pattern.length || 1;
  const elapsed = startedAt ? Date.now() - startedAt : 0;
  while (ghostPos < ghostTimeline.length && ghostTimeline[ghostPos].t <= elapsed) ghostPos++;
  const youEl = document.getElementById('cp-you');
  const rivalEl = document.getElementById('cp-rival');
  const gapEl = document.getElementById('cp-gap');
  if (youEl) youEl.style.left = Math.min(100, (st.pos / total) * 100) + '%';
  if (rivalEl) rivalEl.style.left = Math.min(100, (ghostPos / total) * 100) + '%';
  if (gapEl) {
    const d = st.pos - ghostPos; const L = curLang() === 'ru';
    gapEl.textContent = d > 0 ? (L ? `+${d} впереди` : `+${d} ahead`) : d < 0 ? (L ? `${d} позади` : `${d} behind`) : (L ? 'вровень' : 'neck & neck');
    gapEl.className = d >= 0 ? 'cp-ahead' : 'cp-behind';
  }
  ghostRaf = requestAnimationFrame(ghostTick);
}

function renderResult() {
  const r = lastResult!;
  const savedName = localStorage.getItem('tr_name') ?? '';
  const kids = prof === 'kids';
  const L = curLang() === 'ru';
  // вердикт по вызову (если вошли по ссылке-челленджу)
  let chVerdict = '';
  if (activeChallenge) {
    const won = r.wpm > activeChallenge.target_wpm;
    const from = esc(activeChallenge.from_nick);
    chVerdict = won
      ? `<div class="cp-chal won">🎉 ${L ? `Обогнал ${from}!` : `You beat ${from}!`} <small>${activeChallenge.target_wpm} ${t('st.wpm')}</small></div>`
      : `<div class="cp-chal lost">${L ? `Не хватило до ${from}` : `Short of ${from}`}: <b>${activeChallenge.target_wpm}</b> ${t('st.wpm')}</div>`;
  }
  // панель поделиться созданным вызовом
  let shareBox = '';
  if (challengeShareUrl) {
    const enc = encodeURIComponent(challengeShareUrl);
    const txt = encodeURIComponent(L ? `Обгони меня в TypeRIGHTing: ${r.wpm} зн/мин!` : `Beat me in TypeRIGHTing: ${r.wpm} WPM!`);
    shareBox = `<div class="cp-sharebox">
      <div class="sh-row"><input id="cp-shurl" readonly value="${esc(challengeShareUrl)}"/><button id="cp-shcopy">${L ? 'Копировать' : 'Copy'}</button></div>
      <div class="sh-soc"><a href="https://t.me/share/url?url=${enc}&text=${txt}" target="_blank" rel="noopener">Telegram</a><a href="https://vk.com/share.php?url=${enc}" target="_blank" rel="noopener">ВКонтакте</a></div>
    </div>`;
  }
  root!.innerHTML = `
    <div class="wrap compete">
      <div class="cp-result">
        <div class="cp-medal"><img class="medal-img" src="images/icons/medal-${r.medal}.webp" alt=""/></div>
        <h2>${t('comp.' + disc)}</h2>
        ${r.isRecord ? `<div class="cp-record">⭐ ${t('comp.record')}</div>` : ''}
        ${chVerdict}
        <div class="statsbar">
          <div><b>${r.wpm}</b><span>${t('st.wpm')}</span></div>
          <div><b>${r.acc}%</b><span>${t('st.accuracy')}</span></div>
          <div><b>${(r.ms / 1000).toFixed(1)}s</b><span>${t('st.time')}</span></div>
        </div>
        ${kids ? '' : `
        <div class="cp-publish">
          <input id="cp-name" type="text" value="${esc(savedName)}" placeholder="${t('comp.name')}" maxlength="24"/>
          <button id="cp-pub" class="primary" ${published ? 'disabled' : ''}>${published ? '✓' : '🌐 ' + t('comp.publish')}</button>
        </div>
        <div class="donebtns">
          <button id="cp-challenge">🎯 ${L ? 'Бросить вызов' : 'Challenge a friend'}</button>
          <button id="cp-league" class="ghost">🏆 ${L ? 'Лига недели' : 'Weekly league'}</button>
        </div>
        ${shareBox}`}
        <div class="donebtns">
          <button id="cp-again">${t('k.again')}</button>
          <button id="cp-board" class="ghost">🌐 ${t('comp.leaderboard')}</button>
          <button id="cp-menu" class="ghost">${t('k.map')}</button>
        </div>
      </div>
    </div>`;
  (root!.querySelector('#cp-again') as HTMLButtonElement).onclick = () => startDisc(disc);
  (root!.querySelector('#cp-menu') as HTMLButtonElement).onclick = () => { activeChallenge = null; screen = 'menu'; render(); };
  (root!.querySelector('#cp-board') as HTMLButtonElement).onclick = () => openBoard();
  const pub = root!.querySelector('#cp-pub') as HTMLButtonElement | null;
  if (pub) pub.onclick = () => publish((root!.querySelector('#cp-name') as HTMLInputElement).value.trim() || '—');
  const chBtn = root!.querySelector('#cp-challenge') as HTMLButtonElement | null;
  if (chBtn) chBtn.onclick = () => challengeShare(chBtn);
  const lgBtn = root!.querySelector('#cp-league') as HTMLButtonElement | null;
  if (lgBtn) lgBtn.onclick = () => openLeague();
  const shcopy = root!.querySelector('#cp-shcopy') as HTMLButtonElement | null;
  if (shcopy) shcopy.onclick = () => {
    const i = root!.querySelector('#cp-shurl') as HTMLInputElement; i.select();
    navigator.clipboard?.writeText(i.value).then(() => { shcopy.textContent = L ? '✓' : '✓'; }).catch(() => {});
  };
}

// P2: создать вызов из своего результата → ссылка + шеринг
async function challengeShare(btn: HTMLButtonElement) {
  if (!lastResult) return;
  btn.disabled = true;
  const nick = localStorage.getItem('tr_name') || 'Anon';
  const replayId = await saveReplay(nick, disc, curLang(), lastResult.wpm, lastResult.acc, timeline);
  const chId = await createChallenge(nick, disc, curLang(), lastResult.wpm, lastResult.acc, replayId);
  btn.disabled = false;
  if (chId) { challengeShareUrl = `${CHALLENGE_BASE}/${chId}`; render(); }
  else { btn.textContent = curLang() === 'ru' ? 'Ошибка сети' : 'Network error'; }
}

// P2: недельная лига
async function openLeague() {
  screen = 'league'; leagueLoading = true; leagueRows = []; render();
  leagueRows = (await leagueBoard(disc, curLang())) || [];
  leagueLoading = false; render();
}

function renderLeague() {
  const L = curLang() === 'ru';
  const me = (localStorage.getItem('tr_name') || '').toLowerCase();
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="lg-back" class="mode-back">${t('nav.back')}</button>
        <h1>🏆 ${L ? 'Лига недели' : 'Weekly league'}</h1>
      </header>
      <p class="c-intro">${t('comp.' + disc)} · ${curLang().toUpperCase()}</p>
      ${leagueLoading ? `<p class="hint2">${t('comp.loading')}</p>` : leagueRows.length === 0 ? `<p class="hint2">${t('comp.empty')}</p>` : `
        <table class="cp-board">
          <thead><tr><th>#</th><th>${t('comp.player')}</th><th>${t('st.wpm')}</th><th>${t('st.accuracy')}</th></tr></thead>
          <tbody>${leagueRows.map((row) => `<tr class="${row.nick.toLowerCase() === me ? 'me' : ''}"><td>${row.rank}</td><td>${esc(row.nick)}</td><td><b>${row.wpm}</b></td><td>${row.accuracy}%</td></tr>`).join('')}</tbody>
        </table>`}
    </div>`;
  (root!.querySelector('#lg-back') as HTMLButtonElement).onclick = () => { screen = lastResult ? 'result' : 'menu'; render(); };
}

function renderBoard() {
  const L = curLang();
  root!.innerHTML = `
    <div class="wrap compete">
      <header class="mode-head">
        <button id="cp-bback" class="mode-back">${t('nav.back')}</button>
        <h1>🌐 ${t('comp.leaderboard')}</h1>
      </header>
      <p class="c-intro">${t('comp.' + disc)} · ${L.toUpperCase()}</p>
      ${boardLoading ? `<p class="hint2">${t('comp.loading')}</p>` : boardRows.length === 0 ? `<p class="hint2">${t('comp.empty')}</p>` : `
        <table class="cp-board">
          <thead><tr><th>#</th><th>${t('comp.player')}</th><th>${t('st.wpm')}</th><th>${t('st.accuracy')}</th></tr></thead>
          <tbody>${boardRows.map((row, i) => `<tr><td>${i + 1}</td><td>${esc(row.name)}</td><td><b>${row.wpm}</b></td><td>${row.accuracy}%</td></tr>`).join('')}</tbody>
        </table>`}
    </div>`;
  (root!.querySelector('#cp-bback') as HTMLButtonElement).onclick = () => { screen = lastResult ? 'result' : 'menu'; render(); };
}
