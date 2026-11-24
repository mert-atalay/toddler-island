// First playable: walk the island at toddler eye height; the child's hello button makes the animals answer.
import * as THREE from 'three';
import { addSunnyLook, makeRenderer } from '../look';
import { heightAt, makeTerrain, makeWater, makeScenery, makeFarm, tickWind, START, type Collider } from './world';
import { Sound } from './audio';
import { Input } from './input';
import { Fx } from './fx';
import { loadAnimals, PLACEMENTS, type Animal } from './creatures';

const EYE = 1.0, WALK = 2.8, TURN = 1.6, LOOK_UP = 0.5, LOOK_DOWN = -0.75, PLAYER_R = 0.35, HELLO_RANGE = 8;

const canvas = document.getElementById('view') as HTMLCanvasElement;
const overlay = document.getElementById('start')!;
const startBtn = document.getElementById('play') as HTMLButtonElement;
const loadingEl = document.getElementById('loading')!;
const hint = document.getElementById('hint')!;

const renderer = makeRenderer(canvas);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(70, 1, 0.05, 600);
camera.rotation.order = 'YXZ';
scene.add(camera);
const { sun } = addSunnyLook(scene, 40);
scene.fog = new THREE.Fog(0xcfe8f5, 70, 260);

const colliders: Collider[] = [];
scene.add(makeTerrain());
const water = makeWater();
scene.add(water.mesh);

// low-poly clouds drifting slowly
const clouds = new THREE.Group();
{
  const mat = new THREE.MeshLambertMaterial({ color: 0xffffff, flatShading: true, emissive: 0x9fb8c8, emissiveIntensity: 0.35, fog: false });
  for (let i = 0; i < 16; i++) {
    const c = new THREE.Group();
    for (let k = 0; k < 4; k++) {
      const s = new THREE.Mesh(new THREE.IcosahedronGeometry(4 + Math.random() * 4, 0), mat);
      s.position.set(k * 5 - 8 + Math.random() * 2, Math.random() * 2, Math.random() * 4);
      s.scale.y = 0.6;
      c.add(s);
    }
    const a = Math.random() * Math.PI * 2, r = 120 + Math.random() * 160;
    c.position.set(Math.cos(a) * r, 55 + Math.random() * 25, Math.sin(a) * r);
    clouds.add(c);
  }
  scene.add(clouds);
}

const sound = new Sound(camera);
const input = new Input(canvas);
const fx = new Fx(scene);
let animals: Animal[] = [];

const player = { pos: new THREE.Vector3(START.x, 0, START.z), vel: new THREE.Vector3(), yaw: START.yaw, pitch: -0.08 };
const now = () => performance.now() / 1000;

async function load() {
  const step = (s: string) => (loadingEl.textContent = s);
  step('Growing the island…');
  const farmClear = await makeFarm(scene, colliders);
  const homes = PLACEMENTS.map((p) => ({ x: p.x, z: p.z, r: p.home * 0.7 + 1.5 }));
  step('Planting trees…');
  await makeScenery(scene, colliders, [...farmClear, ...homes]);
  step('Waking the animals…');
  await sound.load();
  animals = await loadAnimals(sound);
  for (const a of animals) scene.add(a.root);
  loadingEl.textContent = '';
  startBtn.disabled = false;
  startBtn.focus();
}

let started = false;
async function start() {
  if (started) { canvas.requestPointerLock?.(); return; }
  started = true;
  await sound.listener.context.resume();
  overlay.classList.add('gone');
  try { await document.documentElement.requestFullscreen?.(); } catch { /* fine without */ }
  try { await canvas.requestPointerLock?.(); } catch { /* mouse drag still works */ }
  sound.startBed();
  for (const a of animals) a.purr?.play();
  setTimeout(() => hint.classList.add('fade'), 6000);
}
startBtn.addEventListener('click', start);
canvas.addEventListener('click', () => { if (started && document.pointerLockElement !== canvas) canvas.requestPointerLock?.(); });

// --- hello button --------------------------------------------------------------------------
const fwd = new THREE.Vector3();
function hello() {
  camera.getWorldDirection(fwd); fwd.y = 0; fwd.normalize();
  let best: Animal | null = null, bestScore = Infinity;
  for (const a of animals) {
    const dx = a.pos.x - player.pos.x, dz = a.pos.z - player.pos.z, d = Math.hypot(dx, dz);
    if (d > HELLO_RANGE) continue;
    const ang = Math.acos(Math.max(-1, Math.min(1, (dx * fwd.x + dz * fwd.z) / Math.max(d, 1e-3))));
    // nearest to the middle of the view wins; something behind still answers if nothing is in front
    const score = ang + (ang > 0.9 ? 3 : 0) + d * 0.05;
    if (score < bestScore) { bestScore = score; best = a; }
  }
  if (best) best.hello(sound, fx, now());
  else { fx.butterfly(camera); sound.chime(); }
}

// --- movement ------------------------------------------------------------------------------
let splashT = 0, lastGreet = -99, distantT = 12 + Math.random() * 10, pigeonT = 20 + Math.random() * 20;
const grad = (x: number, z: number) => new THREE.Vector2(heightAt(x + 0.3, z) - heightAt(x - 0.3, z), heightAt(x, z + 0.3) - heightAt(x, z - 0.3));

