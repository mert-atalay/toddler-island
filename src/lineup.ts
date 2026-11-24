// Animal lineup: every candidate model side by side under the game's lighting, at a fair real-world scale.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import { CSS2DRenderer, CSS2DObject } from 'three/addons/renderers/CSS2DRenderer.js';
import { ANIMALS, AREAS } from './animals';
import { addSunnyLook, makeGrass, makeRenderer } from './look';

interface Candidate {
  id: string; title: string; creator: string; licence: string; animated: boolean; page: string; file: string;
}
type Catalogue = Record<string, Candidate[]>;

const canvas = document.getElementById('view') as HTMLCanvasElement;
const renderer = makeRenderer(canvas);
const scene = new THREE.Scene();
addSunnyLook(scene, 70);
scene.add(makeGrass(400));

const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 1000);
camera.position.set(0, 18, 40);
const labels = new CSS2DRenderer();
labels.domElement.style.cssText = 'position:fixed;top:0;left:0;pointer-events:none;overflow:hidden';
document.body.appendChild(labels.domElement);
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.maxPolarAngle = Math.PI * 0.49;

function resize() {
  const w = window.innerWidth - 340, h = window.innerHeight;
  renderer.setSize(w, h, false);
  labels.setSize(w, h);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

// --- layout: one row per area (rows far apart so nothing blocks the view), stations side by side ---
const ROW_GAP = 45;
const slotWidth = (h: number) => Math.max(1.6, Math.min(h * 2.2, 5));
const stationPos = new Map<string, THREE.Vector3>();
for (const [ri, area] of AREAS.entries()) {
  const row = ANIMALS.filter((x) => x.area === area);
  const widths = row.map((a) => slotWidth(a.height) * 3 + 3);
  let x = -widths.reduce((s, w) => s + w, 0) / 2;
  row.forEach((a, i) => {
    stationPos.set(a.key, new THREE.Vector3(x + widths[i] / 2, 0, -ri * ROW_GAP));
    x += widths[i];
  });
}

// Some static models were authored lying down (a different "up" axis); clicking one tries the next orientation.
const ORIENTS: [number, number, number][] = [[0, 0, 0], [-Math.PI / 2, 0, 0], [Math.PI / 2, 0, 0], [0, 0, Math.PI / 2], [0, 0, -Math.PI / 2]];
function nextOrient(inner: THREE.Object3D) {
  const d = inner.userData as { orient?: number; height: number; root: THREE.Object3D; label?: HTMLElement; labelObj: THREE.Object3D };
  d.orient = ((d.orient ?? 0) + 1) % ORIENTS.length;
  d.root.rotation.set(...ORIENTS[d.orient]);
  d.root.position.set(0, 0, 0);
  d.root.scale.set(1, 1, 1);
  inner.scale.set(1, 1, 1);
  inner.position.set(0, 0, 0);
  const parent = inner.parent!;
  parent.remove(inner); // measure in local space, not the station's world position
  const size = prepare(inner, d.height);
  parent.add(inner);
  d.labelObj.position.y = size.y + 0.25;
  if (d.label) d.label.querySelector('small')!.textContent = d.orient ? ' static, turned' : ' static';
}

const mixers: THREE.AnimationMixer[] = [];
const clickable: THREE.Object3D[] = [];
const picks: Record<string, string> = {};
const labelEls = new Map<string, HTMLElement>(); // candidate id -> label
const stations = new Map<string, THREE.Object3D>(); // candidate id -> model group
const labelObjs: THREE.Object3D[] = [];
const tmpV = new THREE.Vector3();

function playNext(root: THREE.Object3D) {
  const d = root.userData as { mixer?: THREE.AnimationMixer; clips?: THREE.AnimationClip[]; idx?: number; action?: THREE.AnimationAction; label?: HTMLElement; title?: string };
  if (!d.mixer || !d.clips?.length) return;
  d.idx = ((d.idx ?? -1) + 1) % d.clips.length;
  d.action?.fadeOut(0.25);
  d.action = d.mixer.clipAction(d.clips[d.idx]).reset().fadeIn(0.25).play();
  if (d.label) d.label.querySelector('small')!.textContent = ` ${d.clips[d.idx].name.split('|').pop()}`;
}

function prepare(obj: THREE.Object3D, targetHeight: number) {
  obj.traverse((o) => {
    const m = o as THREE.Mesh;
    if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; m.frustumCulled = false; }
  });
  obj.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(obj);
  const size = box.getSize(new THREE.Vector3());
  const s = targetHeight / Math.max(size.y, 1e-6);
  obj.scale.multiplyScalar(s);
  obj.updateMatrixWorld(true);
  const box2 = new THREE.Box3().setFromObject(obj);
  const centre = box2.getCenter(new THREE.Vector3());
  obj.position.x -= centre.x;
  obj.position.z -= centre.z;
  obj.position.y -= box2.min.y;
  return box2.getSize(new THREE.Vector3());
}

