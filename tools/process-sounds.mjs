// node tools/process-sounds.mjs
// Turns the clips kept in choices/sounds.json into game-ready files in public/sounds/game/:
// downloads each original once (downloads/sounds-raw), picks the cut (the parent's own cut if they
// dragged one, otherwise the loudest call, at most 3 s), evens out loudness, adds fades, exports mono MP3.
// Writes public/sounds/game.json, which the game and the sound check page read.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import ffmpeg from 'ffmpeg-static';

const UA = 'toddler-island-asset-check/0.1 (home project)';
const RATE = 22050;
const saved = JSON.parse(fs.readFileSync('choices/sounds.json', 'utf8'));
const kept = saved.kept;
// Longer, quieter sounds that play under the calls rather than as a greeting.
const AMBIENT = { 'Jupey purring.wav': 6, '30goldfinch.ogg': 8, 'Six Horses Galloping By.ogg': 4 };

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function download(url, file) {
  if (fs.existsSync(file) && fs.statSync(file).size > 0) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  for (let t = 0; t < 6; t++) {
    const r = await fetch(url, { headers: { 'User-Agent': UA } });
    if (r.ok) { fs.writeFileSync(file, Buffer.from(await r.arrayBuffer())); await sleep(2000); return; }
    console.log(`  ${r.status}, waiting`);
    await sleep(15000 * (t + 1));
  }
  throw new Error('download failed ' + url);
}
function decode(file) {
  const p = spawnSync(ffmpeg, ['-v', 'error', '-i', file, '-ac', '1', '-ar', String(RATE), '-f', 'f32le', '-'], { maxBuffer: 1 << 30 });
  if (p.status !== 0) throw new Error(p.stderr.toString());
  return new Float32Array(p.stdout.buffer, p.stdout.byteOffset, p.stdout.length / 4);
}
const rms = (d, a, b) => { let s = 0; for (let i = a; i < b; i++) s += d[i] * d[i]; return Math.sqrt(s / Math.max(1, b - a)); };

function pickCut(d, maxLen, ambient) {
  const F = Math.round(RATE * 0.02); // 20 ms frames
  const fr = []; for (let i = 0; i + F <= d.length; i += F) fr.push(rms(d, i, i + F));
  const dur = d.length / RATE;
  if (dur <= maxLen && !ambient) return [0, dur];
  const n = Math.round(maxLen / 0.02);
  if (ambient) { // steadiest loud stretch of the wanted length
    let best = 0, bi = 0, s = 0;
    for (let i = 0; i < fr.length; i++) { s += fr[i]; if (i >= n) s -= fr[i - n]; if (i >= n - 1 && s > best) { best = s; bi = i - n + 1; } }
    return [bi * 0.02, Math.min(dur, (bi + n) * 0.02)];
  }
  // a call: grow out from the loudest frame while the sound stays above the threshold
  const sorted = [...fr].sort((a, b) => a - b);
  const floor = sorted[Math.floor(sorted.length * 0.2)], peak = sorted[sorted.length - 1];
  const thr = Math.max(floor * 4, peak * 0.12);
  const top = fr.indexOf(peak);
  let a = top, b = top, gap = 0;
  const gapMax = 8; // allow 160 ms dips inside one call
  for (let i = top; i >= 0 && top - i < n; i--) { if (fr[i] >= thr) { a = i; gap = 0; } else if (++gap > gapMax) break; }
  gap = 0;
  for (let i = top; i < fr.length && i - a < n; i++) { if (fr[i] >= thr) { b = i; gap = 0; } else if (++gap > gapMax) break; }
  let s = Math.max(0, a * 0.02 - 0.08), e = Math.min(dur, (b + 1) * 0.02 + 0.12);
  if (e - s < 0.5) { const m = (s + e) / 2; s = Math.max(0, m - 0.25); e = Math.min(dur, s + 0.5); }
  return [s, Math.min(e, s + maxLen)];
}

fs.mkdirSync('public/sounds/game', { recursive: true });
const out = {};
for (const [animal, clips] of Object.entries(kept)) {
  if (!clips.length) continue;
  out[animal] = [];
  for (const [i, c] of clips.entries()) {
    const raw = path.join('downloads/sounds-raw', animal, c.title.replace(/[^\w.\-]+/g, '_'));
    await download(c.url, raw);
    const d = decode(raw);
    const ambient = AMBIENT[c.title];
    const own = c.start != null && c.end != null && !c.auto;
    const given = c.start != null && c.end != null;
    const [s, e] = given ? [c.start, c.end] : pickCut(d, ambient || 3, !!ambient);
    const seg = d.subarray(Math.floor(s * RATE), Math.floor(e * RATE));
    // loudness of the active part only, so a call with silence around it is not pushed too hard
    const F = Math.round(RATE * 0.02); const frames = [];
    for (let k = 0; k + F <= seg.length; k += F) frames.push(rms(seg, k, k + F));
    frames.sort((x, y) => y - x);
    const active = frames.slice(0, Math.max(1, Math.ceil(frames.length * 0.5)));
    const level = Math.sqrt(active.reduce((t, v) => t + v * v, 0) / active.length) || 1e-4;
    let pk = 0; for (const v of seg) pk = Math.max(pk, Math.abs(v));
    const target = ambient ? -26 : -18;
    const gain = Math.min(10 ** (target / 20) / level, 10 ** (-1 / 20) / (pk || 1));
    const len = e - s;
    const fin = ambient ? 0.5 : 0.01, fout = ambient ? 0.8 : Math.min(0.15, len * 0.2);
    const name = `${animal}-${i + 1}.mp3`;
    const p = spawnSync(ffmpeg, ['-v', 'error', '-y', '-ss', s.toFixed(3), '-t', len.toFixed(3), '-i', raw, '-ac', '1', '-ar', '44100',
      '-af', `highpass=f=50,volume=${gain.toFixed(4)},afade=t=in:d=${fin},afade=t=out:st=${Math.max(0, len - fout).toFixed(3)}:d=${fout.toFixed(3)}`,
      '-b:a', '128k', path.join('public/sounds/game', name)]);
    if (p.status !== 0) throw new Error(p.stderr.toString());
    out[animal].push({ file: `/sounds/game/${name}`, title: c.title, page: c.page, start: +s.toFixed(2), end: +e.toFixed(2),
      cut: own ? 'yours' : 'automatic', kind: ambient ? 'ambient' : 'call', gainDb: +(20 * Math.log10(gain)).toFixed(1) });
    // write the automatic cut back so the sound picker shows it and the parent can drag to change it
    if (!given) { Object.assign(c, { start: +s.toFixed(2), end: +e.toFixed(2), auto: true }); Object.assign((saved.choices[c.file] ||= {}), { start: c.start, end: c.end, auto: true }); }
    console.log(`${name.padEnd(14)} ${s.toFixed(2)}-${e.toFixed(2)} s (${(e - s).toFixed(2)} s) ${own ? 'your cut' : 'auto'} ${ambient ? 'ambient' : ''} gain ${(20 * Math.log10(gain)).toFixed(1)} dB`);
  }
}
fs.writeFileSync('public/sounds/game.json', JSON.stringify(out, null, 1));
fs.writeFileSync('choices/sounds.json', JSON.stringify(saved, null, 2));