function movePlayer(dt: number) {
  const look = input.takeLook();
  player.yaw -= look.x + input.stickLook.x * TURN * dt;
  player.pitch -= look.y + input.stickLook.y * 1.1 * dt;
  player.pitch = Math.max(LOOK_DOWN, Math.min(LOOK_UP, player.pitch));

  const f = new THREE.Vector3(-Math.sin(player.yaw), 0, -Math.cos(player.yaw));
  const r = new THREE.Vector3(Math.cos(player.yaw), 0, -Math.sin(player.yaw));
  const want = f.multiplyScalar(input.move.y * WALK).add(r.multiplyScalar(input.move.x * WALK));
  player.vel.lerp(want, Math.min(1, dt * 6));

  const prev = player.pos.clone();
  player.pos.addScaledVector(player.vel, dt);

  // wading: the ground gently turns the player back uphill
  let h = heightAt(player.pos.x, player.pos.z);
  if (h < -0.15) {
    const g = grad(player.pos.x, player.pos.z).normalize();
    const push = Math.min(3, (-0.15 - h) * 6) * dt;
    player.pos.x += g.x * push; player.pos.z += g.y * push;
  }
  if (heightAt(player.pos.x, player.pos.z) < -0.45) player.pos.copy(prev);

  // trees, rocks, buildings and animals push softly aside
  const solids: Collider[] = [...colliders, ...animals.map((a) => a.collider)];
  for (const c of solids) {
    const dx = player.pos.x - c.x, dz = player.pos.z - c.z, d = Math.hypot(dx, dz), min = c.r + PLAYER_R;
    if (d > 0.001 && d < min) { const k = Math.min(1, dt * 10) * (min - d); player.pos.x += (dx / d) * k; player.pos.z += (dz / d) * k; }
  }

  h = heightAt(player.pos.x, player.pos.z);
  const targetY = Math.max(h, -0.3) + EYE;
  player.pos.y = player.pos.y ? player.pos.y + (targetY - player.pos.y) * Math.min(1, dt * 10) : targetY;
  camera.position.copy(player.pos);
  camera.rotation.set(player.pitch, player.yaw, 0);

  splashT -= dt;
  if (h < 0.02 && player.vel.lengthSq() > 0.3 && splashT <= 0) { fx.splash(player.pos); splashT = 0.35; }
}

// --- loop ----------------------------------------------------------------------------------
function resize() {
  const w = innerWidth, h = innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h; camera.updateProjectionMatrix();
}
addEventListener('resize', resize);
resize();

const clock = new THREE.Clock();
let fpsAcc = 0, fpsN = 0, fps = 0;
function frame() {
  const dt = Math.min(clock.getDelta(), 0.05);
  const t = clock.elapsedTime;
  const presses = input.poll();
  if (started) {
    for (let i = 0; i < presses; i++) hello();
    movePlayer(dt);
  } else {
    // slow look around the start while loading / waiting
    player.yaw = START.yaw + Math.sin(t * 0.15) * 0.4;
    movePlayer(0);
    if (presses && !startBtn.disabled) startBtn.click();
  }

  const ctx = { sound, now: t, canGreet: () => t - lastGreet > 3, greeted: () => { lastGreet = t; }, colliders };
  for (const a of animals) a.update(dt, player.pos, ctx);

  // now and then an animal calls from far away, so the parent can ask "where is it?"
  distantT -= dt;
  if (started && distantT <= 0) {
    distantT = 18 + Math.random() * 17;
    const far = animals.filter((a) => { const d = a.pos.distanceTo(player.pos); return d > 14 && d < 70 && t - a.lastCall > 20; });
    const a = far[Math.floor(Math.random() * far.length)];
    if (a) { sound.call(a.voice, a.sp.key, false); a.lastCall = t; }
  }
  pigeonT -= dt;
  if (started && pigeonT <= 0) { pigeonT = 25 + Math.random() * 25; sound.background(); }

  fx.tick(dt);
  tickWind(t);
  water.uniforms.time.value = t;
  clouds.children.forEach((c, i) => { c.position.x += dt * (0.6 + (i % 3) * 0.2); if (c.position.x > 300) c.position.x = -300; });
  // the sun's shadow box follows the player
  sun.position.set(player.pos.x + 30, 45, player.pos.z + 20);
  sun.target.position.set(player.pos.x, 0, player.pos.z);

  renderer.render(scene, camera);
  fpsAcc += dt; fpsN++;
  if (fpsAcc > 1) { fps = Math.round(fpsN / fpsAcc); fpsAcc = 0; fpsN = 0; }
  requestAnimationFrame(frame);
}
movePlayer(0);
frame();
load().catch((e) => { loadingEl.textContent = 'Something went wrong loading: ' + e; console.error(e); });

// for testing from the console
Object.assign(window, { __game: { player, input, colliders, heightAt, get animals() { return animals; }, scene, hello, sound, get fps() { return fps; }, camera, renderer } });