const gltf = new GLTFLoader();
const fbx = new FBXLoader();
async function load(file: string): Promise<{ root: THREE.Object3D; clips: THREE.AnimationClip[] }> {
  if (file.endsWith('.fbx')) {
    const o = await fbx.loadAsync(file);
    return { root: o, clips: o.animations };
  }
  const g = await gltf.loadAsync(file);
  return { root: g.scene, clips: g.animations };
}

function preferredClip(clips: THREE.AnimationClip[]) {
  const name = (c: THREE.AnimationClip) => c.name.split('|').pop()!;
  const order = [/^idle$/i, /^idle/i, /^eat/i, /^walk$/i, /^walk/i, /idle/i];
  for (const r of order) { const i = clips.findIndex((c) => r.test(name(c))); if (i >= 0) return i; }
  return 0;
}

async function placeStation(animal: (typeof ANIMALS)[number], list: Candidate[]) {
  const base = stationPos.get(animal.key)!;
  const width = slotWidth(animal.height);
  const results = await Promise.allSettled(list.map((c) => load(c.file)));
  results.forEach((r, i) => {
    const c = list[i];
    const holder = new THREE.Group();
    holder.position.copy(base).add(new THREE.Vector3((i - (list.length - 1) / 2) * width, 0, 0));
    scene.add(holder);
    const el = document.createElement('div');
    el.className = 'label';
    el.innerHTML = `${c.title} <small></small>`;
    labelEls.set(c.id, el);
    const label = new CSS2DObject(el);
    labelObjs.push(label);
    holder.add(label);
    if (r.status === 'rejected') {
      el.innerHTML = `${c.title} <small>failed to load</small>`;
      label.position.y = 0.6;
      console.warn('failed', c.file, r.reason);
      return;
    }
    const { root, clips } = r.value;
    const inner = new THREE.Group();
    inner.add(root);
    const size = prepare(inner, animal.height);
    holder.add(inner);
    label.position.y = size.y + 0.25;
    inner.userData = { label: el, title: c.title, root, height: animal.height, labelObj: label };
    stations.set(c.id, inner);
    if (clips.length) {
      const mixer = new THREE.AnimationMixer(root);
      mixers.push(mixer);
      inner.userData.mixer = mixer;
      inner.userData.clips = clips;
      inner.userData.idx = preferredClip(clips) - 1;
      playNext(inner);
    } else {
      el.querySelector('small')!.textContent = ' static';
    }
    inner.traverse((o) => { o.userData.station = inner; });
    clickable.push(inner);
  });
}

// --- side panel ---
const listEl = document.getElementById('list')!;
const statusEl = document.getElementById('status')!;
const notesEl = document.getElementById('notes') as HTMLTextAreaElement;

function refreshLabels(catalogue: Catalogue) {
  for (const [key, list] of Object.entries(catalogue)) {
    for (const c of list) labelEls.get(c.id)?.classList.toggle('picked', picks[key] === c.id);
  }
}

function flyTo(key: string) {
  const p = stationPos.get(key);
  const a = ANIMALS.find((x) => x.key === key)!;
  if (!p) return;
  const n = (window as unknown as { catalogue: Catalogue }).catalogue[key]?.length || 3;
  const spread = Math.max(1.6, a.height * 2.2) * n;
  const d = Math.max(4, spread * 1.25, a.height * 2.5);
  controls.target.set(p.x, a.height * 0.45, p.z);
  camera.position.set(p.x, a.height * 0.45 + d * 0.3, p.z + Math.min(d, ROW_GAP * 0.8));
  document.querySelectorAll('.animal').forEach((e) => e.classList.toggle('active', (e as HTMLElement).dataset.key === key));
}

