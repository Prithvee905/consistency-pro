/* Streak rule, identical to the app (app/lib/store.dart, streakFor):
 *  - today not being logged yet does not break the streak
 *  - one missed day can be covered, at most 2 times per streak
 *  - never two missed days in a row
 */
(function (root) {
  var MAX_BRIDGES = 2;

  /** @param {boolean[]} done oldest first, last item = today */
  function compute(done) {
    var i = done.length - 1;
    if (i >= 0 && !done[i]) i -= 1;

    function activityBefore(idx) {
      for (var k = 0; k < idx; k++) if (done[k]) return true;
      return false;
    }

    var current = 0;
    var bridged = [];
    var lastWasBridge = false;

    while (i >= 0) {
      if (done[i]) {
        current += 1;
        lastWasBridge = false;
      } else if (!lastWasBridge && bridged.length < MAX_BRIDGES && activityBefore(i)) {
        bridged.push(i);
        lastWasBridge = true;
      } else {
        break;
      }
      i -= 1;
    }
    // A cover at the very edge of the streak doesn't connect to anything.
    if (lastWasBridge) bridged.pop();

    return { current: current, bridged: bridged };
  }

  var api = { compute: compute, MAX_BRIDGES: MAX_BRIDGES };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.Streak = api;
})(typeof window !== 'undefined' ? window : globalThis);
