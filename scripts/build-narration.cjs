#!/usr/bin/env node
'use strict';

// TTS is a build-time provider. The runtime only consumes measured timings.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const directory = path.join(root, 'site/assets/narration');
const cache = path.join(root, 'output/narration');
const ffmpeg = process.env.MOONMANIM_FFMPEG || 'ffmpeg';
const voice = process.env.MOONMANIM_TTS_VOICE || 'Tingting';
const rate = Number(process.env.MOONMANIM_TTS_RATE || 145);
const recordings = process.env.MOONMANIM_TTS_RECORDINGS;
if (!Number.isFinite(rate) || rate < 80 || rate > 400) throw new Error('TTS rate must be 80–400');
const speech = JSON.parse(execFileSync('moon', ['run', 'src/cmd/dynamics', '--target', 'native',
  '--release', '--deny-warn', 'narration-script'], { cwd: root, encoding: 'utf8' }));
fs.mkdirSync(directory, { recursive: true });
fs.mkdirSync(cache, { recursive: true });

const provider = recordings ? {
  name: 'recorded',
  synthesize(segment, output) {
    const source = path.resolve(recordings, segment.key + '.wav');
    if (!fs.existsSync(source)) throw new Error('Missing narration recording: ' + source);
    execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', source, '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', output]);
  },
} : {
  name: 'macos-say',
  synthesize(text, speed, output) {
    if (process.platform !== 'darwin') throw new Error('Use MOONMANIM_TTS_RECORDINGS on platforms without macOS say');
    const aiff = output + '.aiff';
    // argv values are passed directly; authored speech never becomes shell code.
    execFileSync('say', ['-v', voice, '-r', String(speed), '-o', aiff, text]);
    execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', aiff, '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', output]);
    fs.unlinkSync(aiff);
  },
};

const styleDefaults = {
  neutral: { pitch: 0, energy: 0 },
  curious: { pitch: 1.2, energy: 0.7 },
  reveal: { pitch: -0.8, energy: 1.0 },
  calm: { pitch: -1.0, energy: -0.5 },
  inviting: { pitch: 0.8, energy: 0.5 },
};
const delivery = beat => {
  const defaults = styleDefaults[beat.style || 'neutral'];
  if (!defaults) throw new Error(`Unknown narration style: ${beat.style}`);
  const pitch = Number(beat.pitch || 0) + defaults.pitch;
  const energy = Number(beat.energy || 0) + defaults.energy;
  if (!Number.isFinite(pitch) || pitch < -6 || pitch > 6 ||
      !Number.isFinite(energy) || energy < -6 || energy > 6) {
    throw new Error(`Invalid delivery controls for beat: ${beat.text}`);
  }
  return { pitch, energy };
};

const transform = (input, output, beat) => {
  const { pitch, energy } = delivery(beat);
  const filters = [];
  if (Math.abs(pitch) > 0.001) {
    const ratio = Math.pow(2, pitch / 12);
    // Change pitch while restoring the original duration for timeline stability.
    filters.push(`asetrate=${48000 * ratio},aresample=48000,atempo=${1 / ratio}`);
  }
  if (Math.abs(energy) > 0.001) filters.push(`volume=${Math.pow(10, energy / 20).toFixed(6)}`);
  const args = ['-v', 'error', '-y', '-i', input];
  if (filters.length) args.push('-af', filters.join(','));
  args.push('-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', output);
  execFileSync(ffmpeg, args);
};

