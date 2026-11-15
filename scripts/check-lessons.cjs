#!/usr/bin/env node
'use strict';

// Compare the actual native video adapter with the shipped browser runtime.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const context = vm.createContext({ console });
vm.runInContext(fs.readFileSync(path.join(root, 'site/assets/engine.js'), 'utf8'), context);
const metadata = JSON.parse(context.MoonManim.describeLesson());
const source = execFileSync('moon', ['run', 'src/cmd/dynamics', '--target', 'native',
  '--release', '--deny-warn', 'samples'], { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
const frames = source.trim().split('\n').map(JSON.parse);
const number = /[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?/g;
const near = (a, b) => assert.ok(Math.abs(a - b) < 1e-7, `${a} differs from ${b}`);
for (const native of frames) {
  const browser = JSON.parse(context.MoonManim.renderLesson(native.time / metadata.duration));
  assert.equal(browser.chapter, native.chapter);
  assert.equal(browser.phase, native.phase);
  for (const key of Object.keys(native.values)) near(browser.values[key], native.values[key]);
  assert.equal(browser.svg.replace(number, '#'), native.svg.replace(number, '#'));
  const nativeNumbers = [...native.svg.matchAll(number)].map(match => Number(match[0]));
  const browserNumbers = [...browser.svg.matchAll(number)].map(match => Number(match[0]));
  assert.equal(nativeNumbers.length, browserNumbers.length);
  nativeNumbers.forEach((value, i) => near(value, browserNumbers[i]));
}
console.log(`${frames.length} native/browser checkpoints agree: chapter, parameters and every SVG coordinate (tolerance 1e-7 px).`);
