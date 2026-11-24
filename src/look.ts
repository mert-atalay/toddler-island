// The game's lighting and sky, shared by the lineup page now and the game later.
import * as THREE from 'three';

export function makeRenderer(canvas: HTMLCanvasElement) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  return renderer;
}

/** Warm late-morning sun, sky-blue fill from above, gentle haze, gradient sky dome. */
export function addSunnyLook(scene: THREE.Scene, shadowSize = 40) {
  scene.fog = new THREE.Fog(0xcfe8f5, 60, 220);

  const hemi = new THREE.HemisphereLight(0xbfe3ff, 0x8fb36a, 1.1);
  scene.add(hemi);

  const sun = new THREE.DirectionalLight(0xfff1d6, 2.4);
  sun.position.set(30, 45, 20);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  const c = sun.shadow.camera;
  c.left = -shadowSize; c.right = shadowSize; c.top = shadowSize; c.bottom = -shadowSize;
  c.near = 1; c.far = 150;
  sun.shadow.bias = -0.0005;
  sun.shadow.normalBias = 0.03;
  scene.add(sun, sun.target);

  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(400, 32, 16),
    new THREE.ShaderMaterial({
      side: THREE.BackSide,
      depthWrite: false,
      fog: false,
      uniforms: { top: { value: new THREE.Color(0x5fb3ec) }, bottom: { value: new THREE.Color(0xdff1fb) } },
      vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.); }',
      fragmentShader: 'uniform vec3 top; uniform vec3 bottom; varying vec3 vP; void main(){ float h = clamp(vP.y*1.6+0.1,0.,1.); gl_FragColor = vec4(mix(bottom, top, h), 1.); }',
    }),
  );
  scene.add(sky);
  return { sun, hemi, sky };
}

export function makeGrass(size: number) {
  const geo = new THREE.PlaneGeometry(size, size, 1, 1);
  geo.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(geo, new THREE.MeshLambertMaterial({ color: 0x8ccf5d }));
  mesh.receiveShadow = true;
  return mesh;
}
