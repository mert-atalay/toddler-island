// Animals: four simple states (idle or graze, wander inside a home patch, notice the player, react to hello).
// They never flee or threaten; attack and death clips in the packs stay unused.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { heightAt, type Collider } from './world';
import type { Sound } from './audio';
import type { Fx } from './fx';

interface Species { key: string; height: number; speed: number; radius: number; yawOffset?: number }
export const SPECIES: Record<string, Species> = {
  cow: { key: 'cow', height: 1.45, speed: 0.9, radius: 0.9 },
  horse: { key: 'horse', height: 1.7, speed: 1.1, radius: 0.9 },
  donkey: { key: 'donkey', height: 1.25, speed: 0.9, radius: 0.7 },
  // the farm-pack sheep and pig only have Idle and Jump, so they stay in their patch and jump for hello
  sheep: { key: 'sheep', height: 0.95, speed: 0, radius: 0.55 },
  pig: { key: 'pig', height: 0.8, speed: 0, radius: 0.55 },
  dog: { key: 'dog', height: 0.7, speed: 1.3, radius: 0.45 },
  cat: { key: 'cat', height: 0.35, speed: 0, radius: 0.3, yawOffset: -Math.PI / 2 }, // this model's head points sideways
  deer: { key: 'deer', height: 1.75, speed: 1.0, radius: 0.7 },
};

export interface Placement { key: string; x: number; z: number; home: number }
export const PLACEMENTS: Placement[] = [
  { key: 'cow', x: -50, z: 10, home: 13 }, { key: 'cow', x: -44, z: 2, home: 13 },
  { key: 'horse', x: -38, z: 18, home: 11 },
  { key: 'donkey', x: -57, z: 17, home: 8 },
  { key: 'sheep', x: -40, z: -9, home: 9 }, { key: 'sheep', x: -43, z: -12, home: 9 }, { key: 'sheep', x: -37, z: -12, home: 9 },
  { key: 'pig', x: -60, z: -2, home: 6 }, { key: 'pig', x: -58, z: -6, home: 6 },
  { key: 'dog', x: 8, z: 60, home: 9 },
  { key: 'cat', x: 13, z: 66, home: 0 },
  { key: 'deer', x: -4, z: -54, home: 8 },
];

const clipName = (c: THREE.AnimationClip) => c.name.split('|').pop()!;
function findClip(clips: THREE.AnimationClip[], ...res: RegExp[]) {
  for (const re of res) { const c = clips.find((x) => re.test(clipName(x))); if (c) return c; }
  return undefined;
}

function prepare(obj: THREE.Object3D, targetHeight: number) {
  obj.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh) { m.castShadow = true; m.receiveShadow = false; m.frustumCulled = false; } });
  obj.updateMatrixWorld(true);
  const size = new THREE.Box3().setFromObject(obj).getSize(new THREE.Vector3());
  obj.scale.multiplyScalar(targetHeight / Math.max(size.y, 1e-6));
  obj.updateMatrixWorld(true);
  const b = new THREE.Box3().setFromObject(obj), c = b.getCenter(new THREE.Vector3());
  obj.position.x -= c.x; obj.position.z -= c.z; obj.position.y -= b.min.y;
}

type State = 'idle' | 'wander' | 'notice' | 'react';
const angleTo = (from: number, to: number) => Math.atan2(Math.sin(to - from), Math.cos(to - from));

export class Animal {
  root = new THREE.Group(); // at the ground, turns to face
  hop = new THREE.Group(); // lifts for the hello hop
  mixer: THREE.AnimationMixer;
  idle: THREE.AnimationAction[] = [];
  eat?: THREE.AnimationAction;
  walk?: THREE.AnimationAction;
  jump?: THREE.AnimationAction;
  current?: THREE.AnimationAction;
  state: State = 'idle';
  timer = 2 + Math.random() * 4;
  target = new THREE.Vector2();
  greetCooldown = 3 + Math.random() * 6;
  hopT = -1;
  yaw = Math.random() * Math.PI * 2;
  voice: THREE.PositionalAudio;
  purr?: THREE.PositionalAudio;
  collider: Collider;
  lastCall = -99;

