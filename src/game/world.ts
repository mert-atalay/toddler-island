// The island: one height function for everything, a flat-shaded terrain mesh, water, and scattered scenery.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { FBXLoader } from 'three/addons/loaders/FBXLoader.js';

export const ISLAND = 100; // rough radius in metres
export const POND = { x: 0, z: 0, r: 11 };
// Areas (west = -x, south = +z). Start is in the home garden.
export const AREA = {
  garden: new THREE.Vector2(4, 58),
  meadow: new THREE.Vector2(-50, 4),
  forest: new THREE.Vector2(-4, -54),
};
export const START = { x: 6, z: 70, yaw: 0 }; // yaw 0 looks toward -z (north, into the island)

// --- deterministic noise -------------------------------------------------------------------
function hash(x: number, z: number) {
  const s = Math.sin(x * 127.1 + z * 311.7) * 43758.5453;
  return s - Math.floor(s);
}
function vnoise(x: number, z: number) {
  const xi = Math.floor(x), zi = Math.floor(z), xf = x - xi, zf = z - zi;
  const u = xf * xf * (3 - 2 * xf), v = zf * zf * (3 - 2 * zf);
  const a = hash(xi, zi), b = hash(xi + 1, zi), c = hash(xi, zi + 1), d = hash(xi + 1, zi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
const smooth = (a: number, b: number, t: number) => { const x = Math.min(1, Math.max(0, (t - a) / (b - a))); return x * x * (3 - 2 * x); };

export function shoreRadius(x: number, z: number) {
  const a = Math.atan2(z, x);
  return ISLAND - 6 + 7 * Math.sin(3 * a + 0.6) + 4 * Math.sin(5 * a + 2.1) + 2.5 * Math.sin(9 * a);
}

/** Distance to the walking loop: a wobbly ring around the pond that passes every area. */
export function pathDistance(x: number, z: number) {
  const a = Math.atan2(z, x);
  const ring = 46 + 5 * Math.sin(2 * a + 1.3) + 3 * Math.sin(3 * a);
  let d = Math.abs(Math.hypot(x, z) - ring);
  // spur from the loop down to the start in the garden
  const sx = START.x, sz = START.z, ex = 2, ez = 46;
  const t = Math.max(0, Math.min(1, ((x - sx) * (ex - sx) + (z - sz) * (ez - sz)) / ((ex - sx) ** 2 + (ez - sz) ** 2)));
  d = Math.min(d, Math.hypot(x - (sx + t * (ex - sx)), z - (sz + t * (ez - sz))));
  return d;
}

export function heightAt(x: number, z: number) {
  const r = Math.hypot(x, z);
  const t = r / shoreRadius(x, z);
  const land = 1 - smooth(0.86, 1.0, t);
  let hills = 1.6 * vnoise(x * 0.025, z * 0.025) + 0.6 * vnoise(x * 0.07 + 9, z * 0.07 + 3);
  // gentle forest rise to the north, meadow stays flat-ish
  hills += 2.2 * smooth(10, 70, -z) * smooth(0.95, 0.6, t);
  hills *= 1 - 0.6 * smooth(30, 0, Math.hypot(x - AREA.meadow.x, z - AREA.meadow.y));
  // paths are flattened a little so walking feels even
  const p = smooth(4, 0, pathDistance(x, z));
  let h = land * (1.0 + hills * (1 - 0.35 * p)) - (1 - land) * 2.2;
  // the pond
  const pd = Math.hypot(x - POND.x, z - POND.z);
  h -= 2.0 * smooth(POND.r + 3, POND.r - 4, pd);
  return h;
}
export const WATER_Y = 0;

// --- terrain mesh --------------------------------------------------------------------------
export function makeTerrain() {
  const size = 240, seg = 200;
  const geo = new THREE.PlaneGeometry(size, size, seg, seg).rotateX(-Math.PI / 2).toNonIndexed();
  const pos = geo.attributes.position as THREE.BufferAttribute;
  for (let i = 0; i < pos.count; i++) pos.setY(i, heightAt(pos.getX(i), pos.getZ(i)));
  const col = new Float32Array(pos.count * 3);
  const c = new THREE.Color();
  const grassA = new THREE.Color(0x86c95a), grassB = new THREE.Color(0x6fb54c), forestG = new THREE.Color(0x5d9e44);
  const sand = new THREE.Color(0xe8d59a), wetSand = new THREE.Color(0xcbb47a), path = new THREE.Color(0xd9bf86), under = new THREE.Color(0x9c8a5c);
  for (let f = 0; f < pos.count; f += 3) {
    const cx = (pos.getX(f) + pos.getX(f + 1) + pos.getX(f + 2)) / 3;
    const cz = (pos.getZ(f) + pos.getZ(f + 1) + pos.getZ(f + 2)) / 3;
    const cy = (pos.getY(f) + pos.getY(f + 1) + pos.getY(f + 2)) / 3;
    const n = vnoise(cx * 0.15, cz * 0.15);
    c.copy(grassA).lerp(grassB, n);
    c.lerp(forestG, smooth(20, 55, -cz) * 0.7);
    if (pathDistance(cx, cz) < 1.6 + 0.4 * n) c.copy(path).offsetHSL(0, 0, (n - 0.5) * 0.04);
    if (cy < 0.55) c.copy(sand).lerp(wetSand, smooth(0.55, 0.0, cy));
    if (cy < -0.25) c.copy(under);
    c.offsetHSL(0, 0, (hash(cx, cz) - 0.5) * 0.025);
    for (let k = 0; k < 3; k++) col.set([c.r, c.g, c.b], (f + k) * 3);
  }
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
  geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true }));
  mesh.receiveShadow = true;
  return mesh;
}

