#!/usr/bin/env node
'use strict';

// Integration checks exercise the compiled engine, not a parallel JS implementation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const site = path.join(root, 'site');
const context = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(site, 'assets/engine.js'), 'utf8'), context);
const render = (name, progress, a, b, c = 0) => {
  const frame = JSON.parse(context.MoonManim.render(name, progress, a, b, c));
  assert.ok(frame.svg?.startsWith('<svg '), `${name} must produce SVG`);
  assert.ok(!/NaN|Infinity|undefined/.test(frame.svg), `${name} must produce finite coordinates`);
  return frame.values;
};
const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-6, `${actual} differs from ${expected}`);
for (const rotation of [-90, 0, 35, 90]) {
  for (const shear of [-1.5, 0, 1.5]) {
    for (const scale of [-1.5, 0, 1, 2]) {
      near(render('matrix', 0, shear, scale, rotation).determinant, 1);
      near(render('matrix', 1, shear, scale, rotation).determinant, scale);
      render('matrix', 0.5, shear, scale, rotation);
    }
  }
}
near(render('bezier', 0, 0, 0).length, 8);
near(render('bezier', 1, 0, 0).drawn, 8);
for (const first of [-3, 0, 3]) {
  for (const second of [-3, 0, 3]) {
    for (const t of [0, 0.5, 1]) {
      const values = render('bezier', t, first, second);
      assert.ok(values.length >= 8);
      near(values.drawn, values.length * t);
    }
  }
}
for (const a of [0.5, 2, 4]) {
  for (const b of [0.5, 3, 4]) {
    for (const t of [0, 0.5, 1]) {
      const values = render('pythagoras', t, a, b);
      near(values.a2 + values.b2, values.c2);
    }
  }
}
for (const t of [0, 0.5, 1]) render('morph', t, 0, 0, t);
assert.ok(JSON.parse(context.MoonManim.render('pythagoras', 0, -1, 2, 0)).error);

// Relative assets must resolve both at / and at /moonbit-Manim/ on GitHub Pages.
const html = fs.readFileSync(path.join(site, 'index.html'), 'utf8');
let assets = 0;
for (const match of html.matchAll(/(?:src|href|poster)="([^"#]+)"/g)) {
  const url = match[1];
  if (/^https?:/.test(url)) continue;
  assert.ok(!url.startsWith('/'), `Use a relative URL for Pages: ${url}`);
  assert.ok(fs.existsSync(path.join(site, url.split('#')[0])), `Missing asset: ${url}`);
  assets++;
}
assert.equal((html.match(/<video\b/g) || []).length, 6);
assert.ok(fs.existsSync(path.join(site, 'assets/licenses/MATHJAX-LICENSE.txt')));
assert.ok(fs.existsSync(path.join(site, 'assets/social.png')));
console.log(`Browser engine verified: identity, shear, rotation, reflection, singular matrices, arc lengths and area invariance. ${assets} local links/assets verified.`);
