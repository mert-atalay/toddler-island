// Sound picker: listen to every candidate recording, mark a trim, keep the best, veto the scary ones.
import { ANIMALS, AREAS } from './animals';

interface Clip {
  title: string; url: string; file: string; seconds: number | null; licence: string; author: string;
  page: string; fromPlan: boolean;
}
type Manifest = Record<string, Clip[]>;
interface Choice { auto?: boolean; keep?: boolean; veto?: boolean; start?: number; end?: number; note?: string }

const ctx = new AudioContext();
const buffers = new Map<string, AudioBuffer>();
const choices: Record<string, Choice> = {}; // keyed by clip file
const notes: Record<string, string> = {}; // per animal
let playing: AudioBufferSourceNode | null = null;
const statusEl = document.getElementById('status')!;

const pending = new Map<string, Promise<AudioBuffer>>();
async function decodeNow(file: string) {
  for (let t = 0; t < 4; t++) {
    const r = await fetch(file);
    if (r.status === 429) { await new Promise((res) => setTimeout(res, 4000 * (t + 1))); continue; }
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const buf = await ctx.decodeAudioData(await r.arrayBuffer());
    buffers.set(file, buf);
    return buf;
  }
  throw new Error('Commons is busy (429), try again in a minute');
}
// Waveforms load two at a time in page order so the page stays responsive; pressing play jumps the queue.
const queue: (() => void)[] = [];
let active = 0;
function pump() {
  while (active < 2 && queue.length) { active++; queue.shift()!(); }
}
function decode(file: string, urgent = false): Promise<AudioBuffer> {
  if (buffers.has(file)) return Promise.resolve(buffers.get(file)!);
  if (urgent) return pending.get(file) ?? decodeNow(file);
  if (!pending.has(file)) {
    pending.set(file, new Promise<AudioBuffer>((resolve, reject) => {
      queue.push(() => decodeNow(file).then(resolve, reject).finally(() => { active--; pump(); }));
      pump();
    }));
  }
  return pending.get(file)!;
}

function draw(canvas: HTMLCanvasElement, buf: AudioBuffer | null, c: Choice, head = -1) {
  const dpr = window.devicePixelRatio || 1;
  const w = (canvas.width = canvas.clientWidth * dpr), h = (canvas.height = canvas.clientHeight * dpr);
  const g = canvas.getContext('2d')!;
  g.clearRect(0, 0, w, h);
  if (!buf) return;
  const dur = buf.duration;
  if (c.start != null && c.end != null) {
    g.fillStyle = '#cdebd7';
    g.fillRect((c.start / dur) * w, 0, ((c.end - c.start) / dur) * w, h);
  }
  const d = buf.getChannelData(0);
  const step = Math.max(1, Math.floor(d.length / w));
  g.fillStyle = '#5b8f72';
  for (let x = 0; x < w; x++) {
    let lo = 1, hi = -1;
    for (let i = x * step, e = Math.min(d.length, i + step); i < e; i++) { const v = d[i]; if (v < lo) lo = v; if (v > hi) hi = v; }
    g.fillRect(x, ((1 - hi) / 2) * h, 1, Math.max(1, ((hi - lo) / 2) * h));
  }
  // one-second ticks
  g.fillStyle = '#0003';
  for (let s = 1; s < dur; s++) g.fillRect((s / dur) * w, h - 6 * dpr, 1, 6 * dpr);
  if (head >= 0) { g.fillStyle = '#a33'; g.fillRect((head / dur) * w, 0, 2 * dpr, h); }
}

function play(file: string, canvas: HTMLCanvasElement) {
  playing?.stop();
  const buf = buffers.get(file);
  if (!buf) return;
  const c = choices[file] || {};
  const start = c.start ?? 0, end = c.end ?? buf.duration;
  const src = ctx.createBufferSource();
  src.buffer = buf;
  src.connect(ctx.destination);
  const t0 = ctx.currentTime;
  src.start(0, start, end - start);
  playing = src;
  const tick = () => {
    if (playing !== src) { draw(canvas, buf, c); return; }
    const pos = start + (ctx.currentTime - t0);
    draw(canvas, buf, c, pos);
    if (pos < end) requestAnimationFrame(tick); else draw(canvas, buf, c);
  };
  tick();
  src.onended = () => { if (playing === src) playing = null; };
}

const fmt = (s: number) => s.toFixed(2) + ' s';