  constructor(public sp: Species, template: THREE.Object3D, clips: THREE.AnimationClip[], public home: Placement, sound: Sound) {
    const model = SkeletonUtils.clone(template);
    this.hop.add(model);
    this.root.add(this.hop);
    this.root.position.set(home.x, heightAt(home.x, home.z), home.z);
    this.mixer = new THREE.AnimationMixer(model);
    const act = (c?: THREE.AnimationClip) => (c ? this.mixer.clipAction(c) : undefined);
    for (const c of [findClip(clips, /^idle$/i), findClip(clips, /^idle_?2$/i), findClip(clips, /idle.*head.?low/i), findClip(clips, /idle/i)]) {
      const a = act(c); if (a && !this.idle.includes(a)) this.idle.push(a);
    }
    this.eat = act(findClip(clips, /^eat/i));
    this.walk = act(findClip(clips, /^walk$/i, /walk/i));
    this.jump = act(findClip(clips, /^jump$/i));
    if (this.jump) { this.jump.setLoop(THREE.LoopOnce, 1); this.jump.clampWhenFinished = true; }
    if (!this.idle.length && clips[0]) this.idle.push(this.mixer.clipAction(clips[0]));
    this.play(this.idle[0], 0);
    this.mixer.update(Math.random() * 3);
    this.voice = sound.makeVoice(this.hop);
    this.voice.position.y = sp.height * 0.8;
    this.collider = { x: home.x, z: home.z, r: sp.radius };
  }

  play(a: THREE.AnimationAction | undefined, fade = 0.35) {
    if (!a || a === this.current) return;
    a.reset().setEffectiveWeight(1).play();
    if (this.current) this.current.crossFadeTo(a, fade, false);
    this.current = a;
  }

  get pos() { return this.root.position; }

  private faceToward(x: number, z: number, rate: number, dt: number) {
    const want = Math.atan2(x - this.pos.x, z - this.pos.z) + (this.sp.yawOffset || 0);
    const d = angleTo(this.yaw, want);
    this.yaw += Math.sign(d) * Math.min(Math.abs(d), rate * dt);
    return Math.abs(d);
  }

  private pickWanderTarget() {
    for (let i = 0; i < 12; i++) {
      const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * this.home.home;
      const x = this.home.x + Math.cos(a) * r, z = this.home.z + Math.sin(a) * r;
      if (heightAt(x, z) > 0.6) { this.target.set(x, z); return true; }
    }
    return false;
  }

  /** The child pressed hello and this animal was chosen. */
  hello(sound: Sound, fx: Fx, now: number) {
    this.state = 'react';
    this.timer = 2.6;
    if (this.jump) { this.current = undefined; this.mixer.stopAllAction(); this.play(this.jump, 0); this.timer = Math.max(2.6, this.jump.getClip().duration + 0.3); }
    else { this.hopT = 0; this.play(this.idle[0], 0.2); }
    sound.call(this.voice, this.sp.key, true);
    this.lastCall = now;
    this.greetCooldown = 8 + Math.random() * 2;
    fx.hearts(new THREE.Vector3(this.pos.x, this.pos.y + this.sp.height * 1.05, this.pos.z));
  }

