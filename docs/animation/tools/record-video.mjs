// record-video.mjs
// Deterministically render the tunnel animation to an MP4 by driving the
// built-in tunnelaSeek(t) hook frame-by-frame, then encoding with ffmpeg.
//
// Why this instead of screen-recording Safari?
//   - exact 1280x720 every time (no window chrome / cursor / Retina guesswork)
//   - exact duration & fps (no real-time drift)
//   - reproducible: re-run after editing the HTML to regenerate the video
//
// One-time setup:
//   npm i -D playwright
//   npx playwright install chromium
//   (ffmpeg must be on PATH: `brew install ffmpeg`)
//
// Usage:
//   node tools/record-video.mjs                 # 1920x1080, 60fps, high quality
//   FPS=30 SCALE=1 ./...                          # 1280x720, 30fps
//   CRF=12 ./...                                  # even higher quality (lower = better)
//   BITRATE=30M ./...                             # force an explicit high bitrate instead of CRF
//   SCALE=2 ./...                                 # 2560x1440 source (downscale in ffmpeg if needed)

import { chromium } from 'playwright';
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

// tools/ → animation/ → docs/ → git/ → tunnela/ (project workspace, outside git repo)
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VIDEOS_DIR = path.resolve(__dirname, '../../../../videos');

const FPS   = Number(process.env.FPS   || 60);                       // frames per second
const SCALE = Number(process.env.SCALE || 1.5);                      // 1.5 = 1920x1080, 1 = 1280x720, 2 = 2560x1440
const CRF   = String(process.env.CRF   || '16');                     // quality (lower = better; 14-18 is excellent)
const BITRATE = process.env.BITRATE || '';                           // e.g. "30M" to force an explicit bitrate
const INPUT = process.env.INPUT || 'Tunnela Tunnel Animation.html';  // source HTML (uses anim.css / anim.js)
const OUT   = process.env.OUT   || path.join(VIDEOS_DIR, 'tunnela-tunnels.mp4');
const W = 1280, H = 720;

const root = process.cwd();
const url = pathToFileURL(path.resolve(root, INPUT)).href;
const framesDir = path.resolve(root, '.video-frames');
rmSync(framesDir, { recursive: true, force: true });
mkdirSync(framesDir, { recursive: true });
mkdirSync(path.dirname(OUT), { recursive: true });

console.log(`▶ rendering ${INPUT} @ ${FPS}fps, ${W*SCALE}x${H*SCALE}`);

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: SCALE });
await page.goto(url, { waitUntil: 'load' });

// clean mode (no controls), pin the board at scale 1 / top-left, wait for fonts
await page.evaluate(async () => {
  document.body.classList.add('clean');
  const b = document.getElementById('board');
  b.style.transformOrigin = 'top left';
  b.style.transform = 'scale(1)';
  b.style.position = 'absolute';
  b.style.left = '0';
  b.style.top = '0';
  try { if (document.fonts && document.fonts.ready) await document.fonts.ready; } catch (e) {}
});
await page.waitForTimeout(400);

const total = await page.evaluate(() => window.tunnelaTotal || 28.7);
const N = Math.ceil(total * FPS);
console.log(`▶ ${N} frames (${total.toFixed(1)}s)`);

for (let i = 0; i < N; i++) {
  await page.evaluate((t) => window.tunnelaSeek(t), i / FPS);
  await page.screenshot({
    path: path.join(framesDir, `f${String(i).padStart(5, '0')}.png`),
    clip: { x: 0, y: 0, width: W, height: H },
  });
  if (i % 30 === 0) process.stdout.write(`\r  frame ${i}/${N}`);
}
process.stdout.write(`\r  frame ${N}/${N}\n`);
await browser.close();

const quality = BITRATE
  ? ['-b:v', BITRATE, '-maxrate', BITRATE, '-bufsize', '60M']
  : ['-crf', CRF, '-preset', 'slow'];
console.log(`▶ encoding mp4 with ffmpeg (${BITRATE ? 'bitrate ' + BITRATE : 'crf ' + CRF})…`);
const r = spawnSync('ffmpeg', [
  '-y',
  '-framerate', String(FPS),
  '-i', path.join(framesDir, 'f%05d.png'),
  '-c:v', 'libx264',
  ...quality,
  '-pix_fmt', 'yuv420p',
  '-movflags', '+faststart',
  OUT,
], { stdio: 'inherit' });

if (r.status === 0) {
  rmSync(framesDir, { recursive: true, force: true });
  console.log(`✓ wrote ${OUT}`);
} else {
  console.error('ffmpeg failed — frames left in .video-frames/ for inspection');
}
process.exit(r.status || 0);
