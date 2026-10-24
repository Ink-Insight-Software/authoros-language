// Drives the writing screen in a real browser against a fake Supabase client.
//   NODE_PATH=$(npm root -g) node model/writer/ui.test.mjs
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const page_url = 'file://' + path.join(path.dirname(fileURLToPath(import.meta.url)), 'index.html');

// Installed before the page's own scripts run.
const FAKE = () => {
  const rows = [];
  let session = null;
  const listeners = [];
  const log = { inserts: [], updates: [], deletes: [], otp: [] };
  const done = (data) => Promise.resolve({ data, error: null });
  window.__log = log;
  window.__setSession = (s) => { session = s; listeners.forEach((f) => f('SIGNED_IN', session)); };
  window.__seed = (r) => rows.push(r);
  window.__client = {
    auth: {
      getSession: () => done({ session }),
      onAuthStateChange: (f) => { listeners.push(f); },
      signInWithOtp: (a) => { log.otp.push(a); return done({}); },
      signOut: () => { session = null; listeners.forEach((f) => f('SIGNED_OUT', null)); return done({}); },
    },
    from: () => ({
      select: () => ({ order: () => done(rows.slice().reverse()) }),
      insert: (r) => {
        if (rows.some((x) => x.reply.toLowerCase() === r.reply.toLowerCase())) {
          return Promise.resolve({ error: { message: 'duplicate key value violates unique constraint' } });
        }
        log.inserts.push(r);
        rows.push({ id: 'id' + rows.length, status: 'submitted', ...r });
        return done(null);
      },
      update: (r) => ({ eq: (_c, id) => { log.updates.push([id, r]); Object.assign(rows.find((x) => x.id === id), r); return done(null); } }),
      delete: () => ({ eq: (_c, id) => { log.deletes.push(id); rows.splice(rows.findIndex((x) => x.id === id), 1); return done(null); } }),
    }),
  };
};

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 900, height: 1400 } });
await ctx.route('**/supabase.min.js', (r) => r.fulfill({ contentType: 'text/javascript', body: '' }));
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
await page.addInitScript(FAKE);
await page.goto(page_url);

// Signed out: only the sign-in card.
assert.ok(await page.locator('#signin').isVisible());
assert.ok(!(await page.locator('#app').isVisible()));
await page.fill('#email', 'nonsense');
await page.click('#send');
assert.match(await page.textContent('#signin-message'), /Enter your email/);
await page.fill('#email', 'writer@example.com');
await page.click('#send');
assert.match(await page.textContent('#signin-message'), /Check your email/);
assert.strictEqual(await page.evaluate(() => window.__log.otp[0].email), 'writer@example.com');

// Signed in: the writing form.
await page.evaluate(() => window.__setSession({ user: { email: 'writer@example.com' } }));
assert.ok(await page.locator('#app').isVisible());
assert.strictEqual(await page.textContent('#who-email'), 'writer@example.com');
assert.ok(await page.locator('#add').isDisabled());

// Opening has no author line; chat does.
await page.selectOption('#moment', 'opening');
assert.ok(!(await page.locator('#said-wrap').isVisible()));
await page.selectOption('#moment', 'chat');
assert.ok(await page.locator('#said-wrap').isVisible());

// The rules are shown as you type, and the button waits.
await page.selectOption('#voice', 'sardonic');
await page.fill('#said', 'Good morning!');
await page.fill('#reply', 'Ah, Tom. Back in 5 minutes.');
const problems = await page.locator('#problems li').allTextContents();
assert.ok(problems.some((p) => /digit/.test(p)), problems.join('|'));
assert.ok(problems.some((p) => /name someone/.test(p)), problems.join('|'));
await page.fill('#writtenBy', 'Test Writer');
await page.check('#human');
assert.ok(await page.locator('#add').isDisabled(), 'a rule-breaking line cannot be added');

await page.fill('#reply', 'Is it? Do tell me what is good about it.');
assert.match(await page.textContent('#problems'), /follows the rules/);
assert.strictEqual(await page.textContent('#count'), '10 words');
assert.ok(await page.locator('#add').isEnabled());
await page.uncheck('#human');
assert.ok(await page.locator('#add').isDisabled(), 'the attestation is required');
await page.check('#human');

