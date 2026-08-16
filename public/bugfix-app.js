/* bugfix-app · VER 1 · 16.08.2026 · webcheck · встраиваемый in-app багфикс для Tauri/webview-приложений */
/*
 * ЕДИНЫЙ in-app багфикс на все 5+ Tauri-приложений (psygames / TypeRIGHT / Гидромаш-в-цеху / fydao / grovi).
 * НЕ внешний загрузчик (в APK CSP script-src 'self' его режет + офлайн) — файл ВЕНДОРИТСЯ в приложение
 * (кладётся локально, грузится из 'self'). Пишет в ЕДИНЫЙ bug_reports + бакет bug-shots (как сайтовый
 * багфикс) → авто-задача в TeamOps. Фреймворк-агностик: чистый DOM (все наши app = webview, даже RN-Web).
 *
 * ПОДКЛЮЧЕНИЕ (vanilla, напр. TypeRIGHT):
 *   import './bugfix-app.js';            // или <script src="/bugfix-app.js">
 *   BugfixApp.init({ project: 'typefree', version: '1.203.0', enabled: __TEST_BUILD__ });
 *
 * ПОДКЛЮЧЕНИЕ (своя кнопка, headless, напр. psygames RN):
 *   BugfixApp.init({ project: 'psygames', button: false, enabled: FEEDBACK_ENABLED });
 *   // из своего FeedbackWidget: await BugfixApp.send('bug', text, contact);
 *
 * CSP приложения: connect-src должен включать https://iuvvheeocobhiothfgei.supabase.co
 * html2canvas: если global.html2canvas есть — будет скрин; нет — репорт уйдёт без скрина (не падаем).
 */
