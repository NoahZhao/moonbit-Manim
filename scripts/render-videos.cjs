#!/usr/bin/env node
'use strict';

// Demo export adapter. Geometry and animation come exclusively from MoonBit.
// Requires sharp on Node's module path and FFmpeg (or MOONMANIM_FFMPEG).
const fs = require('node:fs/promises');
const path = require('node:path');
const { spawn } = require('node:child_process');
const sharp = require('sharp');
const { readFileSync } = require('node:fs');

const root = path.resolve(__dirname, '..');
const flags = new Set(process.argv.slice(2));
for (const flag of flags) if (!['--lessons', '--dynamics', '--cnn', '--stills'].includes(flag)) throw new Error('Unknown option: ' + flag);
const lessons = flags.has('--lessons');
const dynamics = flags.has('--dynamics');
const cnn = flags.has('--cnn');
if ([lessons, dynamics, cnn].filter(Boolean).length > 1) throw new Error('Choose one video family');
const stillsOnly = flags.has('--stills');
const command = dynamics ? 'src/cmd/dynamics' : lessons ? 'src/cmd/lessons' : 'src/cmd/videos';
const output = path.join(root, 'output', dynamics ? 'dynamics' : lessons ? 'lessons' : cnn ? 'cnn' : 'videos');
const ffmpeg = process.env.MOONMANIM_FFMPEG || 'ffmpeg';
const narration = dynamics ? JSON.parse(readFileSync(path.join(root, 'site/assets/narration/tangent.json'), 'utf8')) : null;
const scenes = dynamics ? [
  { name: 'tangent', file: '01-tangent', title: '从割线到切线：让导数动起来',
    subtitle: 'Moving points / Secant limit / Tangent slope',
    frames: narration.frames, posters: narration.segments.map(s => Math.round((s.start + s.duration / 2) * 60)), contact: narration.segments.slice(1, 3).map(s => Math.round((s.start + s.duration / 2) * 60)) },
] : lessons ? [
  { name: 'formula', file: '01-quadratic', title: '配方法：从方程到两个根',
    subtitle: 'Completing the square / Semantic formula matching / Graph verification',
    frames: 1158, posters: [180, 480, 780, 1080], contact: [480, 1080] },
  { name: 'matrix', file: '02-linear-algebra', title: '矩阵变换与行列式',
    subtitle: 'Basis vectors / Shear / Area scaling',
    frames: 1080, posters: [120, 480, 840, 1020], contact: [480, 1020] },
  { name: 'pythagoras', file: '03-pythagoras', title: '勾股定理：面积重排证明',
    subtitle: 'Four congruent triangles / Area conservation / Algebraic cancellation',
    frames: 1278, posters: [180, 480, 840, 1200], contact: [480, 1200] },
] : cnn ? [
  { name: 'cnn', file: '01-cnn', title: '卷积神经网络：从像素到特征图',
    subtitle: 'Receptive field / Kernel scan / Feature map', frames: 627,
    posters: [60, 180, 360, 480], contact: [180, 480] },
] : [
  { name: 'morph', file: '01-geometry', title: 'Geometry transforms',
    subtitle: 'Create / Transform / Rotate / Fade', frames: 645 },
  { name: 'create', file: '02-path-creation', title: 'Drawing by arc length',
    subtitle: 'Straight curves / Bezier curves / Separate contours', frames: 528 },
  { name: 'groups', file: '03-group-transforms', title: 'Groups in motion',
    subtitle: 'Parallel animation / Nested transforms / Parent opacity', frames: 660 },
];

function watch(child) {
  let diagnostic = '';
  if (child.stderr) child.stderr.on('data', chunk => {
    diagnostic = (diagnostic + chunk.toString()).slice(-16000);
  });
  return new Promise(resolve => {
    child.once('error', error => resolve({ code: -1, diagnostic: error.message }));
    child.once('close', code => resolve({ code, diagnostic }));
  });
}

