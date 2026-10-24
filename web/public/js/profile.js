(function () {
  'use strict';

  var cfg = window.CONSISTENCY || {};
  var root = document.getElementById('root');

  // ---------------------------------------------------------------- helpers

  function el(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text; // textContent only: data is user-supplied
    return node;
  }

  function clearRoot() { while (root.firstChild) root.removeChild(root.firstChild); }

  function dayKey(d) {
    var m = String(d.getMonth() + 1).padStart(2, '0');
    var day = String(d.getDate()).padStart(2, '0');
    return d.getFullYear() + '-' + m + '-' + day;
  }

  function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n); }

  function mondayOf(d) { return addDays(d, -((d.getDay() + 6) % 7)); }

  function int(v, min, max) {
    var n = Math.round(Number(v));
    if (!isFinite(n)) n = min;
    return Math.min(max, Math.max(min, n));
  }

  function cssColor(v) {
    var n = int(v, 0, 0xffffffff) & 0xffffff;
    return '#' + n.toString(16).padStart(6, '0');
  }

  function plainText(v, max, fallback) {
    var s = typeof v === 'string' ? v.trim() : '';
    return (s || fallback).slice(0, max);
  }

  // ----------------------------------------------------- Firestore REST decode

  function decode(v) {
    if (v === null || typeof v !== 'object') return null;
    if ('stringValue' in v) return v.stringValue;
    if ('integerValue' in v) return Number(v.integerValue);
    if ('doubleValue' in v) return Number(v.doubleValue);
    if ('booleanValue' in v) return v.booleanValue;
    if ('timestampValue' in v) return v.timestampValue;
    if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
    if ('mapValue' in v) {
      var out = {};
      var f = v.mapValue.fields || {};
      Object.keys(f).forEach(function (k) { out[k] = decode(f[k]); });
      return out;
    }
    return null;
  }

  // ------------------------------------------------------------------ data

  function demoProfile() {
    var today = new Date();
    function days(pattern) {
      var list = [];
      for (var i = 0; i < 112; i++) if (pattern(i)) list.push(dayKey(addDays(today, -i)));
      return list;
    }
    return {
      name: 'Aarav (sample)',
      updatedAt: today.toISOString(),
      habits: [
        { name: 'Running', emoji: '🏃', color: 0xf97316, streak: 12, best: 19, weeklyDone: 3, weeklyTarget: 4,
          days: days(function (i) { return i < 12 || (i > 14 && i % 3 !== 0 && i < 70); }) },
        { name: 'Study', emoji: '📚', color: 0x3b82f6, streak: 31, best: 31, weeklyDone: 5, weeklyTarget: 6,
          days: days(function (i) { return i < 31 || (i > 33 && i % 5 !== 0 && i < 100); }) },
        { name: 'Gym', emoji: '🏋️', color: 0xe11d48, streak: 4, best: 11, weeklyDone: 2, weeklyTarget: 4,
          days: days(function (i) { return i < 4 || (i > 5 && i % 2 === 0 && i < 80); }) },
      ],
    };
  }

  function slugFromLocation() {
    var m = /^\/u\/([A-Za-z0-9]{3,32})\/?$/.exec(window.location.pathname);
    if (m) return m[1];
    var q = new URLSearchParams(window.location.search).get('slug');
    return q && /^[A-Za-z0-9]{3,32}$/.test(q) ? q : null;
  }

  function fetchProfile(slug) {
    if (slug === 'demo') return Promise.resolve(demoProfile());

    var fb = cfg.firebase || {};
    if (!fb.projectId || !fb.apiKey) {
      return Promise.reject(new Error('not-configured'));
    }
    var url = 'https://firestore.googleapis.com/v1/projects/' + encodeURIComponent(fb.projectId) +
      '/databases/(default)/documents/profiles/' + encodeURIComponent(slug) +
      '?key=' + encodeURIComponent(fb.apiKey);

    return fetch(url).then(function (res) {
      if (res.status === 404) throw new Error('not-found');
      if (!res.ok) throw new Error('http-' + res.status);
      return res.json();
    }).then(function (doc) {
      return decode({ mapValue: { fields: doc.fields || {} } });
    });
  }

  // ---------------------------------------------------------------- render

  function renderState(title, message) {
    clearRoot();
    var box = el('div', 'state');
    box.appendChild(el('h1', '', title));
    box.appendChild(el('p', '', message));
    var a = el('a', 'btn btn-primary', 'See what Consistency is');
    a.href = '/';
    box.appendChild(a);
    root.appendChild(box);
  }

  function buildMap(habit) {
    var map = el('div', 'map');
    map.style.setProperty('--habit', cssColor(habit.color));
    map.setAttribute('role', 'img');
    var set = {};
    (Array.isArray(habit.days) ? habit.days : []).slice(0, 200).forEach(function (k) {
      if (typeof k === 'string') set[k] = true;
    });
    var today = new Date();
    var todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    var start = addDays(mondayOf(todayStart), -7 * 15);
    var count = 0;
    for (var w = 0; w < 16; w++) {
      for (var d = 0; d < 7; d++) {
        var day = addDays(start, w * 7 + d);
        var cell = el('i');
        if (day > todayStart) cell.className = 'future';
        else if (set[dayKey(day)]) { cell.className = 'on'; count++; }
        map.appendChild(cell);
      }
    }
    map.setAttribute('aria-label', count + ' days logged in the last 16 weeks');
    return map;
  }

  function renderProfile(p) {
    var name = plainText(p.name, 40, 'Someone consistent');
    document.title = name + "'s streaks | Consistency";
    clearRoot();

    root.appendChild(el('h1', '', name + "'s streaks"));
    var updated = p.updatedAt ? new Date(p.updatedAt) : null;
    var subText = updated && !isNaN(updated)
      ? 'Last updated ' + updated.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
      : 'Shared from the Consistency app';
    root.appendChild(el('p', 'sub', subText));

    var habits = Array.isArray(p.habits) ? p.habits.slice(0, 12) : [];
    if (!habits.length) {
      root.appendChild(el('p', 'sub', 'No habits shared yet.'));
    }

    habits.forEach(function (h) {
      var card = el('section', 'streak-card');
      var head = el('header');
      head.appendChild(el('span', 'emoji', plainText(h.emoji, 8, '⭐')));
      head.appendChild(el('h2', '', plainText(h.name, 40, 'Habit')));
      card.appendChild(head);

      var nums = el('div', 'nums');
      nums.appendChild(el('span', 'n', String(int(h.streak, 0, 100000))));
      nums.appendChild(el('span', 'u', 'day streak'));
      nums.appendChild(el('span', 'side', 'Best ' + int(h.best, 0, 100000)));
      var target = int(h.weeklyTarget, 1, 7);
      nums.appendChild(el('span', 'side', 'This week ' + Math.min(int(h.weeklyDone, 0, 7), 7) + ' of ' + target + ' days'));
      card.appendChild(nums);

      card.appendChild(buildMap(h));
      root.appendChild(card);
    });

    root.appendChild(el('p', 'privacy', 'Only the habits, streaks and logged days this person chose to share are shown here.'));
    var cta = el('p');
    var a = el('a', 'btn btn-primary', 'Track your own habits');
    a.href = '/';
    cta.appendChild(a);
    root.appendChild(cta);
  }

  // ------------------------------------------------------------------ boot

  var slug = slugFromLocation();
  if (!slug) {
    renderState('This link is missing something', 'Ask your friend to send their streak link again.');
    return;
  }

  fetchProfile(slug).then(renderProfile).catch(function (err) {
    var msg = err && err.message;
    if (msg === 'not-found') {
      renderState('No streak page here', 'This link may have been turned off, or it was typed wrong.');
    } else if (msg === 'not-configured') {
      console.warn('Set firebase.projectId and firebase.apiKey in /js/config.js');
      renderState('This page can\'t load yet', 'The site owner still needs to finish connecting it. Try again later.');
    } else {
      renderState('Can\'t load this page right now', 'Check your connection and reload.');
    }
  });
})();