// --- water ---------------------------------------------------------------------------------
export function makeWater() {
  // bake the terrain height into a texture so the water shader can show depth and a foam edge
  const N = 256, span = 240;
  const data = new Float32Array(N * N);
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) data[j * N + i] = heightAt((i / (N - 1) - 0.5) * span, (j / (N - 1) - 0.5) * span);
  const tex = new THREE.DataTexture(data, N, N, THREE.RedFormat, THREE.FloatType);
  tex.magFilter = THREE.LinearFilter; tex.minFilter = THREE.LinearFilter; tex.needsUpdate = true;
  const uniforms = {
    time: { value: 0 }, heightTex: { value: tex }, span: { value: span },
    shallow: { value: new THREE.Color(0x7fe0d6) }, deep: { value: new THREE.Color(0x2f8fc4) },
    fogColor: { value: new THREE.Color(0xcfe8f5) }, fogNear: { value: 60 }, fogFar: { value: 220 },
  };
  const mat = new THREE.ShaderMaterial({
    uniforms, transparent: true, depthWrite: false,
    vertexShader: `
      uniform float time; varying vec3 vW; varying float vFog;
      void main(){
        vec3 p = position;
        vec4 w = modelMatrix * vec4(p,1.);
        w.y += 0.05*sin(w.x*0.35+time*1.3) + 0.04*sin(w.z*0.45+time*1.1);
        vW = w.xyz;
        vec4 mv = viewMatrix * w; vFog = -mv.z;
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: `
      uniform float time; uniform sampler2D heightTex; uniform float span;
      uniform vec3 shallow; uniform vec3 deep; uniform vec3 fogColor; uniform float fogNear; uniform float fogFar;
      varying vec3 vW; varying float vFog;
      void main(){
        vec2 uv = vW.xz/span + 0.5;
        float ground = (uv.x<0.||uv.x>1.||uv.y<0.||uv.y>1.) ? -6. : texture2D(heightTex, uv).r;
        float depth = max(0., vW.y - ground);
        vec3 c = mix(shallow, deep, smoothstep(0.0, 3.5, depth));
        float foam = smoothstep(0.35, 0.0, depth + 0.06*sin(time*2.0 + vW.x*1.7 + vW.z*1.3));
        c = mix(c, vec3(1.), foam*0.85);
        float sparkle = pow(max(0., sin(vW.x*2.1+time*2.3)*sin(vW.z*1.7-time*1.9)), 12.)*0.25;
        c += sparkle;
        float a = mix(0.55, 0.92, smoothstep(0.0, 1.5, depth));
        a = max(a, foam);
        c = mix(c, fogColor, smoothstep(fogNear, fogFar, vFog));
        gl_FragColor = vec4(c, a);
      }`,
  });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(900, 900, 180, 180).rotateX(-Math.PI / 2), mat);
  mesh.position.y = WATER_Y;
  mesh.renderOrder = 1;
  return { mesh, uniforms };
}

// --- scenery -------------------------------------------------------------------------------
export interface Collider { x: number; z: number; r: number }

let seed = 12345;
const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

const gltf = new GLTFLoader();
const fbx = new FBXLoader();

/** Wind sway for leaves and grass, applied per vertex by height above the instance origin. */
const windUniform = { value: 0 };
export function tickWind(t: number) { windUniform.value = t; }
function addSway(mat: THREE.Material, amount: number) {
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.windTime = windUniform;
    sh.vertexShader = 'uniform float windTime;\n' + sh.vertexShader.replace('#include <begin_vertex>', `
      #include <begin_vertex>
      #ifdef USE_INSTANCING
        vec3 ip = vec3(instanceMatrix[3][0], instanceMatrix[3][1], instanceMatrix[3][2]);
      #else
        vec3 ip = vec3(0.);
      #endif
      float sw = max(0., position.y) * ${amount.toFixed(4)};
      transformed.x += sin(windTime*1.6 + ip.x*0.3 + ip.z*0.2) * sw;
      transformed.z += cos(windTime*1.3 + ip.x*0.2 - ip.z*0.3) * sw * 0.6;`);
  };
  mat.customProgramCacheKey = () => 'sway' + amount;
}

async function instanced(file: string, places: THREE.Matrix4[], opts: { shadow?: boolean; sway?: number } = {}) {
  const g = await gltf.loadAsync(file);
  const group = new THREE.Group();
  g.scene.updateMatrixWorld(true);
  g.scene.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh) return;
    const geo = m.geometry.clone().applyMatrix4(m.matrixWorld);
    const mats = (Array.isArray(m.material) ? m.material : [m.material]).map((mm) => {
      const c = mm.clone();
      if (opts.sway) addSway(c, opts.sway);
      return c;
    });
    const im = new THREE.InstancedMesh(geo, mats.length === 1 ? mats[0] : mats, places.length);
    places.forEach((p, i) => im.setMatrixAt(i, p));
    im.castShadow = !!opts.shadow; im.receiveShadow = true;
    im.computeBoundingSphere();
    group.add(im);
  });
  return group;
}

const TREE_FILES = ['CommonTree_1', 'CommonTree_2', 'CommonTree_3', 'CommonTree_4', 'CommonTree_5'];
const PINE_FILES = ['Pine_1', 'Pine_2', 'Pine_3', 'Pine_4', 'Pine_5'];

/** Keeps scenery off paths, the pond, the farm yard, the start and the beach. */
function freeSpot(x: number, z: number, margin: number) {
  const h = heightAt(x, z);
  if (h < 0.7) return false;
  if (pathDistance(x, z) < 2.5 + margin) return false;
  if (Math.hypot(x - POND.x, z - POND.z) < POND.r + 4 + margin) return false;
  if (Math.hypot(x - START.x, z - START.z) < 6 + margin) return false;
  return true;
}

export async function makeScenery(scene: THREE.Scene, colliders: Collider[], keepClear: { x: number; z: number; r: number }[]) {
  const clear = (x: number, z: number, m: number) => freeSpot(x, z, m) && keepClear.every((k) => Math.hypot(x - k.x, z - k.z) > k.r + m);
  const mat4 = (x: number, z: number, s: number, rot = rand() * Math.PI * 2, sink = 0.05) =>
    new THREE.Matrix4().compose(new THREE.Vector3(x, heightAt(x, z) - sink, z), new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), rot), new THREE.Vector3(s, s, s));

  // Trees: dense in the north forest, a ring of them along the outer island, a few in the garden.
  const trees: Record<string, THREE.Matrix4[]> = {};
  const addTree = (file: string, x: number, z: number, s: number) => {
    (trees[file] ||= []).push(mat4(x, z, s));
    colliders.push({ x, z, r: 0.55 * s });
  };
  for (let i = 0; i < 2600 && Object.values(trees).flat().length < 240; i++) {
    const x = (rand() - 0.5) * 210, z = (rand() - 0.5) * 210;
    const r = Math.hypot(x, z), sr = shoreRadius(x, z);
    const inForest = z < -22 && Math.hypot(x - AREA.forest.x, z - AREA.forest.y) < 42;
    const outer = r > sr * 0.72 && r < sr * 0.9;
    const p = inForest ? 0.55 : outer ? 0.16 : 0.012;
    if (rand() > p) continue;
    // forest keeps a clearing for the deer
    if (inForest && Math.hypot(x - AREA.forest.x, z - AREA.forest.y) < 11) continue;
    if (!clear(x, z, 1.5)) continue;
    if (Object.values(trees).flat().some((m) => { const e = m.elements; return Math.hypot(e[12] - x, e[14] - z) < 4.2; })) continue;
    const pine = inForest ? rand() < 0.55 : rand() < 0.2;
    const list = pine ? PINE_FILES : TREE_FILES;
    addTree(list[Math.floor(rand() * list.length)], x, z, 0.9 + rand() * 0.5);
  }

  // Bushes, rocks, flowers, grass, clover.
  const scatter: Record<string, THREE.Matrix4[]> = {};
  const put = (file: string, n: number, sMin: number, sMax: number, margin: number, where: (x: number, z: number) => boolean = () => true, collide = 0) => {
    let placed = 0;
    for (let i = 0; i < n * 12 && placed < n; i++) {
      const x = (rand() - 0.5) * 210, z = (rand() - 0.5) * 210;
      if (!clear(x, z, margin) || !where(x, z)) continue;
      const s = sMin + rand() * (sMax - sMin);
      (scatter[file] ||= []).push(mat4(x, z, s));
      if (collide) colliders.push({ x, z, r: collide * s });
      placed++;
    }
  };
  put('Bush_Common', 70, 0.8, 1.3, 1, undefined, 0.6);
  put('Bush_Common_Flowers', 40, 0.8, 1.2, 1, undefined, 0.6);
  put('Rock_Medium_1', 14, 0.7, 1.4, 1, undefined, 0.6);
  put('Rock_Medium_2', 14, 0.7, 1.4, 1, undefined, 0.6);
  put('Rock_Medium_3', 14, 0.7, 1.4, 1, undefined, 0.6);
  put('Fern_1', 90, 0.8, 1.3, 0, (x, z) => z < -20);
  put('Mushroom_Common', 40, 0.8, 1.2, 0, (x, z) => z < -25);
  for (const f of ['Flower_3_Group', 'Flower_4_Group', 'Flower_3_Single', 'Flower_4_Single']) put(f, 70, 0.8, 1.3, 0, (x, z) => z > -25);
  for (const f of ['Grass_Common_Short', 'Grass_Wispy_Short']) put(f, 220, 0.7, 1.1, -1.5);
  put('Grass_Common_Tall', 60, 0.6, 0.9, -1.5);
  put('Clover_1', 120, 0.9, 1.3, -1.5);
  put('Pebble_Round_1', 60, 0.6, 1.2, -2);

  const jobs: Promise<THREE.Group>[] = [];
  for (const [f, list] of Object.entries(trees)) jobs.push(instanced(`/scenery/nature/${f}.gltf`, list, { shadow: true, sway: 0.006 }));
  for (const [f, list] of Object.entries(scatter)) {
    const big = /Bush|Rock/.test(f);
    jobs.push(instanced(`/scenery/nature/${f}.gltf`, list, { shadow: big, sway: /Grass|Fern|Flower|Clover/.test(f) ? 0.12 : /Bush/.test(f) ? 0.03 : 0 }));
  }
  for (const g of await Promise.all(jobs)) scene.add(g);
}

/** Farm buildings around the meadow, sized by height since the FBX units vary. */
export async function makeFarm(scene: THREE.Scene, colliders: Collider[]) {
  const items: { file: string; x: number; z: number; h: number; rot: number; r: number }[] = [
    { file: 'Barn', x: -70, z: -6, h: 7, rot: Math.PI / 2, r: 6 },
    { file: 'Windmill', x: -62, z: 26, h: 11, rot: 0.4, r: 3.5 },
    { file: 'Silo', x: -72, z: 8, h: 8, rot: 0, r: 2.6 },
    { file: 'Well', x: -36, z: 22, h: 2.4, rot: 0.8, r: 1.3 },
  ];
  const loaded = await Promise.all(items.map((i) => fbx.loadAsync(`/scenery/farm/${i.file}.fbx`)));
  items.forEach((it, k) => {
    const o = loaded[k];
    o.traverse((c) => { const m = c as THREE.Mesh; if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
    o.updateMatrixWorld(true);
    const b = new THREE.Box3().setFromObject(o), sz = b.getSize(new THREE.Vector3());
    o.scale.multiplyScalar(it.h / sz.y);
    o.rotation.y = it.rot;
    o.updateMatrixWorld(true);
    const b2 = new THREE.Box3().setFromObject(o), ctr = b2.getCenter(new THREE.Vector3());
    // sit on the lowest corner of the footprint so nothing floats on a slope
    const ground = Math.min(heightAt(it.x - 2, it.z - 2), heightAt(it.x + 2, it.z + 2), heightAt(it.x - 2, it.z + 2), heightAt(it.x + 2, it.z - 2));
    o.position.set(it.x - ctr.x + o.position.x, ground - b2.min.y + o.position.y - 0.1, it.z - ctr.z + o.position.z);
    scene.add(o);
    colliders.push({ x: it.x, z: it.z, r: it.r });
  });
  return items.map((i) => ({ x: i.x, z: i.z, r: i.r + 2 }));
}