function escapeXml(text) {
  return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

function labelFrame(svg, config, frame) {
  const overlay =
    '<g font-family="PingFang SC, Noto Sans CJK SC, DejaVu Sans, sans-serif">' +
    '<rect x="0" y="0" width="1280" height="112" fill="#080c14"/>' +
    '<rect x="0" y="644" width="1280" height="76" fill="#080c14"/>' +
    '<text x="64" y="29" font-size="12" letter-spacing="3" fill="#58c4dd">MOONMANIM / ' + (lessons ? 'MATHEMATICAL LESSONS' : 'ENGINE PREVIEW') + '</text>' +
    '<text x="64" y="68" font-size="30" font-weight="600" fill="#edf3fa">' +
    escapeXml(config.title) + '</text>' +
    '<text x="64" y="94" font-size="15" fill="#94a5bc">' +
    escapeXml(config.subtitle) + '</text>' +
    '<text x="1216" y="66" text-anchor="end" font-family="monospace" font-size="16" fill="#94a5bc">' +
    (frame.index / 60).toFixed(2) + ' s</text>' +
    '<path d="M 64 111 H 1216 M 64 645 H 1216" stroke="#243041" stroke-width="1"/>' +
    '<text x="64" y="678" font-size="16" fill="#cbd7e6">' +
    escapeXml(frame.phase) + '</text>' +
    '<text x="1216" y="703" text-anchor="end" font-size="11" letter-spacing="1" fill="#64758c">1280 x 720 / 60 FPS</text>' +
    '</g>';
  const end = svg.lastIndexOf('</svg>');
  if (end < 0) throw new Error('Frame has no SVG root');
  return svg.slice(0, end) + overlay + svg.slice(end);
}

async function exportScene(config) {
  const temporary = path.join(output, config.file + '.part.mp4');
  const target = path.join(output, config.file + '.mp4');
  const source = spawn('moon', [
    'run', command, '--target', 'native', '--release', '--deny-warn', config.name,
  ], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  source.stdout.setEncoding('utf8'); // JSONL captions can span UTF-8 chunk boundaries.
  const sourceResult = watch(source);
  const encoder = stillsOnly ? null : spawn(ffmpeg, [
    '-hide_banner', '-loglevel', 'error', '-y',
    '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-video_size', '1280x720',
    '-framerate', '60', '-i', 'pipe:0',
    ...(dynamics ? ['-i', path.join(root, 'site', narration.source), '-c:a', 'copy', '-t', String(narration.duration)] : ['-an']),
    '-vf', 'scale=out_color_matrix=bt709',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-threads', '2',
    '-pix_fmt', 'yuv420p', '-color_primaries', 'bt709', '-color_trc', 'bt709',
    '-colorspace', 'bt709', '-movflags', '+faststart',
    '-metadata', 'title=MoonManim - ' + config.title,
    temporary,
  ], { cwd: root, stdio: ['pipe', 'ignore', 'pipe'] });
  const encoderResult = encoder ? watch(encoder) : Promise.resolve({ code: 0 });
  let pipeError;
  if (encoder) encoder.stdin.on('error', error => { pipeError = error; });
  let frames = 0;
  let started = false;
  let finished = false;
  let pending = '';
  const posterFrames = new Set(config.posters || [120, 180, 300]);
  try {
    // Await each raw frame write before reading the next chunk. The OS pipes
    // backpressure the MoonBit producer instead of retaining the whole movie.
    for await (const chunk of source.stdout) {
      pending += chunk.toString('utf8');
      let newline;
      while ((newline = pending.indexOf('\n')) !== -1) {
        const line = pending.slice(0, newline);
        pending = pending.slice(newline + 1);
        if (!line.trim()) continue;
        const record = JSON.parse(line);
        if (record.type === 'start') {
          if (started || record.scene !== config.name || record.width !== 1280 ||
              record.height !== 720 || record.fps !== 60) {
            throw new Error('Unexpected frame stream metadata');
          }
          started = true;
        } else if (record.type === 'end') {
          if (finished || record.frames !== frames || frames !== config.frames ||
              Math.abs(record.duration - frames / 60) > 1e-9) {
            throw new Error('Frame stream ended with an unexpected duration');
          }
          finished = true;
        } else if (record.type === 'frame') {
          if (!started || finished || record.index !== frames ||
              typeof record.phase !== 'string' || typeof record.svg !== 'string') {
            throw new Error('Missing or unordered engine frame');
          }
          if (stillsOnly && !posterFrames.has(frames)) { frames++; continue; }
          const labelled = labelFrame(record.svg, config, record);
          const { data, info } = await sharp(Buffer.from(labelled))
            .flatten({ background: '#080c14' }).removeAlpha().raw()
            .toBuffer({ resolveWithObject: true });
          if (info.width !== 1280 || info.height !== 720 || info.channels !== 3) {
            throw new Error('Unexpected raster frame format');
          }
          if (pipeError) throw pipeError;
          if (encoder) await new Promise((resolve, reject) => {
            encoder.stdin.write(data, error => error ? reject(error) : resolve());
          });
          if (posterFrames.has(frames)) {
            await sharp(data, { raw: { width: 1280, height: 720, channels: 3 } })
              .png().toFile(path.join(output, config.file + '-frame-' + frames + '.png'));
          }
          frames++;
          if (frames % 120 === 0) console.log(config.file + ': ' + frames + '/' + config.frames + ' frames');
        } else {
          throw new Error('Unknown frame stream record');
        }
      }
    }
    const produced = await sourceResult;
    if (produced.code !== 0) throw new Error('MoonBit scene failed: ' + produced.diagnostic);
    if (!started || !finished || pending.trim()) throw new Error('Incomplete engine frame stream');
    if (encoder) encoder.stdin.end();
    const encoded = await encoderResult;
    if (encoded.code !== 0) throw new Error('Video encoder failed: ' + encoded.diagnostic);
    if (encoder) await fs.rename(temporary, target);
    const stat = encoder ? await fs.stat(target) : { size: 0 };
    console.log(stillsOnly ? 'Saved stills: ' + config.file : 'Saved ' + target);
    return {
      file: config.file + '.mp4', title: config.title,
      frames, fps: 60, duration: frames / 60, bytes: stat.size,
    };
  } catch (error) {
    source.kill('SIGTERM');
    if (encoder) { encoder.stdin.destroy(); encoder.kill('SIGTERM'); }
    await Promise.all([sourceResult, encoderResult]);
    await fs.rm(temporary, { force: true });
    throw error;
  }
}

async function compilation() {
  const list = path.join(output, 'concat.txt');
  await fs.writeFile(list, scenes.map(scene => {
    const file = path.join(output, scene.file + '.mp4').replaceAll("'", "'\\''");
    return "file '" + file + "'";
  }).join('\n') + '\n');
  const child = spawn(ffmpeg, [
    '-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0',
    '-i', list, '-c', 'copy', '-movflags', '+faststart',
    path.join(output, dynamics ? '00-all-dynamics.mp4' : lessons ? '00-all-lessons.mp4' : '00-all-demos.mp4'),
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  const result = await watch(child);
  await fs.rm(list, { force: true });
  if (result.code !== 0) throw new Error('Compilation failed: ' + result.diagnostic);
}

async function contactSheet() {
  const images = [];
  for (let row = 0; row < scenes.length; row++) {
    for (const [column, frame] of (scenes[row].contact || [120, 300]).entries()) {
      images.push({
        input: await sharp(path.join(output, scenes[row].file + '-frame-' + frame + '.png'))
          .resize(640, 360).toBuffer(),
        left: column * 640, top: row * 360,
      });
    }
  }
  await sharp({
    create: { width: 1280, height: 360 * scenes.length, channels: 3, background: '#080c14' },
  }).composite(images).png().toFile(path.join(output, 'demo-contact-sheet.png'));
}

async function main() {
  await fs.mkdir(output, { recursive: true });
  const results = [];
  for (const scene of scenes) results.push(await exportScene(scene));
  if (!stillsOnly) await compilation();
  await contactSheet();
  await fs.writeFile(path.join(output, stillsOnly ? 'stills-manifest.json' : 'manifest.json'), JSON.stringify({
    pipeline: 'MoonBit scene -> MoonBit SVG frames -> sharp rasterization -> FFmpeg H.264',
    overlay: 'Titles, phase captions and elapsed time are export labels. Lesson formulas are real MoonBit vector objects, compiled from TeX assets.',
    stillsOnly,
    videos: results,
  }, null, 2) + '\n');
  console.log('All demos complete: ' + output);
}

main().catch(error => { console.error(error); process.exitCode = 1; });
