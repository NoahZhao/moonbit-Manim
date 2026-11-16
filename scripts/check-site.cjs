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
for (const x of [-3, -1.5, 0, 1.5, 3]) {
  for (const gap of [0, 0.05, 1, 2]) {
    for (const t of [0, 0.25, 0.75, 1]) {
      const values = render('tangent', t, x, gap);
      near(values.x, x);
      near(values.y, x * x / 4);
      near(values.gap, gap * (1 - t));
      near(values.derivative, x / 2);
      near(values.slope, x / 2 + values.gap / 4);
      if (values.gap > 1e-6) near(values.slope,
        (((x + values.gap) ** 2 - x ** 2) / 4) / values.gap);
    }
  }
}
for (const a of [1, 3, 6]) {
  for (const b of [1, 2, 6]) {
    for (const phase of [-180, 0, 90, 180]) {
      for (const t of [0, 0.25, 0.5, 1]) {
        const values = render('lissajous', t, a, b, phase);
        near(values.x, 3.6 * Math.sin(a * t * 2 * Math.PI + phase * Math.PI / 180));
        near(values.y, 2.6 * Math.sin(b * t * 2 * Math.PI));
      }
      near(render('lissajous', 0, a, b, phase).x, render('lissajous', 1, a, b, phase).x);
    }
  }
}
for (const t of [0, 0.5, 1]) {
  const values = render('morph', t, 0, 0, Math.PI / 4);
  near(values.alpha, t);
  near(values.rotation, 45);
}
assert.ok(JSON.parse(context.MoonManim.render('pythagoras', 0, -1, 2, 0)).error);
const lesson = JSON.parse(context.MoonManim.describeLesson());
const narration = JSON.parse(fs.readFileSync(path.join(site, 'assets/narration/tangent.json'), 'utf8'));
near(lesson.duration, narration.duration);
near(lesson.narration.duration, lesson.duration);
assert.ok(fs.statSync(path.join(site, lesson.narration.source)).size > 1000);
assert.ok(fs.readFileSync(path.join(site, 'assets/narration/tangent.vtt'), 'utf8').startsWith('WEBVTT'));
lesson.narration.cues.forEach((cue, i) => {
  assert.equal(cue.text, narration.segments[i].text);
  near(cue.start, narration.segments[i].start);
  near(cue.end, narration.segments[i].end);
  const sample = JSON.parse(context.MoonManim.renderLesson(cue.start / lesson.duration));
  assert.equal(sample.bookmark, cue.key);
  assert.equal(sample.phase, cue.text);
});
assert.equal(lesson.chapters.length, 6);
assert.deepEqual(lesson.parameters.map(p => p.key), ['x', 'h']);
for (const chapter of lesson.chapters) {
  const sample = JSON.parse(context.MoonManim.renderLesson(chapter.start / lesson.duration));
  assert.equal(sample.title, chapter.title);
  assert.ok(sample.svg.startsWith('<svg '));
  assert.ok(!/NaN|Infinity/.test(sample.svg));
}
const retained = context.MoonManim.renderLesson(0.2);
context.MoonManim.renderLesson(1);
context.MoonManim.render('tangent', 0, 3, 2, 0);
assert.equal(context.MoonManim.renderLesson(0.2), retained);
assert.ok(JSON.parse(context.MoonManim.renderLesson(NaN)).error);
for (const args of [['tangent', 0, 4, 1, 0], ['lissajous', 0, 1.5, 2, 0],
  ['lissajous', 0, 1, 7, 0], ['matrix', NaN, 1, 1, 0], ['unknown', 0, 0, 0, 0]]) {
  assert.ok(JSON.parse(context.MoonManim.render(...args)).error);
}

// Relative assets must resolve both at / and at /moonbit-Manim/ on GitHub Pages.
const html = fs.readFileSync(path.join(site, 'index.html'), 'utf8');
const features = fs.readFileSync(path.join(site, 'features.html'), 'utf8');
assert.ok(features.includes('能力支持'));
assert.ok(features.includes('feature-table'));
assert.equal((features.match(/data-feature=/g) || []).length, 20);
assert.ok(fs.existsSync(path.join(site, 'features.css')));
assert.ok(fs.existsSync(path.join(site, 'features.js')));
let assets = 0;
for (const match of html.matchAll(/(?:src|href|poster)="([^"]+)"/g)) {
  const url = match[1];
  if (/^https?:/.test(url) || url.startsWith('#')) continue;
  assert.ok(!url.startsWith('/'), `Use a relative URL for Pages: ${url}`);
  const parsed = new URL(url, 'https://example.com/moonbit-Manim/');
  const local = parsed.pathname.slice('/moonbit-Manim/'.length) || 'index.html';
  assert.ok(fs.existsSync(path.join(site, local)), `Missing asset: ${url}`);
  assets++;
}
for (const match of features.matchAll(/(?:src|href|poster)="([^"]+)"/g)) {
  const url = match[1];
  if (/^https?:/.test(url) || url.startsWith('#')) continue;
  const parsed = new URL(url, 'https://example.com/moonbit-Manim/features.html');
  const local = parsed.pathname.slice('/moonbit-Manim/'.length) || 'index.html';
  assert.ok(fs.existsSync(path.join(site, local)), `Missing features asset: ${url}`);
}
const projects = ['matrix', 'bezier', 'pythagoras', 'tangent', 'lissajous', 'morph'];
assert.equal((html.match(/role="tab"/g) || []).length, projects.length);
assert.equal((html.match(/class="project-card"/g) || []).length, projects.length);
for (const name of projects) {
  assert.ok(html.includes(`data-scene="${name}"`), `Missing experiment tab: ${name}`);
  assert.ok(html.includes(`?scene=${name}#playground`), `Missing project link: ${name}`);
  assert.ok(fs.readFileSync(path.join(site, 'assets/projects', name + '.svg'), 'utf8').startsWith('<svg '));
}
assert.equal((html.match(/<video\b/g) || []).length, 9);
assert.ok(fs.statSync(path.join(site, 'assets/demos/cnn.mp4')).size > 1000);
assert.ok(fs.statSync(path.join(site, 'assets/demos/cnn.webp')).size > 1000);
assert.ok(fs.statSync(path.join(site, 'assets/demos/cnn-pooling.mp4')).size > 1000);
assert.ok(fs.statSync(path.join(site, 'assets/demos/cnn-pooling.webp')).size > 1000);
assert.ok(fs.existsSync(path.join(site, 'assets/licenses/MATHJAX-LICENSE.txt')));
assert.ok(fs.existsSync(path.join(site, 'assets/social.png')));
console.log(`Six browser projects verified: matrices, arc lengths, area invariance, secant limits, oscillator coordinates and morph endpoints. Nine videos and ${assets} local links/assets verified.`);