function clipRow(animal: string, clip: Clip) {
  const row = document.createElement('div');
  row.className = 'clip';
  const c = (choices[clip.file] ||= {});
  row.innerHTML = `
    <button class="play" title="Play">▶</button>
    <div>
      <div class="meta"><span class="${clip.fromPlan ? 'plan' : ''}">${clip.title}</span> · ${clip.seconds ? clip.seconds.toFixed(1) + ' s' : ''} · ${clip.licence || '?'} · <a href="${clip.page}" target="_blank">page</a></div>
      <canvas></canvas>
      <div class="trim"></div>
    </div>
    <div class="btns"><button class="keep">Keep</button><button class="veto">Veto</button><button class="clear">Clear cut</button></div>`;
  const canvas = row.querySelector('canvas')!;
  const trimEl = row.querySelector('.trim')!;
  const keepBtn = row.querySelector<HTMLButtonElement>('.keep')!;
  const vetoBtn = row.querySelector<HTMLButtonElement>('.veto')!;
  const sync = () => {
    keepBtn.classList.toggle('on', !!c.keep);
    vetoBtn.classList.toggle('on', !!c.veto);
    row.classList.toggle('kept', !!c.keep);
    row.classList.toggle('vetoed', !!c.veto);
    trimEl.textContent = c.start != null && c.end != null ? `${c.auto ? 'Automatic cut' : 'Cut'}: ${fmt(c.start)} to ${fmt(c.end)} (${fmt(c.end - c.start)})` : '';
    draw(canvas, buffers.get(clip.file) ?? null, c);
    updateCount(animal);
  };
  decode(clip.file).then(sync).catch((e) => {
    trimEl.innerHTML = `<span class="err">Could not load (${String(e).slice(0, 70)}). Press ▶ to retry.</span>`;
  });

  row.querySelector('.play')!.addEventListener('click', async () => {
    await ctx.resume();
    try { await decode(clip.file, true); play(clip.file, canvas); sync(); }
    catch (e) { trimEl.innerHTML = `<span class="err">${String(e).slice(0, 80)}</span>`; }
  });
  keepBtn.addEventListener('click', () => {
    if (!c.keep && keptCount(animal) >= 3) { statusEl.textContent = 'Three kept already for this animal'; return; }
    c.keep = !c.keep; if (c.keep) c.veto = false; sync();
  });
  vetoBtn.addEventListener('click', () => { c.veto = !c.veto; if (c.veto) c.keep = false; sync(); });
  row.querySelector('.clear')!.addEventListener('click', () => { delete c.start; delete c.end; delete c.auto; sync(); });

  // drag to select the cut
  let dragFrom: number | null = null;
  const timeAt = (e: PointerEvent) => {
    const buf = buffers.get(clip.file); if (!buf) return 0;
    const r = canvas.getBoundingClientRect();
    return Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)) * buf.duration;
  };
  canvas.addEventListener('pointerdown', (e) => { dragFrom = timeAt(e); canvas.setPointerCapture(e.pointerId); });
  canvas.addEventListener('pointermove', (e) => {
    if (dragFrom == null) return;
    const t = timeAt(e);
    c.start = Math.min(dragFrom, t); c.end = Math.max(dragFrom, t); delete c.auto; sync();
  });
  canvas.addEventListener('pointerup', async (e) => {
    if (dragFrom == null) return;
    const t = timeAt(e);
    if (Math.abs(t - dragFrom) < 0.05) { delete c.start; delete c.end; delete c.auto; }
    dragFrom = null; sync();
    if (c.start != null) { await ctx.resume(); play(clip.file, canvas); }
  });
  return row;
}

let manifest: Manifest = {};
const keptCount = (animal: string) => (manifest[animal] || []).filter((x) => choices[x.file]?.keep).length;
function updateCount(animal: string) {
  const el = document.querySelector(`[data-count="${animal}"]`);
  if (el) { const n = keptCount(animal); el.textContent = n ? `${n} kept` : 'none kept yet'; }
}

async function main() {
  manifest = await fetch('/sounds/candidates.json').then((r) => r.json());
  try {
    const saved = await fetch('/api/choices/sounds').then((r) => r.json());
    if (saved.choices) Object.assign(choices, saved.choices);
    if (saved.notes) Object.assign(notes, saved.notes);
    if (saved.savedAt) statusEl.textContent = `Last saved ${new Date(saved.savedAt).toLocaleString()}`;
  } catch { /* nothing saved yet */ }

  // Only the animals the parent picked a model for on the lineup page (all of them if nothing is saved yet).
  let inGame = (_k: string) => true;
  try {
    const models = await fetch('/api/choices/models').then((r) => r.json());
    if (models.picks) inGame = (k) => !!models.picks[k] && models.picks[k].id !== 'none';
  } catch { /* lineup not saved yet */ }
  const list = document.getElementById('list')!;
  const groups: [string, { key: string; name: string }[]][] = AREAS
    .map((area): [string, { key: string; name: string }[]] => [area, ANIMALS.filter((a) => a.area === area && inGame(a.key))])
    .filter(([, as]) => as.length);
  groups.push(['Background', [{ key: 'background', name: 'Birdsong, pigeon, bee' }]]);
  for (const [area, animals] of groups) {
    const h = document.createElement('h2'); h.textContent = area; list.appendChild(h);
    for (const a of animals) {
      const box = document.createElement('div');
      box.className = 'animal';
      box.innerHTML = `<b>${a.name}</b><span class="count" data-count="${a.key}"></span>`;
      for (const clip of manifest[a.key] || []) box.appendChild(clipRow(a.key, clip));
      if (!(manifest[a.key] || []).length) box.insertAdjacentHTML('beforeend', '<div class="err">No recordings downloaded</div>');
      const ta = document.createElement('textarea');
      ta.placeholder = 'Notes, e.g. "all too scary, find a softer one"';
      ta.value = notes[a.key] || '';
      ta.addEventListener('input', () => { notes[a.key] = ta.value; });
      box.appendChild(ta);
      list.appendChild(box);
      updateCount(a.key);
    }
  }
}

document.getElementById('save')!.addEventListener('click', async () => {
  const kept: Record<string, unknown[]> = {};
  for (const [animal, clips] of Object.entries(manifest)) {
    kept[animal] = clips.filter((c) => choices[c.file]?.keep).map((c) => ({ ...c, start: choices[c.file].start ?? null, end: choices[c.file].end ?? null, auto: !!choices[c.file].auto }));
  }
  const shown = new Set([...document.querySelectorAll<HTMLElement>('[data-count]')].map((e) => e.dataset.count));
  const missing = ANIMALS.filter((a) => shown.has(a.key) && !kept[a.key]?.length).map((a) => a.name);
  const r = await fetch('/api/choices/sounds', { method: 'POST', body: JSON.stringify({ kept, missing, choices, notes }) });
  statusEl.textContent = r.ok ? `Saved${missing.length ? ` (${missing.length} animals with nothing kept)` : ', every animal has a sound'}` : 'Save failed';
});

main();