let totalFrames = 0;
const segments = [];
const padded = [];
for (const segment of speech) {
  if (!/^[a-z][a-z0-9-]*$/.test(segment.key)) throw new Error('Invalid speech key');
  const beats = segment.beats?.length ? segment.beats : [{ text: segment.text, rate, pauseAfter: 0.2, style: 'neutral', pitch: 0, energy: 0 }];
  const sourceHash = recordings ? crypto.createHash('sha256').update(fs.readFileSync(path.resolve(recordings, segment.key + '.wav'))).digest('hex') : '';
  const hash = crypto.createHash('sha256').update(JSON.stringify({ provider: provider.name, voice, rate, ...segment, sourceHash })).digest('hex');
  const wav = path.join(cache, hash + '.wav');
  if (recordings) {
    if (!fs.existsSync(wav) || fs.statSync(wav).size < 1000) provider.synthesize(segment, wav);
  } else if (!fs.existsSync(wav) || fs.statSync(wav).size < 1000) {
    const beatFiles = [];
    for (const [index, beat] of beats.entries()) {
      const beatHash = crypto.createHash('sha256').update(JSON.stringify({ voice, ...beat, delivery: delivery(beat) })).digest('hex');
      const raw = path.join(cache, `${beatHash}.wav`);
      if (!fs.existsSync(raw) || fs.statSync(raw).size < 1000) {
        const speech = path.join(cache, `${beatHash}-speech.wav`);
        if (!fs.existsSync(speech) || fs.statSync(speech).size < 1000) {
          // Reuse pre-style cached speech when available. This keeps a build
          // deterministic on machines where macOS say is unavailable.
          const legacyHash = crypto.createHash('sha256').update(JSON.stringify({
            voice, text: beat.text, rate: beat.rate, pauseAfter: beat.pauseAfter,
          })).digest('hex');
          const legacy = path.join(cache, `${legacyHash}.wav`);
          if (fs.existsSync(legacy) && fs.statSync(legacy).size >= 1000) fs.copyFileSync(legacy, speech);
          else provider.synthesize(beat.text, beat.rate || rate, speech);
        }
        transform(speech, raw, beat);
      }
      const measure = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'a:0',
        '-show_entries', 'stream=duration_ts,sample_rate', '-of', 'json', raw], { encoding: 'utf8' })).streams[0];
      const pauseSamples = Math.max(0, Math.round(Number(beat.pauseAfter || 0) * 48000));
      const paddedBeat = path.join(cache, `${hash}-${index}.wav`);
      execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', raw,
        '-af', `apad=whole_len=${Number(measure.duration_ts) + pauseSamples},atrim=end_sample=${Number(measure.duration_ts) + pauseSamples}`,
        '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', paddedBeat]);
      beatFiles.push(paddedBeat);
    }
    const beatInputs = beatFiles.flatMap(file => ['-i', file]);
    const beatFilter = beatFiles.map((_, index) => `[${index}:a]`).join('') + `concat=n=${beatFiles.length}:v=0:a=1[a]`;
    execFileSync(ffmpeg, ['-v', 'error', '-y', ...beatInputs, '-filter_complex', beatFilter, '-map', '[a]',
      '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', wav]);
  }
  const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'a:0',
    '-show_entries', 'stream=duration_ts,sample_rate', '-of', 'json', wav], { encoding: 'utf8' })).streams[0];
  if (Number(probe.sample_rate) !== 48000 || !(probe.duration_ts > 0)) throw new Error('Invalid PCM narration');
  // 800 audio samples per 60 fps frame. Add 200ms for a natural chapter pause.
  const frames = Math.ceil(probe.duration_ts / 800) + 12;
  const duration = frames / 60;
  const file = path.join(cache, segment.key + '-padded.wav');
  execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', wav, '-af', `apad=whole_len=${frames * 800},atrim=end_sample=${frames * 800}`, '-c:a', 'pcm_s16le', file]);
  padded.push(file);
    segments.push({ ...segment, start: totalFrames / 60, end: (totalFrames + frames) / 60,
    duration, frames, spokenDuration: probe.duration_ts / 48000, cacheKey: hash });
  totalFrames += frames;
  console.log(`${segment.key}: ${duration.toFixed(3)}s (${frames} frames)`);
}
const inputs = padded.flatMap(file => ['-i', file]);
const filter = padded.map((_, i) => `[${i}:a]`).join('') + `concat=n=${padded.length}:v=0:a=1[a]`;
execFileSync(ffmpeg, ['-v', 'error', '-y', ...inputs, '-filter_complex', filter, '-map', '[a]', '-c:a', 'pcm_s16le', path.join(cache, 'tangent.wav')]);
execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', path.join(cache, 'tangent.wav'), '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', path.join(directory, 'tangent.m4a')]);
const manifest = { version: 1, provider: provider.name, voice, rate, language: 'zh-CN',
  source: 'assets/narration/tangent.m4a', sampleRate: 48000, fps: 60,
  frames: totalFrames, duration: totalFrames / 60, segments };
fs.writeFileSync(path.join(directory, 'tangent.json'), JSON.stringify(manifest, null, 2) + '\n');
const stamp = seconds => {
  const ms = Math.round(seconds * 1000);
  return `${String(Math.floor(ms / 3600000)).padStart(2, '0')}:${String(Math.floor(ms / 60000) % 60).padStart(2, '0')}:${String(Math.floor(ms / 1000) % 60).padStart(2, '0')}.${String(ms % 1000).padStart(3, '0')}`;
};
fs.writeFileSync(path.join(directory, 'tangent.vtt'), 'WEBVTT\n\n' + segments.map(s => `${s.key}\n${stamp(s.start)} --> ${stamp(s.end)}\n${s.text}\n`).join('\n'));
fs.writeFileSync(path.join(root, 'src/lessons/tangent/narration.generated.mbt'),
  '// Generated by npm run narration from measured audio. Do not edit.\n///|\nfn narration_durations() -> Array[Double] {\n  [' + segments.map(s => s.duration).join(', ') + ']\n}\n');
console.log(`Narration compiled: ${manifest.duration.toFixed(3)}s / ${totalFrames} frames. Cached speech in output/narration/.`);