(function (global) {
  'use strict';
  if (global.BugfixApp) return;   // одна копия на приложение

  var SB_URL = 'https://iuvvheeocobhiothfgei.supabase.co';
  var SB_KEY_DEFAULT = 'sb_publishable_A2vJ5DjemTZIKrKX6XGqvQ_WaiuAkk1'; // публичный, RLS INSERT-only
  var QKEY = 'odv_bugfix_queue';
  var DKEY = 'odv_bugfix_device';
  var CFG = null;

  function lsGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function lsSet(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  function deviceId() {
    var id = lsGet(DKEY);
    if (id) return id;
    var c = global.crypto;
    id = (c && c.randomUUID) ? c.randomUUID() : ('d-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10));
    lsSet(DKEY, id); return id;
  }

  // Platform.OS для Tauri-APK врёт 'web' (паттерн psygames) — детект по __TAURI__ + UA.
  function detectPlatform() {
    var ua = (typeof navigator !== 'undefined' ? navigator.userAgent : '') || '';
    var tauri = !!(global.__TAURI__ || global.__TAURI_INTERNALS__);
    var mob = /Android/i.test(ua) ? 'android' : (/iPhone|iPad|iPod/i.test(ua) ? 'ios' : null);
    if (tauri) return mob ? ('tauri-' + mob) : 'tauri-desktop';
    return mob ? ('web-' + mob) : 'web';
  }

  function viewport() {
    try {
      var probe = document.createElement('div');
      probe.style.cssText = 'position:absolute;visibility:hidden;font-size:16px';
      probe.textContent = 'M';
      document.body.appendChild(probe);
      var px = parseFloat(getComputedStyle(probe).fontSize) || 16;
      probe.remove();
      return { w: global.innerWidth, h: global.innerHeight, dpr: global.devicePixelRatio, fontScale: Math.round(px / 16 * 100) / 100 };
    } catch (e) { return null; }
  }

  // буфер ошибок консоли — контекст репорта
  var errBuf = [];
  function pushErr(s) { try { errBuf.push(String(s).slice(0, 300)); if (errBuf.length > 10) errBuf.shift(); } catch (e) {} }
  try { var _ce = console.error; console.error = function () { pushErr(Array.prototype.join.call(arguments, ' ')); return _ce.apply(console, arguments); }; } catch (e) {}
  if (global.addEventListener) global.addEventListener('error', function (e) { pushErr(e && e.message || 'error'); });

  function capture() {
    return new Promise(function (res) {
      var h2c = global.html2canvas;
      if (!h2c || typeof document === 'undefined') return res(null);
      try {
        h2c(document.body, { scale: 0.6, logging: false, useCORS: true, backgroundColor: null })
          .then(function (cv) { cv.toBlob(function (b) { res(b); }, 'image/jpeg', 0.7); })
          .catch(function () { res(null); });
      } catch (e) { res(null); }
    });
  }

  function headers(ct) {
    var h = { apikey: CFG.apiKey, Authorization: 'Bearer ' + CFG.apiKey };
    if (ct) h['Content-Type'] = ct;
    return h;
  }

  function uploadShot(blob) {
    if (!blob) return Promise.resolve(null);
    var path = new Date().toISOString().slice(0, 10) + '/' + Math.random().toString(36).slice(2) + '.jpg';
    return fetch(SB_URL + '/storage/v1/object/bug-shots/' + path, { method: 'POST', headers: headers('image/jpeg'), body: blob })
      .then(function (r) { return r.ok ? path : null; }).catch(function () { return null; });
  }

  function insertReport(row) {
    return fetch(SB_URL + '/rest/v1/bug_reports', {
      method: 'POST',
      headers: Object.assign(headers('application/json'), { Prefer: 'return=minimal' }),
      body: JSON.stringify(row),
    }).then(function (r) { return r.ok; });
  }

  // офлайн-очередь (репорт без скрина — скрин привязан к сессии, в очередь кладём только строку)
  function qLoad() { try { return JSON.parse(lsGet(QKEY) || '[]'); } catch (e) { return []; } }
  function qSave(a) { lsSet(QKEY, JSON.stringify(a.slice(-50))); }
  function enqueue(row) { var a = qLoad(); a.push(row); qSave(a); }
  function flush() {
    if (!CFG) return;
    var a = qLoad(); if (!a.length) return;
    insertReport(a[0]).then(function (ok) {
      if (ok) { var b = qLoad(); b.shift(); qSave(b); if (b.length) flush(); }
    }).catch(function () {});
  }

  function buildRow(kind, message, reporter, shot_path) {
    return {
      project: CFG.project,
      kind: kind || 'bug',
      message: (message || '').slice(0, 4000),
      url: ((CFG.screen ? CFG.screen() : (typeof location !== 'undefined' ? location.href : '')) || '').slice(0, 500),
      shot_path: shot_path || null,
      reporter: (reporter || '').slice(0, 200) || null,
      device_id: deviceId(),
      context: {
        title: (CFG.appName || (typeof document !== 'undefined' ? document.title : '') || '').slice(0, 200),
        platform: detectPlatform(),
        viewport: viewport(),
        consoleErrors: errBuf.slice(-10),
        appVersion: CFG.version || '',
        lang: CFG.lang || (typeof document !== 'undefined' ? (document.documentElement.getAttribute('lang') || '') : ''),
        inApp: true,
      },
    };
  }

  // headless-отправка: приложение может вызвать со своей кнопкой/формой
  function send(kind, message, reporter) {
    return capture().then(function (blob) {
      return uploadShot(blob).then(function (shot_path) {
        var row = buildRow(kind, message, reporter, shot_path);
        return insertReport(row).then(function (ok) {
          if (!ok) { enqueue(buildRow(kind, message, reporter, null)); return false; }
          return true;
        }).catch(function () { enqueue(buildRow(kind, message, reporter, null)); return false; });
      });
    });
  }

  // ---------- минимальный UI (shadow DOM — изоляция от стилей приложения) ----------
  var host = null, sh = null;
  var T = {
    ru: { btn: 'Сообщить о баге', title: 'Что не так?', bug: 'Баг', idea: 'Идея', unclear: 'Непонятно', ph: 'Опишите, что случилось…', contact: 'Контакт для ответа (необязательно)', shot: 'Приложить скриншот', send: 'Отправить', cancel: 'Отмена', okMsg: 'Спасибо! Отчёт отправлен.', queuedMsg: 'Нет сети — отправим позже.' },
    en: { btn: 'Report a bug', title: "What's wrong?", bug: 'Bug', idea: 'Idea', unclear: 'Unclear', ph: 'Describe what happened…', contact: 'Contact for reply (optional)', shot: 'Attach screenshot', send: 'Send', cancel: 'Cancel', okMsg: 'Thanks! Report sent.', queuedMsg: 'Offline — will send later.' },
  };
  function t() { var l = (CFG.lang || (typeof document !== 'undefined' ? document.documentElement.getAttribute('lang') : '') || 'ru').slice(0, 2).toLowerCase(); return Object.assign({}, T.en, T[l] || {}); }

  function mountFab() {
    if (host || typeof document === 'undefined') return;
    host = document.createElement('div');
    host.id = 'odv-bugfix-app-root';
    host.style.cssText = 'all:initial';
    sh = host.attachShadow({ mode: 'open' });
    var side = CFG.position === 'right' ? 'right' : 'left';
    var acc = CFG.color || '#e24b4a';
    sh.innerHTML =
      '<style>' +
      ':host{all:initial}' +
      '.fab{position:fixed;z-index:2147483200;' + side + ':14px;bottom:calc(14px + env(safe-area-inset-bottom));' +
      'display:flex;align-items:center;gap:6px;padding:9px 13px;border-radius:22px;border:none;cursor:pointer;' +
      'font:600 13px system-ui,-apple-system,sans-serif;color:#fff;background:' + acc + ';box-shadow:0 4px 14px rgba(0,0,0,.28)}' +
      '.wrap{position:fixed;inset:0;z-index:2147483201;background:rgba(0,0,0,.45);display:flex;align-items:flex-end;justify-content:center}' +
      '.card{background:#fff;color:#1c1c1e;width:min(440px,100%);border-radius:16px 16px 0 0;padding:16px 16px calc(16px + env(safe-area-inset-bottom));font:14px system-ui,-apple-system,sans-serif}' +
      '@media(min-width:560px){.wrap{align-items:center}.card{border-radius:16px}}' +
      '.hd{font-weight:700;font-size:16px;margin:0 0 12px}' +
      '.kinds{display:flex;gap:8px;margin-bottom:10px}' +
      '.k{flex:1;padding:8px;border:1px solid #d2d2d7;border-radius:10px;background:#f5f5f7;cursor:pointer;text-align:center;font-size:13px}' +
      '.k.on{border-color:' + acc + ';background:#fff;font-weight:600;box-shadow:0 0 0 2px ' + acc + '33}' +
      'textarea,input{width:100%;box-sizing:border-box;border:1px solid #d2d2d7;border-radius:10px;padding:10px;font:14px system-ui;margin-bottom:10px}' +
      'textarea{min-height:84px;resize:vertical}' +
      '.row{display:flex;align-items:center;gap:8px;margin-bottom:12px;font-size:13px;color:#3a3a3c}' +
      '.btns{display:flex;gap:10px}' +
      '.btns button{flex:1;padding:11px;border-radius:10px;border:none;cursor:pointer;font:600 14px system-ui}' +
      '.cancel{background:#f0f0f2;color:#1c1c1e}.send{background:' + acc + ';color:#fff}' +
      '.send[disabled]{opacity:.5}' +
      '.toast{position:fixed;left:50%;bottom:80px;transform:translateX(-50%);z-index:2147483202;background:#1c1c1e;color:#fff;padding:10px 16px;border-radius:22px;font:13px system-ui}' +
      '</style>' +
      '<button class="fab" id="fab">🐞 <span></span></button>';
    sh.getElementById('fab').querySelector('span').textContent = t().btn;
    sh.getElementById('fab').addEventListener('click', openForm);
    document.body.appendChild(host);
  }

  var _kind = 'bug';
  function openForm() {
    if (!sh) { // headless: подмонтируем контейнер под форму
      if (!host) { host = document.createElement('div'); host.id = 'odv-bugfix-app-root'; sh = host.attachShadow({ mode: 'open' }); document.body.appendChild(host); }
    }
    var L = t(); _kind = 'bug';
    var w = document.createElement('div'); w.className = 'wrap';
    w.innerHTML =
      '<div class="card">' +
      '<p class="hd">' + L.title + '</p>' +
      '<div class="kinds"><div class="k on" data-k="bug">🐞 ' + L.bug + '</div><div class="k" data-k="idea">💡 ' + L.idea + '</div><div class="k" data-k="unclear">🤔 ' + L.unclear + '</div></div>' +
      '<textarea id="msg" placeholder="' + L.ph + '"></textarea>' +
      '<input id="contact" placeholder="' + L.contact + '">' +
      '<label class="row"><input type="checkbox" id="shot" checked> ' + L.shot + '</label>' +
      '<div class="btns"><button class="cancel" id="cancel">' + L.cancel + '</button><button class="send" id="send">' + L.send + '</button></div>' +
      '</div>';
    // если fab-стилей нет (headless), добавим стили формы
    if (!sh.querySelector('style')) {
      var st = document.createElement('style');
      st.textContent = '.wrap{position:fixed;inset:0;z-index:2147483201;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;font:14px system-ui}.card{background:#fff;color:#1c1c1e;width:min(440px,92%);border-radius:16px;padding:16px}.hd{font-weight:700;font-size:16px;margin:0 0 12px}.kinds{display:flex;gap:8px;margin-bottom:10px}.k{flex:1;padding:8px;border:1px solid #d2d2d7;border-radius:10px;background:#f5f5f7;cursor:pointer;text-align:center}.k.on{border-color:#e24b4a;background:#fff;font-weight:600}textarea,input{width:100%;box-sizing:border-box;border:1px solid #d2d2d7;border-radius:10px;padding:10px;margin-bottom:10px;font:14px system-ui}textarea{min-height:84px}.row{display:flex;gap:8px;margin-bottom:12px}.btns{display:flex;gap:10px}.btns button{flex:1;padding:11px;border-radius:10px;border:none;cursor:pointer;font:600 14px system-ui}.cancel{background:#f0f0f2}.send{background:#e24b4a;color:#fff}';
      sh.appendChild(st);
    }
    sh.appendChild(w);
    var sendBtn = w.querySelector('#send');
    w.querySelectorAll('.k').forEach(function (el) { el.addEventListener('click', function () { w.querySelectorAll('.k').forEach(function (x) { x.classList.remove('on'); }); el.classList.add('on'); _kind = el.getAttribute('data-k'); }); });
    w.querySelector('#cancel').addEventListener('click', function () { w.remove(); });
    w.addEventListener('click', function (e) { if (e.target === w) w.remove(); });
    sendBtn.addEventListener('click', function () {
      var msg = w.querySelector('#msg').value.trim();
      if (!msg) { w.querySelector('#msg').style.borderColor = '#e24b4a'; return; }
      var contact = w.querySelector('#contact').value.trim();
      var withShot = w.querySelector('#shot').checked;
      sendBtn.disabled = true; sendBtn.textContent = '…';
      var run = withShot ? send(_kind, msg, contact) : sendNoShot(_kind, msg, contact);
      run.then(function (ok) { w.remove(); toast(ok ? L.okMsg : L.queuedMsg); });
    });
  }
  function sendNoShot(k, m, c) {
    var row = buildRow(k, m, c, null);
    return insertReport(row).then(function (ok) { if (!ok) enqueue(row); return ok; }).catch(function () { enqueue(row); return false; });
  }
  function toast(txt) {
    if (!sh) return;
    var el = document.createElement('div'); el.className = 'toast'; el.textContent = txt; sh.appendChild(el);
    setTimeout(function () { try { el.remove(); } catch (e) {} }, 3200);
  }

  var API = {
    init: function (cfg) {
      CFG = Object.assign({ apiKey: SB_KEY_DEFAULT, enabled: true, position: 'left' }, cfg || {});
      if (!CFG.project) { try { console.warn('[bugfix-app] project обязателен'); } catch (e) {} return API; }
      flush();
      if (global.addEventListener) global.addEventListener('online', flush);
      if (CFG.enabled && CFG.button !== false) mountFab();
      return API;
    },
    open: function () { if (CFG) openForm(); },      // открыть форму программно
    send: send,                                       // headless-сабмит (своя UI)
    flush: flush,
    version: 1,
  };
  global.BugfixApp = API;
})(typeof window !== 'undefined' ? window : this);
