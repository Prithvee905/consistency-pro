// Run: node web/test/streak.test.js
const assert = require('assert');
const { compute } = require('../public/js/streak.js');

// Helper: list of "days ago" that are done -> boolean array (oldest first).
function fromDaysAgo(daysAgo, length = 30) {
  const arr = new Array(length).fill(false);
  daysAgo.forEach((n) => { arr[length - 1 - n] = true; });
  return arr;
}

// These mirror app/test/streak_test.dart.
assert.strictEqual(compute(fromDaysAgo([0, 1, 2])).current, 3, 'consecutive');
assert.strictEqual(compute(fromDaysAgo([1, 2])).current, 2, 'today not logged yet');

let r = compute(fromDaysAgo([0, 2, 3]));
assert.strictEqual(r.current, 3, 'one missed day is covered');
assert.deepStrictEqual(r.bridged.length, 1);

assert.strictEqual(compute(fromDaysAgo([0, 3])).current, 1, 'two misses in a row break it');
assert.strictEqual(compute(fromDaysAgo([])).current, 0, 'no logs');
assert.strictEqual(compute([]).current, 0, 'empty array');

// Third cover in one streak is refused.
r = compute(fromDaysAgo([0, 2, 4, 6, 8]));
assert.strictEqual(r.bridged.length, 2, 'max two covers');
assert.strictEqual(r.current, 3, 'stops after the second cover: days 0, 2, 4');

// The landing-page demo pattern: tail of 14 days (see js/home.js) gives 10.
const tail = [1,0,1,1,1,0,1,1,1,1,0,1,1,1].map(Boolean);
r = compute(new Array(70).fill(false).concat(tail));
assert.strictEqual(r.current, 10, 'demo streak');
assert.strictEqual(r.bridged.length, 2, 'demo shows two covered days');

console.log('streak.js: all tests passed');
