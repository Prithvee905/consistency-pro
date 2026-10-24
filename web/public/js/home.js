(function () {
  'use strict';

  var cfg = window.CONSISTENCY || {};

  // ---- download button (only when a real link is configured) ----
  if (cfg.downloadUrl) {
    var soon = document.getElementById('soon');
    var a = document.createElement('a');
    a.className = 'btn btn-primary';
    a.href = cfg.downloadUrl;
    a.textContent = 'Get the app';
    if (soon) soon.replaceWith(a);

    var cta2 = document.getElementById('cta2');
    if (cta2) {
      var b = a.cloneNode(true);
      cta2.appendChild(b);
    }
  } else {
    var cta2Empty = document.getElementById('cta2');
    if (cta2Empty) {
      var s = document.createElement('span');
      s.className = 'soon';
      s.textContent = 'Android app coming soon';
      cta2Empty.appendChild(s);
    }
  }

  // ---- the tappable board ----
  var WEEKS = 12;
  var COUNT = WEEKS * 7;

  // Older 70 days: a believable, fixed pattern (seeded so it never changes).
  function seeded(n) {
    var x = n * 9301 + 49297;
    x = (x * 233280 + 12345) % 2147483647;
    return (x % 1000) / 1000;
  }
  var done = [];
  for (var i = 0; i < COUNT - 14; i++) done.push(seeded(i + 3) < 0.62);
  // Newest 14 days: shows two covered days and a 10-day streak.
  var tail = [1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1];
  tail.forEach(function (v) { done.push(!!v); });

  var grid = document.getElementById('grid');
  var out = document.getElementById('streak');
  if (!grid || !out || !window.Streak) return;

  var cells = [];
  for (var d = 0; d < COUNT; d++) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'cell';
    btn.style.setProperty('--col', Math.floor(d / 7));
    (function (idx) {
      btn.addEventListener('click', function () {
        done[idx] = !done[idx];
        grid.classList.remove('intro');
        render();
      });
    })(d);
    grid.appendChild(btn);
    cells.push(btn);
  }

  function render() {
    var res = window.Streak.compute(done);
    cells.forEach(function (c, idx) {
      var isDone = done[idx];
      var covered = res.bridged.indexOf(idx) !== -1;
      c.className = 'cell' + (isDone ? ' done' : '') + (covered ? ' covered' : '') +
        (idx === COUNT - 1 ? ' today' : '');
      var daysAgo = COUNT - 1 - idx;
      var when = daysAgo === 0 ? 'today' : daysAgo + ' days ago';
      c.setAttribute('aria-pressed', isDone ? 'true' : 'false');
      c.setAttribute('aria-label', when + ': ' + (isDone ? 'done' : covered ? 'covered' : 'missed'));
    });
    out.textContent = res.current;
  }
  render();

  // After the intro wipe finishes, stop it from replaying on re-render.
  window.setTimeout(function () { grid.classList.remove('intro'); }, 1400);

  // ---- sample story card heat grid ----
  var mini = document.getElementById('mini');
  if (mini) {
    for (var m = 0; m < 16 * 7; m++) {
      var el = document.createElement('i');
      if (seeded(m + 40) < 0.7 || m > 16 * 7 - 13) el.className = 'on';
      mini.appendChild(el);
    }
  }
})();
