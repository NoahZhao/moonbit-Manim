#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'site/assets/narration/tangent.json'), 'utf8'));
let frames = 0;
for (const segment of manifest.segments) {
  assert.equal(segment.start, frames / 60);
  assert.ok(segment.spokenDuration > 0 && segment.spokenDuration <= segment.duration);
  frames += segment.frames;
  assert.equal(segment.end, frames / 60);
}
assert.equal(frames, manifest.frames);
const ffmpeg = process.env.MOONMANIM_FFMPEG || 'ffmpeg';
for (const name of ['site/assets/narration/tangent.m4a', 'site/assets/demos/tangent.mp4']) {
  const file = path.join(root, name);
  const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', file], { encoding: 'utf8' }));
  const audio = probe.streams.find(stream => stream.codec_type === 'audio');
  assert.ok(audio, name + ' must contain narration');
  assert.ok(Math.abs(Number(probe.format.duration) - manifest.duration) < 0.05);
  const volume = spawnSync(ffmpeg, ['-hide_banner', '-i', file, '-vn', '-af', 'volumedetect', '-f', 'null', '-'], { encoding: 'utf8' });
  assert.equal(volume.status, 0);
  const match = volume.stderr.match(/mean_volume: ([-\d.]+) dB/);
  assert.ok(match && Number(match[1]) > -60, name + ' must contain audible speech');
  if (name.endsWith('.mp4')) {
    const video = probe.streams.find(stream => stream.codec_type === 'video');
    assert.equal(Number(video.nb_frames), manifest.frames);
  }
}
console.log(`Narration verified: ${frames} synchronized frames, measured chapter boundaries, audible AAC in webpage and MP4.`);
