import { describe, it, expect, beforeAll, beforeEach, vi } from 'vitest';
import { recordKey, pushHistory, onSession, type SessionEvent } from './stats-store';
import { buildRow, enqueue, flushQueue, queueSize, deviceId, topErrKeys } from './session-log';
import { collectLocal } from './account';

// Браузерные глобалы для узла (как в stats-store.test.ts) + перечисление ключей для collectLocal.
const store: Record<string, string> = {};
beforeAll(() => {
  vi.stubGlobal('localStorage', {
    getItem: (k: string) => store[k] ?? null,
    setItem: (k: string, v: string) => { store[k] = v; },
    removeItem: (k: string) => { delete store[k]; },
    key: (i: number) => Object.keys(store)[i] ?? null,
    get length() { return Object.keys(store).length; },
  });
  vi.stubGlobal('window', { setTimeout: () => 0, addEventListener: () => {} });
  vi.stubGlobal('navigator', { userAgent: 'Mozilla/5.0 (X11; Linux x86_64)', maxTouchPoints: 0 });
});
beforeEach(() => { for (const k of Object.keys(store)) delete store[k]; });

const ev = (over: Partial<SessionEvent> = {}): SessionEvent => ({
  t: Date.UTC(2026, 8, 17, 10, 0, 0), wpm: 42, acc: 96.5, len: 120, ms: 60000, err: 4, score: 40,
  errKeys: { KeyF: 3, KeyJ: 1 }, ...over,
});

describe('событие конца сессии из stats-store', () => {
  it('реальная сессия эмитится с ошибками по клавишам и точностью в процентах', () => {
    const got: SessionEvent[] = [];
    const off = onSession((e) => got.push(e));
    let t = 5_000_000;
    for (let i = 0; i < 20; i++) { t += 150; recordKey('KeyA', i % 5 !== 0, t); } // 4 ошибки на KeyA
    pushHistory(50, 0.8, t + 100); // доля — у части режимов точность приходит долей
    off();
    expect(got).toHaveLength(1);
    expect(got[0].errKeys).toEqual({ KeyA: 4 });
    expect(got[0].acc).toBe(80);
    expect(got[0].len).toBe(20);
  });

  it('микро-сессия (меньше 10 нажатий) не уходит в облако', () => {
    const got: SessionEvent[] = [];
    const off = onSession((e) => got.push(e));
    let t = 9_000_000;
    for (let i = 0; i < 5; i++) { t += 150; recordKey('KeyB', true, t); }
    pushHistory(60, 100, t + 100);
    off();
    expect(got).toHaveLength(0);
  });

  it('ошибки сессии не протекают в следующую сессию', () => {
    const got: SessionEvent[] = [];
    const off = onSession((e) => got.push(e));
    let t = 12_000_000;
    for (let i = 0; i < 12; i++) { t += 150; recordKey('KeyC', false, t); }
    pushHistory(30, 50, t + 100);
    for (let i = 0; i < 12; i++) { t += 150; recordKey('KeyD', true, t); }
    pushHistory(40, 100, t + 100);
    off();
    expect(got).toHaveLength(2);
    expect(got[1].errKeys).toEqual({});
  });
});

describe('строка для tr_sessions', () => {
  it('границы значений как у сервера, режим/язык обрезаны', () => {
    const r = buildRow(ev({ wpm: 999, acc: 140, ms: 9_999_999 }), { mode: 'train:letterByLetter-extra', lang: 'pt-BR', layout: 'qwerty' });
    expect(r.wpm).toBe(400);
    expect(r.acc).toBe(100);
    expect(r.duration_ms).toBe(3600000);
    expect(r.mode.length).toBeLessThanOrEqual(20);
    expect(r.lang).toBe('pt-BR');
    expect(r.played_at).toBe('2026-09-17T10:00:00.000Z');
    expect(r.platform).toMatch(/(web|app)-linux$/);
  });

  it('id устройства стабилен, client_id уникален на каждую сессию', () => {
    const a = buildRow(ev(), { mode: 'flow', lang: 'ru', layout: 'qwerty' });
    const b = buildRow(ev(), { mode: 'flow', lang: 'ru', layout: 'qwerty' });
    expect(a.device).toBe(b.device);
    expect(a.device).toBe(deviceId());
    expect(a.client).not.toBe(b.client);
  });

  it('в облако уходят только 30 худших клавиш', () => {
    const many = Object.fromEntries(Array.from({ length: 50 }, (_, i) => [`K${i}`, i]));
    const top = topErrKeys(many);
    expect(Object.keys(top)).toHaveLength(30);
    expect(top.K49).toBe(49);
    expect(top.K0).toBeUndefined();
  });
});

describe('офлайн-очередь', () => {
  const row = () => buildRow(ev(), { mode: 'test', lang: 'en', layout: 'qwerty' });
  const ok = (body: unknown, status = 200) => Promise.resolve(new Response(JSON.stringify(body), { status }));

  it('принято сервером — строка снята, в запросе нет ника без входа', async () => {
    enqueue(row());
    const calls: RequestInit[] = [];
    const sent = await flushQueue(((_: unknown, init?: RequestInit) => { calls.push(init!); return ok({ ok: true, user: false }); }) as typeof fetch);
    expect(sent).toBe(1);
    expect(queueSize()).toBe(0);
    const body = JSON.parse(String(calls[0].body));
    expect(body.p_device).toBe(deviceId());
    expect(body.p_lang).toBe('en');
    expect(body.p_nick).toBeNull();
  });

  it('нет сети — строка остаётся', async () => {
    enqueue(row());
    const sent = await flushQueue((() => Promise.reject(new TypeError('Load failed'))) as typeof fetch);
    expect(sent).toBe(0);
    expect(queueSize()).toBe(1);
  });

  it('сбой сервера (HTTP 500) — строка остаётся', async () => {
    enqueue(row());
    await flushQueue((() => ok({ message: 'boom' }, 500)) as typeof fetch);
    expect(queueSize()).toBe(1);
  });

  it('постоянный отказ (range/date/ids) — строка снята, чтобы очередь не встала навсегда', async () => {
    enqueue(row()); enqueue(row());
    const sent = await flushQueue((() => ok({ ok: false, err: 'date' })) as typeof fetch);
    expect(sent).toBe(0);
    expect(queueSize()).toBe(0);
  });

  it('вошедший пользователь — ник и PIN уходят для привязки на сервере', async () => {
    store.tr_acc = JSON.stringify({ nick: 'alex', pin: '1234' });
    enqueue(row());
    let body: Record<string, unknown> = {};
    await flushQueue(((_: unknown, init?: RequestInit) => { body = JSON.parse(String(init!.body)); return ok({ ok: true, user: true }); }) as typeof fetch);
    expect(body.p_nick).toBe('alex');
    expect(body.p_pin).toBe('1234');
  });
});

describe('облачный синк прогресса', () => {
  it('не разносит id устройства и очередь по другим устройствам', () => {
    deviceId();
    enqueue(buildRow(ev(), { mode: 'flow', lang: 'de', layout: 'qwertz' }));
    store.tr_history = '[]';
    const snap = collectLocal();
    expect(snap.tr_device).toBeUndefined();
    expect(snap.tr_sess_queue).toBeUndefined();
    expect(snap.tr_history).toBe('[]');
  });
});