function buildPanel(catalogue: Catalogue) {
  for (const area of AREAS) {
    const h = document.createElement('h2');
    h.textContent = area;
    listEl.appendChild(h);
    for (const a of ANIMALS.filter((x) => x.area === area)) {
      const div = document.createElement('div');
      div.className = 'animal';
      div.dataset.key = a.key;
      const opts = (catalogue[a.key] || []).map((c) =>
        `<label><input type="radio" name="${a.key}" value="${c.id}"> ${c.title} <span class="tag ${c.animated ? '' : 'static'}">${c.animated ? 'animated' : 'static'}</span> <span style="color:#999">${c.creator}</span></label>`).join('');
      div.innerHTML = `<b>${a.name}</b>${opts}<label class="none"><input type="radio" name="${a.key}" value="none"> none of these</label>`;
      div.addEventListener('click', (e) => {
        const t = e.target as HTMLInputElement;
        if (t.tagName === 'INPUT') { picks[a.key] = t.value; refreshLabels(catalogue); }
        flyTo(a.key);
      });
      listEl.appendChild(div);
    }
  }
}

async function restore(catalogue: Catalogue) {
  try {
    const saved = await fetch('/api/choices/models').then((r) => r.json());
    if (saved.picks) Object.assign(picks, Object.fromEntries(Object.entries(saved.picks).map(([k, v]) => [k, (v as { id: string }).id])));
    if (saved.notes) notesEl.value = saved.notes;
    for (const [k, id] of Object.entries(picks)) {
      const input = document.querySelector<HTMLInputElement>(`input[name="${k}"][value="${id}"]`);
      if (input) input.checked = true;
    }
    refreshLabels(catalogue);
    if (saved.savedAt) statusEl.textContent = `Last saved ${new Date(saved.savedAt).toLocaleString()}`;
  } catch { /* no saved choices yet */ }
}

document.getElementById('save')!.addEventListener('click', async () => {
  const catalogue = (window as unknown as { catalogue: Catalogue }).catalogue;
  const out: Record<string, unknown> = {};
  for (const a of ANIMALS) {
    const id = picks[a.key];
    const cand = catalogue[a.key]?.find((c) => c.id === id);
    const orient = (stations.get(id)?.userData.orient as number | undefined) ?? 0;
    out[a.key] = id === 'none' ? { id: 'none' } : cand ? { ...cand, rotation: ORIENTS[orient] } : null;
  }
  const missing = ANIMALS.filter((a) => !picks[a.key]).map((a) => a.name);
  const r = await fetch('/api/choices/models', { method: 'POST', body: JSON.stringify({ picks: out, notes: notesEl.value, missing }) });
  statusEl.textContent = r.ok ? `Saved${missing.length ? ` (${missing.length} still to pick)` : ', all 23 picked'}` : 'Save failed';
});

// clicking a model cycles its animations
const ray = new THREE.Raycaster();
canvas.addEventListener('click', (e) => {
  const rect = canvas.getBoundingClientRect();
  const p = new THREE.Vector2(((e.clientX - rect.left) / rect.width) * 2 - 1, -((e.clientY - rect.top) / rect.height) * 2 + 1);
  ray.setFromCamera(p, camera);
  const hit = ray.intersectObjects(clickable, true)[0];
  if (!hit) return;
  const inner = hit.object.userData.station as THREE.Object3D;
  if (inner.userData.clips?.length) playNext(inner); else nextOrient(inner);
});

// --- go ---
const catalogue: Catalogue = await fetch('/models/candidates.json').then((r) => r.json());
(window as unknown as { catalogue: Catalogue }).catalogue = catalogue;
buildPanel(catalogue);
await restore(catalogue);
controls.target.set(0, 0.6, 0);
camera.position.set(0, 9, 26);

const clock = new THREE.Clock();
renderer.setAnimationLoop(() => {
  const dt = clock.getDelta();
  for (const m of mixers) m.update(dt);
  controls.update();
  for (const l of labelObjs) l.visible = l.getWorldPosition(tmpV).distanceTo(camera.position) < 38;
  renderer.render(scene, camera);
  labels.render(scene, camera);
});

let done = 0;
const loadingEl = document.getElementById('loading')!;
await Promise.all(ANIMALS.map(async (a) => {
  await placeStation(a, catalogue[a.key] || []);
  loadingEl.textContent = `Loading models… ${++done}/${ANIMALS.length}`;
}));
loadingEl.remove();