  update(dt: number, player: THREE.Vector3, ctx: { sound: Sound; now: number; canGreet: () => boolean; greeted: () => void; colliders: Collider[] }) {
    const dist = Math.hypot(player.x - this.pos.x, player.z - this.pos.z);
    this.greetCooldown -= dt;
    this.timer -= dt;

    // Animals greet first: within about 7 m, stop, face the player and call once.
    if ((this.state === 'idle' || this.state === 'wander') && dist < 7 && this.greetCooldown <= 0 && ctx.canGreet()) {
      this.state = 'notice';
      this.timer = 4;
      this.play(this.idle[0]);
      ctx.greeted();
    }

    switch (this.state) {
      case 'idle':
        if (this.timer <= 0) {
          if (this.sp.speed > 0 && Math.random() < 0.6 && this.pickWanderTarget()) { this.state = 'wander'; this.timer = 20; this.play(this.walk); }
          else {
            this.timer = 4 + Math.random() * 6;
            const options = [...this.idle, ...(this.eat ? [this.eat, this.eat] : [])];
            this.play(options[Math.floor(Math.random() * options.length)]);
          }
        }
        break;
      case 'wander': {
        const off = this.faceToward(this.target.x, this.target.y, 1.4, dt);
        const toGo = Math.hypot(this.target.x - this.pos.x, this.target.y - this.pos.z);
        const blockedByPlayer = dist < this.sp.radius + 1.0 && angleTo(this.yaw, Math.atan2(player.x - this.pos.x, player.z - this.pos.z)) < 0.8;
        if (toGo < 0.4 || this.timer <= 0 || blockedByPlayer) { this.state = 'idle'; this.timer = 3 + Math.random() * 5; this.play(this.idle[0]); break; }
        const sp = this.sp.speed * (off > 0.6 ? 0.25 : 1);
        const nx = this.pos.x + Math.sin(this.yaw) * sp * dt, nz = this.pos.z + Math.cos(this.yaw) * sp * dt;
        if (heightAt(nx, nz) < 0.5) { this.state = 'idle'; this.timer = 2; this.play(this.idle[0]); break; }
        this.pos.x = nx; this.pos.z = nz;
        if (this.walk) this.walk.timeScale = 0.6 + 0.6 * (sp / Math.max(this.sp.speed, 0.01));
        break;
      }
      case 'notice': {
        const off = this.faceToward(player.x, player.z, 2.2, dt);
        if (off < 0.35 && this.lastCall < ctx.now - 5) {
          ctx.sound.call(this.voice, this.sp.key, true);
          this.lastCall = ctx.now;
          this.greetCooldown = 8 + Math.random() * 2 + 3;
          this.timer = Math.min(this.timer, 2.5);
        }
        if (this.timer <= 0) { this.state = 'idle'; this.timer = 2 + Math.random() * 3; }
        break;
      }
      case 'react':
        this.faceToward(player.x, player.z, 6, dt);
        if (this.timer <= 0) { this.state = 'idle'; this.timer = 2 + Math.random() * 3; if (this.current === this.jump) this.play(this.idle[0], 0.3); }
        break;
    }

    // soft push out of trees, rocks and buildings
    for (const c of ctx.colliders) {
      if (c === this.collider) continue;
      const dx = this.pos.x - c.x, dz = this.pos.z - c.z, d = Math.hypot(dx, dz), min = c.r + this.sp.radius;
      if (d > 0.001 && d < min) { this.pos.x += (dx / d) * (min - d); this.pos.z += (dz / d) * (min - d); }
    }
    this.collider.x = this.pos.x; this.collider.z = this.pos.z;

    // the hello hop: one happy bounce
    let lift = 0;
    if (this.hopT >= 0) {
      this.hopT += dt;
      const t = this.hopT / 0.5;
      lift = t < 1 ? Math.sin(t * Math.PI) * Math.max(0.18, this.sp.height * 0.22) : 0;
      if (t >= 1) this.hopT = -1;
    }
    this.hop.position.y = lift;
    this.root.position.y = heightAt(this.pos.x, this.pos.z);
    this.root.rotation.y = this.yaw;
    this.mixer.update(dt);

    // the cat purrs when you are right beside it
    if (this.purr) {
      const want = dist < 3.5 ? 1 : 0;
      const v = this.purr.getVolume();
      this.purr.setVolume(v + (want - v) * Math.min(1, dt * 2));
    }
  }
}

export async function loadAnimals(sound: Sound) {
  const models: Record<string, { file: string }> = await fetch('/models/game/models.json').then((r) => r.json());
  const gltf = new GLTFLoader(), fbx = new FBXLoader();
  const templates: Record<string, { obj: THREE.Object3D; clips: THREE.AnimationClip[] }> = {};
  await Promise.all(Object.entries(models).map(async ([key, m]) => {
    if (!SPECIES[key]) return;
    let obj: THREE.Object3D, clips: THREE.AnimationClip[];
    if (m.file.endsWith('.fbx')) { const o = await fbx.loadAsync(m.file); obj = o; clips = o.animations; }
    else { const g = await gltf.loadAsync(m.file); obj = g.scene; clips = g.animations; }
    // the GLB files list every clip twice (with and without the armature prefix); keep one of each
    const seen = new Set<string>();
    clips = clips.filter((c) => { const n = clipName(c).toLowerCase(); if (seen.has(n)) return false; seen.add(n); return true; });
    const holder = new THREE.Group();
    holder.add(obj);
    prepare(obj, SPECIES[key].height);
    templates[key] = { obj: holder, clips };
  }));
  const animals = PLACEMENTS.filter((p) => templates[p.key]).map((p) => new Animal(SPECIES[p.key], templates[p.key].obj, templates[p.key].clips, p, sound));
  for (const a of animals) {
    const purr = sound.bank[a.sp.key]?.ambient[0];
    if (a.sp.key === 'cat' && purr) {
      a.purr = sound.makeVoice(a.hop);
      a.purr.setBuffer(purr); a.purr.setLoop(true); a.purr.setRefDistance(2); a.purr.setVolume(0);
    }
  }
  return animals;
}