await page.click('#add');
await page.waitForFunction(() => document.querySelectorAll('#lines .line').length === 1);
const sent = await page.evaluate(() => window.__log.inserts[0]);
assert.deepStrictEqual(sent, {
  written_by: 'Test Writer', rights: 'own', ai_assisted: false,
  voice: 'sardonic', length: 'measured', moment: 'chat',
  author_line: 'Good morning!', reply: 'Is it? Do tell me what is good about it.',
});
assert.match(await page.textContent('#message'), /Added/);
assert.strictEqual(await page.inputValue('#reply'), '');
assert.ok(!(await page.locator('#human').isChecked()), 'the attestation is asked for each line');

// Coverage counts it.
const cell = await page.locator('#coverage tr', { hasText: 'sardonic' }).locator('td').nth(3).textContent();
assert.strictEqual(cell, '1');

// A repeat is explained, not a raw error.
await page.fill('#said', 'Good morning!');
await page.fill('#reply', 'is it? do tell me what is good about it.');
await page.check('#human');
await page.click('#add');
await page.waitForFunction(() => /already have that exact line/.test(document.querySelector('#message').textContent));

// Edit a waiting line.
await page.fill('#reply', 'x');
await page.locator('#lines .line').first().getByText('Edit').click();
assert.strictEqual(await page.inputValue('#reply'), 'Is it? Do tell me what is good about it.');
assert.strictEqual(await page.textContent('#add'), 'Save changes');
await page.fill('#reply', 'Is it. Do tell me why.');
await page.check('#human');
await page.click('#add');
await page.waitForFunction(() => /Saved/.test(document.querySelector('#message').textContent));
const upd = await page.evaluate(() => window.__log.updates[0]);
assert.strictEqual(upd[1].reply, 'Is it. Do tell me why.');
assert.ok(!('written_by' in upd[1]) && !('rights' in upd[1]), 'an edit changes only the line');
assert.strictEqual(await page.textContent('#add'), 'Add line');

// A reviewed line is read-only; removing a waiting one asks first.
await page.evaluate(() => window.__seed({ id: 'ok1', status: 'approved', voice: 'warm', length: 'measured', moment: 'opening', author_line: '', reply: 'Hello, and welcome.' }));
await page.evaluate(() => window.__setSession({ user: { email: 'writer@example.com' } }));
await page.waitForFunction(() => document.querySelectorAll('#lines .line').length === 2);
const approved = page.locator('#lines .line', { hasText: 'Hello, and welcome.' });
assert.strictEqual(await approved.getByText('Edit').count(), 0);
assert.strictEqual(await approved.getByText('Remove').count(), 0);
assert.match(await approved.textContent(), /approved/);
page.once('dialog', (d) => d.dismiss());
await page.locator('#lines .line', { hasText: 'Do tell me why' }).getByText('Remove').click();
assert.strictEqual(await page.evaluate(() => window.__log.deletes.length), 0, 'declined: nothing removed');
page.once('dialog', (d) => d.accept());
await page.locator('#lines .line', { hasText: 'Do tell me why' }).getByText('Remove').click();
await page.waitForFunction(() => document.querySelectorAll('#lines .line').length === 1);

// Output is text, never markup.
await page.evaluate(() => window.__seed({ id: 'x', status: 'submitted', voice: 'dry', length: 'terse', moment: 'opening', author_line: '', reply: '<img src=x onerror=window.__pwned=1>' }));
await page.evaluate(() => window.__setSession({ user: { email: 'writer@example.com' } }));
await page.waitForFunction(() => document.querySelectorAll('#lines .line').length === 2);
assert.ok(!(await page.evaluate(() => window.__pwned)), 'rows are shown as text');

// Sign out returns to sign in.
await page.click('#signout');
assert.ok(await page.locator('#signin').isVisible());
assert.ok(!(await page.locator('#app').isVisible()));

// Phone width: nothing scrolls sideways.
await page.setViewportSize({ width: 360, height: 800 });
await page.evaluate(() => window.__setSession({ user: { email: 'writer@example.com' } }));
const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
assert.ok(overflow <= 1, 'page scrolls sideways by ' + overflow);

assert.deepStrictEqual(errors, [], 'no page errors: ' + errors.join('; '));
await page.screenshot({ path: process.env.SHOT || '/tmp/writer.png', fullPage: true });
await browser.close();
console.log('writing screen: all checks passed');
