// node --test model/writer/rules.test.js
const test = require('node:test');
const assert = require('node:assert');
const R = require('./rules.js');
const cases = require('./rule_cases.json');

test('every shared case is judged as expected', () => {
  for (const c of cases) {
    const bad = R.check(c.text, 'reply');
    assert.strictEqual(bad.length === 0, c.ok, JSON.stringify(c) + ' -> ' + bad.join('; '));
  }
});

test('an entry is validated as a whole', () => {
  const base = { voice: 'dry', length: 'terse', moment: 'chat', author_line: 'Good morning!', reply: 'Is it.' };
  assert.deepStrictEqual(R.validate(base), []);
  assert.ok(R.validate({ ...base, voice: 'cheerful' }).length);
  assert.ok(R.validate({ ...base, length: 'huge' }).length);
  assert.ok(R.validate({ ...base, moment: 'nonsense' }).length);
  assert.ok(R.validate({ ...base, author_line: '' }).some((p) => /needs what the author says/.test(p)));
  assert.ok(R.validate({ ...base, author_line: 'Hello at 9' }).some((p) => /author line/.test(p)));
  assert.deepStrictEqual(R.validate({ ...base, moment: 'opening', author_line: '' }), []);
  assert.deepStrictEqual(R.validate({ ...base, moment: 'farewell', author_line: '' }), []);
});

test('the voices, lengths and moments match the Dart package and the database', () => {
  assert.deepStrictEqual(R.TONES.length, 12);
  assert.deepStrictEqual(R.LENGTHS, ['terse', 'measured', 'expansive']);
  assert.deepStrictEqual(R.MOMENTS, ['opening', 'returning', 'chat', 'farewell']);
});
